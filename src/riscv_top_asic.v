//==========================
// File: riscv_top_asic.v
// Description: RV32I single-cycle processor top-level (ASIC target).
//              Wires together all datapath and control sub-modules.
//
//  Ports exposed for simulation / debug:
//    dbg_pc    – current PC (mirrors o_pc)
//    dbg_instr – current instruction word
//    o_pc      – current PC (for testbench monitoring)
//    o_instr   – current instruction (for testbench monitoring)
//    o_ecall   – high when an ECALL instruction is executing
//
//  DFT stub:
//    scan_en / scan_in / scan_out – tied off (passthrough) for non-DFT flows
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module riscv_top_asic (
    input  wire        clk,
    input  wire        rst_n,        // active-low reset

    // Scan chain (DFT stub — tie off for functional simulation)
    input  wire        scan_en,
    input  wire        scan_in,
    output wire        scan_out,

    // Debug / testbench observation ports
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire [31:0] o_pc,
    output wire [31:0] o_instr,
    output wire        o_ecall
);

    // ----------------------------------------------------------------
    // Internal wires – PC
    // ----------------------------------------------------------------
    wire [31:0] pc_current;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;

    assign pc_plus4 = pc_current + 32'd4;

    // ----------------------------------------------------------------
    // Internal wires – Instruction decode
    // ----------------------------------------------------------------
    wire [31:0] instruction;
    wire [6:0]  opcode;
    wire [4:0]  rd_addr;
    wire [2:0]  funct3;
    wire [4:0]  rs1_addr;
    wire [4:0]  rs2_addr;
    wire [6:0]  funct7;
    wire [2:0]  imm_sel;
    wire        is_ecall;

    // ----------------------------------------------------------------
    // Internal wires – Register file
    // ----------------------------------------------------------------
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_wdata;
    wire        reg_wen;

    // ----------------------------------------------------------------
    // Internal wires – Immediate generator
    // ----------------------------------------------------------------
    wire [31:0] imm_out;

    // ----------------------------------------------------------------
    // Internal wires – Control unit
    // ----------------------------------------------------------------
    wire [3:0]  alu_op;
    wire [1:0]  alu_src_a;
    wire        alu_src_b;
    wire        mem_wen;
    wire        mem_ren;
    wire [1:0]  mem_to_reg;
    wire        branch;
    wire [1:0]  jump;

    // ----------------------------------------------------------------
    // Internal wires – ALU
    // ----------------------------------------------------------------
    wire [31:0] alu_opA, alu_opB;
    wire [31:0] alu_result;
    wire        alu_zero, alu_neg, alu_carry, alu_overflow;

    // ----------------------------------------------------------------
    // Internal wires – Branch unit
    // ----------------------------------------------------------------
    wire        branch_taken;
    wire [31:0] branch_target;

    // ----------------------------------------------------------------
    // Internal wires – Data memory / LSU
    // ----------------------------------------------------------------
    wire [31:0] dmem_rdata;
    wire [31:0] load_data;
    wire [31:0] store_data;
    wire [3:0]  byte_en;

    // ----------------------------------------------------------------
    // Program Counter
    // ----------------------------------------------------------------
    pc u_pc (
        .clk     (clk),
        .rst_n   (rst_n),
        .pc_next (pc_next),
        .pc_out  (pc_current)
    );

    // ----------------------------------------------------------------
    // Instruction Memory  (behavioural SRAM; $readmemh in sim path)
    // ----------------------------------------------------------------
    imem_sram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (32),
        .MEM_FILE   ("program.hex")
    ) u_imem (
        .clk  (clk),
        .csb  (1'b0),
        .addr (pc_current[9:2]),   // word-address (byte-addr >> 2)
        .dout (instruction)
    );

    // ----------------------------------------------------------------
    // Instruction Decoder / field extractor
    // ----------------------------------------------------------------
    decoder u_dec (
        .instr    (instruction),
        .opcode   (opcode),
        .rd       (rd_addr),
        .funct3   (funct3),
        .rs1      (rs1_addr),
        .rs2      (rs2_addr),
        .funct7   (funct7),
        .imm_sel  (imm_sel),
        .is_ecall (is_ecall)
    );

    // ----------------------------------------------------------------
    // Register File
    // ----------------------------------------------------------------
    register_file u_rf (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_wdata),
        .reg_wen  (reg_wen),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ----------------------------------------------------------------
    // Immediate Generator
    // ----------------------------------------------------------------
    immediate_generator u_imm (
        .instr   (instruction),
        .imm_sel (imm_sel),
        .imm_out (imm_out)
    );

    // ----------------------------------------------------------------
    // Control Unit
    // ----------------------------------------------------------------
    control_unit u_ctrl (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_op    (alu_op),
        .alu_src_a (alu_src_a),
        .alu_src_b (alu_src_b),
        .reg_wen   (reg_wen),
        .mem_wen   (mem_wen),
        .mem_ren   (mem_ren),
        .mem_to_reg(mem_to_reg),
        .branch    (branch),
        .jump      (jump)
    );

    // ----------------------------------------------------------------
    // Datapath Muxes  (ALU inputs, write-back, PC-next)
    // ----------------------------------------------------------------
    muxes u_mux (
        // ALU src-A
        .rs1_data     (rs1_data),
        .pc_current   (pc_current),
        .alu_src_a    (alu_src_a),
        .alu_opA      (alu_opA),

        // ALU src-B
        .rs2_data     (rs2_data),
        .imm          (imm_out),
        .alu_src_b    (alu_src_b),
        .alu_opB      (alu_opB),

        // Write-back
        .alu_result   (alu_result),
        .load_data    (load_data),
        .pc_plus4     (pc_plus4),
        .mem_to_reg   (mem_to_reg),
        .rd_wdata     (rd_wdata),

        // Next PC
        .branch_target(branch_target),
        .jalr_target  (alu_result),       // JALR target = rs1 + imm (from ALU)
        .branch_taken (branch_taken),
        .jump         (jump),
        .pc_next      (pc_next)
    );

    // ----------------------------------------------------------------
    // ALU
    // ----------------------------------------------------------------
    alu u_alu (
        .alu_op     (alu_op),
        .operand_a  (alu_opA),
        .operand_b  (alu_opB),
        .alu_result (alu_result),
        .zero_flag  (alu_zero),
        .neg_flag   (alu_neg),
        .carry_flag (alu_carry),
        .ovf_flag   (alu_overflow)
    );

    // ----------------------------------------------------------------
    // Branch Unit  — evaluates taken/not-taken and computes target
    //   branch_target = PC + imm  (B-type offset)
    // ----------------------------------------------------------------
    assign branch_target = pc_current + imm_out;

    branch_unit u_bru (
        .funct3      (funct3),
        .branch      (branch),
        .zero_flag   (alu_zero),
        .neg_flag    (alu_neg),
        .carry_flag  (alu_carry),
        .ovf_flag    (alu_overflow),
        .branch_taken(branch_taken)
    );

    // ----------------------------------------------------------------
    // Data Memory  (behavioural SRAM; $readmemh in sim path)
    // ----------------------------------------------------------------
    dmem_sram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (32),
        .MEM_FILE   ("data.hex")
    ) u_dmem (
        .clk   (clk),
        .csb   (~(mem_ren | mem_wen)),
        .web   (~mem_wen),
        .wmask (byte_en),
        .addr  (alu_result[9:2]),
        .din   (store_data),
        .dout  (dmem_rdata)
    );

    // ----------------------------------------------------------------
    // Load/Store Unit — byte-enable generation + sign extension
    // ----------------------------------------------------------------
    load_store_unit u_lsu (
        .funct3     (funct3),
        .mem_rdata  (dmem_rdata),
        .addr_lsb   (alu_result[1:0]),   // byte offset within word
        .load_data  (load_data),
        .rs2_data   (rs2_data),
        .store_data (store_data),
        .byte_en    (byte_en)
    );

    // ----------------------------------------------------------------
    // Observation / debug outputs
    // ----------------------------------------------------------------
    assign o_pc    = pc_current;
    assign o_instr = instruction;
    assign o_ecall = is_ecall;

    assign dbg_pc    = pc_current;
    assign dbg_instr = instruction;

    // ----------------------------------------------------------------
    // DFT stub — scan chain passthrough
    // ----------------------------------------------------------------
    assign scan_out = scan_in;

endmodule

`default_nettype wire
