    .section .data
val1:   .float 3.5
val2:   .float 1.5

    .section .text
    .globl _start
_start:
    #––– Init seven-segment I/O –––
    li   a0, 0xbf800000        # base address for LEDs & 7-seg
    addi x8, x0, 0
    sw   x8, 0xc(a0)           # enable all 8 digits

    #––– Load inputs –––
    la   t0, val1
    flw  f1, 0(t0)             # f1 = 3.5
    la   t0, val2
    flw  f2, 0(t0)             # f2 = 1.5

    #––– Five FPU ops –––
    fadd.s  f3, f1, f2         # 1) f3 = 3.5 + 1.5
    fsub.s  f4, f3, f1         # 2) f4 = 3.5 - 1.5
    fmul.s  f5, f1, f4         # 3) f5 = 3.5 * 1.5
    fdiv.s  f6, f1, f5         # 4) f6 = 3.5 / 1.5
    fsqrt.s f7, f6             # 5) f7 = √3.5

    #––– Directly store IEEE-754 bits of f7 to 7-seg –––
    fsw  f7, 0x10(a0)

loop:
    j loop
