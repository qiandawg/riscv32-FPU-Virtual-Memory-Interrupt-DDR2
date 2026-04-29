    .section .data
    .align 2
    .global val1
val1:
    .float 3.5
    .global val2
val2:
    .float 1.5

    .section .text
    .globl _start
_start:
    # Load values into floating-point registers
    la     a0, val1
    flw    f1, 0(a0)       # f1 = 3.5
    la     a1, val2
    flw    f2, 0(a1)       # f2 = 1.5

    # 1) f3 = f1 + f2
    #    (result used immediately by the next instruction)
    fadd.s f3, f1, f2, rtz

    # 2) f4 = f3 - f2
    #    (depends on f3 from previous)
    fsub.s f4, f3, f2

    # 3) f5 = f4 * f2
    #    (depends on f4)
    fmul.s f5, f4, f2

    # 4) f6 = f5 / f3
    #    (depends on both f5 and earlier f3)
    fdiv.s f6, f5, f3

    # 5) f7 = sqrt(f6)
    #    (depends on f6)
    fsqrt.s f7, f6

    # End of program (infinite loop)
end:
    j end