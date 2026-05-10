//==========================
// File: instruction_memory.v
// Description: Read-only instruction memory (ROM) for RV32I processor.
//              Initialized from a hex file at simulation start.
//              Word-addressed internally; byte address input is divided by 4.
//              All reads are combinatorial (single-cycle latency = 0).
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module instruction_memory #(
    parameter XLEN      = 32,           // Data/address width
    parameter MEM_DEPTH = 1024,         // Memory depth in 32-bit words (4 KB)
    parameter HEX_FILE  = "program.hex" // Initialisation file (Verilog $readmemh format)
)(
    input  wire [XLEN-1:0] addr,        // Byte address from PC
    output wire [XLEN-1:0] instr        // 32-bit instruction word
);

    // -----------------------------------------------------------------------
    // Memory array – word-wide storage
    // -----------------------------------------------------------------------
    reg [XLEN-1:0] mem [0:MEM_DEPTH-1];

    // -----------------------------------------------------------------------
    // Initialise ROM from hex file at elaboration time
    // -----------------------------------------------------------------------
    initial begin
        $readmemh(HEX_FILE, mem);
    end

    // -----------------------------------------------------------------------
    // Combinatorial read – PC is always 4-byte aligned in RV32I
    // Word index = byte_addr[XLEN-1:2]
    // -----------------------------------------------------------------------
    assign instr = mem[addr[XLEN-1:2]];

endmodule

`default_nettype wire
