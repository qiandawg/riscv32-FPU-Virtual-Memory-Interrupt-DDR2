SOFTWARE_ROOT = ..
A_SOURCES = RISCV_DDR2_Smoke_v2.S
C_SOURCES =
PROGNAME = RISCV_DDR2_Smoke_v2

include $(SOFTWARE_ROOT)/makesystem/RISCVWinparent.mk

# ---------------------------------------------------------------------------
# full_tlb_mem_ddr2_v2
#
# Builds the v2 smoke test against:
#   - startup_ddr2_v2.S       (v2 page-table layout + DDR2 .text copier)
#   - full_tlb_mem_ddr2_v2.ld (links .text to VMA 0x80000000, LMA in BRAM)
#
# Output artifacts (mem0..mem3.mem) are produced by the parent fullsim
# rule. After building, point physical_memory_hybrid.v's RAM_FILE0..3
# parameters at this folder and rebuild the bitstream.
#
# v1 targets (full_tlb_mem_ddr2 in RISCV_DDR2_Smoke/Makefile) are not
# affected by this file.
# ---------------------------------------------------------------------------
RV_FULLTLB_DDR2_V2_LD := $(SOFTWARE_ROOT)/makesystem/full_tlb_mem_ddr2_v2.ld

.PHONY: full_tlb_mem_ddr2_v2
full_tlb_mem_ddr2_v2: A_SOURCES+=startup_ddr2_v2.S
full_tlb_mem_ddr2_v2: LDFLAGS+=-T $(RV_FULLTLB_DDR2_V2_LD) -Wl,-e,_start
# Listing startup_ddr2_v2.o explicitly forces the build before link.
full_tlb_mem_ddr2_v2: startup_ddr2_v2.o genihex fullsim

# Build rule for the v2 startup, which lives in makesystem/ rather than
# the local source folder. Mirrors the parent's startup.o rule.
startup_ddr2_v2.o:
	$(CC) $(CCFLAGS) -c $(SOFTWARE_ROOT)/makesystem/startup_ddr2_v2.S -o startup_ddr2_v2.o
