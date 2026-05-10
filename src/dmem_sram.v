`timescale 1ns/1ps
// Data memory wrapper.
//
// This version is intentionally synthesizable into standard cells so OpenLane
// does not require an external SRAM LEF/GDS/LIB macro for floorplanning.
// Simulation still loads data.hex through MEM_FILE.

module dmem_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter MEM_FILE   = "data.hex"
)(
    input  wire                    clk,
    input  wire                    csb,
    input  wire                    web,
    input  wire [DATA_WIDTH/8-1:0] wmask,
    input  wire [ADDR_WIDTH-1:0]   addr,
    input  wire [DATA_WIDTH-1:0]   din,
    output wire [DATA_WIDTH-1:0]   dout
);
    reg [7:0] mem [0:(1<<(ADDR_WIDTH+2))-1];

`ifndef SYNTHESIS
    initial begin
        $readmemh(MEM_FILE, mem);
    end
`endif

    always @(posedge clk) begin
        if (!csb && !web) begin
            if (wmask[0]) mem[{addr,2'b00}+0] <= din[7:0];
            if (wmask[1]) mem[{addr,2'b00}+1] <= din[15:8];
            if (wmask[2]) mem[{addr,2'b00}+2] <= din[23:16];
            if (wmask[3]) mem[{addr,2'b00}+3] <= din[31:24];
        end
    end

    assign dout = csb ? {DATA_WIDTH{1'b0}} : {
        mem[{addr,2'b00}+3],
        mem[{addr,2'b00}+2],
        mem[{addr,2'b00}+1],
        mem[{addr,2'b00}+0]
    };
endmodule
