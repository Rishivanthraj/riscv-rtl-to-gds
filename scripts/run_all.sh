#!/usr/bin/env bash
set -uo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$PROJ_ROOT/scripts"
OUT="$PROJ_ROOT/output"
mkdir -p "$OUT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MASTER_LOG="$OUT/run_all_${TIMESTAMP}.log"

echo "╔══════════════════════════════════════════════╗"
echo "║   RV32I  RTL → GDSII  Full Flow              ║"
echo "║   Started: $(date)         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "All output → $OUT/"
echo "Master log → $MASTER_LOG"
echo ""

# Helper: timestamped section header
section() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════"
}

# Run a step and capture timing
run_step() {
    local name="$1"
    local script="$2"
    section "$name"
    local t0=$SECONDS
    bash "$script" 2>&1 | tee -a "$MASTER_LOG"; local rc=${PIPESTATUS[0]}
    local elapsed=$(( SECONDS - t0 ))
    if [ $rc -ne 0 ]; then
        echo "  ❌  $name FAILED (exit $rc) — aborting flow"
        exit $rc
    fi
    echo "  ✅  $name done in ${elapsed}s"
}

# ── Gate each step on previous success ────────────────────────
run_step "STEP 1/4 — RTL Simulation"   "$SCRIPTS/run_sim.sh"
run_step "STEP 2/4 — Yosys Synthesis"  "$SCRIPTS/run_synth.sh"
run_step "STEP 3/4 — OpenLane P&R"     "$SCRIPTS/run_openlane.sh"
run_step "STEP 4/4 — DRC + LVS"        "$SCRIPTS/run_drc_lvs.sh"

# ── Final output inventory ────────────────────────────────────
section "Final Deliverables"
echo ""
echo "Generated files:"
for f in \
    "$OUT/riscv_netlist.v" \
    "$OUT/riscv_cpu_gl_netlist.v" \
    "$OUT/riscv_cpu_final.gds" \
    "$OUT/synth_area.rpt" \
    "$OUT/drc_report.log" \
    "$OUT/lvs_report.txt" \
    "$OUT/sim_output.log" \
    "$OUT/openlane_reports"
do
    if [ -e "$f" ]; then
        size=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo "  ✅  $(basename $f)  ($size)"
    else
        echo "  ⚠️   $(basename $f)  — not found"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Flow Complete: $(date)    ║"
echo "╚══════════════════════════════════════════════╝"