//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qian Hao Lam (qlam6@JH.edu)
// 
// Create Date: 10/19/2025 01:35:07 AM
// Design Name: 
// Module Name: csr_unit
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

module csr_unit (
    input  wire         clk,
    input  wire         reset,

    // External interrupt request
    input  wire         intr,
    input  wire         cu_intr_ack,

    // CSR instruction interface
    input  wire         csr_en,
    input  wire [2:0]   csr_cmd,       // 001=CSRRW, 010=CSRRS, 011=CSRRC
    input  wire [11:0]  csr_addr,
    input  wire [31:0]  csr_wdata,
    output reg  [31:0]  csr_rdata,

    // Trap/interrupt interface
    input  wire         trap_set,      // 1 when taking a trap this cycle
    input  wire [31:0]  trap_cause,    // bit31=interrupt, low bits=cause code
    input  wire [31:0]  trap_tval,     // faulting VA or 0
    input  wire [31:0]  trap_pc,       // PC to save into *epc
    output reg  [31:0]  trap_vector,   // mtvec or stvec, latched at trap
    input  wire         mret,          // execute MRET
    input  wire         sret,          // execute SRET

    // Side-effect pulses (out)
    output reg tlb_flush_pulse, // 1cyc on satp write
    output reg [31:0] satp,      // [31:30] MODE (1=Sv32), [21:0] PPN (ASID ignored)

    // Exposed to core
    output reg  [31:0]  mstatus_out,
    output reg  [31:0]  mie,
    output reg  [31:0]  mip,
    output reg  [31:0]  mepc_out
	
);
    // -------------------- Constants --------------------
    localparam [1:0] PRV_U = 2'b00, PRV_S = 2'b01, PRV_M = 2'b11;

    // mstatus bit positions we actually use (RV32)
    localparam SIE  = 1,  MIE  = 3;
    localparam SPIE = 5,  MPIE = 7;
    localparam SPP  = 8;
    localparam MPP0 = 11, MPP1 = 12;   // MPP[12:11]
    localparam SUMB = 18, MXRB = 19;

    // Causes used for delegation (exceptions only)
    // 12: inst page fault, 13: load page fault, 15: store/AMO page fault

    // -------------------- CSRs --------------------
    // Machine
    reg [31:0] mstatus;
					 
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;

    // Supervisor
    // sstatus is a view of mstatus; we don't store a separate copy.
    reg [31:0] stvec;
    reg [31:0] sepc;
    reg [31:0] scause;
    reg [31:0] stval;
    reg satp_wr_q;   // previous-cycle SATP access indicator
    // Virtual memory
    
    reg [31:0] medeleg;   // exception delegation mask (interrupts not delegated here)

    // Privilege mode
    reg [1:0]  priv_mode;
    
    // Handy wires
    wire       is_interrupt = trap_cause[31];
    wire [4:0] cause_code   = trap_cause[4:0];
    wire       delegate_to_s = (!is_interrupt) && (medeleg[cause_code]) && (priv_mode != PRV_M);
      // MVP: don't delegate traps taken in M; no mideleg (interrupt delegation)
    wire satp_access = csr_en && (csr_addr == 12'h180);
    
    // -------------- Reset / sequential updates --------------
    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            mstatus   <= 32'b0;
            mie       <= 32'b0;
            mtvec     <= 32'b0;
            mepc      <= 32'b0;
            mcause    <= 32'b0;
            mtval     <= 32'b0;
            mip       <= 32'b0;

            stvec     <= 32'b0;
            sepc      <= 32'b0;
            scause    <= 32'b0;
            stval     <= 32'b0;

            satp      <= 32'b0;   // MODE=0 (bare)
            medeleg   <= 32'b0;

            priv_mode <= PRV_M;
            trap_vector     <= 32'b0;
            tlb_flush_pulse <= 1'b0;
            satp_wr_q <= 1'b0;
        end else begin
            tlb_flush_pulse <= 1'b0; // default

            // External interrupt pending (MEIP) bookkeeping
            if (intr)           mip[11] <= 1'b1;
            else if (cu_intr_ack) mip[11] <= 1'b0;

            // -------- Trap entry (highest priority) --------
            if (trap_set) begin
                if (delegate_to_s) begin
                    // S-mode trap
                    sepc   <= trap_pc;
                    scause <= trap_cause;
                    stval  <= trap_tval;

                    // sstatus: SPIE <- SIE; SIE <- 0; SPP <- priv_mode (U or S; MVP: set to S if no U)
                    mstatus[SPIE] <= mstatus[SIE];
                    mstatus[SIE]  <= 1'b0;
                    mstatus[SPP]  <= (priv_mode == PRV_U) ? 1'b0 : 1'b1;

                    priv_mode     <= PRV_S;
                    trap_vector   <= stvec;
                end else begin
                    // M-mode trap
                    mepc   <= trap_pc;
                    mcause <= trap_cause;
                    mtval  <= trap_tval;

                    // mstatus: MPIE <- MIE; MIE <- 0; MPP <- priv_mode
                    mstatus[MPIE] <= mstatus[MIE];
                    mstatus[MIE]  <= 1'b0;
                    mstatus[MPP1:MPP0] <= priv_mode;

                    priv_mode     <= PRV_M;
                    trap_vector   <= mtvec;
                end

            // -------- Returns --------
            end else if (mret) begin
                // Return to MPP
                priv_mode <= mstatus[MPP1:MPP0];
                mstatus[MIE]  <= mstatus[MPIE];
                mstatus[MPIE] <= 1'b1;           // spec: set to 1 on xRET
                mstatus[MPP1:MPP0] <= PRV_U;     // MVP: clear to U (00); OK even if U not implemented TODO: SUPERVISOR

            end else if (sret) begin
                // Return to SPP
                priv_mode <= mstatus[SPP] ? PRV_S : PRV_U;
                mstatus[SIE]  <= mstatus[SPIE];
                mstatus[SPIE] <= 1'b1;
                mstatus[SPP]  <= 1'b0;          // spec: clear to U

            // -------- CSR instruction writes (commit-time) --------
            end else if (csr_en) begin
                case (csr_addr)
                    12'h300: begin // mstatus
                        case (csr_cmd)
                          3'b001: mstatus <= csr_wdata;
                          3'b010: mstatus <= mstatus | csr_wdata;
                          3'b011: mstatus <= mstatus & ~csr_wdata;
                        endcase
                    end
                    12'h304: begin // mie
                        case (csr_cmd)
                          3'b001: mie <= csr_wdata;
                          3'b010: mie <= mie | csr_wdata;
                          3'b011: mie <= mie & ~csr_wdata;
                        endcase
                    end
                    12'h305: begin // mtvec
                        case (csr_cmd)
                          3'b001: mtvec <= csr_wdata;
                          3'b010: mtvec <= mtvec | csr_wdata;
                          3'b011: mtvec <= mtvec & ~csr_wdata;
                        endcase
                    end
                    12'h341: begin // mepc
                        case (csr_cmd)
                          3'b001: mepc <= csr_wdata;
                          3'b010: mepc <= mepc | csr_wdata;
                          3'b011: mepc <= mepc & ~csr_wdata;
                        endcase
                    end
                    12'h342: begin // mcause
                        case (csr_cmd)
                          3'b001: mcause <= csr_wdata;
                          3'b010: mcause <= mcause | csr_wdata;
                          3'b011: mcause <= mcause & ~csr_wdata;
                        endcase
                    end
                    12'h343: begin // mtval
                        case (csr_cmd)
                          3'b001: mtval <= csr_wdata;
                          3'b010: mtval <= mtval | csr_wdata;
                          3'b011: mtval <= mtval & ~csr_wdata;
                        endcase
                    end
                    12'h344: begin // mip (SW only; MEIP is also set/cleared by intr/ack)
                        case (csr_cmd)
                          3'b001: mip <= csr_wdata;
                          3'b010: mip <= mip | csr_wdata;
                          3'b011: mip <= mip & ~csr_wdata;
                        endcase
                    end

                    // ------- Supervisor CSRs -------
                    12'h100: begin // sstatus (view of mstatus)
                        // Only update the bits that exist in sstatus (SIE,SPIE,SPP,SUM,MXR)
                        case (csr_cmd)
                          3'b001,3'b010: begin
                            mstatus[SIE]  <= csr_cmd[0] ? (mstatus[SIE]  | csr_wdata[SIE])  : csr_wdata[SIE];
                            mstatus[SPIE] <= csr_cmd[0] ? (mstatus[SPIE] | csr_wdata[SPIE]) : csr_wdata[SPIE];
                            mstatus[SPP]  <= csr_cmd[0] ? (mstatus[SPP]  | csr_wdata[SPP])  : csr_wdata[SPP];
                            mstatus[SUMB] <= csr_cmd[0] ? (mstatus[SUMB] | csr_wdata[SUMB]) : csr_wdata[SUMB];
                            mstatus[MXRB] <= csr_cmd[0] ? (mstatus[MXRB] | csr_wdata[MXRB]) : csr_wdata[MXRB];
                          end
                          3'b011: begin
                            mstatus[SIE]  <= mstatus[SIE]  & ~csr_wdata[SIE];
                            mstatus[SPIE] <= mstatus[SPIE] & ~csr_wdata[SPIE];
                            mstatus[SPP]  <= mstatus[SPP]  & ~csr_wdata[SPP];
                            mstatus[SUMB] <= mstatus[SUMB] & ~csr_wdata[SUMB];
                            mstatus[MXRB] <= mstatus[MXRB] & ~csr_wdata[MXRB];
                          end
                        endcase
                    end
                    12'h105: begin // stvec
                        case (csr_cmd)
                          3'b001: stvec <= csr_wdata;
                          3'b010: stvec <= stvec | csr_wdata;
                          3'b011: stvec <= stvec & ~csr_wdata;
                        endcase
                    end
                    12'h141: begin // sepc
                        case (csr_cmd)
                          3'b001: sepc <= csr_wdata;
                          3'b010: sepc <= sepc | csr_wdata;
                          3'b011: sepc <= sepc & ~csr_wdata;
                        endcase
                    end
                    12'h142: begin // scause
                        case (csr_cmd)
                          3'b001: scause <= csr_wdata;
                          3'b010: scause <= scause | csr_wdata;
                          3'b011: scause <= scause & ~csr_wdata;
                        endcase
                    end
                    12'h143: begin // stval
                        case (csr_cmd)
                          3'b001: stval <= csr_wdata;
                          3'b010: stval <= stval | csr_wdata;
                          3'b011: stval <= stval & ~csr_wdata;
                        endcase
                    end
                    12'h180: begin // satp (Sv32)
                        case (csr_cmd)
                          3'b001: satp <= csr_wdata;
                          3'b010: satp <= satp | csr_wdata;
                          3'b011: satp <= satp & ~csr_wdata;
                        endcase
//                        tlb_flush_pulse <= 1'b1; // flush TLB on any satp write before tlb_flush_Pulse latch issue fix
                          tlb_flush_pulse <= satp_access & ~satp_wr_q;   // Fixing pulse latch issue
                          satp_wr_q       <= satp_access;// Fixing pulse latch issue
                    end
                    12'h302: begin // medeleg (exceptions only)
                        case (csr_cmd)
                          3'b001: medeleg <= csr_wdata;
                          3'b010: medeleg <= medeleg | csr_wdata;
                          3'b011: medeleg <= medeleg & ~csr_wdata;
                        endcase
                    end

                    default: ;
                endcase
            end														
        end
    end
	   

																		 
    // ---------------- Combinational CSR read ----------------
    // sstatus is a *view* of mstatus
    wire [31:0] sstatus_view = (32'b0)
        | (mstatus[SIE ]   << SIE )
        | (mstatus[SPIE]   << SPIE)
        | (mstatus[SPP ]   << SPP )
        | (mstatus[SUMB]   << SUMB)
        | (mstatus[MXRB]   << MXRB);

    always @(*) begin
        case (csr_addr)
            // Machine
            12'h300: csr_rdata = mstatus;
            12'h304: csr_rdata = mie;
            12'h305: csr_rdata = mtvec;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h343: csr_rdata = mtval;
            12'h344: csr_rdata = mip;

            // Supervisor
            12'h100: csr_rdata = sstatus_view;
            12'h105: csr_rdata = stvec;
            12'h141: csr_rdata = sepc;
            12'h142: csr_rdata = scause;
            12'h143: csr_rdata = stval;
            12'h180: csr_rdata = satp;

            // Delegation
            12'h302: csr_rdata = medeleg;

            default: csr_rdata = 32'b0;
        endcase
    end

    // ---------------- Expose outputs ----------------
									 
																		 
    always @(*) begin
        mstatus_out = mstatus;
        mepc_out    = mepc;
        // (If you want: expose satp/stvec here as extra ports)
    end

endmodule
