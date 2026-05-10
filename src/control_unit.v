//==========================
// File: control_unit.v
// Description: Main control unit for the RV32I single-cycle processor.
//              Decodes opcode, funct3, funct7 and generates all datapath
//              control signals:
//
//  Signal list:
//   alu_op     [3:0]  – ALU operation select (matches alu.v encoding)
//   alu_src_a  [1:0]  – ALU operand A: 00=rs1, 01=PC, 10=zero (unused)
//   alu_src_b  [1:0]  – ALU operand B: 00=rs2, 01=imm
//   reg_wen           – Register file write enable
//   mem_wen           – Data memory write enable
//   mem_ren           – Data memory read enable  (load)
//   mem_to_reg [1:0]  – Write-back source: 00=ALU, 01=mem, 10=PC+4
//   branch            – This is a branch instruction
//   jump       [1:0]  – 00=no jump, 01=JAL, 10=JALR
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module control_unit (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,        // funct7[6:0] = instr[31:25]; key bit is [5]=instr[30]

    // ----- Datapath control outputs -----
    output reg  [3:0]  alu_op,
    output reg  [1:0]  alu_src_a,     // 0=rs1, 1=PC
    output reg         alu_src_b,     // 0=rs2, 1=imm
    output reg         reg_wen,       // Register write enable
    output reg         mem_wen,       // Memory write enable
    output reg         mem_ren,       // Memory read enable
    output reg  [1:0]  mem_to_reg,    // WB mux: 00=ALU, 01=MEM, 10=PC+4
    output reg         branch,        // Branch instruction
    output reg  [1:0]  jump           // 00=none, 01=JAL, 10=JALR
);

    // -----------------------------------------------------------------------
    // ALU_OP constants – must match alu.v
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
    localparam ALU_PASSB= 4'b1010;   // Pass operand_b (LUI)

    // Opcode table
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_ALUI   = 7'b0010011;
    localparam OP_ALUR   = 7'b0110011;
    localparam OP_SYSTEM = 7'b1110011;

    // mem_to_reg encoding
    localparam WB_ALU   = 2'b00;
    localparam WB_MEM   = 2'b01;
    localparam WB_PC4   = 2'b10;

    // jump encoding
    localparam JMP_NONE = 2'b00;
    localparam JMP_JAL  = 2'b01;
    localparam JMP_JALR = 2'b10;

    // funct7 bit[30] distinguishes ADD/SUB, SRL/SRA
    // funct7[5] = instr[30]: key differentiator for SUB/SRA/SRAI vs ADD/SRL/SRLI
    // funct7 is declared [6:0] and connected to instr[31:25] directly (7-bit clean)
    wire f7_alt = funct7[5]; // 1=SUB/SRA/SRAI, 0=ADD/SRL/SRLI

    // -----------------------------------------------------------------------
    // Main decode block
    // -----------------------------------------------------------------------
    always @(*) begin
        // Default / safe values (NOP-like)
        alu_op     = ALU_ADD;
        alu_src_a  = 2'b00;   // rs1
        alu_src_b  = 1'b0;    // rs2
        reg_wen    = 1'b0;
        mem_wen    = 1'b0;
        mem_ren    = 1'b0;
        mem_to_reg = WB_ALU;
        branch     = 1'b0;
        jump       = JMP_NONE;

        case (opcode)

            // ----------------------------------------------------------------
            // LUI – Load Upper Immediate: rd = imm
            // ----------------------------------------------------------------
            OP_LUI: begin
                alu_op     = ALU_PASSB;   // Pass immediate through ALU
                alu_src_b  = 1'b1;        // Use immediate
                reg_wen    = 1'b1;
                mem_to_reg = WB_ALU;
            end

            // ----------------------------------------------------------------
            // AUIPC – Add Upper Immediate to PC: rd = PC + imm
            // ----------------------------------------------------------------
            OP_AUIPC: begin
                alu_op     = ALU_ADD;
                alu_src_a  = 2'b01;       // PC
                alu_src_b  = 1'b1;        // immediate
                reg_wen    = 1'b1;
                mem_to_reg = WB_ALU;
            end

            // ----------------------------------------------------------------
            // JAL – Jump And Link: rd = PC+4; PC = PC + imm
            // ----------------------------------------------------------------
            OP_JAL: begin
                alu_op     = ALU_ADD;
                alu_src_a  = 2'b01;       // PC (compute branch target in ALU)
                alu_src_b  = 1'b1;        // immediate
                reg_wen    = 1'b1;
                mem_to_reg = WB_PC4;      // rd = PC+4 (return address)
                jump       = JMP_JAL;
            end

            // ----------------------------------------------------------------
            // JALR – Jump And Link Register: rd = PC+4; PC = (rs1 + imm) & ~1
            // ----------------------------------------------------------------
            OP_JALR: begin
                alu_op     = ALU_ADD;
                alu_src_a  = 2'b00;       // rs1
                alu_src_b  = 1'b1;        // immediate
                reg_wen    = 1'b1;
                mem_to_reg = WB_PC4;      // rd = PC+4
                jump       = JMP_JALR;
            end

            // ----------------------------------------------------------------
            // Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            // ALU subtracts rs1-rs2; branch_unit evaluates flags
            // ----------------------------------------------------------------
            OP_BRANCH: begin
                alu_op     = ALU_SUB;     // Subtraction for flag generation
                alu_src_b  = 1'b0;        // rs2
                branch     = 1'b1;
                reg_wen    = 1'b0;        // No register write for branches
            end

            // ----------------------------------------------------------------
            // Load instructions (LB, LH, LW, LBU, LHU)
            // ----------------------------------------------------------------
            OP_LOAD: begin
                alu_op     = ALU_ADD;     // Effective address = rs1 + imm
                alu_src_b  = 1'b1;        // immediate
                reg_wen    = 1'b1;
                mem_ren    = 1'b1;
                mem_to_reg = WB_MEM;
            end

            // ----------------------------------------------------------------
            // Store instructions (SB, SH, SW)
            // ----------------------------------------------------------------
            OP_STORE: begin
                alu_op     = ALU_ADD;     // Effective address = rs1 + imm
                alu_src_b  = 1'b1;        // immediate (S-type)
                mem_wen    = 1'b1;
                reg_wen    = 1'b0;
            end

            // ----------------------------------------------------------------
            // ALU Immediate instructions (ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
            //                            SLLI, SRLI, SRAI)
            // ----------------------------------------------------------------
            OP_ALUI: begin
                alu_src_b  = 1'b1;        // Use immediate
                reg_wen    = 1'b1;
                mem_to_reg = WB_ALU;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI  (shamt in imm[4:0])
                    3'b101: alu_op = f7_alt ? ALU_SRA : ALU_SRL; // SRAI / SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            // ----------------------------------------------------------------
            // ALU Register instructions (ADD, SUB, SLL, SLT, SLTU, XOR,
            //                           SRL, SRA, OR, AND)
            // ----------------------------------------------------------------
            OP_ALUR: begin
                alu_src_b  = 1'b0;        // Use rs2
                reg_wen    = 1'b1;
                mem_to_reg = WB_ALU;
                case (funct3)
                    3'b000: alu_op = f7_alt ? ALU_SUB : ALU_ADD; // ADD / SUB
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = f7_alt ? ALU_SRA : ALU_SRL; // SRA / SRL
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end

            // ----------------------------------------------------------------
            // SYSTEM: ECALL / EBREAK – treated as NOP here (testbench handles)
            // ----------------------------------------------------------------
            OP_SYSTEM: begin
                reg_wen = 1'b0;
                mem_wen = 1'b0;
            end

            // ----------------------------------------------------------------
            // Default: NOP
            // ----------------------------------------------------------------
            default: begin
                /* all defaults already applied above */
            end

        endcase
    end

endmodule

`default_nettype wire
