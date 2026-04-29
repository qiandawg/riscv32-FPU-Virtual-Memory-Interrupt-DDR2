module pl_reg_em (ewreg,em2reg,ewmem,eal,edata,erd,clk,clrn,
                      mwreg,mm2reg,mwmem,mal,md,mrd,wremw,mwfpr,ewfpr,epc,mpc,ex_csr_en, efunc3, ex_csr_addr, csr_wdata_ex, is_mret_ex,
                          mem_csr_en, mfunc3, mem_csr_addr, csr_wdata_mem, is_mret_mem, no_cache_stall,fence_i_ex, sfence_vma_all_ex, sret_ex, fence_i_mem, sfence_vma_all_mem, sret_mem, 
                          eswfp, mswfp, eldst, mldst);
    input clk;
    input clrn;
    input ewreg;
    input em2reg;
    input ewmem;
    input [31:0] eal;
    input [31:0] edata;
    input [4:0] erd;
    output  reg mwreg;
    output reg mm2reg;
    output reg mwmem;
    output reg [31:0] mal;
    output reg [4:0] mrd;
//    output reg [31:0] md;
    output reg [31:0] md;
    input wremw;
    output reg mwfpr;
    input ewfpr;
    input [31:0] epc;
    output reg [31:0] mpc;
    input ex_csr_en;
    input [2:0] efunc3;
    input  [11:0] ex_csr_addr;
    input[31:0]  csr_wdata_ex;
    input is_mret_ex;
    output reg mem_csr_en;
    output  reg [2:0]  mfunc3;
    output  reg  [11:0] mem_csr_addr;
    output reg [31:0]  csr_wdata_mem;
    output reg is_mret_mem;
    input no_cache_stall;
    input fence_i_ex;
    input sfence_vma_all_ex; 
    input sret_ex;    
    output reg fence_i_mem;
    output reg sfence_vma_all_mem; 
    output reg sret_mem;  
    input eswfp;
    output reg mswfp;
    input eldst;
    output reg mldst;
    
    always @(negedge clrn or posedge clk)
       if (!clrn) begin
        	mwreg <=0;
        	mm2reg <=0;
        	mwmem <=0;
        	mal <=0;
        	mrd <=0;
//        	md <=0;
            md <= 0;
        	mwfpr <= 0;
        	mpc <= 0;
        	mem_csr_en <= 0;
            mfunc3 <= 0;
            mem_csr_addr <= 0;
            csr_wdata_mem <= 0;
            is_mret_mem <= 0;
            fence_i_mem <= 0; 
        	sfence_vma_all_mem <= 0; 
        	sret_mem <= 0;    
        	mswfp <= 0;  
        	mldst <=0;
        	
       end else if (no_cache_stall)  begin
 		    mwreg <=ewreg;
       		mm2reg <=em2reg;
       		mwmem <= ewmem;
      		mal <=eal;
       		mrd <=erd;
//       		md <= ed;
            md <= edata;
       		mwfpr <= ewfpr;
       		mpc <= epc;
       		mem_csr_en <= ex_csr_en;
            mfunc3 <= efunc3;
            mem_csr_addr <= ex_csr_addr;
            csr_wdata_mem <= csr_wdata_ex;
            is_mret_mem <= is_mret_ex;
            fence_i_mem <= fence_i_ex; 
        	sfence_vma_all_mem <= sfence_vma_all_ex; 
        	sret_mem <= sret_ex;  
        	mswfp <= eswfp;
        	mldst <= eldst;
       end 
endmodule                       
