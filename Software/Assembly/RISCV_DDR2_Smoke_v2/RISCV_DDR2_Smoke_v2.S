/* RISCV_DDR2_Smoke_v2.S
 *
 * V2 smoke test for the realistic memory map. Unlike the v1 smoke, this
 * program executes from DDR2 (its .text is linked at VMA 0x80000000) and
 * exercises a load/store to a different DDR2 page. If you can read the
 * pass signature on the LEDs, then:
 *
 *   1) DDR2 calibration completed (LED[15] from MIG).
 *   2) startup_ddr2_v2.S successfully copied .text from BRAM into DDR2
 *      (otherwise the CPU would have fetched garbage at 0x80000000).
 *   3) Sv32 page-table walks resolve VA 0x80000000+ -> PA 0x80000000+.
 *   4) DDR2 read/write round-trips through physical_memory_hybrid +
 *      mem_example + MIG.
 *   5) MMIO bypass to the LED register still works under satp[31]=1.
 *
 * LED encoding (matches v1):
 *   LED[0]      = 1 on pass, 0 on fail
 *   LED[15:8]   = low byte of the readback word (0xBE for the canonical
 *                 pattern 0xCAFEBABE)
 *   LED[15]     = init_calib_complete (driven by hardware)
 */

    .option norvc
    .text
    .globl __user_start

/* MMIO LED register. v_addr[31:20] == 0xBF8 hits the MMIO bypass in
 * rv_memsubsys.v regardless of satp, so this works pre- and post-paging. */
.equ LED_VA,    0xBF800000

/* DDR2 test slot. Use a page well past the .text/.rodata/.data region
 * but still inside the 16-page DDR window mapped by startup_ddr2_v2.S
 * (16 pages = 64 KiB ending at 0x80010000). Slot at 0x8000F000 is
 * inside the window and unlikely to alias the test's own data. */
.equ DDR2_VA,   0x8000F000

.equ PATTERN,   0xCAFEBABE

__user_start:
    nop
    nop

    /* t0 = DDR2 test address */
    li      t0, DDR2_VA

    /* t1 = pattern */
    li      t1, PATTERN

    /* Store pattern to DDR2 */
    sw      t1, 0(t0)

    /* No base FENCE in this CPU; the DDR2 wrapper serializes via ready. */
    nop

    /* Read it back */
    lw      t2, 0(t0)

    /* Compare */
    li      t3, LED_VA
    beq     t1, t2, pass

fail:
    /* Show low byte of readback on LED[15:8]; LED[0] stays 0. */
    andi    t4, t2, 0xff
    slli    t4, t4, 8
    sw      t4, 0(t3)
    j       spin

pass:
    /* LED[0]=1 + low byte of readback on LED[15:8]. */
    andi    t4, t2, 0xff
    slli    t4, t4, 8
    ori     t4, t4, 0x0001
    sw      t4, 0(t3)

spin:
    j       spin
    nop
