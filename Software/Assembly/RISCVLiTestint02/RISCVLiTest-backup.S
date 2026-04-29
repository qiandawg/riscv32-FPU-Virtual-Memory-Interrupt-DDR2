        .option norvc


    .section .text
    # Minimal perms (kept for reference to match your comments)
    .set PERM_XRV, 0x0B        # V|R|X
    .set PERM_WRV, 0x07        # V|R|W

    .globl __user_start
__user_start:

 fpu: add     a1,   x0,  x0    # (d0)   address 0
     # Load floating-point values using absolute addressing
     la      t0, floatadd1   
     flw     f1, 0(t0)       # Load from floatadd1   (d4)   0x40c00000 <--
     la      t0, floatadd2    
     flw     f2, 0(t0)       # Load from floatadd2   (d8)   0x41c00000 <--
     la      t0, floatadd3    
     flw     f3, 0(t0)       # Load from floatadd3   (dc)   0x43c00000 <--
     la      t0, floatadd4    
     flw     f4, 0(t0)       # Load from floatadd4   (e0)  0x47c00000 <--

     fadd.s  f4,  f4, f1   # (e4) = 0x41400000 <--
     fsub.s  f3,  f3, f4   # (e8) = 0x41ba0000 <--
     fmul.s  f2,  f4, f2   # (ec) = 0x43900000 <--
     fmul.s  f1,  f1, f4   # (f0) = 0x42900000 <--
     # Store floating-point values using absolute addressing
     la      t0, floatstore1
     fsw     f1, 0(t0)       # Store to floatstore1
     
     la      t0, floatstore2
     fsw     f2, 0(t0)       # Store to floatstore2
     
     la      t0, floatstore3
     fsw     f3, 0(t0)       # Store to floatstore3
     
     la      t0, floatstore4
     fsw     f4, 0(t0)       # Store to floatstore4
     
     la      t0, floatadd5
     flw     f0, 0(t0)       # 4.000000 (0x40800000)
     
     la      t0, floatadd6
     flw     f1, 0(t0)       # 2.000000 (0x40000000)
 
     fdiv.s  f3,  f0, f1   # (10c)   2.000000 (0x40000000) <--
     fsqrt.s f3,  f3        # (110) = 1.414214 (0x3fb504f3) <--
     fsqrt.s f3,  f3        # (114) = 1.189207 (0x3f9837f0) <--
     end: 
     j end
     nop
     
    .section .data
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
    .float 6.0   # 0x40c00000
    .global floatadd2
floatadd2:
    .float 24.0  # 0x41c00000
    .global floatadd3
floatadd3:
    .float 384.0 # 0x43c00000
    .global floatadd4
floatadd4:
    .float 698304.0 # 0x492a7c00
    .global floatadd5
floatadd5:
    .float 4.0  # 0x40800000
    .global floatadd6
floatadd6:
    .float 2.0  # 0x40000000


   