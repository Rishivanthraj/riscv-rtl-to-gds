//==========================
// File: pc.v
// Description: Program Counter module for RV32I single-cycle processor.
//              Holds the current PC and updates it every clock cycle
//              based on the next-PC value computed by the control/branch unit.
// Author      : RTL Design Example
// Style       : Synchronous reset, active-high rst_n (active LOW reset)
//==========================

`timescale 1ns/1ps
`default_nettype none

module pc #(
    parameter XLEN       = 32,          // Register/address width (always 32 for RV32I)
    parameter RESET_ADDR = 32'h0000_0000 // Boot vector
)(
    input  wire             clk,        // System clock (rising-edge triggered)
    input  wire             rst_n,      // Asynchronous active-LOW reset
    input  wire [XLEN-1:0]  pc_next,    // Next PC value (from mux: PC+4 / branch / jump)
    output reg  [XLEN-1:0]  pc_out      // Current PC value broadcast to rest of design
);

    // -----------------------------------------------------------------------
    // Sequential logic – update PC every cycle
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_out <= RESET_ADDR;       // Reset to boot vector
        else
            pc_out <= pc_next;          // Latch next-PC computed combinatorially
    end

endmodule

`default_nettype wire
