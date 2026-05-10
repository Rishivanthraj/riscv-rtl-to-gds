#!/usr/bin/env bash
set -euo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENLANE_ROOT="${OPENLANE_ROOT:-$HOME/OpenLane}"
DESIGN_DIR="$PROJ_ROOT/openlane/riscv_cpu"
OUT="$PROJ_ROOT/output"
mkdir -p "$OUT"

echo "============================================"
echo " Step 3/4 — OpenLane RTL-to-GDS Flow"
echo "============================================"

# ── Verify OpenLane is installed ──────────────────────────────
if [ ! -d "$OPENLANE_ROOT" ]; then
    echo "ERROR: OpenLane not found at $OPENLANE_ROOT"
    echo "Install with:"
    echo "  git clone https://github.com/The-OpenROAD-Project/OpenLane.git ~/OpenLane"
    echo "  cd ~/OpenLane && make"
    exit 1
fi

# ── Verify Docker is running ───────────────────────────────────
if ! docker info &>/dev/null; then
    echo "ERROR: Docker not running. Start with: sudo systemctl start docker"
    exit 1
fi

# ── Copy source into OpenLane's expected layout ────────────────
# OpenLane flow_wrapper.tcl expects the design dir to be inside $OPENLANE_ROOT/designs/
DESIGNS_DIR="$OPENLANE_ROOT/designs/riscv_cpu"
mkdir -p "$DESIGNS_DIR"
cp -r "$DESIGN_DIR/"* "$DESIGNS_DIR/"
cp -r "$PROJ_ROOT/src" "$DESIGNS_DIR/"
cp -r "$PROJ_ROOT/constraints" "$DESIGNS_DIR/"
cp "$PROJ_ROOT/program.hex" "$DESIGNS_DIR/src/"
cp "$PROJ_ROOT/data.hex" "$DESIGNS_DIR/src/"
sed -i 's|"program.hex"|"/openlane/designs/riscv_cpu/src/program.hex"|g' "$DESIGNS_DIR/src/riscv_top_asic.v"
sed -i 's|"data.hex"|"/openlane/designs/riscv_cpu/src/data.hex"|g' "$DESIGNS_DIR/src/riscv_top_asic.v"

echo "Design copied to: $DESIGNS_DIR"
echo ""

# ── Run OpenLane ───────────────────────────────────────────────
cd "$OPENLANE_ROOT"

# The OpenLane Docker flow command:
#   ./flow.tcl -design <name> -tag <run_tag> -overwrite

docker run --rm -v "$OPENLANE_ROOT":/openlane \
           -v "$HOME/pdk":/openlane/pdk \
           -e PDK_ROOT=/openlane/pdk \
           --user $(id -u):$(id -g) \
           ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64 \
           bash -c "cd /openlane && ./flow.tcl -design riscv_cpu -tag run_$(date +%Y%m%d_%H%M%S) -overwrite" \
    | tee "$OUT/openlane_run.log"

echo ""
echo "OpenLane run complete."
echo "Outputs are in: $OPENLANE_ROOT/designs/riscv_cpu/runs/"

# ── Copy final outputs ────────────────────────────────────────
LATEST_RUN=$(ls -td "$OPENLANE_ROOT/designs/riscv_cpu/runs/"*/ | head -1)
echo "Latest run: $LATEST_RUN"

# GDS
GDS_FILE=$(find "$LATEST_RUN" -name "*.gds" | head -1)
[ -n "$GDS_FILE" ] && cp "$GDS_FILE" "$OUT/riscv_cpu_final.gds" && \
    echo "✅  GDS copied to: $OUT/riscv_cpu_final.gds"

# Final netlist
NL_FILE=$(find "$LATEST_RUN/results/final/nl" -name "*.v" 2>/dev/null | head -1)
[ -n "$NL_FILE" ] && cp "$NL_FILE" "$OUT/riscv_cpu_gl_netlist.v"

# Reports
REPORT_DIR="$LATEST_RUN/reports"
[ -d "$REPORT_DIR" ] && cp -r "$REPORT_DIR" "$OUT/openlane_reports"

echo ""
echo "Final outputs:"
ls -lh "$OUT/" 2>/dev/null || true