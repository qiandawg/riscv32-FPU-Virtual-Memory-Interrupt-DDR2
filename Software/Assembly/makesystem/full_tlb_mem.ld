MEMORY {
  ram0 (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00001000
  ram1 (rx)  : ORIGIN = 0x10000000, LENGTH = 0x00001000
  
  /*OLD  Matches system_ram2 (Bit 13=0). Holds Data/Stack. */
  /*OLD ram2 (rw)  : ORIGIN = 0x20000000, LENGTH = 0x00002000*/
    /* CHANGE: Set ORIGIN to Virtual Address 0x1000 (Data) */
  ram2 (rw)  : ORIGIN = 0x00001000, LENGTH = 0x00002000
  
  /* Matches system_ram3 (Bit 13=1). Holds Text. */
  /*OLD ram3 (rx)  : ORIGIN = 0x20002000, LENGTH = 0x00002000*/
  /* CHANGE: Set ORIGIN to Virtual Address 0x2000 (Text) */
  ram3 (rx)  : ORIGIN = 0x00002000, LENGTH = 0x00002000
}

SECTIONS
{
  .init_text 0x00000000 : { *(.init_text) } AT> ram0
  .pt_data   0x00000000 : { *(.pt_data) }   AT> ram1

  /* DATA (VA 0x0 -> PA 0x20000000) */
  . = 0x00000000;
  .data : { *(.data .data.* .sdata .sdata.*) } AT> ram2
  .bss (NOLOAD) : { *(.bss .bss.*) } > ram2

  /* STACK (VA 0x1000 -> PA 0x20001000) */
  . = 0x00001000;
  .early_stack : { *(.early_stack) } AT> ram2
  _stack_top = 0x00002000; /* Helper symbol for SP */

  /* TEXT (VA 0x2000 -> PA 0x20002000) */
  . = 0x00002000;
  __user_start = .;
  .text : { *(.text .text.*) } AT> ram3

  /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}