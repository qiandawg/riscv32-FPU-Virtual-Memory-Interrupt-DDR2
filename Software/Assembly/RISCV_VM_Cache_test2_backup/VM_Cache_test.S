        .option norvc
        .text
        .globl __user_start

# Minimal perms (kept for reference to match your comments)
.set PERM_XRV, 0x0B        # V|R|X
.set PERM_WRV, 0x07        # V|R|W

__user_start:
        # If you want the a0 check to pass (no exec blob), set it here:
        lui     a0, 0x12345
        addi    a0, a0, 0x678

        # expect a0 = 0x12345678
        lui     t0, 0x12345
        addi    t0, t0, 0x678
        nop
        bne     a0, t0, fail

        # ===== D-side test: store+load @ VA 0x1000 =====
        lui     t5, 0x1                 # t5 = 0x00001000
        lui     t6, 0xCAFEC
        addi    t6, t6, -0x542          # t6 = 0xCAFEBABE
        sw      t6, 0(t5)
        lw      t2, 0(t5)
        nop
        bne     t6, t2, fail

success:
        nop
		addi    t5, t5, 0x1
        jal     x0, success             # spin OK
        nop

fail:
        nop
        jal     x0, fail                # spin on mismatch
        nop
