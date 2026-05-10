# ===========================================================================
# File: program.s (reference assembly – not needed to simulate)
# Description: RV32I test program exercising:
#   - LUI / AUIPC
#   - ADDI / ADD / SUB
#   - STORE / LOAD (SW/LW, SH/LH, SB/LB, LBU, LHU)
#   - Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
#   - JAL / JALR
#   - ECALL to terminate
#
# Register usage:
#   x1  (ra) – return address
#   x2  (sp) – stack pointer (init to 0x100)
#   x10 (a0) – argument / result
#   x11 (a1) – argument
#   x28-x31  – scratch temporaries
#
# Memory map:
#   0x000–0x0FF  Instruction ROM
#   0x000–0x0FF  Data RAM (separate address space in this design)
# ===========================================================================

# ----- Reset vector: 0x000 -----
# 1.  LUI  x28, 0xDEAD      ; x28 = 0xDEAD_0000
# 2.  ADDI x28, x28, 0x123  ; x28 = 0xDEAD_0123  (lower 12 bits)
# 3.  AUIPC x29, 0x0        ; x29 = current PC (= 0x008)
# 4.  ADDI x2, x0, 0x100    ; x2  = 0x100  (stack pointer)
#
# ----- ADD / SUB test -----
# 5.  ADDI x10, x0, 15      ; x10 = 15
# 6.  ADDI x11, x0, 7       ; x11 = 7
# 7.  ADD  x12, x10, x11    ; x12 = 22
# 8.  SUB  x13, x10, x11    ; x13 = 8
#
# ----- Store / Load test -----
# 9.  SW   x12, 0(x2)       ; mem[0x100] = 22 (word)
# 10. LW   x14, 0(x2)       ; x14 = 22
# 11. SH   x11, 4(x2)       ; mem[0x104] = 7  (halfword)
# 12. LH   x15, 4(x2)       ; x15 = 7  (sign-extended)
# 13. SB   x10, 8(x2)       ; mem[0x108] = 15 (byte)
# 14. LBU  x16, 8(x2)       ; x16 = 15 (zero-extended)
#
# ----- Branch test -----
# 15. BEQ  x14, x12, +4     ; taken (22==22) → skip next
# 16. ADDI x17, x0, 0xFF    ; NOT executed
# 17. ADDI x17, x0, 0x1     ; x17 = 1  (branch skipped ADDI 0xFF)
# 18. BNE  x10, x11, +4     ; taken (15≠7) → skip next
# 19. ADDI x18, x0, 0xAA    ; NOT executed
# 20. ADDI x18, x0, 0x2     ; x18 = 2
# 21. BLT  x11, x10, +4     ; taken (7 < 15)
# 22. ADDI x19, x0, 0xBB    ; NOT executed
# 23. ADDI x19, x0, 0x3     ; x19 = 3
#
# ----- JAL / JALR test -----
# 24. JAL  x1,  +8          ; x1 = PC+4, jump forward 8 bytes
# 25. ADDI x20, x0, 0xCC    ; NOT executed (jumped over)
# 26. ADDI x20, x0, 0x4     ; NOT executed (jumped over)
# 27. ADDI x20, x0, 0x4     ; x20 = 4  (JAL landing)
# 28. JALR x0, x1, 0        ; Jump back to saved RA — but this would loop!
#                            ; So we use JALR to a fixed return: see actual hex

# NOTE: The hex below is a hand-assembled version of the program above
#       with the ECALL at the end.  Addresses are 0-based word indices.
