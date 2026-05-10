`timescale 1ns/1ps
// Instruction memory wrapper.
//
// This version is intentionally synthesizable into standard cells so OpenLane
// does not require an external SRAM LEF/GDS/LIB macro for floorplanning.
// Simulation still loads program.hex through MEM_FILE.

module imem_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter MEM_FILE   = "program.hex"
)(
    input  wire                  clk,
    input  wire                  csb,
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] dout
);
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

`ifndef SYNTHESIS
    initial begin
        $readmemh(MEM_FILE, mem);
    end
`endif

    assign dout = csb ? {DATA_WIDTH{1'b0}} : mem[addr];

    wire _unused_clk = clk;
endmodule
