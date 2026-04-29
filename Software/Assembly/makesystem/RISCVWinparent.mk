#The file including us must at a minimum define:
#SOFTWARE_ROOT A_SOURCES C_SOURCES PROGNAME

#CC = riscv-none-elf-gcc-14.2.0
CC = riscv-none-elf-gcc
AS = riscv-none-elf-as
LD = riscv-none-elf-ld
SIZE = riscv-none-elf-size
STRIP = riscv-none-elf-strip
OBJCOPY = riscv-none-elf-objcopy
OBJDUMP = riscv-none-elf-objdump

#CCFLAGS =  -g 
#ASFLAGS =  -g 
# -fma = remove fused multiply add
# 
CCFLAGS = -g -march=rv32imf_zicsr_zifencei -mabi=ilp32f -mcmodel=medlow -fno-pic
ASFLAGS = -g -march=rv32imf_zicsr_zifencei -mcmodel=medlow -fno-pic
#CCFLAGS = -g -march=rv32imf_zicsr_zifencei -mabi=ilp32f
#ASFLAGS = -g -march=rv32imf_zicsr_zifencei
LDFLAGS =  -g -nostdlib 

# ASFLAGS   = -g -march=rv32imf
# CCFLAGS   = -g -march=rv32imf -mabi=ilp32f
# LDFLAGS   = -g -nostdlib

# ---- Startup + RV full-tlb linker script ----
STARTUP_S := $(SOFTWARE_ROOT)/makesystem/startup.S
RV_FULLTLB_LD := $(SOFTWARE_ROOT)/makesystem/full_tlb_mem.ld


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

#.PHONY: full_tlb_mem
#full_tlb_mem: PROGNAME:=VM_Cache_test
#full_tlb_mem: A_SOURCES:=VM_Cache_test.S
#full_tlb_mem: C_SOURCES:=
#full_tlb_mem: LDFLAGS+=-T $(SOFTWARE_ROOT)/makesystem/full_tlb_mem.ld -Wl,-e,_start
#full_tlb_mem: genihex fullsim

.PHONY: full_tlb_mem
# Build like MIPS: link startup.S and use the 4-way split linker script
full_tlb_mem: A_SOURCES+=startup.S
#added 11/24/2025
#full_tlb_mem: C_SOURCES+=startup.S  
full_tlb_mem: LDFLAGS+=-T $(RV_FULLTLB_LD) -Wl,-e,_start
full_tlb_mem: startup.o genihex fullsim


.PHONY: clean
clean:
	rm -f $(OBJECTS)
	rm -f startup.o
	rm -f RSICVcrt.o
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
	$(CC) $(CCFLAGS) -c $(SOFTWARE_ROOT)/makesystem/startup.S -o startup.o



RISCVcrt.o:
	$(CC) $(CCFLAGS) -c $(SOFTWARE_ROOT)/makesystem/RISCVcrt.c -o RISCVcrt.o

%.o: %.S
	$(CC) $(CCFLAGS) -c $< -o $@
#	$(AS) $(ASFLAGS) $< -o $@

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

	C:/"Program Files"/Vim/vim91/xxd  -e mem.bin > memL.mem
	C:/"Program Files"/Vim/vim91/xxd  -r memL.mem > memL.bin
	C:/"Program Files"/Vim/vim91/xxd  -c 4 -ps memL.bin > mem.mem

idsim: assemble
	$(OBJCOPY) -O binary -j .text $(PROGNAME).elf imem.bin
	$(OBJCOPY) -O binary -j .data $(PROGNAME).elf dmem.bin
	$(OBJCOPY) -O ihex -j .text $(PROGNAME).elf imem.ihex
	$(OBJCOPY) -O ihex -j .data $(PROGNAME).elf dmem.ihex
	-$(OBJDUMP) -s -j .data $(PROGNAME).elf
	-$(OBJDUMP) -d -S -j .text $(PROGNAME).elf

	C:/"Program Files"/Vim/vim91/xxd -e imem.bin >  imemL.mem
	C:/"Program Files"/Vim/vim91/xxd -r imemL.mem  > imemL.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps imemL.bin >  imem.mem
	C:/"Program Files"/Vim/vim91/xxd -e dmem.bin  > dmemL.mem
	C:/"Program Files"/Vim/vim91/xxd -r dmemL.mem  > dmemL.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps dmemL.bin  > dmem.mem


#fullsim: assemble
#	$(OBJCOPY) -O binary -j .text $(PROGNAME).elf mem0.bin
#	$(OBJCOPY) -O binary --gap-fill 0x00 -j .data -j .rodata -j .bss $(PROGNAME).elf mem3.bin
#	-$(OBJDUMP) -s -j .data $(PROGNAME).elf
#	-$(OBJDUMP) -d -S -M reg-names=numeric -j .text $(PROGNAME).elf


