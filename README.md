<div align="center">

# Gandiva RISC-V Processor Core

![alt text](gandiva-banner.png)

**A 5-stage, in-order RV32IMACB RISC-V processor core**


<p align="center">
  <img src="https://img.shields.io/badge/ISA-RV32IMACB-orange" alt="ISA"/>
  <img src="https://img.shields.io/badge/Extensions-Zicsr-blue" alt="Extensions"/>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow" alt="License: MIT"/></a>
  <a href="https://www.linkedin.com/company/open-risc-v/"><img src="https://img.shields.io/badge/LinkedIn-Follow-0077B5" alt="LinkedIn Follow"/></a>
  <a href="https://or5.org"><img src="https://img.shields.io/badge/Visit-or5.org-purple?logo=google-chrome" alt="Visit or5.org"/></a>
  
</p>
</div>

---
## Overview

**Gandiva** is a high-efficiency, synthesizable 32-bit RISC-V processor core implementing the **RV32IMAC** instruction set architecture with the ratified **`B`** bit-manipulation extension (`Zba`, `Zbb`, `Zbs`), **`Zbc`** carry-less multiply, and **`Zicsr`** (`RV32IMACB_Zicsr_Zbc`). Engineered as an in-order 5-stage pipeline, Gandiva balances high performance with low area, targeting embedded control planes, real-time control, IoT edge devices, and FPGA soft-core deployments.

---

## Key Features

- **5-Stage Pipeline**: Single-issue `IF → ID → EX → MEM → WB` with full operand forwarding.
- **RV32IMACB_Zicsr_Zbc**: `I`, `M`, `A`, `C`, `Zicsr`, the ratified `B` extension (`Zba`, `Zbb`, `Zbs`), and `Zbc` carry-less multiply.
- **Dynamic Branch Prediction**: 256-entry gshare predictor, 64-entry BTB, and hardware RAS.
- **Privilege & Security** (`SECURE` build): Machine and User modes, user-level trap delegation (from the withdrawn `N` extension draft, never ratified; `misa.N` is not set), and 8-region PMP with Smepmp (`mseccfg`: machine mode lockdown `MML`, whitelist `MMWP`, rule-lock bypass `RLB`). PMP checks instruction fetches, loads, stores and atomics.
- **Misaligned Access**: hardware unaligned load/store support. A SECDED ECC register file module (`rtl/common/gandiva_regfile_ecc.sv`) is included and unit-tested (`./build.sh ecc`) but is **not yet integrated** into the core.
- **Debug & Triggers**: RISC-V external debug over JTAG (Debug Module and JTAG DTM report debug spec 0.13 (`dmstatus.version` = 2)), plus `Sdtrig` hardware breakpoints/watchpoints using the `mcontrol6` trigger format (defined in Debug spec 1.0).
- **Interconnect & RTOS**: Native memory bus, drop-in AXI4-Lite master bridge, and turnkey FreeRTOS port.

> For comprehensive microarchitectural descriptions, instruction encodings, CSR listings, and circuit details, please see the **[documentation](docs/index.md)**.

---

## Microarchitecture

```
             +-------------------------------------------------------------+
             |                 BRANCH PREDICTION UNIT                      |
             |       [ 64-Entry BTB ]  [ 256-Entry gshare ]  [ RAS ]       |
             +------------------------------+------------------------------+
                                            | Next PC / Predict Target
                                            v
     IF STAGE               ID STAGE                EX STAGE             MEM STAGE          WB STAGE
+------------------+   +------------------+   +------------------+   +---------------+   +--------------+
|                  |   |                  |   |   ALU / B-Manip  |   |               |   |              |
| Instruction      |-->| Decode & RVC Exp |-->|   MULDIV Unit    |-->| Data Memory   |-->| Register     |
| Fetch            |   | RegFile Read     |   |   Traps & PMP    |   | Access & AMO  |   | Writeback    |
|                  |   |                  |   |   Branch Resolve |   | Misaligned FSM|   | Commit       |
+------------------+   +------------------+   +------------------+   +---------------+   +--------------+
         ^                                              |                   |                   |
         |                   Pipeline Redirect / Flush  |                   |                   |
         +----------------------------------------------+                   |                   |
         |                                                                  |                   |
         |                                Operand Bypassing & Forwarding   |                   |
         +==================================================================+===================+
```

