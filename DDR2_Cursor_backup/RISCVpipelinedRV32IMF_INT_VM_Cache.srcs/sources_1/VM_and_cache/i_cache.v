/************************************************
  The Verilog HDL code example is from the book
  Computer Principles and Design in Verilog HDL
  by Yamin Li, published by A JOHN WILEY & SONS
************************************************/
module i_cache (                 // direct mapping, 2^6 blocks, 1 word/block
    input  [31:0] p_a,                             // cpu address
    output [31:0] p_din,                           // cpu data from mem
    input         p_strobe,                        // cpu strobe
    input         uncached,                        // uncached
    output        p_ready,                         // ready (to cpu)
    output        cache_miss,                      // cache miss
    input         clk, clrn,                       // clock and reset
    output [31:0] m_a,                             // mem address
    input  [31:0] m_dout,                          // mem data out to cpu
    output        m_strobe,                        // mem strobe , when asserted, memory system knows icache
                                                   // wants the bus and needs data on m_dout.
    input         m_ready,                          // mem ready
    input        flush,
    input  no_cache_stall,
     output reg [31:0] ic_hits
    , output reg [31:0] ic_misses
    , output reg [31:0] ic_refills
    , output reg [31:0] ic_stall_cycles           
                );
    reg           d_valid [0:63];                  // 1-bit valid
    reg    [23:0] d_tags  [0:63];                  // 24-bit tag
    reg    [31:0] d_data  [0:63];                  // 32-bit data
    wire    [5:0] index = p_a[7:2];                // block index
    wire   [23:0] tag = p_a[31:8];                 // address tag
    wire          c_write;                         // cache write
    wire   [31:0] c_din;                           // data to cache
    integer i;
    always @ (posedge clk or negedge clrn)
        if (!clrn) begin
            for (i=0; i<64; i=i+1)
                d_valid[i] <= 0;                   // cleat valid
        end else if (flush) begin
            for (i=0;i<64;i=i+1) d_valid[i] <= 1'b0;
        end else if (c_write)
            d_valid[index] <= 1;                   // write valid
    always @ (posedge clk)  
        if (c_write) begin
            d_tags[index] <= tag;                  // write address tag
            d_data[index] <= c_din;                // write data
        end
    wire          valid = d_valid[index];          // read cache valid
    wire   [23:0] tagout = d_tags[index];          // read cache tag
    wire   [31:0] c_dout = d_data[index];          // read cache data
    wire   cache_hit  = p_strobe &   valid & (tagout == tag);  // cache hit
    assign cache_miss = p_strobe & (!valid | (tagout != tag)); // cache miss
    assign m_a      = p_a;                         // mem <-- cpu address
    assign m_strobe = cache_miss ;                 // read on miss
    assign p_ready  = cache_hit | cache_miss & m_ready;       // data ready
    assign c_write  = cache_miss & ~uncached & m_ready;       // write cache
    assign c_din    = m_dout;                      // data from mem
    assign p_din    = cache_hit? c_dout : m_dout;  // data from cache or mem
    
    
    
        // -------------------------------
    // Perf counters (minimal intrusion)
    // -------------------------------
    // Definitions of "events":
    // - hit:       cache_hit (p_strobe & valid & tag match)  [counts instructions served from I$]
    // - miss:      cache_miss (p_strobe & (!valid | tag mismatch)) [counts miss requests]
    // - refill:    c_write (miss & ~uncached & m_ready)      [miss completed: line written into I$]
    // - stall cyc: cache_miss & ~m_ready                     [cycles the core waited on this miss]
    //
    // Counters are 32-bit and free-run (wrap on overflow). They reset on clrn.
    always @(posedge clk or negedge clrn) begin
        if (!clrn) begin
            ic_hits         <= 32'd0;
            ic_misses       <= 32'd0;
            ic_refills      <= 32'd0;
            ic_stall_cycles <= 32'd0;
        end else if (no_cache_stall) begin
            if (cache_hit)
                ic_hits <= ic_hits + 32'd1;

            if (cache_miss)
                ic_misses <= ic_misses + 32'd1;

            if (c_write)
                ic_refills <= ic_refills + 32'd1;

            if (cache_miss & ~m_ready)
                ic_stall_cycles <= ic_stall_cycles + 32'd1;
        end
    end
    
    
    
endmodule
