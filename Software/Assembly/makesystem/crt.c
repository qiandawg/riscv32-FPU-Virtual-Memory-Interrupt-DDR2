void crt(void);
void main(void);

//BSS variables filled in by the linker script
extern unsigned int _BSS_BEGIN;
extern unsigned int _BSS_END;

extern unsigned int _STACK_TOP;

__asm(
    "lui $sp, 0x0000 \n"
    "ori $sp, 0x1040" //EARLY INITIAL STACK TOP
    );

void crt()
{
    unsigned int* bss_begin = &_BSS_BEGIN;
    unsigned int* bss_end = &_BSS_END;
    unsigned int* stack_top = &_STACK_TOP;

    while(bss_begin != bss_end)
    {
        *bss_begin = 0;
        bss_begin++;
    }

    //Swtich over to our "real" stack pointer at the top of user ram
    __asm(
        "move $sp, %0"
        :                 //Output
        : "r" (stack_top) //Input
        : "sp"            //Clobbers
        );

    main();

    __asm("j . \n"
          "nop"
          );
}
