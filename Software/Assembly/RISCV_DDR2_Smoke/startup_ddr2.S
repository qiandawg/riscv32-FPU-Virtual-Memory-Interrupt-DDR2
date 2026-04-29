/* startup_ddr2.S
 *
 * Companion to startup.S, extended with a single extra page-table entry:
 *
 *   L0[4]: VA 0x4000 -> PA 0x8000_0000  (W|R|V)
 *
 * This opens a 4 KiB window into the DDR2 physical range (a[31]==1) so the
 * smoke test in RISCV_DDR2_Smoke.S can do a plain sw/lw against a virtual
 * address without having to bypass the TLB. All other mappings are byte
 * identical to makesystem/startup.S, so existing code keeps working.
 */

    .globl _start
    .globl start
start = _start

.option norvc

/* CSRs */
.equ mcause,  0x342
.equ mepc,    0x341
.equ mstatus, 0x300
.equ mtvec,   0x305
.equ mie,     0x304
.equ satp,    0x180

/* Page table locations (PHYSICAL) */
.equ L1_BASE, 0x00004000
.equ L0_BASE, 0x00005000

/* Leaf perms */
.equ PERM_XRV, 0x0B      /* X|R|V */
.equ PERM_WRV, 0x07      /* W|R|V */

.section .init_text, "ax"
/* Reset vector @ 0x00000000 */
    j      _start
    nop

/* Exception base @ 0x00000008 — soft-reset MMU then re-enter _start.
   Body lives at fatal_handler (placed after _start) because we cannot
   inline csrw/sfence/j here without overwriting _start at PA 0x10. */
exc_base:
    j      fatal_handler
    nop

.global _start
_start:
    /* mtvec = exc_base (0x00000008) */
    li     t0, 0x08
    csrrw  x0, mtvec, t0

    /* Enable external machine interrupts (MEIE bit 11) */
    li     t0, (1 << 11)
    csrrs  x0, mie, t0

    /* Enable global MIE */
    addi   t3, x0, 0x0F
    csrw   mstatus, t3

    /* ---- Build minimal Sv32 PTs in PHYS RAM ---- */
    lui    t0, %hi(L1_BASE)
    addi   t0, t0, %lo(L1_BASE)
    lui    t1, %hi(L0_BASE)
    addi   t1, t1, %lo(L0_BASE)

    /* L1[0] = (PPN(L0)<<10) | V */
    addi   t2, x0, 5
    slli   t2, t2, 10
    ori    t2, t2, 1
    sw     t2, 0(t0)

    /* L0[0]: VA 0x0000 -> PA 0x0000_0000 (bootloader), X|R|V */
    li     t3, 0
    addi   t3, t3, PERM_XRV
    sw     t3, 0(t1)

    /* L0[1]: VA 0x1000 -> PA 0x2000_0000 (stack/data), W|R|V */
    lui    s7, 0x20000
    srli   s7, s7, 2
    addi   t3, x0, PERM_WRV
    or     t3, t3, s7
    sw     t3, 4(t1)

    /* L0[2]: VA 0x2000 -> PA 0x2000_2000 (user text), X|R|V */
    lui    s7, 0x20002
    srli   s7, s7, 2
    addi   t3, x0, PERM_XRV
    or     t3, t3, s7
    sw     t3, 8(t1)

    /* L0[3]: VA 0x3000 -> PA 0x2000_3000, X|R|V */
    lui    s7, 0x20003
    srli   s7, s7, 2
    addi   t5, x0, PERM_XRV
    or     t5, t5, s7
    sw     t5, 12(t1)

    /* L0[4]: VA 0x4000 -> PA 0x8000_0000 (DDR2 window), W|R|V
       This is the only difference from makesystem/startup.S. The DDR2 smoke
       test reads and writes one word here to verify the first CPU<->DDR2
       round trip.

       PPN(PA 0x8000_0000) = PA >> 12 = 0x80000. Using `lui s7, 0x80000`
       gives s7 = 0x8000_0000, then `srli s7, s7, 2` aligns the PPN into
       bits [31:10] of the PTE (the PTE format places PPN in [31:10], so
       PPN << 10 == PA >> 2). */
    lui    s7, 0x80000
    srli   s7, s7, 2
    addi   t3, x0, PERM_WRV
    or     t3, t3, s7
    sw     t3, 16(t1)

    /* Enable Sv32 (satp[31]=1, PPN(L1)=0x4) => 0x8000_0004 */
    lui    t4, 0x80000
    addi   t4, t4, 4
    csrrw  x0, satp, t4
    nop
    nop
    nop
    nop
    fence.i

    /* Jump to the user program */
    li     sp, 0x2000
    j      __user_start
    nop

/* Fatal trap handler — entered via 'j fatal_handler' at exc_base (PA 0x08).
   Reachable under satp[31]=1 because L0[0] identity-maps VA 0x0000-0x0FFF
   (X|R|V) to the same PA range, so this code (still in .init_text below
   PA 0x1000) is fetchable on both first and second pass.

   Drops translation and flushes the TLB so the subsequent re-entry to
   _start runs its bare-mode page-table setup (sw to PA 0x4000/0x5000)
   instead of taking another store page fault on VA 0x5000 -> L0[5] (unmapped). */
fatal_handler:
    csrw       satp, x0
    sfence.vma x0, x0
    j          _start
