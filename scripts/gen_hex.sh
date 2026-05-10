#!/usr/bin/env bash
# Regenerates program.hex (256 words) and data.hex (1024 bytes) cleanly
PROJ=/mnt/c/Users/rishi/Downloads/files

# ── program.hex ──────────────────────────────────────────────
# 30 real instructions + 226 NOPs = 256 words total
cat > "$PROJ/program.hex" << 'EOF'
0DEADE37
123E0E13
00000E97
10000113
00F00513
00700593
00B50633
40B506B3
00C12023
00012703
00B11223
00411783
00A10423
00814803
00C70463
0FF00893
00100893
00B51463
0AA00913
00200913
00A5C463
0BB00993
00300993
00C000EF
0CC00A13
0DD00A13
00400A13
01008067
00500B13
00000073
EOF

# Pad to 256 words with NOPs (ADDI x0,x0,0)
CURRENT=$(wc -l < "$PROJ/program.hex")
NEEDED=$((256 - CURRENT))
for i in $(seq 1 $NEEDED); do
    echo "00000013"
done >> "$PROJ/program.hex"

FINAL=$(wc -l < "$PROJ/program.hex")
echo "program.hex: $FINAL words (should be 256)"

# ── data.hex ─────────────────────────────────────────────────
# 256 word-addresses × 4 bytes = 1024 bytes
printf '%s\n' $(for i in $(seq 1 1024); do printf '00 '; done) | tr ' ' '\n' | head -1024 > "$PROJ/data.hex"
DLINES=$(wc -l < "$PROJ/data.hex")
echo "data.hex: $DLINES bytes (should be 1024)"
