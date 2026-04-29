.equ CONSTANT, 0xcafebabe        # a 32-bit immediate
.text                            # code segment
main:                            # program entry
	li    a0,  0x0000aaaa
	li	  a1,  0x00000002
    mulhu a3,a0,a1               # multiply unsigned*unsigned
    mul   a2,a0,a1               # first fuse
    li    a0,  0xffffffff
    mulhsu a3,a0,a1              # multiply signed*unsigned
    mul   a2,a0,a1               # second fuse
    li    a1,  0xffffff0
    mulh  a3,a0,a1               # multiply signed*signed
    mul   a2,a0,a1               # third fuse
    li    a0,4096
    li    a1,511
    divu  a3,a0,a1               # divide 4096/511
    remu  a2,a0,a1               # forth fuse
    li    a0, -23
    li    a1, 7
    div   a3,a0,a1               # divide -23/7
    rem   a2,a0,a1               # fifth fuse
    li    a1,-7
    div   a3,a0,a1               # divide -23/-7
    rem   a2,a0,a1               # fifth fuse
    li    a0,45
    li    a1,2
    mul   a2,a0,a1               # check out just getting lower order

loop: j loop         #end the program here 
     nop


.end
