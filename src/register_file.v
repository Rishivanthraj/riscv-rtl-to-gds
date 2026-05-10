//==========================
// File: register_file.v
// Description: 32 x 32-bit general-purpose register file for RV32I.
//              * x0 is hardwired to 0 (reads always return 0; writes ignored).
//              * Two asynchronous read ports.
//              * One synchronous write port (rising-edge).
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module register_file #(
    parameter XLEN   = 32,             // Register width
    parameter NREGS  = 32              // Number of registers
)(
    input  wire             clk,       // System clock
    input  wire             rst_n,     // Active-LOW synchronous reset (clears all regs)

    // ----- Read port A (rs1) -----
    input  wire [4:0]       rs1_addr,  // Source register 1 index
    output wire [XLEN-1:0]  rs1_data,  // Source register 1 data

    // ----- Read port B (rs2) -----
    input  wire [4:0]       rs2_addr,  // Source register 2 index
    output wire [XLEN-1:0]  rs2_data,  // Source register 2 data

    // ----- Write port (rd) -----
    input  wire [4:0]       rd_addr,   // Destination register index
    input  wire [XLEN-1:0]  rd_data,   // Data to write
    input  wire             reg_wen    // Write-enable
);

    // -----------------------------------------------------------------------
    // Register storage
    // -----------------------------------------------------------------------
    reg [XLEN-1:0] regs [0:NREGS-1];

    integer i;

    // -----------------------------------------------------------------------
    // Synchronous write & reset
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear all registers on reset
            for (i = 0; i < NREGS; i = i + 1)
                regs[i] <= {XLEN{1'b0}};
        end else begin
            // Normal write – x0 is never written (hardwired 0)
            if (reg_wen && (rd_addr != 5'd0))
                regs[rd_addr] <= rd_data;
        end
    end

    // -----------------------------------------------------------------------
    // Asynchronous read – x0 always reads as 0
    // -----------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? {XLEN{1'b0}} : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? {XLEN{1'b0}} : regs[rs2_addr];

endmodule

`default_nettype wire
