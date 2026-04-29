// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (win64) Build 5239630 Fri Nov 08 22:35:27 MST 2024
// Date        : Sun Apr 19 21:12:32 2026
// Host        : QianPC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/JHU_Classes/Spring2026_DDR2/mig_example/mig_example.runs/pll_synth_1/pll_stub.v
// Design      : pll
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CORE_GENERATION_INFO = "pll,clk_wiz_v6_0_15_0_0,{component_name=pll,use_phase_alignment=false,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0,feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=2,clkin1_period=10.000,clkin2_period=10.000,use_power_down=false,use_reset=false,use_locked=true,use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}" *) 
module pll(clk_mem, clk_cpu, locked, clk_in)
/* synthesis syn_black_box black_box_pad_pin="locked,clk_in" */
/* synthesis syn_force_seq_prim="clk_mem" */
/* synthesis syn_force_seq_prim="clk_cpu" */;
  output clk_mem /* synthesis syn_isclock = 1 */;
  output clk_cpu /* synthesis syn_isclock = 1 */;
  output locked;
  input clk_in;
endmodule
