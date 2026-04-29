/************************************************
  The Verilog HDL code example is from the book
  Computer Principles and Design in Verilog HDL
  by Yamin Li, published by A JOHN WILEY & SONS
************************************************/
`include "mfp_ahb_const.vh"
module physical_memory (a,dout,din,strobe,rw,
                     ready,clk,memclk,clrn);
    input         clk, memclk, clrn;                     // clocks and reset
    input  [31:0] a;                                     // memory address
    output [31:0] dout;                                  // data out
    input  [31:0] din;                                   // data in
    input         strobe;                                // strobe
    input         rw;                                    // read/write
    output        ready;                                 // memory ready
    wire   [31:0] mem_data_out0;
    wire   [31:0] mem_data_out1;
    wire   [31:0] mem_data_out2;
    wire   [31:0] mem_data_out3;
    wire   [31:0] modified_addr3;
    // for memory ready
    reg     [2:0] wait_counter;
    reg           ready;
    
    //Be sure to use forward slashes '/', even on Windows
//    parameter RAM_FILE0 = "/home/fpgauser/525.612Distro/mips-cpu/Software/Assembly/pipelinefulltlbpmodOLEDrgbtestC/mem0.mem";
//    parameter RAM_FILE1 = "/home/fpgauser/525.612Distro/mips-cpu/Software/Assembly/pipelinefulltlbpmodOLEDrgbtestC/mem1.mem";
//    parameter RAM_FILE2 = "/home/fpgauser/525.612Distro/mips-cpu/Software/Assembly/pipelinefulltlbpmodOLEDrgbtestC/mem2.mem";
//    parameter RAM_FILE3 = "/home/fpgauser/525.612Distro/mips-cpu/Software/Assembly/pipelinefulltlbpmodOLEDrgbtestC/mem3.mem";
//    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_VM_Cache_test2/mem0.mem";
//    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_VM_Cache_test2/mem1.mem";
//    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_VM_Cache_test2/mem2.mem";
//    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_VM_Cache_test2/mem3.mem";

//    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_pipeSwitchLED7Seg/mem0.mem";
//    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_pipeSwitchLED7Seg/mem1.mem";
//    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_pipeSwitchLED7Seg/mem2.mem";
//    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_pipeSwitchLED7Seg/mem3.mem";
    
    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem0.mem";
    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem1.mem";
    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem2.mem";
    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_TLB_LEDCount/mem3.mem";
    
    
//    parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCVLiTestint02/mem0.mem";
//    parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCVLiTestint02/mem1.mem";
//    parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCVLiTestint02/mem2.mem";
//    parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCVLiTestint02/mem3.mem";
    
    always @ (negedge clrn or posedge clk) begin
        if (!clrn) begin
            wait_counter <= 3'b0;
        end else begin
            if (strobe) begin
                if (wait_counter == 3'h5) begin          // 6 clock cycles
                    ready <= 1;                          // ready
                    wait_counter <= 3'b0;
                end else begin
                    ready <= 0;
                    wait_counter <= wait_counter + 3'b1;
                end
               end else  begin
                ready <= 0;
                wait_counter <= 3'b0;
            end
        end
    end
    

    // 31 30 29 28 ... 15 14 13 12 ...  3  2  1  0
    //  0  0  0  0      0  0  0  0      0  0  0  0   (0) 0x0000_0000
    //  0  0  0  1      0  0  0  0      0  0  0  0   (1) 0x1000_0000
    //  0  0  1  0      0  0  0  0      0  0  0  0   (2) 0x2000_0000
    //  0  0  1  0      0  0  1  0      0  0  0  0   (3) 0x2000_2000

    wire   [31:0] m_out32 = a[13] ? mem_data_out3 : mem_data_out2;
    wire   [31:0] m_out10 = a[28] ? mem_data_out1 : mem_data_out0;
    wire   [31:0] mem_out = a[29] ? m_out32       : m_out10;
    assign   dout    = ready ? mem_out       : 32'h0000_0000;
 
    // (0) 0x0000_0000- (virtual address 0x8000_0000-)
     wire          write_enable0 = ~a[29] & ~a[28] & rw;
     uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE0), .READ_DELAY(0)) system_ram0
          (.clk(memclk), .we(write_enable0), .cs(strobe), .addr(a), .data_in(din), .data_out(mem_data_out0));
     wire          write_enable1 = ~a[29] &  a[28] & rw;  
     uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE1), .READ_DELAY(0)) system_ram1
          (.clk(memclk), .we(write_enable1), .cs(strobe), .addr(a), .data_in(din), .data_out(mem_data_out1));
     wire          write_enable2 = a[29] & ~a[13] & rw;
     uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE2), .READ_DELAY(0)) system_ram2
          (.clk(memclk), .we(write_enable2), .cs(strobe), .addr(a), .data_in(din), .data_out(mem_data_out2));
     wire          write_enable3 = a[29] & a[13] & rw;   
//     assign modified_addr3 = a - 32'h2000;
     uram #(.A_WIDTH(11), .INIT_FILE(RAM_FILE3), .READ_DELAY(0)) system_ram3
          (.clk(memclk), .we(write_enable3), .cs(strobe), .addr(a), .data_in(din), .data_out(mem_data_out3));
   
  
       

 
endmodule
