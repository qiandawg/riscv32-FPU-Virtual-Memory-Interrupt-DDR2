MEMORY
{
	/* ram - Text and Data */
	ram  : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    . = 0x00000000;
	.text : { *(.text) } AT> ram
	
    _DRAM_BASE = .;

	/* Setup the early stack (if any) right here. Usually a part of crt.c to bootstrap things.*/
	.early_stack . : { *(.early_stack) } AT> ram

	.data . : { _DATA_BEGIN = .; *(.data) } AT>ram /* put in "ram" */

	/* rodata and bss are used for C constants and zero-initialized "stack" variables */
	.rodata . : { *(.rodata) } AT>ram /* put in "ram" */
	.bss . : { _BSS_BEGIN = .; *(.bss); _BSS_END = .; } AT>ram

	/* The user-code stack top starts at the next available 4-byte aligned address */
	_STACK_TOP = _DRAM_BASE + LENGTH(ram) - 4; /* Any space in our data ram is used for stack */
	
	/DISCARD/ : { *(.reginfo) *(.MIPS.abiflags) *(.gnu.attributes) }
}
