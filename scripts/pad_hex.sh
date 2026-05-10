#!/usr/bin/env bash
# Pad program.hex to exactly 256 words (NOP = ADDI x0,x0,0 = 0x00000013)
HEX=/mnt/c/Users/rishi/Downloads/files/program.hex
LINES=$(wc -l < "$HEX")
PAD=$((256 - LINES))
if [ $PAD -gt 0 ]; then
    for i in $(seq 1 $PAD); do echo '00000013'; done >> "$HEX"
    echo "Padded program.hex: added $PAD NOP words (total 256)"
else
    echo "program.hex already has $LINES words (no padding needed)"
fi

# Pad data.hex to exactly 1024 bytes
DHEX=/mnt/c/Users/rishi/Downloads/files/data.hex
DLINES=$(wc -l < "$DHEX")
DPAD=$((1024 - DLINES))
if [ $DPAD -gt 0 ]; then
    for i in $(seq 1 $DPAD); do echo '00'; done >> "$DHEX"
    echo "Padded data.hex: added $DPAD zero bytes (total 1024)"
else
    echo "data.hex already has $DLINES bytes (no padding needed)"
fi
