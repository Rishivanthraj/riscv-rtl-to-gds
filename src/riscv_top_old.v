//==========================
// File: riscv_top.v
// Description: Top-level integration module for the RV32I single-cycle
//              processor.  Instantiates and wires together all sub-modules:
//
//              pc  →  instruction_memory  →  decoder
//                                          →  immediate_generator
//                                          →  control_unit
//                                          →  register_file
//                                          →  muxes (ALU inputs)
//                                          →  alu
//                                          →  branch_unit
//                                          →  load_store_unit
//                                          →  data_memory
//                                          →  muxes (write-back, next-PC)
//                                          →  register_file (write)
//
//  Datapath summary (single-cycle, combinatorial between clock edges):
//   PC → fetch → decode → execute → mem → write-back → next-PC → PC
//
// Author      : RTL Design Example
// Parameters  : XLEN, IMEM_DEPTH, DMEM_DEPTH, IMEM_FILE, DMEM_FILE
//==========================

`timescale 1ns/1ps
`default_nettype none

module riscv_top #(
    parameter XLEN        = 32,
    parameter IMEM_DEPTH  = 1024,           // Instruction memory depth (words)
    parameter DMEM_DEPTH  = 4096,           // Data memory depth (bytes)
    parameter IMEM_FILE   = "program.hex",
    parameter DMEM_FILE   = "data.hex",
    parameter RESET_ADDR  = 32'h0000_0000
)(
    input  wire clk,
    input  wire rst_n,

    // Expose for testbench monitoring
    output wire [XLEN-1:0] o_pc,
    output wire [XLEN-1:0] o_instr,
    output wire             o_ecall
);

    // ==========================================================================
    // Internal signal declarations
    // ==========================================================================

    // ----- PC stage -----
    wire [XLEN-1:0] pc_current;       // Current PC value
    wire [XLEN-1:0] pc_plus4;         // PC + 4
    wire [XLEN-1:0] pc_next;          // Next PC (from mux)

    // ----- Fetch stage -----
    wire [XLEN-1:0] instr;            // Instruction word from IMEM

    // ----- Decode stage -----
    wire [6:0]      opcode;
    wire [4:0]      rd_addr;
    wire [2:0]      funct3;
    wire [4:0]      rs1_addr;
    wire [4:0]      rs2_addr;
    wire [6:0]      funct7;
    wire [2:0]      imm_sel;
    wire            is_ecall;

    // ----- Immediate -----
    wire [XLEN-1:0] imm;

    // ----- Control signals -----
    wire [3:0]      alu_op;
    wire [1:0]      alu_src_a;
    wire            alu_src_b;
    wire            reg_wen;
    wire            mem_wen;
    wire            mem_ren;
    wire [1:0]      mem_to_reg;
    wire            branch;
    wire [1:0]      jump;

    // ----- Register file -----
    wire [XLEN-1:0] rs1_data;
    wire [XLEN-1:0] rs2_data;
    wire [XLEN-1:0] rd_wdata;

    // ----- ALU -----
    wire [XLEN-1:0] alu_opA;
    wire [XLEN-1:0] alu_opB;
    wire [XLEN-1:0] alu_result;
    wire            zero_flag;
    wire            neg_flag;
    wire            carry_flag;
    wire            ovf_flag;

    // ----- Branch / Jump targets -----
    wire            branch_taken;
    wire [XLEN-1:0] branch_target;    // PC + imm  (used by both branches and JAL)
    wire [XLEN-1:0] jalr_target;      // (rs1 + imm) & ~1

    // ----- Memory -----
    wire [XLEN-1:0] dmem_rdata;       // Raw word from data memory
    wire [XLEN-1:0] load_data;        // Sign/zero-extended load result
    wire [XLEN-1:0] store_data;       // Aligned store data
    wire [3:0]       byte_en;          // Byte enables for DMEM write

    // ==========================================================================
    // PC+4 adder (always needed)
    // ==========================================================================
    assign pc_plus4 = pc_current + 32'd4;

    // ==========================================================================
    // Branch / jump target computation
    //  branch_target = PC + imm   (for BXX and JAL)
    //  jalr_target   = (rs1 + imm) & ~1  (for JALR, clearing bit 0)
    // ==========================================================================
    assign branch_target = pc_current + imm;
    assign jalr_target   = (rs1_data + imm) & {{(XLEN-1){1'b1}}, 1'b0};

    // ==========================================================================
    // Top-level output probes
    // ==========================================================================
    assign o_pc    = pc_current;
    assign o_instr = instr;
    assign o_ecall = is_ecall;

    // ==========================================================================
    // Sub-module instantiation
    // ==========================================================================

    // --------------------------------------------------------------------------
    // 1. Program Counter
    // --------------------------------------------------------------------------
    pc #(
        .XLEN       (XLEN),
        .RESET_ADDR (RESET_ADDR)
    ) u_pc (
        .clk     (clk),
        .rst_n   (rst_n),
        .pc_next (pc_next),
        .pc_out  (pc_current)
    );

    // --------------------------------------------------------------------------
    // 2. Instruction Memory (ROM)
    // --------------------------------------------------------------------------
    instruction_memory #(
        .XLEN      (XLEN),
        .MEM_DEPTH (IMEM_DEPTH),
        .HEX_FILE  (IMEM_FILE)
    ) u_imem (
        .addr  (pc_current),
        .instr (instr)
    );

    // --------------------------------------------------------------------------
    // 3. Decoder – field extraction
    // --------------------------------------------------------------------------
    decoder #(
        .XLEN (XLEN)
    ) u_decoder (
        .instr    (instr),
        .opcode   (opcode),
        .rd       (rd_addr),
        .funct3   (funct3),
        .rs1      (rs1_addr),
        .rs2      (rs2_addr),
        .funct7   (funct7),
        .imm_sel  (imm_sel),
        .is_ecall (is_ecall)
    );

    // --------------------------------------------------------------------------
    // 4. Immediate Generator
    // --------------------------------------------------------------------------
    immediate_generator #(
        .XLEN (XLEN)
    ) u_immgen (
        .instr   (instr),
        .imm_sel (imm_sel),
        .imm_out (imm)
    );

    // --------------------------------------------------------------------------
    // 5. Control Unit
    // --------------------------------------------------------------------------
    control_unit u_ctrl (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_op     (alu_op),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_wen    (reg_wen),
        .mem_wen    (mem_wen),
        .mem_ren    (mem_ren),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump)
    );

    // --------------------------------------------------------------------------
    // 6. Register File
    // --------------------------------------------------------------------------
    register_file #(
        .XLEN  (XLEN),
        .NREGS (32)
    ) u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .rd_addr  (rd_addr),
        .rd_data  (rd_wdata),
        .reg_wen  (reg_wen)
    );

    // --------------------------------------------------------------------------
    // 7. Datapath Muxes (ALU inputs & write-back & next-PC)
    // --------------------------------------------------------------------------
    muxes #(
        .XLEN (XLEN)
    ) u_muxes (
        // ALU src-A
        .rs1_data      (rs1_data),
        .pc_current    (pc_current),
        .alu_src_a     (alu_src_a),
        .alu_opA       (alu_opA),
        // ALU src-B
        .rs2_data      (rs2_data),
        .imm           (imm),
        .alu_src_b     (alu_src_b),
        .alu_opB       (alu_opB),
        // Write-back
        .alu_result    (alu_result),
        .load_data     (load_data),
        .pc_plus4      (pc_plus4),
        .mem_to_reg    (mem_to_reg),
        .rd_wdata      (rd_wdata),
        // Next-PC
        .branch_target (branch_target),
        .jalr_target   (jalr_target),
        .branch_taken  (branch_taken),
        .jump          (jump),
        .pc_next       (pc_next)
    );

    // --------------------------------------------------------------------------
    // 8. ALU
    // --------------------------------------------------------------------------
    alu #(
        .XLEN (XLEN)
    ) u_alu (
        .alu_op     (alu_op),
        .operand_a  (alu_opA),
        .operand_b  (alu_opB),
        .alu_result (alu_result),
        .zero_flag  (zero_flag),
        .neg_flag   (neg_flag),
        .carry_flag (carry_flag),
        .ovf_flag   (ovf_flag)
    );

    // --------------------------------------------------------------------------
    // 9. Branch Unit
    // --------------------------------------------------------------------------
    branch_unit u_branch (
        .funct3      (funct3),
        .branch      (branch),
        .zero_flag   (zero_flag),
        .neg_flag    (neg_flag),
        .carry_flag  (carry_flag),
        .ovf_flag    (ovf_flag),
        .branch_taken(branch_taken)
    );

    // --------------------------------------------------------------------------
    // 10. Load / Store Unit
    //     Effective address from ALU; byte offset from address LSBs
    // --------------------------------------------------------------------------
    load_store_unit #(
        .XLEN (XLEN)
    ) u_lsu (
        .funct3    (funct3),
        .mem_rdata (dmem_rdata),
        .addr_lsb  (alu_result[1:0]),
        .load_data (load_data),
        .rs2_data  (rs2_data),
        .store_data(store_data),
        .byte_en   (byte_en)
    );

    // --------------------------------------------------------------------------
    // 11. Data Memory (RAM)
    // --------------------------------------------------------------------------
    data_memory #(
        .XLEN      (XLEN),
        .MEM_DEPTH (DMEM_DEPTH),
        .HEX_FILE  (DMEM_FILE)
    ) u_dmem (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr    (alu_result),          // Effective address from ALU
        .wdata   (store_data),
        .byte_en (byte_en),
        .mem_wen (mem_wen),
        .rdata   (dmem_rdata)
    );

endmodule

`default_nettype wire
