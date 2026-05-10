//==========================
// File: decoder.v
// Description: Instruction field extractor for RV32I.
//              Splits the 32-bit instruction word into its named fields:
//              opcode, rd, funct3, rs1, rs2, funct7.
//              Also determines the immediate format for the immediate
//              generator and exposes the ecall/ebreak flag.
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module decoder #(
    parameter XLEN = 32
)(
    input  wire [XLEN-1:0] instr,      // Full instruction word

    // ----- Individual fields -----
    output wire [6:0]      opcode,     // instr[6:0]
    output wire [4:0]      rd,         // instr[11:7]
    output wire [2:0]      funct3,     // instr[14:12]
    output wire [4:0]      rs1,        // instr[19:15]
    output wire [4:0]      rs2,        // instr[24:20]
    output wire [6:0]      funct7,     // instr[31:25]  (bit [5]=instr[30] is key differentiator)

    // ----- Immediate format -----
    output reg  [2:0]      imm_sel,    // Immediate format selector for imm_gen

    // ----- Special flags -----
    output wire            is_ecall    // 1 when instruction is ECALL (system call)
);

    // -----------------------------------------------------------------------
    // Field extraction – purely structural
    // -----------------------------------------------------------------------
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];  // 7 bits [6:0], bit[5]=instr[30]

    // -----------------------------------------------------------------------
    // ECALL detection: opcode=SYSTEM and imm[11:0]=0
    // -----------------------------------------------------------------------
    assign is_ecall = (opcode == 7'b1110011) && (instr[31:20] == 12'h000);

    // -----------------------------------------------------------------------
    // Immediate format selection (must match immediate_generator.v encodings)
    // -----------------------------------------------------------------------
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;
    localparam IMM_X = 3'd7; // No immediate

    // Opcode definitions (matches RISC-V spec Table 24.1)
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_ALUI   = 7'b0010011; // ALU immediate (I-type)
    localparam OP_ALUR   = 7'b0110011; // ALU register  (R-type)
    localparam OP_SYSTEM = 7'b1110011;

    always @(*) begin
        case (opcode)
            OP_LUI   : imm_sel = IMM_U;
            OP_AUIPC : imm_sel = IMM_U;
            OP_JAL   : imm_sel = IMM_J;
            OP_JALR  : imm_sel = IMM_I;
            OP_BRANCH: imm_sel = IMM_B;
            OP_LOAD  : imm_sel = IMM_I;
            OP_STORE : imm_sel = IMM_S;
            OP_ALUI  : imm_sel = IMM_I;
            OP_ALUR  : imm_sel = IMM_X;
            OP_SYSTEM: imm_sel = IMM_I;
            default  : imm_sel = IMM_X;
        endcase
    end

endmodule

`default_nettype wire
