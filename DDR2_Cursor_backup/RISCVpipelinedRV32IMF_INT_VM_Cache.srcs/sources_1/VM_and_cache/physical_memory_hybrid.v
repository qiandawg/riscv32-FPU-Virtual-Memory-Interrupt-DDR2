/************************************************
  Hybrid BRAM + DDR2 physical memory.
  Drop-in replacement for physical_memory.v.

  Memory map:
    a[31] == 0 -> existing 4x BRAM (boot code, low addresses, unchanged)
    a[31] == 1 -> DDR2 via mem_example (128 MiB window at 0x80000000)

  Public port list matches physical_memory.v and adds:
    - clk_mem_200          : 200 MHz MIG reference clock (from top-level pll)
    - ddr2_*               : DDR2 SDRAM pads, routed up to the top level
    - init_calib_complete  : synced MIG calibration status (debug LED)
************************************************/
`include "mfp_ahb_const.vh"
`include "io_def.vh"

module physical_memory_hybrid (
    a, dout, din, strobe, rw, ready, clk, memclk, clrn,
    clk_mem_200,
    ddr2_dq, ddr2_dqs_n, ddr2_dqs_p,
    ddr2_addr, ddr2_ba,
    ddr2_ras_n, ddr2_cas_n, ddr2_we_n,
    ddr2_ck_p, ddr2_ck_n, ddr2_cke, ddr2_cs_n,
    ddr2_dm, ddr2_odt,
    init_calib_complete
);
    input         clk, memclk, clrn;
    input  [31:0] a;
    output [31:0] dout;
    input  [31:0] din;
    input         strobe;
    input         rw;
    output        ready;

    input         clk_mem_200;

    inout  [15:0] ddr2_dq;
    inout  [ 1:0] ddr2_dqs_n;
    inout  [ 1:0] ddr2_dqs_p;
    output [12:0] ddr2_addr;
    output [ 2:0] ddr2_ba;
    output        ddr2_ras_n;
    output        ddr2_cas_n;
    output        ddr2_we_n;
    output [ 0:0] ddr2_ck_p;
    output [ 0:0] ddr2_ck_n;
    output [ 0:0] ddr2_cke;
    output [ 0:0] ddr2_cs_n;
    output [ 1:0] ddr2_dm;
    output [ 0:0] ddr2_odt;

    output        init_calib_complete;

    // .mem files for BRAM boot image. Kept byte-identical to physical_memory.v
    // so existing firmware (RISCV_TLB_LEDCount) runs without changes.
