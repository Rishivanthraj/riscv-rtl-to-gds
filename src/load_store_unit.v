//==========================
// File: load_store_unit.v
// Description: Handles byte-enable generation for stores and
//              sign/zero-extension for loads.
//
//  funct3 for loads:
//   3'b000  LB   – signed byte
//   3'b001  LH   – signed halfword
//   3'b010  LW   – word
//   3'b100  LBU  – unsigned byte
//   3'b101  LHU  – unsigned halfword
//
//  funct3 for stores:
//   3'b000  SB   – store byte
//   3'b001  SH   – store halfword
//   3'b010  SW   – store word
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module load_store_unit #(
    parameter XLEN = 32
)(
    // ----- Load path -----
    input  wire [2:0]       funct3,        // Instruction funct3 field
    input  wire [XLEN-1:0]  mem_rdata,     // Raw 32-bit word from data memory
    input  wire [1:0]       addr_lsb,      // LSBs of effective address (byte offset within word)
    output reg  [XLEN-1:0]  load_data,     // Sign/zero-extended load result

    // ----- Store path -----
    input  wire [XLEN-1:0]  rs2_data,      // Store data (from register file)
    output reg  [XLEN-1:0]  store_data,    // Aligned store data (always replicated)
    output reg  [3:0]        byte_en        // Byte-enable strobes for data memory
);

    // -----------------------------------------------------------------------
    // Load data extraction and extension
    // -----------------------------------------------------------------------
    wire [7:0]  byte_sel;
    wire [15:0] half_sel;

    // Select the correct byte/half from the raw 32-bit word based on address LSBs
    // Data memory returns little-endian word; byte 0 is at lowest address.
    assign byte_sel = (addr_lsb == 2'b00) ? mem_rdata[ 7: 0] :
                      (addr_lsb == 2'b01) ? mem_rdata[15: 8] :
                      (addr_lsb == 2'b10) ? mem_rdata[23:16] :
                                            mem_rdata[31:24];

    assign half_sel = (addr_lsb == 2'b00) ? mem_rdata[15: 0] :
                                            mem_rdata[31:16];

    always @(*) begin
        case (funct3)
            3'b000: load_data = {{24{byte_sel[7]}}, byte_sel};         // LB  – sign extend
            3'b001: load_data = {{16{half_sel[15]}}, half_sel};        // LH  – sign extend
            3'b010: load_data = mem_rdata;                             // LW
            3'b100: load_data = {24'h000000, byte_sel};                // LBU – zero extend
            3'b101: load_data = {16'h0000,   half_sel};                // LHU – zero extend
            default: load_data = mem_rdata;
        endcase
    end

    // -----------------------------------------------------------------------
    // Store byte-enable generation
    // Data memory uses byte-granule writes; we must position the write data
    // correctly within the 32-bit bus and assert the right byte enables.
    // -----------------------------------------------------------------------
    always @(*) begin
        store_data = {XLEN{1'b0}};
        byte_en    = 4'b0000;

        case (funct3)
            // SB – store one byte at the correct byte lane
            3'b000: begin
                case (addr_lsb)
                    2'b00: begin store_data = {24'b0, rs2_data[7:0]};        byte_en = 4'b0001; end
                    2'b01: begin store_data = {16'b0, rs2_data[7:0],  8'b0}; byte_en = 4'b0010; end
                    2'b10: begin store_data = { 8'b0, rs2_data[7:0], 16'b0}; byte_en = 4'b0100; end
                    2'b11: begin store_data = {       rs2_data[7:0], 24'b0}; byte_en = 4'b1000; end
                endcase
            end
            // SH – store one halfword (must be 2-byte aligned)
            3'b001: begin
                case (addr_lsb[1])
                    1'b0: begin store_data = {16'b0, rs2_data[15:0]};        byte_en = 4'b0011; end
                    1'b1: begin store_data = {       rs2_data[15:0], 16'b0}; byte_en = 4'b1100; end
                endcase
            end
            // SW – store full word (must be 4-byte aligned)
            3'b010: begin
                store_data = rs2_data;
                byte_en    = 4'b1111;
            end
            default: begin
                store_data = rs2_data;
                byte_en    = 4'b1111;
            end
        endcase
    end

endmodule

`default_nettype wire
