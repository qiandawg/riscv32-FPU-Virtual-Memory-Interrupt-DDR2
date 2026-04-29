module debug_control(
    input serial_rx,
    output serial_tx,

    input sys_rstn, //System reset. Should NOT be externally tied to our cpu_resetn_cpu output

    input cpu_clk,

    output[31:0] cpu_mem_addr,
    output[31:0] cpu_debug_to_mem_data,
    input[31:0] cpu_mem_to_debug_data,
    input cpu_mem_to_debug_data_ready,
    output cpu_mem_ce,
    output cpu_mem_we,

    output cpu_halt_cpu,
    output cpu_resetn_cpu
    );

    // 50MHz / 115200 = 434 Clocks Per Bit.
    parameter CLKS_PER_BIT = 434;

    wire[31:0] addr;
    wire[31:0] data_out;
    wire[31:0] data_in;
    wire data_out_ready;
    wire data_in_valid;
    wire cpu_reset_p;
    
    //The UART debug-monitor
    cmdproc #(.CLKS_PER_BIT(CLKS_PER_BIT)) debug_uart
        (.clk(cpu_clk), .rst_n(sys_rstn), .serial_rx(serial_rx), .serial_tx(serial_tx), 
         .addr(addr), .data_out(data_out), .data_in(data_in), .data_out_ready(data_out_ready),
         .data_write_complete(1'b1), .data_in_valid(data_in_valid),
         .data_imem_p_dmem_n(), .cpu_halt(cpu_halt_cpu), .cpu_step(), 
         .cpu_reset_p(cpu_reset_p));
        
    assign cpu_resetn_cpu = ~cpu_reset_p;
    
    assign cpu_mem_addr = addr;
    assign cpu_debug_to_mem_data = data_out;
    
    assign data_in = cpu_mem_to_debug_data;
    assign cpu_mem_we = data_out_ready;
    
    assign data_in_valid = cpu_mem_to_debug_data_ready;
    assign cpu_mem_ce = cpu_halt_cpu;

endmodule
