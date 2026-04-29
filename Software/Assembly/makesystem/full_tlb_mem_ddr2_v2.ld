/* full_tlb_mem_ddr2_v2.ld
 *
 * V2 linker script for the Realistic V2 Memory Map.
 * See: C:\JHU_Classes\Spring2026_DDR2\MEMORY_MAP_V2_SPEC.md
 *
 * Differences from full_tlb_mem.ld:
 *   - .text and .rodata are linked at VMA 0x80000000 (DDR2),
 *     with LMA placed in BRAM bank 3 (PA 0x20002000) so the bytes
 *     load into mem3.mem at synthesis time. startup_ddr2_v2.S copies
 *     them to DDR2 before enabling Sv32.
 *   - .data/.bss live at VMA 0x80010000 (DDR2 main-memory data area).
 *     Their LMA also lives in BRAM bank 3 so initial values are
 *     present in the bitstream image; the boot copier brings the
 *     entire .text block (which includes any trailing .data/.rodata
 *     emitted into bram_text) over to DDR2.
 *   - Early stack stays in BRAM (used only before satp is on).
 *
 * Section -> mem*.bin mapping (matches the Makefile fullsim rule):
 *     .init_text      -> mem0.bin    (BRAM bank 0)
 *     .pt_data        -> mem1.bin    (BRAM bank 1)
 *     .data/.early_stack -> mem2.bin (BRAM bank 2; data is largely a
 *                                     placeholder under v2 since real
 *                                     .data lives in DDR2 at runtime)
 *     .text/.rodata   -> mem3.bin    (BRAM bank 3, LMA staging for the
 *                                     DDR2 copier)
 */

MEMORY {
  /* BRAM bank 0 — boot/init_text (PA 0x00000000-0x00000FFF) */
  bram_boot  (rx) : ORIGIN = 0x00000000, LENGTH = 0x00001000

  /* BRAM bank 1 — page tables (L1 @ 0x4000, L0 @ 0x5000).
     Bank-1 decode is `a[29:28]==01`, which puts it at PA 0x10000000+
     in the original physical_memory layout, but mem1.mem is mirrored
     so $readmemh fills the right addresses. We expose just the page
     table area to the linker so symbols line up. */
  bram_pt    (rw) : ORIGIN = 0x00004000, LENGTH = 0x00002000

  /* BRAM bank 2 — early data/scratch (PA 0x00001000-0x00003FFF) */
  bram_data  (rw) : ORIGIN = 0x00001000, LENGTH = 0x00003000

  /* BRAM bank 3 — LMA staging for .text/.rodata.
     Physical decode: a[29]==1 && a[13]==1 => PA 0x20002000+ in the
     legacy layout. The fullsim rule packs whatever is in this region
     into mem3.bin / mem3.mem. Boot copier reads from PA 0x20002000. */
  bram_text  (rx) : ORIGIN = 0x20002000, LENGTH = 0x00004000

  /* DDR2 main memory — VMA region for .text/.rodata/.data/.bss.
     Nothing is loaded here at synthesis; startup_ddr2_v2.S populates
     it at runtime from bram_text. */
  ddr_text   (rx) : ORIGIN = 0x80000000, LENGTH = 0x00010000
  ddr_data   (rw) : ORIGIN = 0x80010000, LENGTH = 0x00070000
}

ENTRY(_start)

SECTIONS
{
  /* ---- BRAM bank 0: reset vector + boot stub ---- */
  .init_text 0x00000000 :
  {
    *(.init_text)
  } > bram_boot

  /* ---- BRAM bank 1: page-table backing store ---- */
  .pt_data 0x00004000 :
  {
    *(.pt_data)
  } > bram_pt

  /* ---- BRAM bank 2: early data + early stack ---- */
  . = 0x00001000;
  .early_data : { *(.early_data .early_data.*) } > bram_data
  .early_stack : { *(.early_stack) } > bram_data
  _early_stack_top = 0x00002000;

  /* ---- DDR2: application .text and .rodata ----
     VMA in DDR2, LMA in bram_text so the bytes are in mem3.bin. */
  . = 0x80000000;
  __user_start = .;
  .text : AT(0x20002000)
  {
    *(.text .text.*)
    *(.rodata .rodata.*)
  } > ddr_text

  /* ---- DDR2: application .data / .bss ----
     .data is initialized; we rely on the runtime copier in
     startup_ddr2_v2.S having pulled in the trailing portion of
     bram_text up to TEXT_COPY_BYTES. Keep .data small for the demo
     programs (they mostly use registers and DDR2 buffers). */
  . = 0x80010000;
  .data : { *(.data .data.*) *(.sdata .sdata.*) } > ddr_data
  .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) } > ddr_data

  _ddr_stack_top = 0x80080000;

  /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}
