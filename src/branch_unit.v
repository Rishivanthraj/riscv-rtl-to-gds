//==========================
// File: branch_unit.v
// Description: Evaluates branch conditions for RV32I conditional branches.
//              Takes ALU flags computed from (rs1 - rs2) and funct3 to
//              determine whether the branch should be taken.
//
//  funct3 encoding for branches:
//   3'b000  BEQ   – branch if equal
//   3'b001  BNE   – branch if not equal
//   3'b100  BLT   – branch if less than       (signed)
//   3'b101  BGE   – branch if greater or equal (signed)
//   3'b110  BLTU  – branch if less than       (unsigned)
//   3'b111  BGEU  – branch if greater or equal (unsigned)
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module branch_unit (
    input  wire [2:0]  funct3,         // Branch type selector
    input  wire        branch,         // 1 when this is a branch instruction
    input  wire        zero_flag,      // ALU: result == 0  (rs1 == rs2)
    input  wire        neg_flag,       // ALU: result MSB   (signed less-than indicator)
    input  wire        carry_flag,     // ALU: unsigned borrow (rs1 < rs2 unsigned)
    input  wire        ovf_flag,       // ALU: signed overflow

    output wire        branch_taken    // 1 → take the branch, update PC to branch target
);

    // -----------------------------------------------------------------------
    // Branch condition evaluation
    // All conditions derived from flags of (rs1 - rs2)
    // -----------------------------------------------------------------------
    reg cond;

    always @(*) begin
        case (funct3)
            3'b000: cond = zero_flag;                      // BEQ
            3'b001: cond = ~zero_flag;                     // BNE
            // BLT: signed A < B  →  neg_flag XOR ovf_flag
            3'b100: cond = neg_flag ^ ovf_flag;            // BLT  (signed)
            // BGE: signed A >= B →  NOT(neg XOR ovf)
            3'b101: cond = ~(neg_flag ^ ovf_flag);         // BGE  (signed)
            // BLTU: unsigned A < B → carry_flag set (borrow)
            3'b110: cond = carry_flag;                     // BLTU (unsigned)
            // BGEU: unsigned A >= B
            3'b111: cond = ~carry_flag;                    // BGEU (unsigned)
            default: cond = 1'b0;
        endcase
    end

    // Branch taken only when instruction is actually a branch AND condition holds
    assign branch_taken = branch & cond;

endmodule

`default_nettype wire
