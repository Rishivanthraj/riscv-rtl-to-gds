#!/usr/bin/env bash
set -uo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$PROJ_ROOT/output"
mkdir -p "$OUT"

echo "============================================"
echo " Step 2/4 — Synthesis (Yosys + Sky130)"
echo "============================================"

if ! command -v yosys &>/dev/null; then
    echo "ERROR: yosys not found. Run: sudo apt install yosys"
    exit 1
fi

# Locate Sky130 liberty file
PDK_ROOT="${PDK_ROOT:-$HOME/pdk}"
PDK_LIB="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

if [ ! -f "$PDK_LIB" ]; then
    echo "ERROR: Sky130 liberty not found at $PDK_LIB"
    echo "Set PDK_ROOT or install PDK with:"
    echo "  pip3 install volare"
    echo "  volare enable --pdk sky130 --pdk-root $HOME/pdk bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"
    exit 1
fi

export PDK_LIB

echo "Using PDK liberty: $PDK_LIB"
echo ""

cd "$PROJ_ROOT/synthesis"
sed "s|\$::env(PDK_LIB)|$PDK_LIB|g" synth.ys > synth_tmp.ys
yosys synth_tmp.ys 2>&1 | tee "$OUT/yosys_run.log"; YOSYS_RC=${PIPESTATUS[0]}
rm -f synth_tmp.ys
if [ "$YOSYS_RC" -ne 0 ]; then
    echo "ERROR: Yosys failed (exit $YOSYS_RC) — check $OUT/yosys_run.log"
    exit "$YOSYS_RC"
fi

echo ""
echo "Synthesis outputs:"
echo "  Netlist : $OUT/riscv_netlist.v"
echo "  Area    : $OUT/synth_area.rpt"
echo "  Log     : $OUT/yosys_run.log"

# Show area summary
echo ""
echo "── Area Summary ─────────────────────────────"
grep -A 20 "Printing statistics" "$OUT/yosys_run.log" | head -25 || true
echo "─────────────────────────────────────────────"
