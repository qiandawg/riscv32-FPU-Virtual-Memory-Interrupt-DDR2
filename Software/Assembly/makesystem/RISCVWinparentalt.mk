#The file including us must at a minimum define:
#SOFTWARE_ROOT A_SOURCES C_SOURCES PROGNAME

CC = riscv-none-embed-gcc
AS = riscv-none-embed-as
LD = riscv-none-embed-ld
SIZE = riscv-none-embed-size
STRIP = riscv-none-embed-strip
OBJCOPY = riscv-none-embed-objcopy
OBJDUMP = riscv-none-embed-objdump

CCFLAGS =  -g 
ASFLAGS =  -g 
LDFLAGS =  -g -nostdlib 

A_OBJECTS = $(A_SOURCES:.S=.o)
C_OBJECTS = $(C_SOURCES:.c=.o)

OBJECTS = $(A_OBJECTS) $(C_OBJECTS)

VPATH = $(SOFTWARE_ROOT)

all: help

.PHONY: help
help:
	@echo "RISCV Makefile system"
	@echo "Usage: make <target>"
	@echo "where <target> is one of: single_mem split_i_d_mem full_tlb_mem"
	@echo 
	@echo "For reference, our designs use the following:"
	@echo "Single Cycle with Interrupts: split_i_d_mem"
	@echo "Multi Cycle:                  single_mem"
	@echo "Pipeline:                     split_i_d_mem"
	@echo "Pipeline with Interrupts:     split_i_d_mem"
	@echo "Pipeline with FPU:            split_i_d_mem"
	@echo "Pipeline with Cache-FPU-VM:   full_tlb_mem"
	@echo "Multi-Processor:              split_i_d_mem"

.PHONY: single_mem
single_mem: LDFLAGS+=-T $(SOFTWARE_ROOT)/makesystem/single_mem.ld
single_mem: singlesim genihex

.PHONY: split_i_d_mem
split_i_d_mem: LDFLAGS+=-T $(SOFTWARE_ROOT)/makesystem/split_i_d_mem.ld
split_i_d_mem: idsim

.PHONY: full_tlb_mem
full_tlb_mem: LDFLAGS+=-T $(SOFTWARE_ROOT)/makesystem/full_tlb_mem.ld
full_tlb_mem: A_SOURCES+=startup.S
full_tlb_mem: startup.o genihex fullsim

.PHONY: clean
clean:
	rm -f $(OBJECTS)
	rm -f startup.o
	rm -f crt.o
	rm -f $(PROGNAME).elf
	rm -f $(PROGNAME).srec
	rm -f $(PROGNAME).ihex
	rm -f mem0.bin mem1.bin mem2.bin mem3.bin mem.bin imem.bin dmem.bin imemL.mem imemL.bin dmemL.bin dmemL.mem
	rm -f mem0.mem mem1.mem mem2.mem mem3.mem mem.mem imem.mem dmem.mem mem0L.mem mem0L.bin mem1L.mem mem1L.bin mem2L.mem mem2L.bin mem3L.mem mem3L.bin

assemble: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $(PROGNAME).elf
	#$(STRIP) $(PROGNAME).elf
	@echo "\n----------------------------------\n"
	$(SIZE) $(PROGNAME).elf
	@echo "\n----------------------------------\n"

#Special rules for files in special locations
startup.o:
	$(AS) $(ASFLAGS) $(SOFTWARE_ROOT)/makesystem/startup.S -o startup.o

crt.o:
	$(CC) $(CCFLAGS) -c $(SOFTWARE_ROOT)/makesystem/crt.c -o crt.o

%.o: %.S
	$(AS) $(ASFLAGS) $< -o $@

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@

%.o: %.c
	$(CC) $(CCFLAGS) -c $<

gensrec: assemble
	$(OBJCOPY) -O srec $(PROGNAME).elf --srec-forceS3 $(PROGNAME).srec

genihex: assemble
	$(OBJCOPY) -O ihex $(PROGNAME).elf $(PROGNAME).ihex

singlesim: assemble
	$(OBJCOPY) -O binary -j .text -j .data $(PROGNAME).elf mem.bin
	-$(OBJDUMP) -s -j .data $(PROGNAME).elf
	-$(OBJDUMP) -d -S -M reg-names=numeric -j .text $(PROGNAME).elf

	xxd -e mem.bin memL.mem
	xxd -r memL.mem memL.bin
	xxd -c 4 -ps memL.bin mem.mem

idsim: assemble
	$(OBJCOPY) -O binary -j .text $(PROGNAME).elf imem.bin
	$(OBJCOPY) -O binary -j .data $(PROGNAME).elf dmem.bin
	$(OBJCOPY) -O ihex -j .text $(PROGNAME).elf imem.ihex
	$(OBJCOPY) -O ihex -j .data $(PROGNAME).elf dmem.ihex
	-$(OBJDUMP) -s -j .data $(PROGNAME).elf
	-$(OBJDUMP) -d -S -j .text $(PROGNAME).elf

	xxd -e imem.bin imemL.mem
	xxd -r imemL.mem imemL.bin
	xxd -c 4 -ps imemL.bin imem.mem
	xxd -e dmem.bin dmemL.mem
	xxd -r dmemL.mem dmemL.bin
	xxd -c 4 -ps dmemL.bin dmem.mem
	
fullsim: assemble
	$(OBJCOPY) -O binary -j .init_text $(PROGNAME).elf mem0.bin
	$(OBJCOPY) -O binary -j .tlb_data $(PROGNAME).elf mem1.bin
	-$(OBJDUMP) -s -j .tlb_data $(PROGNAME).elf
	-$(OBJDUMP) -d -M reg-names=numeric -j .init_text $(PROGNAME).elf
	$(OBJCOPY) -O binary -j .text $(PROGNAME).elf mem2.bin
	$(OBJCOPY) -O binary --gap-fill 0x00 -j .data -j .rodata -j .bss -j .early_stack $(PROGNAME).elf mem3.bin
	-$(OBJDUMP) -s -j .data $(PROGNAME).elf
	-$(OBJDUMP) -d -S -M reg-names=numeric -j .text $(PROGNAME).elf

	xxd -e mem0.bin memL0.mem
	xxd -r memL0.mem memL0.bin
	xxd -c 4 -ps memL0.bin mem0.mem
	xxd -e mem1.bin memL1.mem
	xxd -r memL1.mem memL1.bin
	xxd -c 4 -ps memL1.bin mem1.mem
	xxd -e mem2.bin memL2.mem
	xxd -r memL2.mem memL2.bin
	xxd -c 4 -ps memL2.bin mem2.mem
	xxd -e mem3.bin memL3.mem
	xxd -r memL3.mem memL3.bin
	xxd -c 4 -ps memL3.bin mem3.mem