//    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem0.mem";
//    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem1.mem";
//    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem2.mem";
//    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem3.mem";
    
    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem0.mem";
    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem1.mem";
    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem2.mem";
    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem3.mem";
    
     

    wire ddr_sel  =  a[31];
    wire bram_sel = ~a[31];

    //-----------------------------------------------------------------------
    // BRAM path (identical decode to the original physical_memory.v,
    // just additionally gated by ~a[31])
    //-----------------------------------------------------------------------
    wire [31:0] mem_data_out0;
    wire [31:0] mem_data_out1;
    wire [31:0] mem_data_out2;
    wire [31:0] mem_data_out3;   

    wire bram_strobe   = strobe & bram_sel;
    wire write_enable0 = bram_sel & ~a[29] & ~a[28] & rw;
    wire write_enable1 = bram_sel & ~a[29] &  a[28] & rw;
    wire write_enable2 = bram_sel &  a[29] & ~a[13] & rw;
    wire write_enable3 = bram_sel &  a[29] &  a[13] & rw;

    uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE0), .READ_DELAY(0)) system_ram0
         (.clk(memclk), .we(write_enable0), .cs(bram_strobe), .addr(a), .data_in(din), .data_out(mem_data_out0));
    uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE1), .READ_DELAY(0)) system_ram1
         (.clk(memclk), .we(write_enable1), .cs(bram_strobe), .addr(a), .data_in(din), .data_out(mem_data_out1));
    uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE2), .READ_DELAY(0)) system_ram2
         (.clk(memclk), .we(write_enable2), .cs(bram_strobe), .addr(a), .data_in(din), .data_out(mem_data_out2));
    uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE3), .READ_DELAY(0)) system_ram3
         (.clk(memclk), .we(write_enable3), .cs(bram_strobe), .addr(a), .data_in(din), .data_out(mem_data_out3));

    wire [31:0] m_out32  = a[13] ? mem_data_out3 : mem_data_out2;
    wire [31:0] m_out10  = a[28] ? mem_data_out1 : mem_data_out0;
    wire [31:0] bram_out = a[29] ? m_out32       : m_out10;

    // 6-cycle ready counter (matches original physical_memory.v)
    reg [2:0] wait_counter;
    reg       bram_ready;
    always @ (negedge clrn or posedge clk) begin
        if (!clrn) begin
            wait_counter <= 3'b0;
            bram_ready   <= 1'b0;
        end else if (strobe & bram_sel) begin
            if (wait_counter == 3'h5) begin
                bram_ready   <= 1'b1;
                wait_counter <= 3'b0;
            end else begin
                bram_ready   <= 1'b0;
                wait_counter <= wait_counter + 3'b1;
            end
        end else begin
            bram_ready   <= 1'b0;
            wait_counter <= 3'b0;
        end
    end

    //-----------------------------------------------------------------------
    // DDR2 path
    //
    // The CPU-side contract holds `strobe` HIGH for the entire transaction
    // and deasserts it after seeing `ready`. mem_example expects a one-cycle
    // rstrobe/wstrobe pulse, with `addr`/`data_in`/`width` stable until its
    // `transaction_complete` asserts.
    //
    // FSM (CPU clock domain):
    //   IDLE    : no pending work
    //   PENDING : strobe rose while ddr_sel=1; waiting for mem_example ready
    //   BUSY    : submitted, waiting for transaction_complete
    //
    // pending_ddr is set by the strobe rising edge; it latches so we can
    // wait here even if calibration has not completed yet.
    //-----------------------------------------------------------------------
    reg  strobe_prev;
    reg  ddr_sel_prev;
    always @ (negedge clrn or posedge clk) begin
        if (!clrn) begin
            strobe_prev  <= 1'b0;
            ddr_sel_prev <= 1'b0;
        end else begin
            strobe_prev  <= strobe;
            ddr_sel_prev <= ddr_sel;
        end
    end
    wire strobe_redge = strobe & ~strobe_prev;
    wire ddr_sel_redge = ddr_sel & ~ddr_sel_prev;

    wire        memex_ready;
    wire        ddr2_complete;
    wire [63:0] memex_data_out;

    reg  pending_ddr;
    reg  busy_ddr;
    wire submit_pulse = pending_ddr & memex_ready & ~busy_ddr;
    // Robust request detect:
    // - normal case: capture strobe rising edge
    // - reset-edge case: if strobe is already high right after reset deasserts,
    //   still latch one pending DDR request
    // - decode-switch case: if strobe is already high and decode changes into
    //   DDR (ddr_sel rises), still latch one pending DDR request
    wire capture_req  = ddr_sel & strobe & ~pending_ddr & ~busy_ddr;

    always @ (negedge clrn or posedge clk) begin
        if (!clrn) begin
            pending_ddr <= 1'b0;
            busy_ddr    <= 1'b0;
        end else begin
            if (capture_req & (strobe_redge | ddr_sel_redge| ~strobe_prev)) 
                pending_ddr <= 1'b1;
            else if (submit_pulse)                              pending_ddr <= 1'b0;

            if (submit_pulse)      busy_ddr <= 1'b1;
            else if (ddr2_complete) busy_ddr <= 1'b0;
        end
    end

    wire memex_wstrobe = submit_pulse &  rw;
    wire memex_rstrobe = submit_pulse & ~rw;

    mem_example u_memex (
        .clk_mem   (clk_mem_200),
        .rst_n     (clrn),

        .ddr2_dq   (ddr2_dq),
        .ddr2_dqs_n(ddr2_dqs_n),
        .ddr2_dqs_p(ddr2_dqs_p),
        .ddr2_addr (ddr2_addr),
        .ddr2_ba   (ddr2_ba),
        .ddr2_ras_n(ddr2_ras_n),
        .ddr2_cas_n(ddr2_cas_n),
        .ddr2_we_n (ddr2_we_n),
        .ddr2_ck_p (ddr2_ck_p),
        .ddr2_ck_n (ddr2_ck_n),
        .ddr2_cke  (ddr2_cke),
        .ddr2_cs_n (ddr2_cs_n),
        .ddr2_dm   (ddr2_dm),
        .ddr2_odt  (ddr2_odt),

        .cpu_clk              (clk),
        .addr                 (a[27:0]),
        .width                (`RAM_WIDTH32),
        .data_in              ({32'h0, din}),
        .data_out             (memex_data_out),
        .rstrobe              (memex_rstrobe),
        .wstrobe              (memex_wstrobe),
        .transaction_complete (ddr2_complete),
        .ready                (memex_ready),

        .init_calib_complete  (init_calib_complete)
    );

    // mem_example byte-swaps on write and again on read, so for
    // width=RAM_WIDTH32 / addr[0]=0 the CPU word round-trips through
    // data_out[63:32].
    wire [31:0] ddr_out = memex_data_out[63:32];

    assign dout  = ddr_sel ? ddr_out       : bram_out;
    assign ready = ddr_sel ? ddr2_complete : bram_ready;

endmodule
