//==========================
// File: alu.v
// Description: 32-bit Arithmetic Logic Unit for RV32I.
//              Implements all operations required by the base integer ISA.
//              alu_op encoding is defined here and shared via a parameter
//              or localparams; control_unit generates the same encoding.
//
//  ALU_OP encoding (4-bit):
//   4'b0000  ADD  / ADDI
//   4'b0001  SUB
//   4'b0010  SLL  / SLLI
//   4'b0011  SLT  / SLTI   (signed)
//   4'b0100  SLTU / SLTIU  (unsigned)
//   4'b0101  XOR  / XORI
//   4'b0110  SRL  / SRLI
//   4'b0111  SRA  / SRAI
//   4'b1000  OR   / ORI
//   4'b1001  AND  / ANDI
//   4'b1010  LUI pass-through (operand_b passed directly)
//   4'b1011  AUIPC  (pc + imm – handled at top; ALU does ADD)
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module alu #(
    parameter XLEN = 32
)(
    input  wire [3:0]       alu_op,    // ALU operation select
    input  wire [XLEN-1:0]  operand_a, // First  operand (rs1 or PC)
    input  wire [XLEN-1:0]  operand_b, // Second operand (rs2 or immediate)
    output reg  [XLEN-1:0]  alu_result,// Computed result
    output wire             zero_flag, // 1 when alu_result == 0  (used by BEQ/BNE)
    output wire             neg_flag,  // alu_result sign bit      (used by BLT/BGE)
    output wire             carry_flag,// Unsigned carry-out       (used by BLTU/BGEU)
    output wire             ovf_flag   // Signed overflow flag
);

    // -----------------------------------------------------------------------
    // ALU_OP constants – mirror these in control_unit.v
    // -----------------------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_PASSB= 4'b1010; // Pass operand_b (for LUI)

    // -----------------------------------------------------------------------
    // Internal wires for carry/overflow detection on ADD/SUB
    // -----------------------------------------------------------------------
    wire [XLEN:0] add_result_ext; // XLEN+1 bits for carry
    wire [XLEN:0] sub_result_ext;

    assign add_result_ext = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_result_ext = {1'b0, operand_a} - {1'b0, operand_b};

    // -----------------------------------------------------------------------
    // Main combinatorial ALU
    // -----------------------------------------------------------------------
    always @(*) begin
        case (alu_op)
            ALU_ADD  : alu_result = operand_a + operand_b;
            ALU_SUB  : alu_result = operand_a - operand_b;
            ALU_SLL  : alu_result = operand_a << operand_b[4:0];
            ALU_SLT  : alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            ALU_SLTU : alu_result = (operand_a < operand_b)                   ? 32'd1 : 32'd0;
            ALU_XOR  : alu_result = operand_a ^ operand_b;
            ALU_SRL  : alu_result = operand_a >> operand_b[4:0];
            ALU_SRA  : alu_result = $signed(operand_a) >>> operand_b[4:0];
            ALU_OR   : alu_result = operand_a | operand_b;
            ALU_AND  : alu_result = operand_a & operand_b;
            ALU_PASSB: alu_result = operand_b;             // LUI: rd = imm
            default  : alu_result = {XLEN{1'b0}};
        endcase
    end

    // -----------------------------------------------------------------------
    // Flag generation
    // -----------------------------------------------------------------------
    assign zero_flag  = (alu_result == {XLEN{1'b0}});
    assign neg_flag   = alu_result[XLEN-1];

    // Carry: unsigned borrow-out of subtraction (for BLTU / BGEU)
    assign carry_flag = sub_result_ext[XLEN];              // 1 when A < B unsigned

    // Overflow: signed overflow on subtraction
    // Overflow if signs of A and B differ AND sign of result differs from A
    assign ovf_flag   = (operand_a[XLEN-1] ^ operand_b[XLEN-1]) &
                        (operand_a[XLEN-1] ^ sub_result_ext[XLEN-1]);

endmodule

`default_nettype wire
