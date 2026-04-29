`include "mfp_ahb_const.vh"


//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qian Hao Lam (qlam6@JH.edu)
// 
// Create Date: 10/19/2025 01:35:07 AM
// Design Name: 
// Module Name: rv_memsubsys
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------
// rv_memsubsys
// - Reuses MIPS i_cache / d_cache / tlb_8_entry
// - Single shared external memory port (I$ refill has priority)
// - Uncached MMIO via cpugpio (D-side only)
// - Raises RV32 page-fault traps (IF=12, LOAD=13, STORE=15)
// ----------------------------------------------------------------------------

module rv_memsubsys #(
  parameter BYPASS_TLB    = 1'b0,   // 1: bypass ITLB/DTLB (identity map)
  parameter BYPASS_ICACHE = 1'b0,   // 1: bypass I$ (always ready, no miss)
  parameter BYPASS_DCACHE = 1'b0    // 1: bypass D$ (direct to mem/mmio)
)(
  input         clk,
  input         memclk,
  input         clrn,
  input         no_cache_stall,
 // Flush & VM mode (from CSR adapter)
  input         tlb_flush,        // pulse: invalidate all TLB entries
  input         icache_flush,     // pulse: invalidate I$ tags
  input  [31:0] satp,             // CSR satp; MODE decides if TLB active
  // ---------- IF side ----------
  input  [31:0] v_pc,          // virtual PC from IF
  input         if_en,         // IF fetch enable (p_strobe)
  output [31:0] ins,           // instruction to ID
  output        if_ready,      // IF ready this cycle
  output        trap_if_v,     // IF trap pulse (ITLB miss)
  output [3:0]  cause_if,      // 12 = instruction page fault
  output        intr_if,       // always 0 here

  // ---------- MEM side ----------
  input  [31:0] v_addr,        // virtual address from MEM (load/store)
  input  [31:0] wdata,         // store data from MEM
  input         is_load,       // load in MEM stage (mm2reg)
  input         is_store,      // store in MEM stage (mwmem)
  output [31:0] rdata,         // loaded data back to MEM
  output        mem_ready,     // MEM side ready (handshake)
  output        trap_mem_v,    // MEM trap pulse (DTLB miss)
  output [3:0]  cause_mem,     // 13 = load PF, 15 = store PF
  output        intr_mem,      // always 0 here

  // ---------- Combined backpressure ----------
  output        stall_req,     // OR of IF/D wait (like ~no_cache_stall)

  // ---------- Shared external memory port ----------
  output [31:0] mem_a,
  output [31:0] mem_st_data,
  output        mem_access,
  output        mem_write,
  input  [31:0] mem_data,
  input         mem_ready_ext,

  // ---------- MMIO (GPIO) ----------
  input  [`MFP_N_SW-1 :0] IO_Switch,
  input  [`MFP_N_PB-1 :0] IO_PB,
  output [`MFP_N_LED-1:0] IO_LED,
  output [7:0]            IO_7SEGEN_N,
  output [6:0]            IO_7SEG_N,
  output                  IO_BUZZ,
  output                  IO_RGB_SPI_MOSI,
  output                  IO_RGB_SPI_SCK,
  output                  IO_RGB_SPI_CS,
  output                  IO_RGB_DC,
  output                  IO_RGB_RST,
  output                  IO_RGB_VCC_EN,
  output                  IO_RGB_PEN,
  output                  IO_CS,
  output                  IO_SCK,
  input                   IO_SDO,
  output                  miss_d,
  output                  tlb_active
);

  // -----------------------------
  // ITLB/DTLB (or bypass)
  // -----------------------------
