//==========================
// File: muxes.v
// Description: Centralised collection of all datapath multiplexers for the
//              RV32I single-cycle processor.  Keeping muxes in one file
//              reduces clutter in the top-level and makes the datapath
//              connectivity explicit.
//
//  Muxes implemented:
//   1. ALU operand-A mux  : rs1 vs. PC
//   2. ALU operand-B mux  : rs2 vs. immediate
//   3. Write-back mux     : ALU result vs. memory load data vs. PC+4
//   4. Next-PC mux        : PC+4 vs. branch target vs. JAL target vs. JALR target
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module muxes #(
    parameter XLEN = 32
)(
    // ---- ALU src-A mux ----
    input  wire [XLEN-1:0]  rs1_data,      // Register rs1
    input  wire [XLEN-1:0]  pc_current,    // Current PC
    input  wire [1:0]        alu_src_a,     // 00=rs1, 01=PC
    output wire [XLEN-1:0]  alu_opA,       // ALU operand A

    // ---- ALU src-B mux ----
    input  wire [XLEN-1:0]  rs2_data,      // Register rs2
    input  wire [XLEN-1:0]  imm,           // Sign-extended immediate
    input  wire              alu_src_b,     // 0=rs2, 1=imm
    output wire [XLEN-1:0]  alu_opB,       // ALU operand B

    // ---- Write-back mux ----
    input  wire [XLEN-1:0]  alu_result,    // From ALU
    input  wire [XLEN-1:0]  load_data,     // From load_store_unit
    input  wire [XLEN-1:0]  pc_plus4,      // PC+4 (return address for JAL/JALR)
    input  wire [1:0]        mem_to_reg,    // 00=ALU, 01=MEM, 10=PC+4
    output wire [XLEN-1:0]  rd_wdata,      // Data to write to register file

    // ---- Next-PC mux ----
    input  wire [XLEN-1:0]  branch_target, // PC + branch_imm
    input  wire [XLEN-1:0]  jalr_target,   // (rs1 + imm) & ~1
    input  wire              branch_taken,  // From branch_unit
    input  wire [1:0]        jump,          // 00=none, 01=JAL, 10=JALR
    output wire [XLEN-1:0]  pc_next        // Next PC to latch
);

    // -----------------------------------------------------------------------
    // 1. ALU operand-A mux
    //    alu_src_a: 00=rs1, 01=PC
    // -----------------------------------------------------------------------
    assign alu_opA = (alu_src_a == 2'b01) ? pc_current : rs1_data;

    // -----------------------------------------------------------------------
    // 2. ALU operand-B mux
    // -----------------------------------------------------------------------
    assign alu_opB = alu_src_b ? imm : rs2_data;

    // -----------------------------------------------------------------------
    // 3. Write-back mux
    //    00=ALU, 01=MEM load, 10=PC+4
    // -----------------------------------------------------------------------
    assign rd_wdata = (mem_to_reg == 2'b01) ? load_data  :
                      (mem_to_reg == 2'b10) ? pc_plus4   :
                                              alu_result;

    // -----------------------------------------------------------------------
    // 4. Next-PC mux
    //    Priority: JALR > JAL > branch > PC+4
    // -----------------------------------------------------------------------
    assign pc_next = (jump == 2'b10)   ? {jalr_target[XLEN-1:1], 1'b0} :   // JALR (LSB cleared per spec)
                     (jump == 2'b01)   ? branch_target  :   // JAL (target = PC + imm)
                     branch_taken      ? branch_target  :   // Conditional branch
                                         pc_plus4;          // Normal sequential

endmodule

`default_nettype wire