# MIPS YAMIN LI 
#fullsim: assemble
#	$(OBJCOPY) -O binary -j .init_text $(PROGNAME).elf mem0.bin
#	$(OBJCOPY) -O binary -j .pt_data  $(PROGNAME).elf mem1.bin
#	$(OBJCOPY) -O binary -j .text     $(PROGNAME).elf mem2.bin
#	$(OBJCOPY) -O binary --gap-fill 0x00 -j .data -j .rodata -j .bss -j .early_stack $(PROGNAME).elf mem3.bin
#	-$(OBJDUMP) -s -j .pt_data $(PROGNAME).elf
#	-$(OBJDUMP) -d -S -M reg-names=numeric -j .init_text $(PROGNAME).elf
#	-$(OBJDUMP) -d -S -M reg-names=numeric -j .text      $(PROGNAME).elf
#
#	C:/"Program Files"/Vim/vim91/xxd -e mem0.bin > memL0.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL0.mem > memL0.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL0.bin > mem0.mem
#
#	C:/"Program Files"/Vim/vim91/xxd -e mem1.bin > memL1.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL1.mem > memL1.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL1.bin > mem1.mem
#
#	C:/"Program Files"/Vim/vim91/xxd -e mem2.bin > memL2.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL2.mem > memL2.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL2.bin > mem2.mem
#
#	C:/"Program Files"/Vim/vim91/xxd -e mem3.bin > memL3.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL3.mem > memL3.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL3.bin > mem3.mem
# RISCV version 1 working 
#fullsim: assemble
#	$(OBJCOPY) -O binary -j .init_text $(PROGNAME).elf mem0.bin
#	$(OBJCOPY) -O binary -j .pt_data  $(PROGNAME).elf mem1.bin

#	# TEXT NOW LIVES IN ram3 → put it into mem3.bin together with data/rodata/bss.
#	# (Remove the old line that wrote .text to mem2.bin.)
#	# If your BRAM expects a single packed image, this is correct:
#	$(OBJCOPY) -O binary --gap-fill 0x00 \
#	  -j .text -j .data -j .rodata -j .bss -j .early_stack \
#	  $(PROGNAME).elf mem3.bin

#	-$(OBJDUMP) -s -j .pt_data $(PROGNAME).elf
#	-$(OBJDUMP) -d -S -M reg-names=numeric -j .init_text $(PROGNAME).elf
#	-$(OBJDUMP) -d -S -M reg-names=numeric -j .text      $(PROGNAME).elf

	# mem0.mem / mem1.mem as before
#	C:/"Program Files"/Vim/vim91/xxd -e mem0.bin > memL0.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL0.mem > memL0.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL0.bin > mem0.mem

#	C:/"Program Files"/Vim/vim91/xxd -e mem1.bin > memL1.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL1.mem > memL1.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL1.bin > mem1.mem

	# We NO LONGER build mem2.bin; generate an empty mem2.mem (or omit if your loader allows)
#	@cmd /c "echo.> mem2.bin"
#	C:/"Program Files"/Vim/vim91/xxd -e mem2.bin > memL2.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL2.mem > memL2.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL2.bin > mem2.mem

	# mem3.bin now contains .text + data/rodata/bss/early_stack
#	C:/"Program Files"/Vim/vim91/xxd -e mem3.bin > memL3.mem
#	C:/"Program Files"/Vim/vim91/xxd -r memL3.mem > memL3.bin
#	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL3.bin > mem3.mem

fullsim: assemble
	# 1. mem0 (Bootloader)
	$(OBJCOPY) -O binary -j .init_text $(PROGNAME).elf mem0.bin
	
	# 2. mem1 (Page Tables)
	$(OBJCOPY) -O binary -j .pt_data  $(PROGNAME).elf mem1.bin

	# 3. mem2 (Data/Stack -> PA 0x20000000)
	# We include early_stack/bss to ensure the file size is correct if initialized
	$(OBJCOPY) -O binary --gap-fill 0x00 \
		-j .data -j .rodata -j .bss -j .early_stack \
		$(PROGNAME).elf mem2.bin

	# 4. mem3 (Text -> PA 0x20002000)
	$(OBJCOPY) -O binary -j .text $(PROGNAME).elf mem3.bin

	# --- Generate .mem files using xxd ---
	-$(OBJDUMP) -s -j .pt_data $(PROGNAME).elf
	-$(OBJDUMP) -d -S -M numeric -j .init_text $(PROGNAME).elf
	-$(OBJDUMP) -d -S -M numeric -j .text      $(PROGNAME).elf

	# Convert mem0
	C:/"Program Files"/Vim/vim91/xxd -e mem0.bin > memL0.mem
	C:/"Program Files"/Vim/vim91/xxd -r memL0.mem > memL0.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL0.bin > mem0.mem

	# Convert mem1
	C:/"Program Files"/Vim/vim91/xxd -e mem1.bin > memL1.mem
	C:/"Program Files"/Vim/vim91/xxd -r memL1.mem > memL1.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL1.bin > mem1.mem

	# Convert mem2 (Data)
	C:/"Program Files"/Vim/vim91/xxd -e mem2.bin > memL2.mem
	C:/"Program Files"/Vim/vim91/xxd -r memL2.mem > memL2.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL2.bin > mem2.mem

	# Convert mem3 (Text)
	C:/"Program Files"/Vim/vim91/xxd -e mem3.bin > memL3.mem
	C:/"Program Files"/Vim/vim91/xxd -r memL3.mem > memL3.bin
	C:/"Program Files"/Vim/vim91/xxd -c 4 -ps memL3.bin > mem3.mem