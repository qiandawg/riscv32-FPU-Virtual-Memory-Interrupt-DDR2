/* RISCV_DDR2_Smoke.S
 *
 * Minimal smoke test for the hybrid BRAM+DDR2 memory system.
 *
 * Round-trips a known pattern through the DDR2 window, reports the result
 * on the 16 on-board LEDs, and then spins. Relies on the DDR2 page-table
 * entry added by the companion startup_ddr2.S: VA 0x4000 -> PA 0x8000_0000.
 *
 * LED encoding:
 *   LED[0]      -> pass/fail  (1 = pass, 0 = fail)
 *   LED[15:8]   -> low byte of the readback value (pattern sanity check)
 *   LED[15]     -> init_calib_complete from MIG (driven from mfp_nexys4_ddr.v
 *                  when DDR2_DEBUG_LED is defined; firmware does not override
 *                  LED[15] during the pass state to keep the debug LED visible).
 */

    .option norvc
    .text
    .globl __user_start

/* Memory-mapped LED register (same virtual address already used by
   RISCV_TLB_LEDCount -> physical 0x1f80_0000). */
.equ LED_VA,      0xbf800000

/* Virtual base of the DDR2 window. startup_ddr2.S maps this 4 KiB page
   to physical 0x8000_0000 (a[31]==1). */
.equ DDR2_VA,     0x00004000

/* 32-bit test pattern */
.equ PATTERN,     0xCAFEBABE

__user_start:
    nop
    nop

    /* t0 = DDR2 virtual address (word 0 of DDR2) */
    li      t0, DDR2_VA

    /* t1 = pattern */
    li      t1, PATTERN

    /* Store the pattern to DDR2[0] */
    sw      t1, 0(t0)

    /* No base FENCE decode in this CPU's ID/CU; use a plain NOP.
       The DDR wrapper already serializes accesses with ready/stall. */
    nop

    /* Read it back */
    lw      t2, 0(t0)

    /* Compare: if t2 == t1 -> pass */
    li      t3, LED_VA
    beq     t1, t2, pass

fail:
    /* On failure, show the low byte of the readback on LED[15:8] and
       leave LED[0] = 0. This makes miscompares easy to diagnose on-bench. */
    andi    t4, t2, 0xff
    slli    t4, t4, 8
    sw      t4, 0(t3)
    j       spin

pass:
    /* Show pass on LED[0] and the low byte of the readback on LED[8..15]. */
    andi    t4, t2, 0xff
    slli    t4, t4, 8
    ori     t4, t4, 0x0001
    sw      t4, 0(t3)

spin:
    /* Hold the result forever so the user can read the LEDs. */
    j       spin
    nop