### Build-Time Configurations

| Feature | Default Configuration | `SECURE` Configuration (`gandiva_core #(.SECURE(1))`) |
| :--- | :--- | :--- |
| **Privilege Modes** | Machine (`M`) | Machine (`M`) + User (`U`), with user-level trap delegation (withdrawn `N` draft) |
| **PMP Unit** | None (Flat physical memory) | 8-Region PMP + Smepmp (`mseccfg`: `MML`, `MMWP`, `RLB`) |
| **Register File** | Standard 32x32-bit Dual-Read Single-Write | Standard (SECDED ECC module not yet integrated) |
| **Target Application** | Microcontrollers, high-speed soft cores | Secure enclaves, isolated tasks, safety-critical systems |

---

## Performance & Benchmarks

Gandiva has been evaluated across industry-standard embedded benchmarks in bare-metal execution on physical FPGA silicon.

### CoreMark

> **Note:** the reference SoC closes timing at 25 MHz (see [FPGA Resource Utilization](#fpga-resource-utilization)), so the 50 MHz label below is being re-checked. Per-MHz results do not depend on the clock. The run below is about 8.3 s at 50 MHz, under the 10 s minimum in the CoreMark run rules; it will be re-run with more iterations.

| Metric | FPGA (Arty A7 @ 50 MHz) |
| :--- | :--- |
| Iterations | 1,000 |
| Total cycles | 414,036,000 |
| Cycles / iteration | 414,036 |
| CoreMark / MHz | **2.41** |

### Dhrystone v2.1

| Metric | FPGA (Arty A7 @ 25 MHz) |
| :--- | :--- |
| Iterations | 2,000,000 |
| Microseconds / run | 14 |
| Dhrystones / sec | 70,422 |
| DMIPS | 40.080 |
| DMIPS / MHz | **1.602** |

### Embench IoT

| Metric | FPGA (Arty A7 @ 25 MHz) |
| :--- | :--- |
| Workloads | 19 |
| Geometric mean cycles | 4,169,664 |
| Geomean / MHz | **0.97** |

---

## FPGA Resource Utilization

Synthesis and implementation were performed using **AMD Vivado 2023.2** targeting the **Xilinx Artix-7 100T** FPGA (`xc7a100tcsg324-1`) on the Digilent Arty A7 evaluation board.

### Implementation Metrics (Post-Route)

| Component / Target | Slice LUTs | Logic LUTs | LUTRAM | Registers (FF) | DSP48E1 | Block RAM (RAMB36) | Timing Slack (WNS) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Gandiva Core (OOC)** | **6,743** (10.6%) | 6,599 | 144 | **2,442** (1.9%) | **12** (5.0%) | 0 (0.0%) | Evaluated @ 50 MHz |
| **Gandiva Reference SoC** | **6,840** (10.8%) | 6,696 | 144 | **2,488** (2.0%) | **12** (5.0%) | **16** (11.8%) | **+5.119 ns** @ 25 MHz |

- **SoC Subsystem Includes**: Gandiva Core, 64 KB dual-port BRAM memory subsystem, Memory-Mapped CLINT Timer, 115200 Baud UART, and GPIO peripheral controllers.
- **Achievable Frequency**: Timing passes comfortably at 25 MHz with `+5.12 ns` positive slack on Artix-7 speed grade -1 (the +5.119 ns slack on the 40 ns constraint implies an $F_{\text{max}}$ of about 28.7 MHz).
- **Target Board Supported**: Digilent Arty A7-100T (Artix-7).

---

## Repository Structure

```
gandiva/
├── rtl/                        # Core & SoC SystemVerilog source files
│   ├── gandiva_core.sv         # 5-stage pipeline top, forwarding, branch predictor, DM
│   ├── gandiva_soc.sv          # Minimal SoC top (Core, IMEM/DMEM, CLINT, UART)
│   ├── gandiva_axi_lite.sv     # AXI4-Lite Master Bridge
│   ├── gandiva_uart.sv         # 8N1 UART peripheral controller
│   ├── gandiva_trigger.sv      # Sdtrig hardware breakpoint & watchpoint engine
│   ├── gandiva_debug.sv        # RISC-V External Debug Module and DTM
│   └── common/                 # Reusable datapath leaf modules
│       ├── gandiva_pkg.sv      # Architectural package (opcodes, CSRs, types)
│       ├── gandiva_alu.sv      # Arithmetic Logic Unit + 'B' bit-manipulation
│       ├── gandiva_muldiv.sv   # Multi-cycle hardware multiplier and divider
│       ├── gandiva_regfile.sv  # 32-entry dual-read single-write register file
│       ├── gandiva_regfile_ecc.sv # SECDED ECC-protected register file
│       ├── gandiva_csr.sv      # Control & Status Register file
│       ├── gandiva_pmp.sv      # 8-region Physical Memory Protection checker
│       ├── gandiva_rvc.sv      # RVC compressed instruction decompressor
│       ├── gandiva_decode.sv   # Instruction decode unit
│       ├── gandiva_immgen.sv   # Immediate value generator
│       └── gandiva_branch.sv   # Branch condition comparator
├── tb/                         # Testbenches (Smoke, RVFI, Debug, AXI, Triggers, Priv)
├── tools/                      # Golden RV32IM ISA model and lock-step co-simulation
├── sw/                         # Firmware sources, CRT0 startup, and memory generators
├── programs/                   # Python hex generators for directed tests
├── sim/                        # Verilator simulation build outputs
├── third_party/riscv-tests/    # Vendored official riscv-tests (BSD) + Gandiva "p" env
├── tests/expected.txt          # Recorded results checked by run_tests.sh
├── coremark/                   # EEMBC CoreMark benchmark harness & run scripts
├── dhrystone/                  # Dhrystone 2.1 benchmark harness & run scripts
├── embench/                    # Official Embench IoT benchmark suite harness
├── fpga/                       # FPGA project scripts and XDC constraints
│   └── arty_a7/                # Digilent Arty A7-100T board project
├── rtos/                       # FreeRTOS port, BSP, and automated preemption test
├── docs/                       # Complete documentation site (MkDocs)
├── build.sh                    # Unified build and test driver
├── run_isa.sh                  # Official riscv-tests ISA suites (default + SECURE core)
└── run_tests.sh                # Runs every test entry and checks it against tests/expected.txt
```

---

## Quick Start & Build

### Prerequisites

- **Simulators**: [Verilator](https://www.veripool.org/verilator/) `v5.0+` for the core/SoC testbenches and the ISA tests, and Icarus Verilog `12+` for `./build.sh axi`, `./build.sh ecc` and `./build.sh rtos`
- **Host Environment**: Python `3.10+`
- **Toolchain**: RISC-V GCC toolchain (e.g. `riscv-none-elf-gcc`, or `riscv64-unknown-elf-gcc` with `rv32imc` multilib support) with newlib or picolibc; set `RISCV_TC` to its `bin` directory if the tools are not named `riscv-none-elf-*`. CI uses Ubuntu's `gcc-riscv64-unknown-elf` + `picolibc-riscv64-unknown-elf` (see `.github/workflows/ci.yml`)
- **FPGA Synthesis** *(optional)*: AMD Vivado `2022.1+` and `openFPGALoader`

### 1. Basic Compilation & Smoke Simulation

Clone the repository and run the self-checking smoke test:

```bash
git clone https://github.com/OR5-LABS/gandiva.git
cd gandiva

# Compile RTL with Verilator and execute the self-checking smoke program
./build.sh sim
```

*Expected output:*
```text
[TB] Loading IMEM from: programs/build/smoke.hex
[TB] Reset released
[TB] tohost write: 0x00000001 at cycle 299
[TB] PASS
```

### 2. Lock-Step Golden Co-Simulation

Verify the RTL cycle-by-cycle against the independent Python RV32IM ISA reference model:

```bash
./build.sh cosim
```

*Expected output:*
```text
[cosim] MATCH — 142 retires identical. RTL is ISA-correct.
```

### 3. Verification Suite Commands

The unified driver `./build.sh` provides one-line commands for testing individual subsystems:

```bash
./build.sh rvfi      # Check RISC-V Formal Interface invariants on retirement
./build.sh debug     # Test JTAG Debug Module (halt, resume, GPR/CSR access, stepping)
./build.sh trigger   # Verify Sdtrig hardware breakpoints and watchpoints
./build.sh axi       # Test AXI4-Lite master bridge word/byte/halfword transactions (OKAY responses)
./build.sh priv      # Run SECURE config tests (M/U privilege, user-trap delegation, PMP, Smepmp MML)
./build.sh ecc       # Unit-test the standalone SECDED ECC register file module
./build.sh fpga      # Simulate the FPGA SoC (UART banner + LED blink)
./build.sh rtos      # Build and run preemptive FreeRTOS multitasking test
./build.sh clean     # Clean simulation artifacts and build directories
./run_isa.sh         # Official riscv-tests ISA suites on the default and SECURE cores
./run_tests.sh       # Run everything above (and CoreMark) against tests/expected.txt
```

Every `build.sh` target, `run_isa.sh`, and the CoreMark/Dhrystone run scripts exit
non-zero unless the testbench reports its PASS verdict (a FAIL, TIMEOUT or MISMATCH
line, or a missing PASS line, fails the script).

### 4. Test Status

Results of `./run_tests.sh` in the reference container (Ubuntu 24.04, Verilator
5.020, Icarus Verilog 12, GCC 13.2 with picolibc). `tests/expected.txt` holds the
recorded exit code and PASS/FAIL line counts of each entry.

| Entry | What it checks | Result |
| :--- | :--- | :--- |
| `build.sh sim` | Self-checking smoke program on the SoC | PASS |
| `build.sh cosim` | Lock-step co-simulation against the golden RV32IM model (142 retires) | PASS |
| `build.sh rvfi` | RVFI invariants on every retirement (142 checked) | PASS |
| `build.sh debug` | JTAG Debug Module: halt, GPR/CSR access, resume, single-step | PASS |
| `build.sh trigger` | Sdtrig execute breakpoint + store watchpoint, with negative controls | PASS |
| `build.sh priv` | SECURE core: 13 directed M/U privilege, PMP, Smepmp MML, PMP-on-AMO and user-trap tests | PASS (13/13) |
| `build.sh axi` | AXI4-Lite master bridge against a slave-memory BFM (Icarus) | PASS |
| `build.sh ecc` | SECDED register file: single-bit correct, double-bit detect (Icarus) | PASS |
| `build.sh fpga` | FPGA SoC simulation: UART banner + LED blink | PASS |
| `build.sh rtos` | FreeRTOS queue/semaphore/preemption transcript + tick-disabled negative control (Icarus) | PASS |
| `run_isa.sh` | Official riscv-tests, default + SECURE cores, with a corrupted-test negative control | PASS (217 passed, 1 skipped) |
| `coremark/run_coremark_10.sh` | CoreMark, 10 iterations, results validated | PASS |

### 5. Official ISA Tests (riscv-tests)

`./run_isa.sh` builds the official [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
(vendored in `third_party/riscv-tests`, BSD license) with a "p" environment adapted
to Gandiva (`third_party/riscv-tests/env`), and runs each test on two configurations:
the default core in `gandiva_soc` (`tb/tb_gandiva.sv`) and the `SECURE` core
(`tb/tb_gandiva_priv.sv`), where the user-level tests run in U-mode. A test passes
when it writes 1 to `tohost`; a copy of `rv32ui/add` with one corrupted expected
value must fail in each configuration.

| Suite | Default core | `SECURE` core |
| :--- | :---: | :---: |
| rv32ui | 42 / 42 | 42 / 42 |
| rv32um | 8 / 8 | 8 / 8 |
| rv32ua | 10 / 10 | 10 / 10 |
| rv32uc | 1 / 1 | 1 / 1 |
| rv32uzba | 3 / 3 | 3 / 3 |
| rv32uzbb | 18 / 18 | 18 / 18 |
| rv32uzbc | 3 / 3 | 3 / 3 |
| rv32uzbs | 8 / 8 | 8 / 8 |
| rv32mi | 15 / 15 (+1 skipped) | 16 / 16 |
| **Total** | **108 passed, 1 skipped** | **109 passed** |

- Skipped: `rv32mi/pmpaddr` on the default core, which has no PMP (it runs and passes on the `SECURE` core).
- `gandiva_soc` is Harvard-style (stores cannot write IMEM, code cannot run from DRAM). `rv32ui/fence_i` (executes instructions it copied into `.data`) and `rv32uc/rvc` (stores to a word inside `.text`) therefore run on the default core with the testbench's `+IMEM_RW` option, which makes IMEM one unified code+data RAM like the FPGA SoC (`fpga/gandiva_fpga.sv`).

### Known Limitations

- The SECDED ECC register file (`rtl/common/gandiva_regfile_ecc.sv`) is unit-tested but not instantiated in the core.
- The RVC expander (`rtl/common/gandiva_rvc.sv`) also decodes `Zcb` encodings. `Zcb` is not claimed: no `Zcb` tests are run.
- Unprivileged counters `cycle`/`time`/`instret` (`0xC00`-`0xC82`) are not implemented and read as 0 (`Zicntr` is not claimed; `rv32mi/zicntr` only checks that reading them does not trap). Accesses to unimplemented CSRs do not trap.
- `mcycle`/`mcycleh` are read-only (writes are ignored). `minstret`/`minstreth` are writable.
- In `mstatus` only `MPP` is legalized (it holds only implemented modes); other bits that have no function on this core (for example `SPP`, `TVM`, `TSR`, `FS`) are stored as written instead of reading 0.
- `mtvec` accepts `MODE` = 1 (vectored) on write, but traps always jump to the full `mtvec` value; only direct mode (`MODE` = 0) is usable. `mie` stores all written bits.
- Misaligned atomics (`LR`/`SC`/`AMO`) are not trapped; the address is aligned down to a word.
- `fence.i` executes as a no-op: it does not flush instructions already fetched into the pipeline.
- `WFI` is decoded as an illegal instruction.
- `gandiva_soc` data stores cannot write IMEM (see above); use the FPGA SoC or a unified memory for self-modifying code.
- `embench/run_embench.sh` and the Arty A7 scripts are not part of `run_tests.sh` (they need scons + network access, or FPGA hardware).


---

## Running Benchmarks

> If you are on a fresh clone or a new device, you must build the Verilator simulator first by running `./build.sh` from the repository root.

### CoreMark

To compile and run CoreMark in Verilator simulation:

```bash
# Run 10 iterations (quick test)
cd coremark && ./run_coremark_10.sh

# Or run the full benchmark (1000 iterations)
./run_coremark.sh
```

To run on physical hardware (Arty A7-100T FPGA):
```bash
./coremark/run_coremark_arty.sh
```

### Dhrystone 2.1

To compile and run the industry-standard 2,000,000-iteration Dhrystone benchmark in simulation:

```bash
cd dhrystone && ./run_dhrystone.sh
```

To synthesize, program, and monitor on the Arty A7-100T board:
```bash
./dhrystone/run_dhrystone_arty_a7.sh
```

### Embench IoT Suite

To run all 19 IoT workloads through the standard Embench test harness in simulation:

```bash
cd embench && ./run_embench.sh
```

---

## FPGA Synthesis & Bring-Up

Gandiva includes turnkey projects for FPGA deployment.

### Building for Digilent Arty A7-100T

With Vivado sourced in your environment:

```bash
cd fpga/arty_a7
vivado -mode batch -source gandiva_arty_a7.tcl
```

This compiles the complete Gandiva SoC with initialized bootloader firmware, integrates the USB-UART interface, and generates the bitstream.

### Programming the Board

Connect the Arty A7 micro-USB cable and flash using `openFPGALoader`:

```bash
openFPGALoader -b arty_a7_100t gandiva_arty_a7.bit
```

Open a terminal at `115200 8N1` (e.g. `/dev/ttyUSB1`) to observe the boot sequence:
```text
========================================
 Gandiva RV32IMACB Processor SoC
 Core: 5-stage in-order @ 25 MHz
========================================
Booting application...
```

## Documentation

Comprehensive architectural specifications, register maps, and peripheral integration guides are available in [`docs/`](docs) and can be viewed as an interactive site:

```bash
pip install -r docs/requirements.txt
mkdocs serve
# Navigate to http://127.0.0.1:8000 in your browser
```

Key documentation resources:
- [Pipeline Architecture](docs/architecture.md)
- [Instruction Set & Extensions](docs/isa.md)
- [Branch Prediction Microarchitecture](docs/branch-prediction.md)
- [Privilege, PMP & Security](docs/privilege-and-security.md)
- [Memory Map & CSR Specifications](docs/memory-map.md)
- [Debug Module & Sdtrig Engine](docs/debug.md)
- [Bus & AXI4-Lite Integration](docs/bus-integration.md)

---

## License

Gandiva is licensed under the [MIT License](LICENSE).

