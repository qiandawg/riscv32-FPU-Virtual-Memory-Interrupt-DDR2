// mfp_nexys4_ddr.v
// January 1, 2017
// Modified by N Beser for Li Architecture 11/2/2017
//
// Instantiate the sccomp system and rename signals to
// match the GPIO, LEDs and switches on Digilent's (Xilinx)
// Nexys4 DDR board

// Outputs:
// 16 LEDs (IO_LED) 
// Inputs:
// 16 Slide switches (IO_Switch),
// 5 Pushbuttons (IO_PB): {BTNU, BTND, BTNL, BTNC, BTNR}
//

`include "mfp_ahb_const.vh"

module mfp_nexys4_ddr( 
                        input                   CLK100MHZ,
                        input                   CPU_RESETN,
                        input                   BTNU, BTND, BTNL, BTNC, BTNR, 
                        input  [`MFP_N_SW-1 :0] SW,
                        output [`MFP_N_LED-1:0] LED,
                        inout  [4           :1] JA,
                        inout  [ 8          :1] JB,
                        output [ 7          :0] AN,
                        output                  CA, CB, CC, CD, CE, CF, CG,
                        output [ 10          :1] JC,
                        output [ 4          :1] JD,
                        input                   UART_TXD_IN,

                        // DDR2 SDRAM interface (Nexys A7 onboard MT47H64M16HR-25E)
                        inout  [15:0]           ddr2_dq,
                        inout  [ 1:0]           ddr2_dqs_n,
                        inout  [ 1:0]           ddr2_dqs_p,
                        output [12:0]           ddr2_addr,
                        output [ 2:0]           ddr2_ba,
                        output                  ddr2_ras_n,
                        output                  ddr2_cas_n,
                        output                  ddr2_we_n,
                        output                  ddr2_ck_p,
                        output                  ddr2_ck_n,
                        output                  ddr2_cke,
                        output                  ddr2_cs_n,
                        output [ 1:0]           ddr2_dm,
                        output                  ddr2_odt);

  // Press btnCpuReset to reset the processor. 
        
  wire clk_out; 
  wire locked;
 
  wire CPU_RESETX;
  wire reset;
  assign CPU_RESET = reset;
  assign CPU_RESETX =locked & ~CPU_RESET & CPU_RESETN; 
  
   clk_wiz_0 clk_wiz_0(.clk_in1(CLK100MHZ), .reset(reset),.locked(locked),.clk_out1(clk_out));
  //clk_wiz_0 clk_wiz_0(.clk_in1(CLK100MHZ), .clk_out1(clk_out));

  // Dedicated PLL for MIG: 200 MHz DDR2 reference clock.
  // Ported from mig_example (Digilent reference) so the DDR2 clocking path is
  // byte-identical to the bring-up project where LED[0] went green.
  wire clk_mem_200;
  wire pll_mem_locked;
  pll pll_mem (
      .clk_in (CLK100MHZ),
      .clk_mem(clk_mem_200),
      .clk_cpu(/* unused here; CPU still runs from clk_wiz_0 */),
      .locked (pll_mem_locked)
  );

   // Instantiate the button debouncer for reset
    button_debounce #(
        .DEBOUNCE_PERIOD(1000000)  // 10ms at 100MHz
    ) reset_debouncer (
        .clk(CLK100MHZ),
        .btn_in(BTNC),
        .btn_debounced(reset)
    );

button_debounce #(
        .DEBOUNCE_PERIOD(1000000)  // 10ms at 100MHz
    ) intr_debouncer (
        .clk(CLK100MHZ),
        .btn_in(BTNU),
        .btn_debounced(intr)
    );


   // Simple counter to demonstrate the 50MHz clock is working
    // This can be monitored in the ILA
    reg [26:0] counter = 0;
    always @(posedge clk_out or posedge reset) begin
        if (reset)
            counter <= 0;
        else
            counter <= counter + 1;
    end
//  reg         SI_ClkIn,SI_Reset_N;
  wire [31:0] pc,inst,eal,mal,wres;
  
  wire [31:0] e3d,wd;
  wire  [4:0] e1n, e2n, e3n, wn;
  wire ww, stl_lw, stl_fp, stl_lwc1, stl_swc1, stl, e;

  // Debug: MIG DDR2 calibration status. Slow-changing, registered and then
  // surfaced on LED[15] so the user can visually confirm the DDR2 PHY is
  // alive before the CPU ever tries to use it. Set DDR2_DEBUG_LED to 0 to
  // restore the CPU's LED[15].
  `define DDR2_DEBUG_LED 1
  wire                        init_calib_complete;
  wire [`MFP_N_LED-1:0]       cpu_leds;

  pl_computer cpu(
                   .SI_CLK100MHZ(CLK100MHZ),
                    .lock(locked),
                    .SI_ClkIn(clk_out),
                    .SI_Reset_N(CPU_RESETX),                  
                    .pc(pc),
                    .inst(inst),
                    .eal(eal),
                    .mal(mal),
                    .wres(wres),
                    .e3d(e3d),
                    .wd(wd),
                    .e1n(e1n),
                    .e2n(e2n),
                    .e3n(e3n),
                    .wn(wn),
                    .ww(ww),
                    .stl_lw(stl_lw),
                    .stl_fp(stl_fp),
                    .stl_lwc1(stl_lwc1),
                    .stl_swc1(stl_swc1),
                    .stl(stl),
                    .e(e),
                    .IO_Switch(SW),
                    .IO_PB({BTNU, BTND, BTNL, BTNC, BTNR}),
                    .IO_LED(cpu_leds),
                    .IO_7SEGEN_N(AN),
                    .IO_7SEG_N({CA,CB,CC,CD,CE,CF,CG}), 
                    .IO_BUZZ(JD[1]),
                    .IO_RGB_SPI_MOSI(JC[2]),
                    .IO_RGB_SPI_SCK(JC[4]),
                    .IO_RGB_SPI_CS(JC[1]),
                    .IO_RGB_DC(JC[7]),
                    .IO_RGB_RST(JC[8]),
                    .IO_RGB_VCC_EN(JC[9]),
                    .IO_RGB_PEN(JC[10]),
                    .IO_CS(JA[1]),
                    .IO_SCK(JA[4]),
                    .IO_SDO(JA[3]),
                    .UART_RX(UART_TXD_IN),
                    .JB(JB),
                    .counter(counter),
                    .intr(intr),

                    // DDR2 pass-through
                    .clk_mem_200        (clk_mem_200),
                    .init_calib_complete(init_calib_complete),
                    .ddr2_dq            (ddr2_dq),
                    .ddr2_dqs_n         (ddr2_dqs_n),
                    .ddr2_dqs_p         (ddr2_dqs_p),
                    .ddr2_addr          (ddr2_addr),
                    .ddr2_ba            (ddr2_ba),
                    .ddr2_ras_n         (ddr2_ras_n),
                    .ddr2_cas_n         (ddr2_cas_n),
                    .ddr2_we_n          (ddr2_we_n),
                    .ddr2_ck_p          (ddr2_ck_p),
                    .ddr2_ck_n          (ddr2_ck_n),
                    .ddr2_cke           (ddr2_cke),
                    .ddr2_cs_n          (ddr2_cs_n),
                    .ddr2_dm            (ddr2_dm),
                    .ddr2_odt           (ddr2_odt));

  // Final LED muxing. init_calib_complete lives on the MIG ui_clk domain,
  // so route it through a 2-FF synchronizer before driving a pad.
  wire init_calib_sync;
  ff_sync #(.WIDTH(1)) u_calib_sync (
      .clk     (clk_out),
      .rst_p   (~CPU_RESETX),
      .in_async(init_calib_complete),
      .out     (init_calib_sync)
  );

  `ifdef DDR2_DEBUG_LED
    assign LED = {init_calib_sync, cpu_leds[`MFP_N_LED-2:0]};
  `else
    assign LED = cpu_leds;
  `endif


  // ILA: same 24 probes / widths as ila_0 IP; clk = CPU clk (clk_wiz clk_out) for clean PC/inst.
  // DDR2 smoke debug: ext mem handshake, MEM-stage addr, I$/D$ arb (sel_i), PTW stall.
  // Probes 17–18 + 20–23 tap physical_memory_hybrid / mem_example (some MIG nets are ui_clk;
  // sampled on CPU clk for ILA — fine for bring-up, not for timing analysis).
  wire [26:0] ila_probe5 = {
    cpu.ext_mem_a[31],
    cpu.ext_mem_ready,
    cpu.ext_mem_write,
    cpu.ext_mem_access,
    cpu.ext_mem_a[22:0]
  };
  wire [7:0] ila_probe17 = {
    cpu.u_phys_mem.strobe_redge,
    cpu.u_phys_mem.pending_ddr,
    cpu.u_phys_mem.busy_ddr,
    cpu.u_phys_mem.memex_ready,
    cpu.u_phys_mem.ddr2_complete,
    cpu.u_phys_mem.memex_wstrobe,
    cpu.u_phys_mem.memex_rstrobe,
    cpu.u_phys_mem.rw
  };
  wire [6:0] ila_probe18 = {
    cpu.u_phys_mem.u_memex.ui_clk_sync_rst,
    cpu.u_phys_mem.u_memex.mem_rdy,
    cpu.u_phys_mem.u_memex.mem_wdf_rdy,
    cpu.u_phys_mem.u_memex.mem_en,
    cpu.u_phys_mem.u_memex.state
  };
  wire       ila_probe13 = cpu.mwmem | cpu.mswfp;

  ila_0 my_ila (
      .clk(clk_out),
      .probe0(inst),
      .probe1(pc),
      .probe2(cpu.ext_mem_access),
      .probe3(cpu.SI_Reset_N),
      .probe4(cpu.lock),
      .probe5(ila_probe5),
      .probe6(cpu.IO_Switch),
      .probe7(cpu.IO_LED),
      .probe8(cpu.ms_stall_req),
      .probe9(cpu.memsys.sel_i),
      .probe10(cpu.ext_mem_a),
      .probe11(cpu.ext_mem_st_data),
      .probe12(cpu.mldst),
      .probe13(ila_probe13),
      .probe14(cpu.mal),
      .probe15(cpu.ext_mem_dout),
      .probe16(cpu.ms_mem_ready),
      .probe17(ila_probe17),
      .probe18(ila_probe18),
      .probe19(cpu.ms_if_ready),
      .probe20(cpu.u_phys_mem.u_memex.init_calib_complete),
      .probe21(cpu.u_phys_mem.u_memex.transaction_complete),
      .probe22(cpu.u_phys_mem.u_memex.complete),
      .probe23(cpu.u_phys_mem.strobe)
  );


          
endmodule
