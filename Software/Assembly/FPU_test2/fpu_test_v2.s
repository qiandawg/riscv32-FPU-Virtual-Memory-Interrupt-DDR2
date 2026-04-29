
    # Load values into floating-point registers
    la     a0, val1
    flw    f1, 0(a0)       # f1 = 3.5
    la     a1, val2
    flw    f2, 0(a1)       # f2 = 1.5

    # Floating-point addition: f3 = f1 + f2
    fadd.s f1, f2, f3, rtz   # Round toward zero

    # Floating-point subtraction: f4 = f1 - f2
    fsub.s f4, f1, f2

    # Floating-point multiplication: f5 = f1 * f2
    fmul.s f5, f1, f2

    # Floating-point division: f6 = f1 / f2
    fdiv.s f6, f1, f2

    # Floating-point square root: f7 = sqrt(f1)
    fsqrt.s f7, f1

    # End of program (infinite loop)
end:
    j end