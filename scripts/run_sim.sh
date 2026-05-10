#!/usr/bin/env bash
set -uo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$PROJ_ROOT/src"
TB="$PROJ_ROOT/testbench"
OUT="$PROJ_ROOT/output"
mkdir -p "$OUT"

echo "============================================"
echo " Step 1/4 — RTL Simulation (Icarus Verilog)"
echo "============================================"

# Verify iverilog is installed
if ! command -v iverilog &>/dev/null; then
    echo "ERROR: iverilog not found. Run: sudo apt install iverilog"
    exit 1
fi

# Compile — imem_sram / dmem_sram contain the behavioural ($readmemh) sim path
iverilog -g2012 -Wall -o "$OUT/cpu_sim" \
    "$TB/tb_riscv.v" \
    "$SRC/riscv_top_asic.v" \
    "$SRC/pc.v" \
    "$SRC/imem_sram.v" \
    "$SRC/dmem_sram.v" \
    "$SRC/register_file.v" \
    "$SRC/alu.v" \
    "$SRC/control_unit.v" \
    "$SRC/immediate_generator.v" \
    "$SRC/branch_unit.v" \
    "$SRC/load_store_unit.v" \
    "$SRC/decoder.v" \
    "$SRC/muxes.v"

echo "Compiled OK → $OUT/cpu_sim"

# Copy hex files so simulation finds them in working dir
cp "$PROJ_ROOT"/*.hex "$OUT/" 2>/dev/null || true

# Run simulation
cd "$OUT"
vvp cpu_sim | tee sim_output.log; SIM_EXIT=${PIPESTATUS[0]}

echo ""
echo "Simulation log : $OUT/sim_output.log"
echo "Waveform (VCD) : $OUT/dump.vcd   (view with: gtkwave dump.vcd)"

# Quick pass/fail check
if grep -q "SIMULATION ENDED (ECALL)" sim_output.log; then
    echo "✅  Simulation PASSED — ECALL reached successfully"
elif grep -q "WATCHDOG TIMEOUT" sim_output.log; then
    echo "❌  Simulation FAILED — watchdog timeout (CPU stuck or program too short)"
    exit 1
else
    echo "❌  Simulation FAILED — unexpected termination (exit=$SIM_EXIT)"
    exit 1
fi
