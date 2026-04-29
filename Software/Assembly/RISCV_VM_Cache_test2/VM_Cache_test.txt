# vm_Cache_test — RISCV-only MVP for Sv32 + caches (no tlbwi)
# Assumptions:
#   - satp[31:30]=01 means Sv32 in your design
#   - PPN = PA>>12
#   - PTE bits in your core: [9:2] = {U,G,A,D,X,W,R,V} (V=bit0, R=1, W=2, X=3, D=4, A=5)
#   - Use fixed physical addresses for page tables: L1 @ 0x00004000, L0 @ 0x00005000

        .option norvc
        .text
        .globl _start
_start:
        # t0 = 0x00004000 (L1 root), t1 = 0x00005000 (L0 table)
        lui     t0, 0x4
        addi    t0, t0, 0          # t0 = 0x00004000
        lui     t1, 0x5
        addi    t1, t1, 0          # t1 = 0x00005000

        # L1[0] -> L0 (non-leaf): PPN(L0)<<10 | V
        #   PPN(L0)=0x5, so entry = (0x5<<10) | 1 = 0x1401
        lui     t2, 0x1            # t2 = 0x00001000
        addi    t2, t2, 0x401      # t2 = 0x00001401
        sw      t2, 0(t0)

        # L0[0] : map VA 0x0000_0000 -> PA 0x0000_0000 with X|R|V and A|D set
        #   PPN=0x00000 => (0<<10) | (A=1<<5)|(D=1<<4)|(X=1<<3)|(R=1<<1)|V=1 = 0x003B
        addi    t3, x0, 0x3B
        sw      t3, 0(t1)          # L0[0]

        # L0[1] : map VA 0x0000_1000 -> PA 0x0000_1000 with W|R|V and A|D set (no X)
        #   PPN=0x00001 => (1<<10)=0x400; perms A|D|W|R|V = 0x0037; entry = 0x0437
        lui     t3, 0x0
        addi    t3, x0, 0x437
        sw      t3, 4(t1)          # L0[1]

        # satp = MODE(01)<<30 | PPN(L1)
        #   PPN(L1)=0x4, satp = 0x4000_0004
        lui     t4, 0x40000        # t4 = 0x4000_0000
        addi    t4, t4, 4
        csrrw   x0, satp, t4       # enable Sv32 with our root

        sfence.vma                 # flush i/d TLBs
        fence.i                    # (optional) ensure I$ coherence after changing paging

        # D-side test: store+load @ VA 0x1000
        lui     t5, 0x1            # t5 = 0x00001000
        addi    t6, x0, -0x542     # t6 = 0xFFFFFABE (two-step if your assembler dislikes)
				# Replace the two ADDIs that tried to “build up” the constant.
		lui   t6, 0xCAFEC        # upper 20 bits
		addi  t6, t6, -0x542     # lower 12 bits (signed); yields 0xCAFEBABE
        sw      t6, 0(t5)
        lw      t2, 0(t5)
        bne     t6, t2, fail
		nop
		
success:
        jal     x0, success        # spin if OK
		nop
fail:
		nop
		nop
		nop
		nop
        jal     x0, fail           # spin if mismatch
		nop
        # (Optional) To test A/D handling, rewrite L0[1] with D=0 then try SW to fault:
        #   addi  t3, x0, 0x0337   # A=1, D=0, W|R|V
        #   sw    t3, 4(t1)
        #   sfence.vma
        #   sw    t6, 0(t5)        # should raise store page fault in your MVP
