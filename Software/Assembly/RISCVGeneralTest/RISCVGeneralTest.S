.data
float_value1:  .float 12.0          # Space for the first floating point value
float_value2:  .float 8.0           # Space for the second floating point value
result:        .float 0.0            # Space for storing the result
result20:      .float 20.0
result4:       .float 4.0
result1p5:     .float 1.5
resultsqrt:    .word 0x41400000
error_code:    .word 0                # Space for error code, if needed
expected_value: .word 0                # Space for expected integer result

.text
.globl main

main:
    # Initialize LED display to 0
    li x26, 0xbf800000
    li x1, 0x0000                    # Load 0 into register x1
    sw x1, 0(x26)                     # Write 0 to LEDs (address 0xbf800000)

    # Initialize error count
    li x2, 0                         # Error count in x2

    # Test LUI
    lui x3, 0x12345                  # Load upper immediate into x3
    li x4, 0x12345000                # Load lower immediate into x4
    bne x3, x4, increment_error      # Check for error

 # Test JAL Instruction
    lui x5, %hi(test_jal)          # Load upper 20 bits of the address into x5
    addi x5,x5, %lo(test_jal)      # Add lower 12 bits to the value in x5
    #la x5, test_jal                # Load address of test_jal into x5
    jal x6, test_jal               # Jump and link to test_jal (x6 holds return address)
    nop                            # Dummy operation; executed if JAL behavior fails
    bne x0, x6, increment_error    # Ensure x6 holds return address (x6 != 0 or error)
    j end_test                     # Jump to the end of the test

test_jal:
    # Upon entering, x6 has return address
    li x7, 0x4                     # Load immediate value 4 into x7
    add x6, x6, x7                 # Adjust return address in x6 (optional)
    
    # Test JALR Instruction
    lui x5, %hi(test_jal_end)      # Load upper 20 bits of the address into x5
    addi x5,x5, %lo(test_jal_end)  # Add lower 12 bits to the value in x5
    #la x5, test_jal_end            # Load address of test_jal_end into x5 for JALR
    jalr x0, 0(x5)                 # Jump to test_jal_end; use x0 as destination (no link)

test_jal_end:
    nop                            # Dummy operation; verifies JALR behavior
    j end_test                     # Jump to end of test to ensure smooth flow

end_test:
    # End of test marker
    nop                            # Place any necessary termination or status code here

    # Test BEQ
    li x6, 1                          # Load immediate value to x6
    beq x6, x6, pass                 # Jump if equal
    j increment_error                 # Should not reach here

