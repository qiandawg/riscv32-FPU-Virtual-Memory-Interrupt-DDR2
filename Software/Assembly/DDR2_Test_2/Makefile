SOFTWARE_ROOT = ..
A_SOURCES = DDR2_Test_2.S
C_SOURCES =
PROGNAME = DDR2_Test_2

include $(SOFTWARE_ROOT)/makesystem/RISCVWinparent.mk

.PHONY: full_tlb_mem_ddr2_test2
full_tlb_mem_ddr2_test2: A_SOURCES+=startup_ddr2_test2.S
full_tlb_mem_ddr2_test2: LDFLAGS+=-T $(RV_FULLTLB_LD) -Wl,-e,_start
full_tlb_mem_ddr2_test2: startup_ddr2_test2.o genihex fullsim
