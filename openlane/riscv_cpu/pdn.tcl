##############################################################
# PDN Configuration for RV32I CPU — Sky130 HD
# Called by OpenLane's pdn step (uses OpenROAD pdn tool)
##############################################################

set ::power_nets  "VPWR"
set ::ground_nets "VGND"

# Standard cell rails on met1
add_global_connection -net VPWR -pin_pattern "^VPWR$" -power
add_global_connection -net VGND -pin_pattern "^VGND$" -ground

# ── Core ring ─────────────────────────────────────────────────
define_pdn_grid -name "core_grid" -voltage_domains {CORE}

add_pdn_ring \
    -grid "core_grid" \
    -layers {met4 met5} \
    -widths {3.1 3.1} \
    -spacings {1.7 1.7} \
    -core_offsets {2 2}

# ── met1 standard cell rails ──────────────────────────────────
add_pdn_stripe \
    -grid "core_grid" \
    -layer met1 \
    -width 0.48 \
    -followpins

# ── met4 vertical stripes ─────────────────────────────────────
add_pdn_stripe \
    -grid "core_grid" \
    -layer met4 \
    -width 3.1 \
    -pitch 180 \
    -offset 14

# ── met3 horizontal stripes ───────────────────────────────────
add_pdn_stripe \
    -grid "core_grid" \
    -layer met3 \
    -width 3.1 \
    -pitch 180 \
    -offset 14

# ── Connect met1 to met3 to met4 ──────────────────────────────
add_pdn_connect -grid "core_grid" -layers {met1 met4}
add_pdn_connect -grid "core_grid" -layers {met3 met4}
add_pdn_connect -grid "core_grid" -layers {met4 met5}