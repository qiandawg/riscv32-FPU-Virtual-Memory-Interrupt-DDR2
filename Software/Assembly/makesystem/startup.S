/* startup.S — RISC-V “mem0..mem3” startup (MIPS-like, no AUIPC, no JALR for user jump)
   - _start in .init_text (mem0)
   - Minimal Sv32 PTs at PA 0x00004000/0x00005000
   - Jump to __user_start with plain 'j' (label within ±1 MiB)
*/

    .globl _start
    .globl start
start = _start

.option norvc  # no compressed instruction

/* CSRs */
.equ mcause,  0x342
.equ mepc,    0x341
.equ mstatus, 0x300
.equ mtvec,   0x305
.equ mie,     0x304
.equ satp,    0x180

/* Page table locations (PHYSICAL) — ensure these are real RAM in your SoC */
.equ L1_BASE, 0x00004000
.equ L0_BASE, 0x00005000

/* Leaf perms */
.equ PERM_XRV, 0x0B      /* X|R|V */
.equ PERM_WRV, 0x07      /* W|R|V */

.section .init_text, "ax"
/* Reset vector @ 0x00000000 */
    j      _start
    nop

/* Exception base @ 0x00000008 (mtvec will point here)
   Keep trivial to avoid JALR for now: always jump back to reset path. */
exc_base:
    j      _start
    nop

/* Boot body */
.global _start
_start:
    /* mtvec = exc_base (0x00000008) */
    li     t0, 0x08
    csrrw  x0, mtvec, t0

    /* Enable external machine interrupts (MEIE bit 11) */
    li     t0, (1 << 11)
    csrrs  x0, mie, t0

    /* Enable global MIE (same style as before) */
    addi   t3, x0, 0x0F
    csrw   mstatus, t3

    /* ---- Build minimal Sv32 PTs in PHYS RAM ---- */
    /* t0 = L1_BASE; t1 = L0_BASE  (no AUIPC: LUI/ADDI %hi/%lo) */
    lui    t0, %hi(L1_BASE)
    addi   t0, t0, %lo(L1_BASE)
    lui    t1, %hi(L0_BASE)
    addi   t1, t1, %lo(L0_BASE)

    /* L1[0] = (PPN(L0)<<10) | V   (PPN(L0)=0x00005 → 0x00001401) */
    addi   t2, x0, 5
    slli   t2, t2, 10
    ori    t2, t2, 1
    sw     t2, 0(t0)
	
#    /* L0[0]: VA 0x0000 → PA 0x2000_0000 (PPN=0x20000), X|R|V */
#    lui   s7, 0x20000
#    srli  s7, s7, 2
#    addi  t3, x0, PERM_XRV
#    or    t3, t3, s7
#    sw    t3, 0(t1)

#    /* L0[1]: VA 0x1000 → PA 0x2000_1000 (PPN=0x20001), W|R|V */
#    lui   s7, 0x20001
#    srli  s7, s7, 2
#    addi  t3, x0, PERM_WRV
#    or    t3, t3, s7
#    sw    t3, 4(t1)
    #L0[0]: VA 0x0000 -> PA 0x2000_0000. Change to bootloader (Write|Read|Valid) 
    #This allows the CPU to fetch the next instructions after enabling paging 
	li    t3, 0               # PPN = 0x00000
    addi  t3, t3, PERM_XRV    # Execute|Read|Valid
    sw    t3, 0(t1)           # Write to L0[0]

    #/* L0[1]: VA 0x1000 -> PA 0x2000_0000. Keep as Stack and data (Write|Read|Valid) */
    lui   s7, 0x20000
    srli  s7, s7, 2
    addi  t3, x0, PERM_WRV   /* Keep as WRV (Good for Stack space) */
    or    t3, t3, s7
    sw    t3, 4(t1)


    #/* L0[2]: VA 0x2000 → PA 0x2000_2000 (PPN=0x20002), X|R|V  (holds __user_start) */
    lui   s7, 0x20002
    srli  s7, s7, 2
    addi  t3, x0, PERM_XRV
    or    t3, t3, s7
    sw    t3, 8(t1)

    #/* (Optional) L0[3]: VA 0x3000 → PA 0x2000_3000 (PPN=0x20003), X|R|V */
    lui   s7, 0x20003
    srli  s7, s7, 2
    addi  t5, x0, PERM_XRV
    or    t5, t5, s7
    sw    t5, 12(t1)

        # If you want the a0 check to pass (no exec blob), set it here:
		#/* Enable Sv32 (satp[31]=1, PPN(L1)=0x4) => 0x8000_0004 */
	lui    t4, 0x80000
	addi   t4, t4, 4
	csrrw  x0, satp, t4
	nop
	nop
	nop
	nop
    fence.i
    #Jump to user program (must be within ±1 MiB): __user_start in .text VMA=0x00000000 */
    # Set SP to the top of the stack region (VA 0x2000) */
    li sp, 0x2000 
	j      __user_start
    nop
