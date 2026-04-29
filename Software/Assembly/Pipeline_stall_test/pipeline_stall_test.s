    .section .text
    .globl _start
_start:
    # Base addrs for data/signature
    lui x10, %hi(data0)
    addi x10, x10, %lo(data0)

    lui x11, %hi(res0)     # res0 addr
    addi x11, x11, %lo(res0)

    lui x12, %hi(res1)     # res1 addr
    addi x12, x12, %lo(res1)

    lui x13, %hi(res2)     # res2 addr
    addi x13, x13, %lo(res2)

    lui x14, %hi(pass)     # pass flag
    addi x14, x14, %lo(pass)
    sw  x0, 0(x14)         # pass = 0 (clear)

    # ---------------------------
    # A) LW -> dependent ADDI
    # ---------------------------
    lw   x5, 0(x10)        # x5 = data0 (=41)
    addi x6, x5, 1         # must see the loaded value; expect 42
    sw   x6, 0(x11)        # res0 = 42
    addi x7, x0, 42
    bne  x6, x7, fail1     # if not 42, load-use stall/forward is broken

    # ---------------------------
    # B) MUL (multi-cycle) -> ADDI
    # ---------------------------
    mul  x7, x6, x6        # 42 * 42 = 1764
    addi x8, x7, 1         # expect 1765
    sw   x8, 0(x12)        # res1 = 1765
    addi x9, x0, 1765
    bne  x8, x9, fail2     # if not 1765, EX multi-cycle stall/forward is broken

    # ---------------------------
    # C) ALU result -> branch compare
    # ---------------------------
    sub  x9, x6, x6        # x9 = 0 (must be visible to branch)
    beq  x9, x0, ok_branch # should branch immediately using fresh x9
    jal  x0, fail3

ok_branch:
    sw   x9, 0(x13)        # res2 = 0
    addi x15, x0, 1
    sw   x15, 0(x14)       # pass = 1
done:
    jal  x0, done

# ---------- Fail paths (which hazard failed?) ----------
fail1:
    lui  x15, %hi(fail)
    addi x15, x15, %lo(fail)
    addi x16, x0, 0x11     # load-use failed
    sw   x16, 0(x15)
    jal  x0, done

fail2:
    lui  x15, %hi(fail)
    addi x15, x15, %lo(fail)
    addi x16, x0, 0x22     # mul-use failed
    sw   x16, 0(x15)
    jal  x0, done

fail3:
    lui  x15, %hi(fail)
    addi x15, x15, %lo(fail)
    addi x16, x0, 0x33     # branch-forward failed
    sw   x16, 0(x15)
    jal  x0, done

    .section .data
data0: .word 41     # source for the load-use test
res0:  .word 0      # expect 42
res1:  .word 0      # expect 1765
res2:  .word 0      # expect 0
pass:  .word 0      # expect 1 on success
fail:  .word 0      # 0x11 / 0x22 / 0x33 on failure
