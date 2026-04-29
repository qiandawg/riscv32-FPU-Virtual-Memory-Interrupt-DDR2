//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qian Hao Lam (qlam6@JH.edu)
// 
// Create Date: 10/19/2025 01:35:07 AM
// Design Name: 
// Module Name: ptw_sv32
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

module ptw_sv32 (
  input  wire        clk, 
  input  wire        clrn,

  // Kick a walk
  input  wire        start,
  input  wire [31:0] va,           // faulting VA
  input  wire        is_store,     // 0=fetch/load, 1=store (not used for minimal walker)
  input  wire [31:0] satp,         // satp[31:30]=01 => Sv32, satp[21:0]=root PPN

  // External memory port (read-only)
  output reg  [31:0] m_a,
  output reg         m_strobe,
  input  wire        m_ready,
  input  wire [31:0] m_rdata,

  // Result
  output reg         busy,         // walker owns the bus / in progress
  output reg         done,         // 1-cycle pulse when finished
  output reg         found,        // 1 on success, 0 on fault
  output reg  [23:0] pte24,        // {4'b0000, PPN[19:0]} for your 24-bit TLB payload
  output reg  [3:0]  fault_cause   // generic fault code (4'hF on failure)
);

  // ---------------- Constants / bitfields ----------------
  localparam [1:0] MODE_SV32 = 2'b01;

  wire [21:0] root_ppn  = satp[21:0];

  wire [9:0]  vpn0      = va[21:12];
  wire [9:0]  vpn1      = va[31:22];

  // ---------------- State machine ----------------
  localparam [2:0]
    S_IDLE   = 3'd0,
    S_L1_REQ = 3'd1,
    S_L1_CHK = 3'd2,
    S_L0_REQ = 3'd3,
    S_L0_CHK = 3'd4,
    S_DONE   = 3'd5;

  reg [2:0] st;

  // Latched PTEs
  reg [31:0] pte1, pte0;
//  wire [19:0] sv32_ppn20 = { pte0[31:22], pte0[21:12] };
  // ---------------- Helpers (Verilog functions) ----------------
  function [31:0] addr_from_ppn_idx;
    input [21:0] ppn;
    input [9:0]  idx;
    begin
      // word address = base + idx*4
      addr_from_ppn_idx = {ppn, 12'b0} + {20'b0, idx, 2'b00};
    end
  endfunction

  function pte_v;
    input [31:0] p;
    begin pte_v = p[0]; end
  endfunction

  function pte_r;
    input [31:0] p;
    begin pte_r = p[1]; end
  endfunction

  function pte_x;
    input [31:0] p;
    begin pte_x = p[3]; end
  endfunction

  function [21:0] pte_ppn;
    input [31:0] p;
    begin pte_ppn = p[31:10]; end
  endfunction

  // ---------------- Combinational defaults ----------------
  always @* begin
    busy     = (st != S_IDLE) && (st != S_DONE);
    m_strobe = (st == S_L1_REQ) || (st == S_L0_REQ);
  end

  // ---------------- FSM ----------------
  always @(posedge clk or negedge clrn) begin
    if (!clrn) begin
      st          <= S_IDLE;
      done        <= 1'b0;
      found       <= 1'b0;
      pte24       <= 24'h0;
      fault_cause <= 4'h0;
      m_a         <= 32'h0;
      pte1        <= 32'h0;
      pte0        <= 32'h0;
    end else begin
      done <= 1'b0; // default

      case (st)
        S_IDLE: begin
          found       <= 1'b0;
          fault_cause <= 4'h0;
          if (start && satp[31]) begin   // check if a page table walk is requested
            m_a <= addr_from_ppn_idx(root_ppn, vpn1); // L1 read     
            st  <= S_L1_REQ;
          end
        end

        S_L1_REQ: begin
          if (m_ready) begin
            pte1 <= m_rdata;
            st   <= S_L1_CHK;
          end
        end

        S_L1_CHK: begin
          if (!pte_v(pte1)) begin
            // invalid L1 entry
            found       <= 1'b0;
            pte24       <= 24'h0;
            fault_cause <= 4'hF;
            st          <= S_DONE;
          end else if (pte_r(pte1) || pte_x(pte1)) begin
            // L1 leaf (superpage) - not supported in MVP -> fault
            found       <= 1'b0;
            pte24       <= 24'h0;
            fault_cause <= 4'hF;
            st          <= S_DONE;
          end else begin
            // non-leaf → L0
            m_a <= addr_from_ppn_idx(pte1[31:10], vpn0);
            st  <= S_L0_REQ;
          end
        end

        S_L0_REQ: begin
          if (m_ready) begin
            pte0 <= m_rdata;
            st   <= S_L0_CHK;
          end
        end

        S_L0_CHK: begin
          if ( pte_v(pte0) && (pte_r(pte0) || pte_x(pte0)) ) begin
            // 4KB leaf - success

//            pte24 <= {4'b0000, pte0[31:22], pte0[21:12]}; // 24'h020002 for your __user_start mapping

            pte24 <= {4'b0000, pte0[29:10]};   // PPN[19:0] == PTE[29:10]  causing bug
            found       <= 1'b1;
//            done <= 1'b1;   
            fault_cause <= 4'h0;
          end else begin
            // invalid or no (R|X)
            pte24       <= 24'h0;
            found       <= 1'b0;
            fault_cause <= 4'hF;
          end
          st <= S_DONE;    // default case 
//          st <= S_IDLE;    // Testing skip 
          
        end

        S_DONE: begin
          done <= 1'b1;     // 1-cycle pulse
          st   <= S_IDLE;
        end

        default: st <= S_IDLE;
      endcase
    end
  end

  // Optional: silence unused warning for is_store in this minimal walker
  // synopsys translate_off
  wire _unused_is_store = is_store;
  // synopsys translate_on

endmodule
