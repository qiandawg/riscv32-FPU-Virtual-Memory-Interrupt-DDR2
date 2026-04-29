/* DDR2_Test_2.S
 *
 * Option 1 classroom demo:
 *   - Build a 256-entry table in DDR2
 *   - Each entry is 64 words (256 bytes)
 *   - Total table size = 64 KiB (> 32 KiB BRAM in current design)
 *
 * Controls:
 *   SW[7:0]  : entry index (0..255)
 *   SW[8]    : stream enable (1 = stream selected entry to 7-seg/LEDs)
 *
 * Display:
 *   LED[15:0] and 7-seg mirror the current streamed word.
 */

    .option norvc
    .text
    .globl __user_start

.equ IO_BASE,        0xbf800000
.equ IO_SWITCH,      0xbf800004
.equ IO_7SEG_EN,     0x0000000c
.equ IO_7SEG_DATA,   0x00000010

.equ DDR2_BASE_VA,   0x00004000
.equ ENTRY_COUNT,    256
.equ WORDS_PER_ENTRY,64
.equ ENTRY_SHIFT,    8          /* 256 bytes per entry */

__user_start:
    nop
    nop

    li      s0, IO_BASE         /* MMIO base */
    li      s1, IO_SWITCH       /* switch MMIO */
    li      s2, DDR2_BASE_VA    /* DDR2 test table base VA */

    /* Enable all 7-seg digits. */
    li      t0, 0xff
    sw      t0, IO_7SEG_EN(s0)

    /* -----------------------------------------------------------
     * Phase 1: build table in DDR2
     * value = (entry_index << 16) | word_index
     * ----------------------------------------------------------- */
    li      t1, 0               /* entry_index */
    add     t2, s2, x0          /* current entry base pointer */

fill_entry_loop:
    slli    t3, t1, 16          /* entry tag in upper half */
    li      t4, WORDS_PER_ENTRY /* word counter */
    add     t5, t2, x0          /* word pointer */
    li      t6, 0               /* word_index */

fill_word_loop:
    or      a0, t3, t6          /* pattern word */
    sw      a0, 0(t5)
    addi    t5, t5, 4
    addi    t6, t6, 1
    addi    t4, t4, -1
    bne     t4, x0, fill_word_loop
    nop

    addi    t1, t1, 1
    addi    t2, t2, 256         /* next entry */
    li      a1, ENTRY_COUNT
    bne     t1, a1, fill_entry_loop
    nop

wait_stream_enable:
    lw      t0, 0(s1)           /* switches */
    andi    t1, t0, 0x100       /* SW[8] */
    beq     t1, x0, wait_stream_enable
    nop

stream_selected_entry:
    lw      t0, 0(s1)           /* sample switches each pass */
    andi    t1, t0, 0x0ff       /* entry index = SW[7:0] */
    slli    t1, t1, ENTRY_SHIFT /* entry_index * 256 bytes */
    add     t2, s2, t1          /* selected entry base addr */

    li      t3, WORDS_PER_ENTRY

stream_word_loop:
    lw      t4, 0(t2)
    sw      t4, 0(s0)           /* LEDs */
    sw      t4, IO_7SEG_DATA(s0)/* 7-seg (hex mode in this design) */

    /* Visible pacing delay for classroom demo. */
    li      t5, 0x20000
delay_loop:
    addi    t5, t5, -1
    bne     t5, x0, delay_loop
    nop

    addi    t2, t2, 4
    addi    t3, t3, -1
    bne     t3, x0, stream_word_loop
    nop

    /* Re-sample selection and stream again while SW[8] remains high. */
    lw      t0, 0(s1)
    andi    t1, t0, 0x100
    bne     t1, x0, stream_selected_entry
    nop

    j       wait_stream_enable
    nop
