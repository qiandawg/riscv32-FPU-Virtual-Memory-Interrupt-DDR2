#define GPIO_SWs    0xbf800004
#define GPIO_LEDs   0xbf800000
#define GPIO_INOUT  0x80001408

.globl _start
_start:

next:
    li  a1, 0xbf800004            # Read the Switches
    lw  t0, 0(a1)

    li  a0, 0xbf800000
    #srl t0, t0, 16
    sw  t0, 0(a0)               # Write the LEDs

	jal next


.word 0,0,0,0,0,0,0,0,0
.end