//  wire [23:0] ipte_out, dpte_out;
//  wire        itlb_hit, dtlb_hit;
  wire [23:0] ipte_real, dpte_real;
  wire        itlb_hit_real, dtlb_hit_real;
  
  wire [19:0] itlb_vpn = v_pc   [31:12];
  wire [19:0] dtlb_vpn = v_addr [31:12]; 
  wire ptw_start;
  wire satp_mode_sv32 = satp[31];
  assign tlb_active     = (~BYPASS_TLB) & satp_mode_sv32;
  wire sel_ptw;
  wire sel_i;
  wire ptw_done;
  wire tlb_refill_pulse;
  // Select write index/random like the MIPS block expects
   // -----------------------------
  // D$ (or bypass), MMIO routing
  // -----------------------------
  // D$ <-> external or MMIO
  wire [31:0] d_m_a;
  wire [31:0] d_m_din;     // store data to ext/mmio
  wire [31:0] d_m_dout;    // read data from ext/mmio to D$
  wire        d_m_strobe;
  wire        d_m_rw;      // 1=write
  wire        d_m_ready_ext_sel;  // ready from ext mem path
  wire        d_p_ready;
  wire [31:0] d_p_din;     // to pipeline (rdata)
  wire tlbwr_i, tlbwr_d;
  wire [23:0] pte_in_i;
    wire [23:0] pte_in_d;
    // During write, drive TLB's vpn port with latched miss VPN; otherwise normal search VPN
    wire [19:0] itlb_vpn_in;
    wire [19:0] dtlb_vpn_in;
     wire [31:0] ic_hits;
    wire [31:0] ic_misses;
    wire [31:0] ic_refills;
    wire [31:0] ic_stall_cycles; 
    
    assign main_mem_data_write =d_m_din;
  // ITLB
  generate if (BYPASS_TLB) begin : g_itlb_bypass
    assign ipte_real = { v_pc[31:12] };  // identity, top-20 bits
    assign itlb_hit_real = 1'b1;
  end else begin : g_itlb_real
    tlb_8_entry itlb (
      .pte_in   (pte_in_i),
      .tlbwi    (1'b0),
      .tlbwr    (tlbwr_i),
      .index    (3'b000),
      .vpn      (itlb_vpn_in),
      .clk      (clk),
      .clrn     (clrn),
      .flush    (tlb_flush),
      .pte_out  (ipte_real),
      .tlb_hit  (itlb_hit_real)
    );
  end endgenerate

  // DTLB
  generate if (BYPASS_TLB) begin : g_dtlb_bypass
    assign dpte_real = { v_addr[31:12] };
    assign dtlb_hit_real = 1'b1;
  end else begin : g_dtlb_real
    tlb_8_entry dtlb (
      .pte_in  (pte_in_d),
      .tlbwi   (1'b0),
      .tlbwr   (tlbwr_d),
      .index   (3'b000),
      .vpn     (dtlb_vpn_in),
      .clk     (clk),
      .clrn    (clrn),
      .flush   (tlb_flush),
      .pte_out (dpte_real),
      .tlb_hit (dtlb_hit_real)
    );
  end endgenerate

  // Physical addresses (Sv-like 4KB pages; PFN[19:0] << 12 | page offset)
  wire [23:0] ipte_out = tlb_active ? ipte_real : { v_pc[31:12] };
   //  wire [23:0] dpte_out = tlb_active ? dpte_real : { v_addr[31:12] };
   wire mmio_bypass = (v_addr[31:20] == 12'hbf8);
   // If TLB is active BUT we are in the MMIO range, use identity mapping (v_addr)
   wire [23:0] dpte_out = (tlb_active && !mmio_bypass) ? dpte_real : { 4'b0, v_addr[31:12] };

  wire        itlb_hit = tlb_active ? itlb_hit_real : 1'b1;
  wire        dtlb_hit = tlb_active ? dtlb_hit_real : 1'b1;
  
  wire [31:0] i_phys = { ipte_out[19:0], v_pc  [11:0] };
  wire [31:0] d_phys = { dpte_out[19:0], v_addr[11:0] };

 //8888888888888888888888888          PAGE TABLE WALKER         888888888888888888888888888888
   // --- PTW integration ---
    // ---- PTW side classification ----
    reg        miss_is_if_q, miss_is_store_q;
    reg [19:0] miss_vpn_q;     // latched VPN[31:12] for TLB write
    reg [31:0] miss_va_q;      // latched full VA for PTW

    
    wire sv32_on = satp[31] & ~BYPASS_TLB;
    
    wire miss_if = sv32_on & (~itlb_hit) & if_en;
    assign miss_d  = sv32_on & (~dtlb_hit) & (is_load | is_store);
    
    
    always @(posedge clk or negedge clrn) begin
      if (!clrn) begin
        miss_is_if_q <= 1'b0;
        miss_is_store_q <= 1'b0;
        miss_vpn_q   <= 20'h0;
        miss_va_q    <= 32'h0;
      end else if (ptw_start) begin
        miss_is_if_q <= miss_if;
        miss_is_store_q <= (~miss_if) & is_store;   // only meaningful on D-side miss
        miss_vpn_q   <= miss_if ? v_pc[31:12] : v_addr[31:12];
        miss_va_q    <= miss_if ? v_pc        : v_addr;

      end
    end
    
        // After a successful refill, wait until the corresponding TLB visibly hits
    reg refill_wait;
    
    always @(posedge clk or negedge clrn) begin
      if (!clrn) begin
        refill_wait <= 1'b0;
      end else begin
        // Arm the holdoff on a successful refill
        if (tlb_refill_pulse)
          refill_wait <= 1'b1;
        else if (refill_wait) begin
          // Clear when the *same* side reports a hit on the latched VPN
          if (miss_is_if_q) begin
            if (itlb_hit_real && (itlb_vpn == miss_vpn_q))
              refill_wait <= 1'b0;
          end else begin
            if (dtlb_hit_real && (dtlb_vpn == miss_vpn_q))
              refill_wait <= 1'b0;
          end
        end
      end
    end
    // Latch which side we're servicing (IF has priority)
//    reg        ptw_is_if, ptw_is_store;
//    reg [31:0] ptw_va_hold;
//    always @(*) begin
//      if (miss_if) begin
//        ptw_is_if    = 1'b1;
//        ptw_is_store = 1'b0;
//        ptw_va_hold  = v_pc;
//      end else begin
//        ptw_is_if    = 1'b0;
//        ptw_is_store = is_store;
//        ptw_va_hold  = v_addr;
//      end
//    end
    
    // PTW instance
    wire        ptw_busy, ptw_found;
    wire [23:0] ptw_pte24;
    wire [3:0]  ptw_fault;
    

//    assign ptw_start = (miss_if | miss_d) & ~ptw_busy & ~refill_wait;  // Fixes Refill wait
    assign ptw_start = (miss_if | miss_d) & ~ptw_busy & ~refill_wait & ~ptw_done;  
    wire [31:0] ptw_m_a;
    wire        ptw_m_strobe;
    wire        ptw_m_ready = mem_ready_ext & sel_ptw;      // from arbiter
    wire [31:0] ptw_m_rdata = mem_data;
    
    ptw_sv32 u_ptw (
      .clk      (clk),
      .clrn     (clrn),
      .start    (ptw_start),
      .va       (miss_va_q),
      .is_store (miss_is_store_q),
      .satp     (satp),
    
      .m_a      (ptw_m_a),
      .m_strobe (ptw_m_strobe),
      .m_ready  (ptw_m_ready),
      .m_rdata  (ptw_m_rdata),
    
      .busy     (ptw_busy),
      .done     (ptw_done),
      .found    (ptw_found),
      .pte24    (ptw_pte24),
      .fault_cause(ptw_fault)
    );
    
    // Refill on success (random entry)
    assign tlb_refill_pulse = ptw_done & ptw_found;
    assign tlbwr_i = tlb_refill_pulse &  miss_is_if_q;
    assign tlbwr_d = tlb_refill_pulse & ~miss_is_if_q; 

    // Feed PTE payload only where we write (safe to tie always; used only on write)
    assign pte_in_i = ptw_pte24;
    assign pte_in_d = ptw_pte24;
    // During write, drive TLB's vpn port with latched miss VPN; otherwise normal search VPN
    assign itlb_vpn_in = tlbwr_i ? miss_vpn_q : v_pc[31:12];
    assign dtlb_vpn_in = tlbwr_d ? miss_vpn_q : v_addr[31:12];
        


  // Page-fault traps (IF=12, LOAD=13, STORE=15)
  assign intr_if   = 1'b0;
  assign intr_mem  = 1'b0;
//  assign trap_if_v = (~itlb_hit) & if_en & (~BYPASS_TLB);  // Before SATP addition
//  assign trap_if_v = (~itlb_hit) & if_en & tlb_active; // After SATP addition  
  assign trap_if_v  = ptw_done & ~ptw_found &  miss_is_if_q;  // After Hardware PTW
 
  assign cause_if  = 4'd12;

  // Note: assert MEM trap only when the access is active
  wire mem_access_req = is_load | is_store;


//  assign trap_mem_v   = dtlb_miss;  // Before Hardware PTW
  assign trap_mem_v = ptw_done & ~ptw_found & ~miss_is_if_q;
//  assign cause_mem    = is_store ? 4'd15 : 4'd13; // Before Hardware PTW
  assign cause_mem  = miss_is_store_q ? 4'd15 : 4'd13; // store or load page fault
  // -----------------------------
  // MMIO decode (physical)
  // -----------------------------
//  wire [2:0] HSEL;
//  pipelinedcpu_decode d_decode(.HADDR(d_phys), .HSEL(HSEL));
//  wire is_mmio_d = HSEL[2];     // GPIO region → uncached D side

  // Decode only when D is actually requesting, to avoid X-propagation
  wire d_req = mem_strobe;                     // same strobe that goes to D$
  wire [31:0] d_phys_dec = d_req ? d_phys : 32'h0000_0000;
  wire [2:0] HSEL_raw;
  pipelinedcpu_decode d_decode(.HADDR(d_phys_dec), .HSEL(HSEL_raw));
  wire is_mmio_d = d_req & HSEL_raw[2];        // known-0 when idle
  // Keep d_uncached well-defined even when idle
  // (BYPASS_DCACHE is a parameter constant, so this is 0/1 deterministically)
//  wire d_uncached = BYPASS_DCACHE ? 1'b1 : is_mmio_d;


  // -----------------------------
  // I$ (or bypass)
  // -----------------------------
  // I$ <-> external
  wire [31:0] i_m_a;
  wire        i_m_strobe;
  wire        i_m_ready;
  wire        i_cache_miss;
  wire        i_p_ready;
  wire [31:0] i_p_din;  // ins (to IF)

    wire if_ok   = itlb_hit & ~ptw_busy;
    wire mem_ok  = dtlb_hit & ~ptw_busy;
    
    wire if_strobe   = if_en & if_ok;
    wire mem_strobe  = (is_load | is_store) & mem_ok;
    

  generate if (BYPASS_ICACHE) begin : g_ic_bypass
    // Direct fetch: present mem port like i_cache would on every cycle
    // For simplicity, we still use the cache arbitration; but we flag "hit"
    // when external says ready.
    assign i_m_a      = i_phys;
    assign i_m_strobe = if_strobe;             // request instruction
    assign i_m_ready  = (mem_ready_ext);    // from arbiter path
    assign i_cache_miss = 1'b1;             // force arbitration to service IF
    assign i_p_ready  = i_m_ready;          // IF ready when ext mem ready
    assign i_p_din    = mem_data;           // instruction comes from ext mem
  end else begin : g_ic_real
    i_cache icache (
      .p_a      (i_phys),
      .p_din    (i_p_din),
      .p_strobe (if_strobe),
      .uncached (1'b0),         // keep I-side cached
      .p_ready  (i_p_ready),
      .cache_miss(i_cache_miss),
      .clk      (clk),
      .clrn     (clrn),
      .flush    (icache_flush),  // after SATP
      .m_a      (i_m_a),
      .m_dout   (mem_data),
      .m_strobe (i_m_strobe),
      .m_ready  (i_m_ready),
      .no_cache_stall (no_cache_stall),
      .ic_hits (ic_hits),
      .ic_misses(ic_misses),
      .ic_refills(ic_refills),
      .ic_stall_cycles (ic_stall_cycles)
    );
  end endgenerate

  assign ins      = i_p_din;
  assign if_ready = i_p_ready | trap_if_v;  // on trap, IF will redirect



  // GPIO device
  wire [31:0] gpio_dataout;
  wire        gpio_ready;

  // Select uncached path for MMIO
  wire d_uncached = is_mmio_d | BYPASS_DCACHE;

  // D$ proper
  generate if (BYPASS_DCACHE) begin : g_dc_bypass
    assign d_m_a      = d_phys;
    assign d_m_din    = wdata;
    assign d_m_strobe = mem_strobe;
    assign d_m_rw     = is_store;
    // p_ready from merge of ext or gpio
    // p_din  from selected data source
  end else begin : g_dc_real
    d_cache dcache (
      .p_a      (d_phys),
      .p_dout   (wdata),
      .p_din    (d_p_din),
      .p_strobe (mem_strobe),
      .p_rw     (is_store),
      .uncached (d_uncached),
      .p_ready  (d_p_ready),
      .clk      (clk),
      .clrn     (clrn),
      .m_a      (d_m_a),
      .m_dout   (d_m_dout),     // from ext/gpio mux (see below)
      .m_din    (d_m_din),      // to ext/gpio
      .m_strobe (d_m_strobe),
      .m_rw     (d_m_rw),
      .m_ready  (d_m_ready_ext_sel), // from ext/gpio ready mux
      .no_cache_stall (no_cache_stall),
      .dc_hits (dc_hits),
      .dc_misses(dc_misses),
      .dc_refills(dc_refills),
      .dc_stall_cycles (dc_stall_cycles)
    );
  end endgenerate



  // -----------------------------
  // GPIO MMIO hookup
  // -----------------------------
  // GPIO WE only when MMIO and D$ is requesting
  wire gpio_sel   = is_mmio_d & d_m_strobe;
  wire gpio_we    = gpio_sel & d_m_rw;    // writes only
  wire [31:0] gpio_datain = d_m_din;

  cpugpio u_gpio (
    .clk              (clk),
    .clrn             (clrn),
    .dataout          (gpio_dataout),
    .dataout_ready    (gpio_ready),
    .datain           (gpio_datain),
    .haddr            (d_phys[7:2]),
    .we               (gpio_we),
    .HSEL             (gpio_sel),   // perform access only on MMIO
    .IO_Switch        (IO_Switch),
    .IO_PB            (IO_PB),
    .IO_LED           (IO_LED),
    .IO_7SEGEN_N      (IO_7SEGEN_N),
    .IO_7SEG_N        (IO_7SEG_N),
    .IO_BUZZ          (IO_BUZZ),
    .IO_RGB_SPI_MOSI  (IO_RGB_SPI_MOSI), 
    .IO_RGB_SPI_SCK   (IO_RGB_SPI_SCK),
    .IO_RGB_SPI_CS    (IO_RGB_SPI_CS),
    .IO_RGB_DC        (IO_RGB_DC),
    .IO_RGB_RST       (IO_RGB_RST),
    .IO_RGB_VCC_EN    (IO_RGB_VCC_EN),
    .IO_RGB_PEN       (IO_RGB_PEN),
    .IO_SDO           (IO_SDO),
    .IO_CS            (IO_CS),
    .IO_SCK           (IO_SCK)
  );

  // -----------------------------
  // External memory arbitration
  // (I$ miss/refill has priority over D$)
  // -----------------------------

    assign sel_i   = i_cache_miss & ~BYPASS_ICACHE & ~sel_ptw;  // After HW PTW
    assign sel_ptw = ptw_busy;    
    
    assign mem_a       = sel_ptw ? ptw_m_a      : (sel_i ? i_m_a : d_m_a);  // After HW PTW    
    assign mem_st_data = d_m_din;                            // D writes only  // After HW PTW
    assign mem_access  = sel_ptw ? ptw_m_strobe : (sel_i ? i_m_strobe : (d_m_strobe & ~gpio_sel));  // After HW PTW
    assign mem_write   = sel_ptw ? 1'b0         : (sel_i ? 1'b0       : (d_m_rw & ~gpio_sel));  // After HW PTW

  // Feed read data back into caches (both always see mem_data; they use m_ready)
  // Ready demux to each client (and gpio path to D when MMIO)
//  assign i_m_ready          = mem_ready_ext &  sel_i;   // Before HW PTW
//  wire   d_ready_from_mem   = mem_ready_ext & ~sel_i & ~gpio_sel; // Before HW PTW
//  wire   d_ready_from_gpio  = gpio_ready    &  gpio_sel; // Before HW PTW
//  assign d_m_ready_ext_sel  = d_ready_from_mem | d_ready_from_gpio; // Before HW PTW

assign i_m_ready         = mem_ready_ext &  sel_i  & ~sel_ptw;  // After HW PTW
wire   d_ready_from_mem  = mem_ready_ext & ~sel_i  & ~sel_ptw & ~gpio_sel;  // After HW PTW
wire   d_ready_from_gpio = gpio_ready    &  gpio_sel;  // After HW PTW
assign d_m_ready_ext_sel = d_ready_from_mem | d_ready_from_gpio;  // After HW PTW

  // Data back to D$:
  // - For MMIO reads, use GPIO dataout; otherwise use mem_data
  assign d_m_dout = gpio_sel ? gpio_dataout : mem_data;

  // -----------------------------
  // Outputs to pipeline (MEM side)
  // -----------------------------
  assign rdata     = d_p_din;
  assign mem_ready = d_p_ready | trap_mem_v;   // on trap, pipeline redirects

  // -----------------------------
  // Global stall request
  // - IF must wait for instruction
  // - MEM must wait for load/store completion (and not a trap)
  // -----------------------------
  assign stall_req = ptw_busy |
        (~if_ready & ~trap_if_v) |
        (mem_access_req & ~mem_ready & ~trap_mem_v);
// assign stall_req = ptw_busy |
//        (~if_ready & ~trap_if_v) |
//        (miss_d & ~mem_ready & ~trap_mem_v);

//    assign miss_d  = sv32_on & (~dtlb_hit) & (is_load | is_store);

  


endmodule
