/* RISC-V interrupt and exception handler */
/* Define symbols for CSR registers */
.equ mcause,  0x342
.equ mepc,    0x341  
.equ mstatus, 0x300
.equ mtvec,   0x305
.equ mie,     0x304        # CSR address for Machine Interrupt Enable



.text
    j    start             # entry on reset
    nop                    

exc_base:                  # exception handler
    csrr t1, mcause        # read machine cause register
    andi t2, t1, 0xf      # get exception type (bits 7:4)
    la   t3, j_table       # load jump table base address
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
    li   t3, 15       #was 0x8       # Set MIE bit (bit 3)
    csrrs x0, mstatus, t3
    
    lw   t3, 0x48(zero)    # try overflow exception
    lw   t4, 0x4c(zero)    # caused by add
    nop
    
ov:
    add  t3, t3, t4        # overflow (if overflow detection enabled)
    nop

sys:
    ecall                  # environment call (was syscall)
    nop

unimpl:
    # Use an unimplemented instruction or reserved encoding
    .word 0x0000007f       # undefined instruction encoding
    nop

int:
    addi a0, zero, 0x50    # address of data[0]
    addi a1, zero, 4       # counter
    add  t3, zero, zero    # sum <- 0
    nop

loop:
    lw   t4, 0(a0)         # load data
    addi a0, a0, 4         # address + 4
    add  t3, t3, t4        # sum
    addi a1, a1, -1        # counter - 1
    bne  a1, zero, loop    # finish?
    nop

finish:

    # Initialize LEDs / 7-seg
    li  s1, 0xbf800004     # switches
    li  s0, 0xbf800000     # LED / 7-seg base

.equ CONSTANT, 0xcafebabe        # a 32-bit immediate
.text                            # code segment
main:                            # program entry
    li    a0,  0x0000aaaa
    li    a1,  0x00000002
    mulhu a3,a0,a1               # multiply unsigned*unsigned
    mul   a2,a0,a1               # first fuse
    li    a0,  0xffffffff
    mulhsu a3,a0,a1              # multiply signed*unsigned
    mul   a2,a0,a1               # second fuse
    li    a1,  0xffffff0
    mulh  a3,a0,a1               # multiply signed*signed
    mul   a2,a0,a1               # third fuse
    li    a0,4096
    li    a1,511
    divu  a3,a0,a1               # divide 4096/511
    remu  a2,a0,a1               # forth fuse
    li    a0, -23
    li    a1, 7
    div   a3,a0,a1               # divide -23/7
    rem   a2,a0,a1               # fifth fuse
    li    a1,-7
    div   a3,a0,a1               # divide -23/-7
    rem   a2,a0,a1               # fifth fuse
    li    a0,45
    li    a1,2
    mul   a2,a0,a1               # check out just getting lower order



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
    sw  t0, 0x10(a0)            # write the switch values to the 7 segment display in hex
    j  readIO
    nop
    .section .data

# ----------------------------------------------------------
# Data section
# ----------------------------------------------------------
.data


.data
dataspace: .word 0,0,0,0,0,0,0,0
j_table:   .word int_entry     # 0x1 << 2 = 0x4 offset
           .word sys_entry     # 0x2 << 2 = 0x8 offset  
           .word uni_entry     # 0x3 << 2 = 0xc offset
           .word ovf_entry     # 0x4 << 2 = 0x10 offset
           .word 0,0,0,0,0,0
           .word 2
           .word 0x7fffffff
           .word 0xa3
           .word 0x27
           .word 0x79
           .word 0x115
           .word 0,0,0,0,0,0,0,0
.align 2                   # Ensure word alignment
.global int_counter
int_counter: .word 0       # counter for external interrupts

.end
  