SOFTWARE_ROOT = ..
A_SOURCES = RISCV_DDR2_Smoke.S
C_SOURCES =
PROGNAME = RISCV_DDR2_Smoke

include $(SOFTWARE_ROOT)/makesystem/RISCVWinparent.mk

# ---------------------------------------------------------------------------
# full_tlb_mem_ddr2
#
# Same layout as the parent's `full_tlb_mem` target, but links against
# `startup_ddr2.S` (which adds the L0[4] PTE mapping VA 0x4000 -> PA
# 0x8000_0000) instead of the shared `makesystem/startup.S`.
#
# Use this target whenever the firmware needs to touch the DDR2 window
# (a[31]==1) through virtual memory, e.g. the RISCV_DDR2_Smoke test.
# Output artifacts (mem0..mem3.mem, .ihex, .elf) are identical in name
# and location to what `full_tlb_mem` produces.
# ---------------------------------------------------------------------------
.PHONY: full_tlb_mem_ddr2
full_tlb_mem_ddr2: A_SOURCES+=startup_ddr2.S
full_tlb_mem_ddr2: LDFLAGS+=-T $(RV_FULLTLB_LD) -Wl,-e,_start
# Listing startup_ddr2.o explicitly here forces the %.o: %.S pattern rule
# to build it before the linker runs. Target-specific variables like
# `A_SOURCES+=...` propagate into $(OBJECTS) for the link command line,
# but make resolves the prerequisite graph before applying target-specific
# variables, so without this line startup_ddr2.o would be listed on the
# linker command but never actually compiled.
full_tlb_mem_ddr2: startup_ddr2.o genihex fullsim
