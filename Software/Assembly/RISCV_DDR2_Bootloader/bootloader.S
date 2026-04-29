# bootloader.S
# Start Address: 0x8000_0000

.text
.globl _start
_start:
    # 1. Copy mem0 (init_text) to 0x0000_0000
    li a0, 0x81000000    # Source (ROM 0)
    li a1, 0x00000000    # Dest (DDR2)
    li a2, 0x1000        # Size (4KB)
    jal ra, copy_loop

    # 2. Copy mem1 (pt_data) to 0x1000_0000
    li a0, 0x82000000    # Source (ROM 1)
    li a1, 0x10000000    # Dest (DDR2)
    li a2, 0x1000        # Size (4KB)
    jal ra, copy_loop

    # 3. Copy mem2 (data/stack) to 0x0000_1000
    li a0, 0x83000000    # Source (ROM 2)
    li a1, 0x00001000    # Dest (DDR2)
    li a2, 0x2000        # Size (8KB)
    jal ra, copy_loop

    # 4. Copy mem3 (text) to 0x0000_2000
    li a0, 0x84000000    # Source (ROM 3)
    li a1, 0x00002000    # Dest (DDR2)
    li a2, 0x2000        # Size (8KB)
    jal ra, copy_loop

    # 5. Boot the OS!
    li t0, 0x00000000
    jr t0                # Jump to DDR2

# --- Subroutine to copy memory ---
# a0 = src, a1 = dst, a2 = size
copy_loop:
    add a2, a0, a2       # Calculate end_src = src + size
1:
    beq a0, a2, 2f       # Use BEQ: if src == end_src, exit!
    lw t0, 0(a0)         # read word
    sw t0, 0(a1)         # write word
    addi a0, a0, 4       # increment source address
    addi a1, a1, 4       # increment dest address
    jal x0, 1b           # jump back to loop start ('j' pseudo-instruction)
2:
    jalr x0, ra, 0       # return ('ret' pseudo-instruction)
