MEMORY
{
	/* iram - Text */
	iram  : ORIGIN = 0x00000000, LENGTH = 4K

	/* dram - Data */
	dram  : ORIGIN = 0x40000000, LENGTH = 4K

}

SECTIONS
{
	.text 0x00000000 : { *(.text) } AT> iram
	
    . = 0x00000000;
    _DRAM_BASE = .;

	/* Setup the early stack (if any) right here. Usually a part of crt.c to bootstrap things.*/
	.early_stack . : { *(.early_stack) } AT> dram

	.data . : { _DATA_BEGIN = .; *(.data) } AT>dram /* put in "dram" */

	/* rodata and bss are used for C constants and zero-initialized "stack" variables */
	.rodata . : { *(.rodata) } AT>dram /* put in "dram" */
	.bss . : { _BSS_BEGIN = .; *(.bss); _BSS_END = .; } AT>dram

	/* The user-code stack top starts at the next available 4-byte aligned address */
	_STACK_TOP = _DRAM_BASE + LENGTH(dram); /* Any space in our data ram is used for stack */
	
	/DISCARD/ : { *(.reginfo) *(.MIPS.abiflags) *(.gnu.attributes) }	/DISCARD/ : { *(.reginfo) *(.MIPS.abiflags) *(.gnu.attributes) }
}

