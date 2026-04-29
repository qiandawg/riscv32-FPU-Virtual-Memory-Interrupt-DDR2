    .section .text
    .globl _start

_start:
    lui   t3, 0xbf800       # t3 = 0xbf800000 (I/O base address)
    addi  t4, t3, 4         # t4 = 0xbf800004 (switch input address)
    li    t1, 7             # t1 = 7 (counter, unused in this loop)
    li    t2, 0             # t2 = 0 (used to enable all 7-segment displays)

    sw    t2, 12(t3)        # write to 0xbf80000c to enable all 7-seg displays

readIO:
    lw    t2, 0(t4)         # t2 = mem[0xbf800004] (read switches)
    sw    t2, 0(t3)         # mem[0xbf800000] = t2 (write to LEDs)
    sw    t2, 16(t3)        # mem[0xbf800010] = t2 (write to 7-segment)
    j     readIO            # repeat
