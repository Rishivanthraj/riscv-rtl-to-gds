//==========================
// File: immediate_generator.v
// Description: Extracts and sign-extends immediate values from RV32I
//              instruction encodings.  Supports all five immediate formats:
//              I, S, B, U, J.
//
//  Format summary (bits from instr[31:0]):
//
//  I-type : imm[11:0]  = instr[31:20]
//  S-type : imm[11:5]  = instr[31:25], imm[4:0] = instr[11:7]
//  B-type : imm[12]    = instr[31],    imm[10:5] = instr[30:25],
//           imm[4:1]   = instr[11:8],  imm[11]   = instr[7]
//           imm[0]     = 0 (always)
//  U-type : imm[31:12] = instr[31:12], imm[11:0] = 0
//  J-type : imm[20]    = instr[31],    imm[10:1] = instr[30:21],
//           imm[11]    = instr[20],    imm[19:12] = instr[19:12]
//           imm[0]     = 0 (always)
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module immediate_generator #(
    parameter XLEN = 32
)(
    input  wire [XLEN-1:0] instr,      // Full 32-bit instruction word
    input  wire [2:0]      imm_sel,    // Immediate format selector (from decoder)
    output reg  [XLEN-1:0] imm_out    // Sign-extended immediate
);

    // -----------------------------------------------------------------------
    // Immediate format selector encoding – must match decoder.v
    // -----------------------------------------------------------------------
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;
    localparam IMM_X = 3'd7;  // No immediate (R-type)

    // -----------------------------------------------------------------------
    // Combinatorial immediate decode
    // -----------------------------------------------------------------------
    always @(*) begin
        case (imm_sel)
            // ------------------------------------------------------------------
            // I-type: loads, ALU-immediate, JALR, ECALL/EBREAK
            // ------------------------------------------------------------------
            IMM_I: imm_out = {{20{instr[31]}}, instr[31:20]};

            // ------------------------------------------------------------------
            // S-type: stores
            // ------------------------------------------------------------------
            IMM_S: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // ------------------------------------------------------------------
            // B-type: conditional branches
            // imm is PC-relative, bit 0 is always 0
            // ------------------------------------------------------------------
            IMM_B: imm_out = {{19{instr[31]}}, instr[31],   instr[7],
                                               instr[30:25], instr[11:8], 1'b0};

            // ------------------------------------------------------------------
            // U-type: LUI, AUIPC
            // Upper 20 bits in imm[31:12]; lower 12 bits zeroed
            // ------------------------------------------------------------------
            IMM_U: imm_out = {instr[31:12], 12'b0};

            // ------------------------------------------------------------------
            // J-type: JAL
            // imm is PC-relative, bit 0 is always 0
            // ------------------------------------------------------------------
            IMM_J: imm_out = {{11{instr[31]}}, instr[31],   instr[19:12],
                                               instr[20],    instr[30:21], 1'b0};

            // ------------------------------------------------------------------
            // Default (R-type / unknown): immediate not used
            // ------------------------------------------------------------------
            default: imm_out = {XLEN{1'b0}};
        endcase
    end

endmodule

`default_nettype wire
