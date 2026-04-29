# $8 = I/O base
# $9 = cnt (value to write to 7-segment dislays)
# $10 = 0 and digit values
# $12 = 4 (bit width of digits)
# $13 = temporary variable (holds number of bits to shift left)
# $14 = concatenated value of 8 7-segment display digits 
 
main:
   li  a1, 0xbf800004            # Read the Switches
   li  a0, 0xbf800000
   addi 	x9, x0, 7         # cnt = 7-segment displays
   addi  x8, zero, 0x0      # $10 = 0
   sw    x8, 0xc(a0)      # enable all 8 of the 7-segment displays
   
readIO: 
 
    lw  t0, 0(a1)

     #srl t0, t0, 16
    sw  t0, 0(a0)               # Write the LEDs
    
    sw  t0, 0x10(a0)            # write the switch values to the 7 segment display in hex

    beq zero, zero, readIO
    
 
.data
 
dataspace: .word 0,0,0,0,0,0,0,0
           .word 0,0,0,0,0,0
           .word 2
           .word 0x7fffffff
           .word 0xa3
           .word 0x27
           .word 0x79
           .word 0x115
           .word 0,0,0,0,0,0,0,0


.end

