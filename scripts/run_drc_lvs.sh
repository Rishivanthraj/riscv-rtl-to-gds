#!/usr/bin/env bash
set -euo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$PROJ_ROOT/output"
PDK_ROOT="${PDK_ROOT:-$HOME/pdk}"

GDS_FILE="$OUT/riscv_cpu_final.gds"
NETLIST="$OUT/riscv_cpu_gl_netlist.v"
DESIGN="riscv_top_asic"

echo "============================================"
echo " Step 4/4 — DRC (Magic) + LVS (Netgen)"
echo "============================================"

# ── Verify GDS exists ─────────────────────────────────────────
if [ ! -f "$GDS_FILE" ]; then
    echo "ERROR: GDS not found at $GDS_FILE"
    echo "Run run_openlane.sh first."
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# DRC — Magic
# ═══════════════════════════════════════════════════════════════
echo ""
echo "── DRC (Magic) ──────────────────────────────"

DRC_SCRIPT="$OUT/run_drc.tcl"
cat > "$DRC_SCRIPT" <<'MAGIC_TCL'
# Magic DRC script
gds read $env(GDS_FILE)
load $env(DESIGN)
drc on
drc catchup
set drc_count [drc list count total]
puts "DRC violation count: $drc_count"
if {$drc_count > 0} {
    drc listall why
    puts "❌ DRC FAILED with $drc_count violations"
} else {
    puts "✅ DRC CLEAN"
}
quit
MAGIC_TCL

export GDS_FILE DESIGN
magic -noconsole -dnull \
      -rcfile "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc" \
      "$DRC_SCRIPT" 2>&1 | tee "$OUT/drc_report.log"

echo "DRC report: $OUT/drc_report.log"

# ═══════════════════════════════════════════════════════════════
# LVS — Netgen
# ═══════════════════════════════════════════════════════════════
echo ""
echo "── LVS (Netgen) ─────────────────────────────"

# Extract SPICE from GDS using Magic
SPICE_FILE="$OUT/${DESIGN}.spice"
EXTRACT_SCRIPT="$OUT/run_extract.tcl"
cat > "$EXTRACT_SCRIPT" <<MAGIC_TCL2
gds read $GDS_FILE
load $DESIGN
extract all
ext2spice lvs
ext2spice -o $SPICE_FILE
quit
MAGIC_TCL2

magic -noconsole -dnull \
      -rcfile "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc" \
      "$EXTRACT_SCRIPT" 2>&1 | tee "$OUT/extract.log"

echo "Extracted SPICE: $SPICE_FILE"

# Run Netgen LVS
LVS_SETUP="$PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl"
LVS_REPORT="$OUT/lvs_report.txt"

netgen -batch lvs \
    "$SPICE_FILE $DESIGN" \
    "$NETLIST $DESIGN" \
    "$LVS_SETUP" \
    "$LVS_REPORT" 2>&1 | tee "$OUT/lvs_run.log"

echo "LVS report: $LVS_REPORT"

# ── Parse results ─────────────────────────────────────────────
echo ""
echo "── Signoff Summary ──────────────────────────"
if grep -q "Circuits match" "$LVS_REPORT" 2>/dev/null; then
    echo "✅  LVS CLEAN"
else
    echo "❌  LVS FAILED — check $LVS_REPORT"
fi

if grep -q "DRC CLEAN\|0 violations" "$OUT/drc_report.log" 2>/dev/null; then
    echo "✅  DRC CLEAN"
else
    echo "❌  DRC has violations — check $OUT/drc_report.log"
fi
echo "─────────────────────────────────────────────"