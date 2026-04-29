/* startup_ddr2_v2.S
 *
 * V2 startup for the realistic memory map (see MEMORY_MAP_V2_SPEC.md).
 *
 * Differences from startup_ddr2.S:
 *   - Application .text/.rodata execute from DDR2 (PA 0x80000000), not BRAM.
 *   - Boot stub copies the .text image from its load address (BRAM bank 3,
 *     PA 0x20002000 in the v1 fullsim layout) into DDR2 at PA 0x80000000
 *     before enabling Sv32. Without this copy, fetching at VA 0x80000000
 *     would return uninitialized DRAM.
 *   - L0 page table is rebuilt for the v2 layout:
 *       L0[0..3]  : BRAM identity pages (boot, traps, page-tables, scratch)
 *       L0[4]     : VA 0x4000 -> PA 0x80000000 legacy DDR window (kept for
 *                   backward compatibility with smoke v1 patterns)
 *       L0[256+]  : VA 0x80000000 -> PA 0x80000000 (DDR2 main memory),
 *                   16 pages (64 KiB) of contiguous text+data+stack.
 *   - Soft-reset trap handler (csrw satp,x0; sfence.vma; j _start) preserved.
 *
 * Page-table physical placement (BRAM):
 *     L1 root @ 0x00004000
 *     L0 leaf @ 0x00005000
 *     satp     = 0x80000004
 *
 * .text VMA / LMA (set by full_tlb_mem_ddr2_v2.ld):
 *     VMA = 0x80000000   (where the CPU fetches after satp is on)
 *     LMA = 0x20002000   (where the boot loader places the bytes in BRAM
 *                         bank 3; matches mem3.mem decode in
 *                         physical_memory_hybrid.v)
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

/* Page-table locations (PHYSICAL, in BRAM) */
.equ L1_BASE, 0x00004000
.equ L0_BASE, 0x00005000

/* Leaf permissions */
.equ PERM_XRV, 0x0B    /* X|R|V */
.equ PERM_WRV, 0x07    /* W|R|V */

/* DDR2 main memory base (physical) */
.equ DDR_PA_BASE, 0x80000000

/* .text LMA (BRAM bank 3, where mem3.mem is loaded by physical_memory_hybrid) */
.equ TEXT_LMA,    0x20002000

/* Number of 4 KiB DDR2 pages mapped at boot.
 * 16 pages = 64 KiB, big enough for the demos in DDR2_Test_2.
 */
.equ DDR_PAGES, 16

/* Number of bytes to copy from BRAM .text (LMA) -> DDR2 (VMA). Must cover
 * the entire .text + .rodata image. 16 KiB is comfortable for the demos.
 */
.equ TEXT_COPY_BYTES, 0x4000

.section .init_text, "ax"
/* ---- Reset vector @ PA 0x00000000 ---- */
    j      _start
    nop

/* ---- Exception base @ PA 0x00000008 ----
 * Identity-mapped under Sv32 via L0[0], so reachable in both bare and
 * paged mode. Body at fatal_handler (placed below _start) does the
 * MMU soft-reset.
 */
exc_base:
    j      fatal_handler
    nop

.global _start
_start:
    /* mtvec = exc_base */
    li     t0, 0x08
    csrrw  x0, mtvec, t0

    /* Disable interrupts during boot. Demo programs decide whether to
       re-enable later. Keeps DDR2 boot deterministic. */
    csrw   mstatus, x0
    csrw   mie,     x0

    /* ===========================================================
       Stage 1: Copy .text image  BRAM (LMA) -> DDR2 (VMA)
       Runs in BRAM with satp=0, so the CPU is fetching from
       .init_text in BRAM and the DDR2 stores go through
       physical_memory_hybrid's a[31]==1 path.
       =========================================================== */
    lui    t0, %hi(TEXT_LMA)        /* src pointer */
    addi   t0, t0, %lo(TEXT_LMA)
    lui    t1, %hi(DDR_PA_BASE)     /* dst pointer */
    addi   t1, t1, %lo(DDR_PA_BASE)
    li     t2, TEXT_COPY_BYTES      /* byte count */

copy_loop:
    beq    t2, x0, copy_done
    lw     t3, 0(t0)
    sw     t3, 0(t1)
    addi   t0, t0, 4
    addi   t1, t1, 4
    addi   t2, t2, -4
    j      copy_loop
