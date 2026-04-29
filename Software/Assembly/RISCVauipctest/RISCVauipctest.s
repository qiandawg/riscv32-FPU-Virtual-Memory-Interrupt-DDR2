/* RISC-V interrupt and exception handler */
/* Define symbols for CSR registers */
.equ mcause,  0x342
.equ mepc,    0x341  
.equ mstatus, 0x300
.equ mtvec,   0x305
 .equ mie,   0x304        # CSR address for Machine Interrupt Enable

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

int_entry:                 # 0. interrupt handler
    nop                    # deal with interrupt here
    mret                   # return from interrupt
    nop

sys_entry:                 # 1. syscall (ecall) handler  
    li   t5, 10            # t5 ← 10
    li   t6,  3            # t6 ←  3
    sub  t3, t5, t6        # t7 ← 10–3 = 7  <-- proof ecall handler ran
    nop
    
epc_plus4:
    csrr  t1, mepc         # get exception PC
    addi  t1, t1, 4        # epc + 4
    csrw  mepc, t1         # mepc <- mepc + 4
    mret                   # return from exception
    nop

uni_entry:                 # 2. unimplemented inst. handler
    nop                    # do something here
    j     epc_plus4        # return
    nop
    nop
    nop

ovf_entry:                 # 3. overflow handler
    nop                    # do something here  
    j     epc_plus4        # return
    nop

# Simple AUIPC test for RISC-V simulators
# Assemble with: riscv64-unknown-elf-as -march=rv32i -o test.o test.s
# Link with: riscv64-unknown-elf-ld -o test test.o


start:
    # 1) Load a 1 in bit 11 into t0
    li   t0, 1 << 11         # t0 = 0x800
    csrrs x0, mie, t0        # MIE = MIE | t0
    li    t0, 0x08      # full absolute address (exc_base Must be below 12 bits)
    csrrw x0, mtvec, t0
    addi t3, zero, 0xf     # prepare status value
    csrw mstatus, t3       # enable exceptions/interrupts

    # Initialize registers to known values
    li x1, 0
    li x2, 0
    li x3, 0
    
    # Test sequence
test_1:
    auipc x1, 0           # Get current PC
    
test_2:
    auipc x2, 1           # PC + 0x1000
    
test_3:
    auipc x3, 0xFFFFF     # PC + 0xFFFFF000 (negative)
    
    # Calculate differences to verify
    sub x4, x2, x1        # Should be close to 0x1000
    sub x5, x1, x3        # Should be close to 0x1000
    
    # Store results for inspection
    lui x10, %hi(results)
    addi x10, x10, %lo(results)
    sw x1, 0(x10)         # Store first AUIPC result
    sw x2, 4(x10)         # Store second AUIPC result  
    sw x3, 8(x10)         # Store third AUIPC result
    sw x4, 12(x10)        # Store difference 1
    sw x5, 16(x10)        # Store difference 2
    
    # End program
finish: jal finish
    nop

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
results:
    .space 20             # Space for 5 words of results