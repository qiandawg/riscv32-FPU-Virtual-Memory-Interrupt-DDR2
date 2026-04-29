 .text                           # code segment
.set noreorder                           # code segment
.set noat

.globl main

main:   lui  x1, 0         # x1 <- 0
         ori  x4, x1, 80    # x1 <- 80
         addi x5, x0,  4    # x5 <- 4
 call:   jal  x1, sum       # x1 <- 0x10 (return address), call sum
         sw   x6, 0(x4)     # memory[x4+0] <- x6
         lw   x9, 0(x4)     # x6 <- memory[x4+0]
         sub  x8, x9, x4    # x8 <- x9 - x4
         addi x5, x0,  3    # x5 <- 3
 loop2:  addi x5, x5, -1    # x5 <- x5 - 1
         ori  x8, x5, 0xfff # x8 <- x5 | 0xffffffff = 0xffffffff
         xori x8, x8, 0x555 # x8 <- x8 ^ 0x00000555 = 0xfffffaaa
         addi x9, x0, -1    # x9 <- 0xffffffff
         andi x10,x9, 0xfff # x10<- x9 & 0xffffffff = 0xffffffff
         or   x4, x10, x9   # x4 <- x10 | x9 = 0xffffffff
         xor  x8, x10, x9   # x8 <- x10 ^ x9 = 0x00000000
         and  x7, x10, x4   # x7 <- x10 & x4 = 0xffffffff
         beq  x5, x0, shift # if x5 = 0, goto shift
         jal  x0, loop2     # jump loop2
 shift:  addi x5, x0, -1    # x5 <- 0xffffffff
         slli x8, x5, 15    # x8 <- 0xffffffff <<  15 = 0xffff8000
         slli x8, x8, 16    # x8 <- 0xffff8000 <<  16 = 0x80000000
         srai x8, x8, 16    # x8 <- 0x80000000 >>> 16 = 0xffff8000
         srli x8, x8, 15    # x8 <- 0xffff8000 >>  15 = 0x0001ffff
         slt  x3, x4, x6    # x3 <- 0xffffffff < 0x000002ff = 1
 finish: jal  x0, finish    # dead loop
 sum:    add  x6, x0, x0    # x6 <- 0 (subroutine entry)
 loop:   lw   x9, 0(x4)     # x9 <- memory[x4+0]
         addi x4, x4,  4    # x4 <- x4 + 4 (address+4)
         add  x6, x6, x9    # x6 <- x6 + x9 (sum)
         addi x5, x5, -1    # x5 <- x5 - 1 (counter--)
         bne  x5, x0, loop  # if x5 != 0, goto loop
         ret  x1            # return from subroutine
