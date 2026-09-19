# Gandiva

**Gandiva** is a clean, feature-complete **5-stage pipelined RV32IMAC** processor
core with the **`B`** bit-manipulation extension. It is built as a *golden
reference*: every retired instruction is checked, cycle by cycle, against an
independent RV32IM ISA model, so the RTL is known-correct rather than merely
plausible.

It targets embedded and control-plane roles that want a well-verified,
mid-range in-order pipeline with a real branch predictor, standard bus
integration, memory protection, and debug — microcontrollers, real-time
controllers, secure elements, and FPGA soft cores.

## What you get

- **RV32IMAC** base, plus the full **`B`** bit-manipulation set
  (`Zba` / `Zbb` / `Zbc` / `Zbs`), with `Zicsr`.
- A **5-stage in-order pipeline** (IF / ID / EX / MEM / WB) with full forwarding
  and a single load-use interlock.
- A **dynamic branch predictor** — gshare direction predictor + BTB + return
  address stack.
- Optional **M/U privilege** with user-trap delegation and an **8-region PMP**
  (with Smepmp) in the `SECURE` configuration. A SECDED-ECC register file
  module is included and unit-tested but not yet integrated into the core.
- Hardware **debug triggers** (breakpoints / watchpoints).
- Hardware **misaligned** load/store support.
- **RISC-V External Debug** (JTAG DTM + Debug Module).
- An **AXI4-Lite** bus wrapper.
- A ready-to-run **FreeRTOS** port.
- A **verification** flow: the official riscv-tests ISA suites (`run_isa.sh`,
  default and `SECURE` cores), golden-model co-simulation, RVFI, a Debug-Module
  self-check, trigger/AXI self-checks and SECURE privilege tests.
- **2.41 CoreMark/MHz** on RTL (no caches; 414,036 cycles per iteration in
  simulation).

## Where to start

- New here? Read [Getting Started](getting-started.md) to build and run the
  self-checking tests.
- Want the microarchitecture? See [Architecture](architecture.md) and
  [Branch Prediction](branch-prediction.md).
- Integrating it into an SoC? See [Memory Map](memory-map.md),
  [Bus Integration](bus-integration.md), and [Debug](debug.md).

## License

Gandiva is released under the [MIT License](https://opensource.org/licenses/MIT).
