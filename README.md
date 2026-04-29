# DDR2 RISC-V Pipelined Processor (RV32IMF)

This repository contains the implementation of a high-performance, pipelined RISC-V processor (RV32IMF) featuring Virtual Memory, Instruction/Data Caches, Interrupt handling, and integration with DDR2 memory on the Digilent NEXYS A7 board.

## Core Features

- **Architecture:** 32-bit RISC-V (RV32IMF) pipelined core.
    - **RV32I:** Base integer instruction set.
    - **M-Extension:** Hardware integer multiplication and division.
    - **F-Extension:** Single-precision Floating Point Unit (FPU).
- **Memory Management:**
    - **Virtual Memory:** Support for Sv32 paging with a Page Table Walker (`ptw_sv32.v`).
    - **TLB:** 8-entry Translation Lookaside Buffer (`tlb_8_entry.v`).
    - **Caches:** Independent Instruction (`i_cache.v`) and Data (`d_cache.v`) caches.
- **Peripherals & Integration:**
    - **DDR2 Interface:** Integrated with the Nexys A7's onboard DDR2 memory.
    - **Interrupts:** Comprehensive interrupt handling and CSR (Control and Status Register) unit.
    - **UART:** Support for software downloading and debugging.
- **Target Hardware:** Digilent NEXYS A7 (Artix-7 FPGA).

## Project Structure

- `DDR2_Cursor_backup/`: Vivado project files and hardware source code.
    - `srcs/sources_1/new/`: Core processor components including memory subsystem, FPU, and CSR unit.
    - `srcs/sources_1/VM_and_cache/`: Implementation of I/D caches and TLB.
- `Software/`: 
    - `Assembly/`: Extensive collection of test programs, bootloaders, and smoke tests (e.g., FPU tests, TLB tests, DDR2 smoke tests).
    - `UART/`: Python tools for hex conversion and serial communication with the FPGA.

## Hardware Components

### Memory Subsystem (`rv_memsubsys.v`)
Orchestrates the interaction between the CPU core, TLB, caches, and physical memory (DDR2/Internal BRAM).

### Floating Point Unit (`fpu_1_iu.v`)
Handles single-precision floating-point arithmetic according to the RISC-V F-extension.

### Page Table Walker (`ptw_sv32.v`)
Implements the hardware state machine for Sv32 page table traversal on TLB misses.

## Getting Started

### Hardware Setup
1. Open the Vivado project located in `DDR2_Cursor_backup/`.
2. Generate Bitstream and program the Nexys A7 FPGA.

### Software Deployment
1. Navigate to `Software/Assembly/` to find test cases or the bootloader.
2. Use the Python scripts in `Software/UART/` to convert and upload instructions/data to the processor via UART.
    - `download-ihex.py`: Main tool for downloading programs to the hardware.

## License
Refer to the `LICENSE` file for licensing details.
