##############################################################
# riscv_cpu.sdc — Timing constraints for Sky130 @ 25 MHz
# (Sky130 typical cell speed ~ 10–50 MHz for simple logic)
# Adjust CLK_PERIOD to push timing or relax it
##############################################################

set CLK_PERIOD 40.0          ;# 25 MHz — achievable in Sky130
set CLK_NAME   "clk"
set CLK_PORT   [get_ports $CLK_NAME]

# ── Primary clock ──────────────────────────────────────────
create_clock -name $CLK_NAME \
             -period $CLK_PERIOD \
             -waveform [list 0 [expr $CLK_PERIOD / 2]] \
             $CLK_PORT

# ── Clock uncertainty (jitter + skew budget) ───────────────
set_clock_uncertainty -setup 0.5 [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  0.2 [get_clocks $CLK_NAME]

# ── Clock transition (rise/fall time) ──────────────────────
set_clock_transition 0.15 [get_clocks $CLK_NAME]

# ── Input delays (assume 40% of period for external logic) ─
set_input_delay  -max [expr $CLK_PERIOD * 0.40] \
                 -clock $CLK_NAME \
                 [all_inputs]

set_input_delay  -min [expr $CLK_PERIOD * 0.05] \
                 -clock $CLK_NAME \
                 [all_inputs]

# ── Output delays ──────────────────────────────────────────
set_output_delay -max [expr $CLK_PERIOD * 0.40] \
                 -clock $CLK_NAME \
                 [all_outputs]

set_output_delay -min [expr $CLK_PERIOD * 0.05] \
                 -clock $CLK_NAME \
                 [all_outputs]

# ── Don't touch the clock port itself ──────────────────────
set_dont_touch_network [get_clocks $CLK_NAME]

# ── Driving cell for inputs (sky130 standard cell) ─────────
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 \
                 -pin X \
                 [all_inputs]

# ── Load on all outputs ────────────────────────────────────
set_load -pin_load 0.05 [all_outputs]

# ── False paths for async reset (if used) ──────────────────
# set_false_path -from [get_ports rst_n]

# ── Max fanout / transition ────────────────────────────────
set_max_fanout  10 [current_design]
set_max_transition 0.5 [current_design]

# ── Case analysis ──────────────────────────────────────────
set_case_analysis 0 [get_ports scan_en]
