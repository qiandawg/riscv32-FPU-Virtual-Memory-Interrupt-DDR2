# DDR2 Smoke Test

Minimal first-transaction test for the hybrid BRAM+DDR2 memory wrapper.

## What it does

1. `startup_ddr2.S` sets up the same Sv32 page tables as
   `makesystem/startup.S` and adds one extra leaf entry:
   `VA 0x0000_4000 -> PA 0x8000_0000` (W|R|V). This opens a 4 KiB
   window into the DDR2 address range (`a[31]==1`) through the TLB.
2. `RISCV_DDR2_Smoke.S` writes `0xCAFEBABE` to word 0 of that page,
   reads it back, and reports the result on the on-board LEDs.

## Build

```
cd C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke
make clean
make full_tlb_mem_ddr2
```

This produces `mem0.mem`, `mem1.mem`, `mem2.mem`, `mem3.mem`
in the current folder, matching the layout expected by the four BRAM
instances inside `physical_memory_hybrid.v`.

**Do not use `make full_tlb_mem`** for this test. That target (inherited
from `makesystem/RISCVWinparent.mk`) links the shared
`makesystem/startup.S`, which does *not* install the DDR2 page-table
entry. Using it will produce a firmware image that page-faults on the
first DDR2 access and keeps rebooting via `mtvec`.

`full_tlb_mem_ddr2` is defined in the local `Makefile` and differs from
`full_tlb_mem` in exactly one thing: it appends `startup_ddr2.S` (not
`startup.S`) to the source list so the extra `L0[4]` PTE (VA 0x4000 ->
PA 0x8000_0000, W|R|V) makes it into the boot image.

## Load the new boot image

Point the `RAM_FILE*` parameters in
`DDR2_Cursor/RISCVpipelinedRV32IMF_INT_VM_Cache.srcs/sources_1/VM_and_cache/physical_memory_hybrid.v`
at this folder instead of `RISCV_TLB_LEDCount`:

```verilog
parameter RAM_FILE0 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem0.mem";
parameter RAM_FILE1 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem1.mem";
parameter RAM_FILE2 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem2.mem";
parameter RAM_FILE3 = "C:/JHU_Classes/RISC_V/riscv-cpu/Software/Assembly/RISCV_DDR2_Smoke/mem3.mem";
```

Rebuild the bitstream and program the board.

## Expected behavior

* **`LED[15]`** lights up within a few hundred milliseconds of power-on.
  That is `init_calib_complete` from the MIG -- DDR2 is trained and
  ready. If this LED stays dark, the CPU will hang the first time it
  touches the DDR2 window (the wrapper will wait indefinitely for
  `memex_ready`). Debug DDR2 first; see the MIG IP documentation.

* Once the CPU reaches `spin`, the lower byte of the readback shows on
  `LED[8..15]`. After a passing round trip:
  * `LED[0] = 1` (green pass bit)
  * `LED[8..15] = 0xBE` (low byte of `0xCAFEBABE`)

* On a miscompare, `LED[0] = 0` and `LED[8..15]` still holds the low
  byte of whatever came back from DDR2, which is typically enough to
  tell "returned zeros" (DDR2 not answering) from "returned garbage"
  (timing or byte-lane issue).
