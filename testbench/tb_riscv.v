//==========================
// File: tb_riscv.v
// Description: Full self-checking testbench for the RV32I single-cycle
//              processor.
//
//  Features:
//   * Clock generation (10 ns period → 100 MHz)
//   * Asynchronous active-LOW reset
//   * Loads instruction memory from program.hex  (via imem_sram)
//   * Loads data    memory from data.hex         (via dmem_sram)
//   * Runs until ECALL or MAX_CYCLES
//   * Dumps full VCD waveform (dump.vcd)
//   * Prints all 32 register values at end of simulation
//   * Prints final PC
//
// Author      : RTL Design Example
//==========================

`timescale 1ns/1ps
`default_nettype none

module tb_riscv;

    // ==========================================================================
    // Parameters
    // ==========================================================================
    parameter CLK_PERIOD  = 10;            // Clock period in ns (100 MHz)
    parameter RESET_CYCLES = 5;            // Number of cycles to hold reset
    parameter MAX_CYCLES   = 10000;        // Simulation watchdog

    // ==========================================================================
    // DUT interface signals
    // ==========================================================================
    reg  clk;
    reg  rst_n;

    // DFT stub — tie off unused scan ports
    wire scan_out;

    // Observation outputs
    wire [31:0] o_pc;
    wire [31:0] o_instr;
    wire        o_ecall;

    // ==========================================================================
    // Instantiate DUT
    //   riscv_top_asic has NO parameters in the module header — memory depth
    //   and files are fixed inside imem_sram / dmem_sram instantiations.
    // ==========================================================================
    riscv_top_asic u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        // DFT stubs
        .scan_en  (1'b0),
        .scan_in  (1'b0),
        .scan_out (scan_out),
        // Debug / observation
        .dbg_pc   (),        // unused in TB (mirrored by o_pc)
        .dbg_instr(),        // unused in TB (mirrored by o_instr)
        .o_pc     (o_pc),
        .o_instr  (o_instr),
        .o_ecall  (o_ecall)
    );

    // ==========================================================================
    // Clock generation
    // ==========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ==========================================================================
    // VCD waveform dump
    // ==========================================================================
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv);           // Dump entire design hierarchy
    end

    // ==========================================================================
    // Cycle counter
    // ==========================================================================
    integer cycle_count;

    // ==========================================================================
    // Reset and simulation control
    // ==========================================================================
    initial begin
        // Assert reset
        rst_n       = 1'b0;
        cycle_count = 0;

        $display("=============================================================");
        $display("  RV32I Single-Cycle CPU Simulation");
        $display("=============================================================");
        $display("  Time: %0t | Asserting RESET", $time);

        // Hold reset for RESET_CYCLES cycles
        repeat (RESET_CYCLES) @(posedge clk);
        #1; // Small offset to avoid clock-edge race
        rst_n = 1'b1;

        $display("  Time: %0t | Reset de-asserted, CPU running...", $time);
        $display("-------------------------------------------------------------");
        $display("  Cycle  |     PC     |    Instr   | Notes");
        $display("-------------------------------------------------------------");
    end

    // ==========================================================================
    // Per-cycle monitoring
    // ==========================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;

            // Print trace for first 50 cycles to avoid log spam
            if (cycle_count <= 50) begin
                $display("  %5d  | 0x%08h | 0x%08h |%s",
                    cycle_count, o_pc, o_instr,
                    o_ecall ? " <<< ECALL >>>" : "");
            end

            // ---- Stop conditions ----
            if (o_ecall) begin
                $display("-------------------------------------------------------------");
                $display("  ECALL detected at PC=0x%08h, cycle=%0d", o_pc, cycle_count);
                print_regs();
                $display("=============================================================");
                $display("  SIMULATION ENDED (ECALL)");
                $display("=============================================================");
                #(CLK_PERIOD * 2);
                $finish;
            end

            if (cycle_count >= MAX_CYCLES) begin
                $display("-------------------------------------------------------------");
                $display("  WATCHDOG TIMEOUT at cycle=%0d (MAX_CYCLES=%0d)",
                         cycle_count, MAX_CYCLES);
                print_regs();
                $display("=============================================================");
                $display("  SIMULATION ENDED (TIMEOUT)");
                $display("=============================================================");
                $finish;
            end
        end
    end

    // ==========================================================================
    // Task: print all 32 registers
    //   Hierarchy: u_dut (riscv_top_asic) → u_rf (register_file) → regs[i]
    // ==========================================================================
    task print_regs;
        integer i;
        begin
            $display("");
            $display("  ---- Register File Dump ----");
            $display("  Reg  | Value");
            $display("  -----+------------");
            for (i = 0; i < 32; i = i + 1) begin
                $display("  x%-2d  | 0x%08h",
                    i, u_dut.u_rf.regs[i]);
            end
            $display("  -----+------------");
            $display("  PC   | 0x%08h", o_pc);
            $display("");
        end
    endtask

endmodule

`default_nettype wire
