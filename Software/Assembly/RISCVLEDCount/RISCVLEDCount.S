    .section .text
    .globl _start
_start:
    li   t2, 0x0000ffff      # t2 = 0x0000ffff
    li   t1, 1               # t1 = 1 (counter start)
    lui  t0, 0xbf800          # t0 = 0xbf800000 (LED address)

L1:
    sw   t1, 0(t0)           # mem[LED] = t1
    addi t1, t1, 1           # t1++

    bne  t1, t2, delay       # if t1 != 0x0000ffff, jump to delay
    li   t1, 1               # else reset to 1

delay:
    li   t3, 0x002625a2      # t3 = 2,500,000
    li   t4, 0               # t4 = loop counter

L2:
    sub  t5, t3, t4          # t5 = t3 - t4
    addi t4, t4, 1           # increment t4
    bne  t5, zero, L2        # loop if not done

    j    L1                  # jump back to LED update