copy_done:

    /* ===========================================================
       Stage 2: Build Sv32 page tables in BRAM
       =========================================================== */
    lui    t0, %hi(L1_BASE)
    addi   t0, t0, %lo(L1_BASE)
    lui    t1, %hi(L0_BASE)
    addi   t1, t1, %lo(L0_BASE)

    /* L1[0] = (PPN(L0)<<10) | V — covers VA 0x00000000-0x003FFFFF */
    addi   t2, x0, 5
    slli   t2, t2, 10
    ori    t2, t2, 1
    sw     t2, 0(t0)

    /* L1[512] = (PPN(L0)<<10) | V — covers VA 0x80000000-0x803FFFFF
     * Same L0 leaf reused: this gives us a single L0 table whose
     * high entries (>=256 word offset) map the DDR2 window.
     * Index 512 in 4-byte entries = byte offset 512*4 = 0x800.
     * Use a temporary because sw's offset is signed 12-bit (max 0x7FF). */
    addi   t2, x0, 5
    slli   t2, t2, 10
    ori    t2, t2, 1
    addi   s8, t0, 0x7FF              /* s8 = L1_BASE + 0x7FF */
    addi   s8, s8, 1                  /* s8 = L1_BASE + 0x800 */
    sw     t2, 0(s8)

    /* ---- L0 entries (BRAM identity pages) ---- */

    /* L0[0]: VA 0x0000 -> PA 0x0000_0000 (boot/init_text), X+R+V */
    li     t3, 0
    addi   t3, t3, PERM_XRV
    sw     t3, 0(t1)

    /* L0[1]: VA 0x1000 -> PA 0x0000_1000 (early data), W+R+V */
    addi   t3, x0, 1
    slli   t3, t3, 10                /* PPN(0x00001) << 10 */
    ori    t3, t3, PERM_WRV
    sw     t3, 4(t1)

    /* L0[2]: VA 0x2000 -> PA 0x0000_2000 (early stack), W+R+V */
    addi   t3, x0, 2
    slli   t3, t3, 10
    ori    t3, t3, PERM_WRV
    sw     t3, 8(t1)

    /* L0[3]: VA 0x3000 -> PA 0x0000_3000 (scratch), W+R+V */
    addi   t3, x0, 3
    slli   t3, t3, 10
    ori    t3, t3, PERM_WRV
    sw     t3, 12(t1)

    /* L0[4]: VA 0x4000 -> PA 0x8000_0000 legacy DDR2 window, W+R+V
     * Kept so v1-style smoke patterns (which reference VA 0x4000) still
     * resolve into DDR2 under v2.
     */
    lui    s7, 0x80000
    srli   s7, s7, 2
    addi   t3, x0, PERM_WRV
    or     t3, t3, s7
    sw     t3, 16(t1)

    /* ---- L0 entries 256..(256+DDR_PAGES-1):
       VA 0x8000_0000+i*0x1000 -> PA 0x8000_0000+i*0x1000, X+R+V (RWX)
       Index 256 in 4-byte entries = byte offset 256*4 = 0x400. */
    addi   t0, t1, 0x400              /* &L0[256] */
    li     t2, DDR_PA_BASE
    li     t4, DDR_PAGES
    li     t5, PERM_XRV
    /* For RWX so .data writes work too, OR in W bit (PERM_WRV bit 1).
       PERM_XRV=0xB, PERM_WRV=0x7. RWX = X|W|R|V = 0xF. */
    ori    t5, t5, 0x4                /* set W bit -> 0xF */
    /* s9 = page-stride 0x1000 (cannot use addi imm directly; > 12 bits) */
    lui    s9, 1                      /* s9 = 0x1000 */

ddr_pte_loop:
    beq    t4, x0, ddr_pte_done
    /* PTE = (PA >> 2) | perms.  PA is 4 KiB-aligned so the low 12 bits
       are zero; PA>>2 puts PPN in [31:10] which matches the Sv32 PTE
       layout. */
    srli   t6, t2, 2
    or     t6, t6, t5
    sw     t6, 0(t0)
    addi   t0, t0, 4
    add    t2, t2, s9                 /* t2 += 0x1000 (next page) */
    addi   t4, t4, -1
    j      ddr_pte_loop
ddr_pte_done:

    /* ===========================================================
       Stage 3: Enable Sv32, jump to user program in DDR2
       =========================================================== */

    /* satp = (1<<31) | PPN(L1) = 0x80000004 */
    lui    t4, 0x80000
    addi   t4, t4, 4
    csrrw  x0, satp, t4
    nop
    nop
    nop
    nop
    fence.i

    /* Stack pointer at top of the DDR2 region we mapped (16 pages = 64 KiB)
       so VA 0x8001_0000 is one past the last byte. We grow downward. */
    lui    sp, 0x80010

    /* Jump to user program at VA 0x80000000 (must use jalr because target
       is far from PC). __user_start is provided by the linker. */
    lui    t0, %hi(__user_start)
    addi   t0, t0, %lo(__user_start)
    jalr   x0, t0, 0
    nop

/* ---- Fatal trap handler ----
 * Reachable under both bare mode (PA 0x08) and paged mode (VA 0x08 -> PA
 * 0x08 via L0[0]). Drops translation, flushes TLB, restarts boot.
 * Re-running _start re-copies .text into DDR2 and rebuilds page tables,
 * which is safe because BRAM and DDR2 contents are reproducible.
 */
fatal_handler:
    csrw       satp, x0
    sfence.vma x0,   x0
    j          _start
