# RISC-V RTL-to-GDS ASIC Flow
Built a complete RISC-V ASIC flow from RTL to GDSII using Verilog, OpenLane, and Sky130. Implemented synthesis, floorplanning, placement, CTS, routing, STA, DRC/LVS verification,
and final chip layout generation with zero timing and DRC violations.


## Overview

This project demonstrates a complete RTL-to-GDS ASIC implementation flow for a custom RISC-V processor using the open-source OpenLane and OpenROAD toolchain on the Sky130 PDK.

The design was developed in Verilog and successfully taken through:
- RTL Design
- Functional Simulation
- Logic Synthesis
- Floorplanning
- Placement
- Clock Tree Synthesis
- Routing
- STA
- DRC/LVS Verification
- Final GDSII Generation


## Tools & Technologies

- Verilog HDL
- OpenLane
- OpenROAD
- Sky130 PDK
- Magic VLSI
- KLayout
- Icarus Verilog
- GTKWave
- Ubuntu / Docker

## Flow

RTL → Simulation → Synthesis → Floorplan → Placement → CTS → Routing → STA → DRC/LVS → GDSII

## Repository Structure

src/              → Verilog RTL files  
sim/              → Testbenches & waveforms  
scripts/          → OpenLane automation scripts  
config/           → OpenLane configs  
output/           → Final GDS and reports  


## Results

- DRC Violations: 0
- LVS Status: Clean
- Antenna Violations: 0
- Setup Violations: 0
- Hold Violations: 0
- Total Cells: 7021
- Technology Node: Sky130


## Layout Results

### KLayout GDS View

<img width="1919" height="1016" alt="KLayout Layout" src="https://github.com/user-attachments/assets/0cd5af4e-dc92-4b10-bb9c-4911ca6d3987" />

### Magic Layout View

<img width="1919" height="1021" alt="Magic Layout" src="https://github.com/user-attachments/assets/c090027f-ff9f-4bbd-a3db-22097ecf94fc" />

