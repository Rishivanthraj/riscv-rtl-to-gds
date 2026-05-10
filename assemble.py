# ===========================================================================
# File: assemble.py
# Generates program.hex by hand-encoding all RV32I instructions
# ===========================================================================

def r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7<<25)|(rs2<<20)|(rs1<<15)|(funct3<<12)|(rd<<7)|opcode

def i(imm12, rs1, funct3, rd, opcode):
    imm12 = imm12 & 0xFFF
    return (imm12<<20)|(rs1<<15)|(funct3<<12)|(rd<<7)|opcode

def s(imm12, rs2, rs1, funct3, opcode):
    imm12 = imm12 & 0xFFF
    imm11_5 = (imm12 >> 5) & 0x7F
    imm4_0  = imm12 & 0x1F
    return (imm11_5<<25)|(rs2<<20)|(rs1<<15)|(funct3<<12)|(imm4_0<<7)|opcode

def b(offset, rs2, rs1, funct3, opcode):
    # offset is signed, in bytes
    o = offset & 0x1FFF  # 13 bits
    imm12   = (o >> 12) & 1
    imm11   = (o >> 11) & 1
    imm10_5 = (o >> 5)  & 0x3F
    imm4_1  = (o >> 1)  & 0xF
    return (imm12<<31)|(imm10_5<<25)|(rs2<<20)|(rs1<<15)|(funct3<<12)|(imm4_1<<8)|(imm11<<7)|opcode

def u(imm20, rd, opcode):
    imm20 = imm20 & 0xFFFFF
    return (imm20<<12)|(rd<<7)|opcode

def j(offset, rd, opcode):
    o = offset & 0x1FFFFF  # 21 bits
    imm20    = (o >> 20) & 1
    imm10_1  = (o >> 1)  & 0x3FF
    imm11    = (o >> 11) & 1
    imm19_12 = (o >> 12) & 0xFF
    return (imm20<<31)|(imm19_12<<23)|(imm11<<20)|(imm10_1<<21)|(rd<<7)|opcode

# Opcodes
LUI    = 0b0110111
AUIPC  = 0b0010111
JAL    = 0b1101111
JALR   = 0b1100111
BRANCH = 0b1100011
LOAD   = 0b0000011
STORE  = 0b0100011
ALUI   = 0b0010011
ALUR   = 0b0110011
SYSTEM = 0b1110011

# Registers
x0,x1,x2,x3,x4,x5,x6,x7 = 0,1,2,3,4,5,6,7
x8,x9,x10,x11,x12,x13,x14,x15 = 8,9,10,11,12,13,14,15
x16,x17,x18,x19,x20,x21,x22,x23 = 16,17,18,19,20,21,22,23
x24,x25,x26,x27,x28,x29,x30,x31 = 24,25,26,27,28,29,30,31

# -------------------------------------------------------------------------
# Program layout (word addresses 0..N-1)
# Each instruction is 4 bytes; PC = word_index * 4
# -------------------------------------------------------------------------
# PC=0x00: LUI   x28, 0xDEAD     -> x28 = 0xDEAD0000
# PC=0x04: ADDI  x28, x28, 0x123 -> Note: 0x123 sign-extends fine (positive)
#           BUT 0xDEAD0000 + 0x123 = 0xDEAD0123 (not really needed for test,but matches comment)
# PC=0x08: AUIPC x29, 0          -> x29 = PC+0 = 0x08
# PC=0x0C: ADDI  x2,  x0, 0x100  -> x2 = 0x100 (stack pointer) 
#           BUT 0x100 = 256 which fits in 12 bits signed: OK
# PC=0x10: ADDI  x10, x0, 15     -> x10 = 15
# PC=0x14: ADDI  x11, x0, 7      -> x11 = 7
# PC=0x18: ADD   x12, x10, x11   -> x12 = 22  (0x16)
# PC=0x1C: SUB   x13, x10, x11   -> x13 = 8
# PC=0x20: SW    x12, 0(x2)      -> mem[0x100] = 22
# PC=0x24: LW    x14, 0(x2)      -> x14 = 22
# PC=0x28: SH    x11, 4(x2)      -> mem[0x104] = 7
# PC=0x2C: LH    x15, 4(x2)      -> x15 = 7
# PC=0x30: SB    x10, 8(x2)      -> mem[0x108] = 15
# PC=0x34: LBU   x16, 8(x2)      -> x16 = 15
# ---- Branch tests ----
# PC=0x38: BEQ   x14, x12, +8   -> taken (22==22): skip 2 instr -> target=0x40
# PC=0x3C: ADDI  x17, x0, 0xFF  -> NOT executed
# PC=0x40: ADDI  x17, x0, 1     -> x17 = 1 (branch skipped 0xFF write)
# PC=0x44: BNE   x10, x11, +8   -> taken (15≠7): skip -> target=0x4C
# PC=0x48: ADDI  x18, x0, 0xAA  -> NOT executed
# PC=0x4C: ADDI  x18, x0, 2     -> x18 = 2
# PC=0x50: BLT   x11, x10, +8   -> taken (7<15): skip -> target=0x58
# PC=0x54: ADDI  x19, x0, 0xBB  -> NOT executed
# PC=0x58: ADDI  x19, x0, 3     -> x19 = 3
# ---- JAL test ----
# PC=0x5C: JAL   x1, +12        -> x1 = 0x60, jump to 0x68
# PC=0x60: ADDI  x20, x0, 0xCC  -> NOT executed (skipped)
# PC=0x64: ADDI  x20, x0, 0xDD  -> NOT executed (skipped)
# PC=0x68: ADDI  x20, x0, 4     -> x20 = 4
# ---- JALR back via x1 ----
# PC=0x6C: JALR  x21, x1, 0     -> x21=0x70, jump to x1=0x60... 
#           This would loop; instead jump to fixed address past return
#           Better: JALR to after the JAL (0x60) but we already set x1=0x60
#           So JALR x0, x1, 16  -> jumps to 0x60+16=0x70 (no reg write, x0)
# PC=0x70: ADDI  x22, x0, 5     -> x22=5 (proves JALR worked)
# ---- End: ECALL ----
# PC=0x74: ECALL (terminates simulation)
# -------------------------------------------------------------------------