pass:
    # Test BNE
    bne x6, x1, increment_error      # This should fail, check error

    # Test ADDI
    addi x7, x6, 1                   # x7 = x6 + 1
    li x27,2
    bne x7, x27, increment_error        # Check for error

    # Test SUB
    sub x8, x6, x7                   # x8 = x6 - x7
    li x27,-1
    bne x8, x27, increment_error       # Check for error (1 - 2 should be -1)

    # Test SLT
    slt x9, x7, x6                   # x9 = (x7 < x6) ?
    bne x9, x0, increment_error        # Check if result is as expected

    # Test XOR
    xor x1, x6, x7                   # x1 = x6 ^ x7
    li x27,3
    bne x1, x27, increment_error        # Check if result is correct (1 ^ 2 = 3)

    # Test OR
    or x1, x6, x7                    # x1 = x6 | x7
    li x27, 3
    bne x1, x27, increment_error        # Check if result is correct (1 | 2 = 3)

    # Test AND
    and x1, x6, x7                   # x1 = x6 & x7
    beq x1, x0, increment_error        # 1 & 2 should be 0

    # Test SLL
    slli x3, x6, 1                   # x3 = x6 << 1
    li x27,1
    bne x3, x27, increment_error        # Check if result is correct

    # Test SRL
    srli x4, x7, 1                   # x4 = x7 >> 1
    li x27,1
    bne x4, x27, increment_error        # Check for error

    # Test SRA
    srai x5, x8, 1                    # Arithmetic right shift
    li x27, -1
    bne x5, x27, increment_error       # Check for error

    # Test MUL
    mul x6, x7, x8                   # x6 = x7 * x8
    li x27, 2
    bne x6, x27, increment_error        # Check if result is correct

    # Test DIV
    div x7, x8, x6                   # x7 = x8 / x6
    li x27,1
    bne x7, x27, increment_error        # Check if result is correct

    # Test REM
    rem x8, x7, x6                   # x8 = x7 % x6
    bne x8, x0, increment_error        # Check if result is correct

    # Load Word from Memory (floating-point)
    lui x1, %hi(float_value1)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value1)    # Add lower 12 bits to the value in x1
    #la x1, float_value1              # Load address of float_value1 into x1
    flw f1, 0(x1)                    # Load float value into f1
    li x2, 12                         # Expected value for comparison

    # Store the float value in memory for comparison
    lui x3, %hi(expected_value)         # Load upper 20 bits of the address into x3
    addi x3, x1, %lo(expected_value)    # Add lower 12 bits to the value in x3
    #la x3, expected_value            # Load address for expected_value
    fsw f1, 0(x3)                    # Store the loaded float value in memory

    # Verify the stored value by loading it back into an integer register
    flw f1, 0(x3)                    # Load it as a float into f1
    # Convert float to integer manually
    # Store the float in memory and then load back to integer for comparison
    li x4, 12                         # Load expected integer value into x4
    bne x4, x4, increment_error       # Validate the comparison as needed

    # Test FSW (Store floating point)
    lui x1, %hi(float_value2)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value2)    # Add lower 12 bits to the value in x1
    #la x1, float_value2              # Load address of float_value2 into x1
    li x2, 8                          # Prepare integer representation
    sw x2, 0(x1)                     # Store integer 8 into float_value2

    # Verify FSW by loading back the value
    lw x5, 0(x1)                     # Load the value back into x5
    li x6, 8                          # Expected value (8.0 as integer)
    bne x5, x6, increment_error       # Check if stored and loaded values are equal

    # Test FADD (Floating-point Add)
    lui x1, %hi(float_value1)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value1)    # Add lower 12 bits to the value in x1
    #la x1, float_value1              # Load address of float_value1
    flw f1, 0(x1)                    # Load float_value1 into f1
    lui x2, %hi(float_value2)         # Load upper 20 bits of the address into x2
    addi x2, x2, %lo(float_value2)    # Add lower 12 bits to the value in x2
    #la x2, float_value2              # Load address of float_value2
    flw f2, 0(x2)                    # Load float_value2 into f2
    fadd.s f4, f1, f2                # f4 = f1 + f2

    # Store the result of FADD to memory
    lui x3, %hi(result)         # Load upper 20 bits of the address into x3
    addi x3, x3, %lo(result)    # Add lower 12 bits to the value in x3
    #la x3, result                    # Load address of result
    fsw f4, 0(x3)                    # Store the result back to memory

    # Verify FADD
    lui x6, %hi(result)         # Load upper 20 bits of the address into x6
    addi x6, x6, %lo(result)    # Add lower 12 bits to the value in x6
    #la x6,result
    lui x7, %hi(result20)         # Load upper 20 bits of the address into x7
    addi x7, x7, %lo(result20)    # Add lower 12 bits to the value in x7
    #la x7,result20
    lw x8,0(x6)
    lw x9,0(x7)
    bne x8, x9, increment_error       # Check for error

    # Test FSUB (Floating-point Subtraction)
    lui x1, %hi(float_value1)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value1)    # Add lower 12 bits to the value in x1
    #la x1, float_value1              # Load address of float_value1
    flw f1, 0(x1)                    # Load f1 = float_value1
    lui x2, %hi(float_value2)         # Load upper 20 bits of the address into x2
    addi x2, x2, %lo(float_value2)    # Add lower 12 bits to the value in x2
    #la x2, float_value2              # Load address of float_value2
    flw f2, 0(x2)                    # Load f2 = float_value2
    fsub.s f6, f1, f2                # f6 = f1 - f2 (Should be 4.0)

    # Store the result of FSUB to memory
    lui x3, %hi(result)         # Load upper 20 bits of the address into x3
    addi x3, x3, %lo(result)    # Add lower 12 bits to the value in x3
    #la x3, result                    # Load address of result
    fsw f6, 0(x3)                    # Store the result back to memory

    # Verify FSUB
    lui x10, %hi(result)         # Load upper 20 bits of the address into x10
    addi x10, x10, %lo(result)    # Add lower 12 bits to the value in x10
    #la x10, result
    lui x11, %hi(result)         # Load upper 20 bits of the address into x11
    addi x11, x11, %lo(result)    # Add lower 12 bits to the value in x1
    #la x11, result4
    lw x12,0(x10)
    lw x13,0(x11)

    bne x12, x13, increment_error     # Check for error

    # Test FDIV (Floating-point Division)
    lui x1, %hi(float_value1)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value1)    # Add lower 12 bits to the value in x1
    #la x1, float_value1              # Load address of float_value1
    flw f1, 0(x1)                    # Load f1 = float_value1
    lui x2, %hi(float_value2)         # Load upper 20 bits of the address into x2
    addi x2, x2, %lo(float_value2)    # Add lower 12 bits to the value in x2
    #la x2, float_value2              # Load address of float_value2
    flw f2, 0(x2)                    # Load f2 = float_value2
    fdiv.s f14, f1, f2               # f14 = f1 / f2 (Should be 1.5)

    # Store the result of FDIV to memory
    lui x3, %hi(result)         # Load upper 20 bits of the address into x3
    addi x3, x3, %lo(result)    # Add lower 12 bits to the value in x3
    #la x3, result                    # Load address of result
    fsw f14, 0(x3)                   # Store the result back to memory

    # Verify FDIV
    lui x15, %hi(result)         # Load upper 20 bits of the address into x15
    addi x15, x15, %lo(result)    # Add lower 12 bits to the value in x15
    #la x15, result
    lui x16, %hi(result1p5)         # Load upper 20 bits of the address into x16
    addi x16, x16, %lo(result1p5)    # Add lower 12 bits to the value in x16
    #la x16, result1p5
    lw x19,0x(x15)
    lw x18,0x(x16)
    bne x19, x18, increment_error     # Check for error

    # Test FSQRT (Floating-point Square Root)
    lui x1, %hi(float_value1)         # Load upper 20 bits of the address into x1
    addi x1, x1, %lo(float_value1)    # Add lower 12 bits to the value in x1
    #la x1, float_value1              # Load address of float_value1
    flw f1, 0(x1)                    # Load f1 = float_value1
    fsqrt.s f20, f1                   # f20 = sqrt(f1) (Should be ~3.464)

    # Store the result of FSQRT to memory
    lui x3, %hi(result)         # Load upper 20 bits of the address into x3
    addi x3, x3, %lo(result)    # Add lower 12 bits to the value in x3
    #la x3, result                    # Load address of result
    fsw f20, 0(x3)                   # Store result

    # Verify FSQRT (consider an acceptable tolerance)
    lui x22, %hi(result)         # Load upper 20 bits of the address into x22
    addi x22, x22, %lo(result)    # Add lower 12 bits to the value in x22
    #la x22,result
    lui x23, %hi(resultsqrt)         # Load upper 20 bits of the address into x23
    addi x23, x23, %lo(resultsqrt)    # Add lower 12 bits to the value in x23
    #la x23,resultsqrt
    lw x24,0x(x22)
    lw x25,0x(x23)
    bne x25, x24, increment_error     # Check for error

    # If all tests pass, display 0x0000
    li x1, 0x0000                    # Load 0 into x1
    li x26, 0xbf800000
    sw x1, 0(x26)                # Set LEDs to 0x0000 (no error)

    # Wait before re-running the tests
    j main                           # Loop back to main

increment_error:
    lui x28, %hi(error_code)         # Load upper 20 bits of the address into x28
    addi x28, x28, %lo(error_code)    # Add lower 12 bits to the value in x28
    #la x28, error_code
    lw x1, 0(x28)                # Load the current error code
    addi x1, x1, 1                   # Increment the error code
    sw x1, 0(x28)                # Store updated error code

error_handler:
    lw x1, 0(x28)                # Load the current error code
    li x26, 0xbf800000
    sw x1, 0(x26)                # Display error code on LEDs

    # Wait for button press
wait_for_button:
    j check_button                   # Call to check the button state

check_button:
    li x26, 0xbf800008              # Load the address for the button input
    lw x2, 0(x26)                    # Read the button state into x2

    # Check if the BTNL button is pressed (value is 4)
    andi x3, x2, 4                   # Mask x2 with 4 to check if BTNL is pressed
    beq x3, x0, button_not_pressed  # Branch if BTNL is not pressed

    # Code to handle button pressed action
    j button_pressed                 # Jump to where you handle button press

button_not_pressed:
    j check_button                   # Continue checking the button state

button_pressed:
    # Code to handle the button pressed action
    ret                               # Return from this subroutine