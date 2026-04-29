void crt(void);
void main(void);

//BSS variables filled in by the linker script
extern unsigned int _BSS_BEGIN;
extern unsigned int _BSS_END;

extern unsigned int _STACK_TOP;

// Early setup of stack pointer
__asm(
    ".section .init\n"
    ".globl _start\n"
    "_start:\n"
    "lui sp, 0x1\n"
    "addi sp, sp, 0x40\n"
    "call crt\n"
);

void crt()
{
    unsigned int* bss_begin = &_BSS_BEGIN;
    unsigned int* bss_end = &_BSS_END;
    unsigned int* stack_top = &_STACK_TOP;

    // Clear BSS
    while (bss_begin != bss_end) {
        *bss_begin++ = 0;
    }

    // Switch to real stack
    __asm volatile (
        "mv sp, %0"
        :
        : "r" (stack_top)
    );

    main();

    // Infinite loop to prevent return
    __asm volatile (
        "j .\n"
        "nop"
    );
}
