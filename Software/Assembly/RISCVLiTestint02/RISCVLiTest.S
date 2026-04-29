.option norvc

    .section .text
    # Minimal perms
    .set PERM_XRV, 0x0B         # V|R|X
    .set PERM_WRV, 0x07         # V|R|W

    .globl __user_start
__user_start:

 fpu: add     a1,   x0,  x0     # (d0)   address 0
 
     # --- Load floatadd1 (0x40c00000) ---
     lui     t0, %hi(floatadd1)        # Load Upper Immediate (Absolute)
     addi    t0, t0, %lo(floatadd1)    # Add Lower Immediate
     flw     f1, 0(t0)

     # --- Load floatadd2 (0x41c00000) ---
     lui     t0, %hi(floatadd2)
     addi    t0, t0, %lo(floatadd2)
     flw     f2, 0(t0)

     # --- Load floatadd3 (0x43c00000) ---
     lui     t0, %hi(floatadd3)
     addi    t0, t0, %lo(floatadd3)
     flw     f3, 0(t0)

     # --- Load floatadd4 (0x47c00000) ---
     lui     t0, %hi(floatadd4)
     addi    t0, t0, %lo(floatadd4)
     flw     f4, 0(t0)

     # --- Arithmetic Operations ---
     fadd.s  f4,  f4, f1    # (e4) = 0x492a7c60
     fsub.s  f3,  f3, f4    # (e8) = 0xc92a6460
     fmul.s  f2,  f4, f2    # (ec) = 0x4b7fba90
     fmul.s  f1,  f1, f4    # (f0) = 0x4a7fba90

     # --- Store to floatstore1 ---
     lui     t0, %hi(floatstore1)
     addi    t0, t0, %lo(floatstore1)
     fsw     f1, 0(t0)
     
     # --- Store to floatstore2 ---
     lui     t0, %hi(floatstore2)
     addi    t0, t0, %lo(floatstore2)
     fsw     f2, 0(t0)
     
     # --- Store to floatstore3 ---
     lui     t0, %hi(floatstore3)
     addi    t0, t0, %lo(floatstore3)
     fsw     f3, 0(t0)
     
     # --- Store to floatstore4 ---
     lui     t0, %hi(floatstore4)
     addi    t0, t0, %lo(floatstore4)
     fsw     f4, 0(t0)
     
     # --- Load floatadd5 (4.0) ---
     lui     t0, %hi(floatadd5)
     addi    t0, t0, %lo(floatadd5)
     flw     f0, 0(t0)
     
     # --- Load floatadd6 (2.0) ---
     lui     t0, %hi(floatadd6)
     addi    t0, t0, %lo(floatadd6)
     flw     f1, 0(t0)


     # --- More Arithmetic ---
     fdiv.s  f3,  f0, f1     # (10c)    2.000000
     fsqrt.s f3,  f3         # (110) = 1.414214
     fsqrt.s f3,  f3         # (114) = 1.189207
     
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