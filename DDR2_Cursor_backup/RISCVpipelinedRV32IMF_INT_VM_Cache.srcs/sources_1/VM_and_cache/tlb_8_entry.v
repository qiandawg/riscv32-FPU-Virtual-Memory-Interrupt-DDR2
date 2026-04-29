/************************************************
  The Verilog HDL code example is from the book
  Computer Principles and Design in Verilog HDL
  by Yamin Li, published by A JOHN WILEY & SONS
************************************************/

// Sv32 leaf PTE fields (from a 32-bit PTE):
//   PPN[21:0] = pte[31:10]
//   perm bits = {U,G,A,D,X,W,R,V} = {pte[4], pte[5], pte[6], pte[7], pte[3], pte[2], pte[1], pte[0]}
//   superpage = 1 if leaf at level-1 (4 MiB), else 0


module tlb_8_entry (
//    input  [31:0] pte_in,      // packed Sv32 TLB entry (PFN+attrs as you defined) 32 bit is wrong
    input  [23:0] pte_in,
    input         tlbwi,       // write by index
    input         tlbwr,       // write random
    input   [2:0] index,       // index for tlbwi
    input  [19:0] vpn,         // virtual page number to probe
    input         clk, clrn,
    input         flush,       // NEW: invalidate all entries (one-cycle pulse)
    output [23:0] pte_out,     // PTE read at ram_idx
    output        tlb_hit,     // 1 when CAM matches vpn
    output  [2:0] hit_idx      // matched CAM index (optional)
);

// Select write index (random for tlbwr, index for tlbwi)
    wire    [2:0] random;
    wire    [2:0] w_idx;
    wire    [2:0] ram_idx;
    wire    [2:0] vpn_index;
    wire          tlbw = tlbwi | tlbwr;

    // Random index generator (unchanged)
    rand3   rdm (clk, clrn, random);

    // Choose write address: tlbwr uses random, tlbwi uses explicit index
    mux2x3  w_address   (index, random, tlbwr, w_idx);

    // When writing (tlbw==1) we address RAM with w_idx; otherwise use vpn_index
    mux2x3  ram_address (vpn_index, w_idx, tlbw, ram_idx);

    // PTE RAM (same width/instance you already had)
    ram8x24 rpn (ram_idx, pte_in, clk, tlbw, pte_out);

   // CAM: match VPN -> gives vpn_index, tlb_hit
   // UPDATED to pass through flush. Add `input flush` to cam8x21 and clear all valids on flush.
   cam8x21 valid_tag (clk, vpn, w_idx, tlbw, flush, vpn_index, tlb_hit);

    assign hit_idx = vpn_index; // optional

endmodule