instructions = []

# Helper for signed 12-bit immediate clamping check
def check_imm12(v, name="imm"):
    if v < -2048 or v > 2047:
        raise ValueError(f"{name}={v} out of 12-bit signed range")
    return v & 0xFFF

# Word 0: LUI x28, 0xDEAD
instructions.append(u(0xDEAD, x28, LUI))

# Word 1: ADDI x28, x28, 0x123 = 291
instructions.append(i(0x123, x28, 0b000, x28, ALUI))

# Word 2: AUIPC x29, 0
instructions.append(u(0, x29, AUIPC))

# Word 3: ADDI x2, x0, 0x100 = 256
instructions.append(i(0x100, x0, 0b000, x2, ALUI))

# Word 4: ADDI x10, x0, 15
instructions.append(i(15, x0, 0b000, x10, ALUI))

# Word 5: ADDI x11, x0, 7
instructions.append(i(7, x0, 0b000, x11, ALUI))

# Word 6: ADD x12, x10, x11
instructions.append(r(0b0000000, x11, x10, 0b000, x12, ALUR))

# Word 7: SUB x13, x10, x11
instructions.append(r(0b0100000, x11, x10, 0b000, x13, ALUR))

# Word 8: SW x12, 0(x2)   -> S-type, imm=0
instructions.append(s(0, x12, x2, 0b010, STORE))

# Word 9: LW x14, 0(x2)
instructions.append(i(0, x2, 0b010, x14, LOAD))

# Word 10: SH x11, 4(x2)
instructions.append(s(4, x11, x2, 0b001, STORE))

# Word 11: LH x15, 4(x2)
instructions.append(i(4, x2, 0b001, x15, LOAD))

# Word 12: SB x10, 8(x2)
instructions.append(s(8, x10, x2, 0b000, STORE))

# Word 13: LBU x16, 8(x2)
instructions.append(i(8, x2, 0b100, x16, LOAD))

# Word 14 (PC=0x38): BEQ x14, x12, +8 -> target=0x38+8=0x40
instructions.append(b(8, x12, x14, 0b000, BRANCH))

# Word 15 (PC=0x3C): ADDI x17, x0, 0xFF
instructions.append(i(0xFF, x0, 0b000, x17, ALUI))

# Word 16 (PC=0x40): ADDI x17, x0, 1
instructions.append(i(1, x0, 0b000, x17, ALUI))

# Word 17 (PC=0x44): BNE x10, x11, +8 -> target=0x44+8=0x4C
instructions.append(b(8, x11, x10, 0b001, BRANCH))

# Word 18 (PC=0x48): ADDI x18, x0, 0xAA
instructions.append(i(0xAA, x0, 0b000, x18, ALUI))

# Word 19 (PC=0x4C): ADDI x18, x0, 2
instructions.append(i(2, x0, 0b000, x18, ALUI))

# Word 20 (PC=0x50): BLT x11, x10, +8 -> target=0x50+8=0x58
instructions.append(b(8, x10, x11, 0b100, BRANCH))

# Word 21 (PC=0x54): ADDI x19, x0, 0xBB
instructions.append(i(0xBB, x0, 0b000, x19, ALUI))

# Word 22 (PC=0x58): ADDI x19, x0, 3
instructions.append(i(3, x0, 0b000, x19, ALUI))

# Word 23 (PC=0x5C): JAL x1, +12 -> x1=0x60, target=0x5C+12=0x68
instructions.append(j(12, x1, JAL))

# Word 24 (PC=0x60): ADDI x20, x0, 0xCC  (NOT executed, jumped over)
instructions.append(i(0xCC, x0, 0b000, x20, ALUI))

# Word 25 (PC=0x64): ADDI x20, x0, 0xDD  (NOT executed, jumped over)
instructions.append(i(0xDD, x0, 0b000, x20, ALUI))

# Word 26 (PC=0x68): ADDI x20, x0, 4   (JAL landing point)
instructions.append(i(4, x0, 0b000, x20, ALUI))

# Word 27 (PC=0x6C): JALR x0, x1, 16 -> jump to x1(=0x60)+16=0x70, rd=x0(discard)
instructions.append(i(16, x1, 0b000, x0, JALR))

# Word 28 (PC=0x70): ADDI x22, x0, 5   (JALR landing - proves JALR worked)
instructions.append(i(5, x0, 0b000, x22, ALUI))

# Word 29 (PC=0x74): ECALL
instructions.append(i(0, x0, 0b000, x0, SYSTEM))

# Print hex
print(f"Total instructions: {len(instructions)}")
for idx, instr in enumerate(instructions):
    print(f"  [{idx:2d}] PC=0x{idx*4:04x}: 0x{instr:08x}")

# Write program.hex
with open("program_new.hex", "w") as f:
    for instr in instructions:
        f.write(f"{instr:08x}\n")

print("\nWritten to program_new.hex")
