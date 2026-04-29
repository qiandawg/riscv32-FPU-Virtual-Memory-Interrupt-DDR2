/* RISC-V interrupt and exception handler */
/* Define symbols for CSR registers */
.equ mcause,  0x342
.equ mepc,    0x341  
.equ mstatus, 0x300
.equ mtvec,   0x305
.equ mie,     0x304        # CSR address for Machine Interrupt Enable

    .section .data

# ----------------------------------------------------------
# Data section
# ----------------------------------------------------------
.data
.align 2                   # Ensure word alignment
.global int_counter
int_counter: .word 0       # counter for external interrupts

.global dataspace
dataspace: .word 0,0,0,0,0,0,0,0

.align 2                   # Ensure jump table is word-aligned
.global j_table
j_table:   .word int_entry     # offset 0
           .word sys_entry     # offset 1
           .word uni_entry     # offset 2
           .word ovf_entry     # offset 3
           .word 0,0,0,0,0,0
           .word 2
           .word 0x7fffffff
           .word 0xa3
           .word 0x27
           .word 0x79
           .word 0x115
           .word 0,0,0,0,0,0,0,0

.align 2                   # Ensure float data is word-aligned

.global floatstore1
floatstore1: .word 0
.global floatstore2
floatstore2: .word 0
.global floatstore3
floatstore3: .word 0
.global floatstore4
floatstore4: .word 0
.global floatstore5
floatstore5: .word 0

    .global floatadd1
floatadd1:
    .float 6.0
    .global floatadd2
floatadd2:
    .float 24.0
    .global floatadd3
floatadd3:
    .float 384.0
    .global floatadd4
floatadd4:
    .float 6.0
    .global floatadd5
floatadd5:
    .float 4.0
    .global floatadd6
floatadd6:
    .float 2.0	

.text
    j    start             # entry on reset
    nop                    

exc_base:                  # exception handler
    csrr t1, mcause        # read machine cause register
    andi t2, t1, 0xf       # get exception code (bits 3:0)
    slli t2, t2, 2         # multiply by 4 for word alignment
    la   t3, j_table
    #lui  t3, %hi(j_table)  # load jump table base address (upper)
    #ori  t3, t3, %lo(j_table)  # load jump table base address (lower)
    add  t2, t2, t3        # calculate table entry address
    lw   t2, 0(t2)         # get handler address from table
    jr   t2                # jump to handler
    nop

# ----------------------------------------------------------
# External interrupt handler
# ----------------------------------------------------------
int_entry:
    # Load current counter
    la   t0, int_counter
    #lui  t0, %hi(int_counter)
    #ori  t0, t0, %lo(int_counter)
    lw   t1, 0(t0)
    addi t1, t1, 1          # increment counter
    sw   t1, 0(t0)

    # Write counter value to 7-seg display
    li   t2, 0xbf800000     # base address for LEDs/7-seg
    sw   t1, 0x10(t2)       # 0x10 offset: 7-segment display

    mret                   # return from interrupt
    nop

sys_entry:                 # 1. syscall (ecall) handler  
    li   t5, 10            
    li   t6,  3            
    sub  t3, t5, t6        
    nop
    
epc_plus4:
    csrr  t1, mepc         
    addi  t1, t1, 4        
    csrw  mepc, t1         
    mret                   
    nop

uni_entry:                 
    nop                    
    j     epc_plus4        
    nop
    nop
    nop

ovf_entry:                 
    nop                    
    j     epc_plus4        
    nop

# ----------------------------------------------------------
# Program entry point
# ----------------------------------------------------------
start:
    # Enable external interrupts in mie
    li   t0, (1 << 11)
    csrrs x0, mie, t0

    # Set trap vector - use absolute address
    lui  t0, %hi(exc_base)
    ori  t0, t0, %lo(exc_base)         
    csrrw x0, mtvec, t0

    # Enable global MIE in mstatus
    li   t3, 0x8              # Set MIE bit (bit 3)
    csrrs x0, mstatus, t3

fpu: add     a1,   x0,  x0    # (d0)   address 0
     # Load floating-point values using absolute addressing
     la      t0, floatadd1	 
     flw     f1, 0(t0)       # Load from floatadd1
	 nop
	 nop
	 nop
     # Store floating-point values using absolute addressing
     la      t0, floatstore1	 
     fsw     f1, 0(t0)       # Store to floatstore1

     lw      a1,0(t0)

     la      t0, floatadd2	 
     flw     f2, 0(t0)       # Load from floatadd2

      # Store floating-point values using absolute addressing
     la      t0, floatstore2	 
     fsw     f1, 0(t0)       # Store to floatstore2

     lw      a1,0(t0)
	 
     la      t0, floatadd4	 
     flw     f7, 0(t0)       # Load from floatadd4

    # Store floating-point values using absolute addressing
     la      t0, floatstore4	 
     fsw     f1, 0(t0)       # Store to floatstore1

     lw      a1,0(t0) 


     la      t0, floatadd3	 
     flw     f3, 0(t0)       # Load from floatadd3
  
    # Store floating-point values using absolute addressing
     la      t0, floatstore3	 
     fsw     f1, 0(t0)       # Store to floatstore3

     lw      a1,0(t0)


     
     fadd.s  f4,  f7, f1   # (e4) = 0x47c00300
     fsub.s  f3,  f3, f4   # (e8) = 384-12 = 372
     fmul.s  f2,  f4, f2   # 12*24
     fmul.s  f1,  f1, f4   # 6*12 =42900000
     
     # Store floating-point values using absolute addressing
     la      t0, floatstore1
     #lui     t0, %hi(floatstore1)
     #ori     t0, t0, %lo(floatstore1)
     fsw     f1, 0(t0)       # Store to floatstore1
     
     la      t0, floatstore2
     #lui     t0, %hi(floatstore2)
     #ori     t0, t0, %lo(floatstore2)
     fsw     f2, 0(t0)       # Store to floatstore2
     
     la      t0, floatstore3
     #lui     t0, %hi(floatstore3)
     #ori     t0, t0, %lo(floatstore3)
     fsw     f3, 0(t0)       # Store to floatstore3
     
     la      t0, floatstore4
     #lui     t0, %hi(floatstore4)
     #ori     t0, t0, %lo(floatstore4)
     fsw     f4, 0(t0)       # Store to floatstore4
     
     la      t0, floatadd5
     #lui     t0, %hi(floatadd5)
     #ori     t0, t0, %lo(floatadd5)
     flw     f0, 0(t0)       # 4.000000 (0x40800000)
     
     la      t0, floatadd6
     #lui     t0, %hi(floatadd6)
     #ori     t0, t0, %lo(floatadd6)
     flw     f1, 0(t0)       # 2.000000 (0x40000000)
     
     fdiv.s  f3,  f0, f1   # 2.000000 (0x40000000)
     fsqrt.s f3,  f3        # = 1.414214 (0x3fb504f3)
     fsqrt.s f3,  f3        # = 1.189207 (0x3f9837f0)
  
    # Initialize LEDs / 7-seg
    li  a1, 0xbf800004     # switches
    li  a0, 0xbf800000     # LED / 7-seg base
    addi x9, x0, 7         
    addi x8, zero, 0x0
    sw   x8, 0xc(a0)       # enable all 8 of the 7-segment displays
    nop

# ----------------------------------------------------------
# Main loop
# ----------------------------------------------------------
readIO: 
    lw  t0, 0(a1)
    sw  t0, 0(a0)          # Switch value to LEDs
    j  readIO
    nop

