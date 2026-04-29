/* startup_ddr2_test2.S
 *
 * Same baseline as startup_ddr2.S, but maps a 64 KiB DDR2 VA window:
 *   VA 0x00004000 .. 0x00013FFF  ->  PA 0x80000000 .. 0x8000FFFF
 * by populating L0[4]..L0[19] (16 pages).
 */

    .globl _start
    .globl start
start = _start

.option norvc

/* CSRs */
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

/* Exception base @ 0x00000008 */
exc_base:
    j      fatal_handler
    nop

.global _start
_start:
    /* mtvec = exc_base (0x00000008) */
    li     t0, 0x08
    csrrw  x0, mtvec, t0

    /* Keep interrupts disabled for deterministic memory demo behavior. */
    csrw   mie, x0
    csrw   mstatus, x0

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

    /* L0[0]: VA 0x0000 -> PA 0x0000_0000 (boot), X|R|V */
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

    /* Map 16 DDR2 pages:
     * L0[4+i] = PA(0x80000000 + i*0x1000), W|R|V
     * First PTE = 0x20000007, then +0x400 per page.
     */
    addi   t6, t1, 16       /* &L0[4] */
    lui    s7, 0x80000
    srli   s7, s7, 2        /* PTE base bits for PA 0x80000000 */
    addi   s7, s7, PERM_WRV /* first PTE value */
    li     t2, 16           /* number of pages */

map_ddr_loop:
    sw     s7, 0(t6)
    addi   t6, t6, 4
    addi   s7, s7, 0x400
    addi   t2, t2, -1
    bne    t2, x0, map_ddr_loop
    nop

    /* Enable Sv32 (satp[31]=1, PPN(L1)=0x4) => 0x8000_0004 */
    lui    t4, 0x80000
    addi   t4, t4, 4
    csrrw  x0, satp, t4
    nop
    nop
    nop
    nop
    fence.i

    /* Jump to user program */
    li     sp, 0x2000
    j      __user_start
    nop

/* Trap path: soft-reset MMU state and restart. */
fatal_handler:
    csrw       satp, x0
    sfence.vma x0, x0
    j          _start
