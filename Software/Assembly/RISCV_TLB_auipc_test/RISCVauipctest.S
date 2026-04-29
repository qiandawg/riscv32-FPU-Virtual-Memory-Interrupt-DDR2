.option norvc        # Disable compressed instructions to ensure 4-byte alignment
    .text
    .globl __user_start

__user_start:
    nop
    nop

    # ==========================================
    # INIT REGISTERS
    # ==========================================
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x30, 0            # x30 will act as our "Pass/Fail" accumulator

    # ==========================================
    # TEST 1: Basic PC Capture
    # ==========================================
    # Instruction: auipc rd, 0
    # Expected: rd = PC of this instruction
test_1:
    auipc x1, 0          # x1 gets address of test_1

    # ==========================================
    # TEST 2: Positive Offset (PC + 0x1000)
    # ==========================================
    # Instruction: auipc rd, 1
    # Expected: rd = PC + (1 << 12) = PC + 4096
    # Note: test_2 is exactly 4 bytes after test_1
test_2:
    auipc x2, 1          # x2 gets (address of test_2) + 0x1000

    # ==========================================
    # TEST 3: Negative Offset (PC - 0x1000)
    # ==========================================
    # Instruction: auipc rd, 0xFFFFF (-1 signed 20-bit)
    # Expected: rd = PC + (-1 << 12) = PC - 4096
    # Note: test_3 is exactly 4 bytes after test_2
test_3:
    auipc x3, 0xFFFFF    # x3 gets (address of test_3) - 0x1000

    # ==========================================
    # VERIFICATION MATH
    # ==========================================
    
    # ---------------------------------------------------
    # Check 1: Delta between Test 2 and Test 1
    # x2 = (PC_1 + 4) + 0x1000
    # x1 = PC_1
    # Expected Diff: 0x1004
    # ---------------------------------------------------
    sub x4, x2, x1       # x4 = x2 - x1
    li  x5, 0x1004       # Load expected constant
    sub x6, x4, x5       # x6 should be 0 if correct
    beq x6, x0, mark_pass_1
    j fail_check

mark_pass_1:
    addi x30, x30, 1     # Increment score

    # ---------------------------------------------------
    # Check 2: Delta between Test 1 and Test 3
    # x1 = PC_1
    # x3 = (PC_1 + 8) - 0x1000
    # Diff (x1 - x3): PC_1 - (PC_1 + 8 - 4096) 
    #               = -8 + 4096 = 4088 = 0xFF8
    # ---------------------------------------------------
    sub x7, x1, x3       # x7 = x1 - x3
    li  x8, 0xFF8        # Load expected constant (4088)
    sub x9, x7, x8       # x9 should be 0 if correct
    beq x9, x0, mark_pass_2
    j fail_check

mark_pass_2:
    addi x30, x30, 1     # Increment score (Score should be 2 now)

    # ==========================================
    # STORE RESULTS
    # ==========================================
    lui x10, %hi(results)
    addi x10, x10, %lo(results)

    sw x1, 0(x10)        # Store Test 1 Result (PC)
    sw x2, 4(x10)        # Store Test 2 Result
    sw x3, 8(x10)        # Store Test 3 Result
    sw x4, 12(x10)       # Store Calc Diff 1 (Should be 0x1004)
    sw x7, 16(x10)       # Store Calc Diff 2 (Should be 0xFF8)
    sw x30, 20(x10)      # Store Score (Should be 2)

    # Store a final success flag if score == 2
    li x11, 2
    beq x30, x11, all_good
    
    # Logic for failure (write 0xDEAD)
    li x12, 0xDEAD
    sw x12, 24(x10)
    j finish

all_good:
    # Logic for success (write 0xGOOD)
    li x12, 0x600D
    sw x12, 24(x10)

finish:
    jal finish
    nop

fail_check:
    # If we jump here, math failed. x30 will not be 2.
    j finish

# ==========================================
# DATA SECTION
# ==========================================
.data
.align 4
results:
    .space 32            # Reserved for: x1, x2, x3, diff1, diff2, score, status flag