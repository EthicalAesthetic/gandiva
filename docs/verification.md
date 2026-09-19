# Verification

Gandiva is built as a *golden reference*, so verification is central: from quick
self-checking smoke tests to lock-step co-simulation against an independent
golden model and a formal interface.

## Golden co-simulation

`build.sh cosim` runs the smoke program on the RTL **and** on an independent
golden **RV32IM ISA model** (`tools/golden_rv32im.py`), comparing the committed
instruction stream retire-by-retire (PC, instruction, register writes). Any
divergence is reported at the first mismatching instruction.

```
[cosim] MATCH — 142 retires identical. RTL is ISA-correct.
```

## Official ISA tests (riscv-tests)

`run_isa.sh` builds the official riscv-tests suites the core claims (rv32ui,
rv32um, rv32ua, rv32uc, rv32uzba, rv32uzbb, rv32uzbc, rv32uzbs, rv32mi) from
`third_party/riscv-tests` with a Gandiva "p" environment, and runs each test on
the default core (`gandiva_soc`) and on the `SECURE` core, where the user-level
tests run in U-mode. Result: 108 passed and 1 skipped (`rv32mi/pmpaddr`, no PMP)
on the default core, 109 passed on the `SECURE` core. A copy of `rv32ui/add` with
a corrupted expected value must fail in each configuration, so the harness
cannot pass a broken test.

## Self-checking tests

Every testbench is self-checking: it loads a program, runs it, and asserts an
expected result, signalling PASS/FAIL through the `tohost` handshake. The
directed programs (privilege, PMP, triggers, atomics, misaligned, bit-manip)
each pair a positive test with a **load-bearing negative control**, so a check
that silently stops working is caught.

## RVFI (RISC-V Formal Interface)

`build.sh rvfi` exposes an RVFI retirement port and checks the standard formal
invariants over a real run — instruction-order monotonicity, `x0` always zero,
PC continuity, and that the retired instruction matches memory. A corrupted-field
negative control confirms the checker actually fires.

## Debug, trigger, AXI, and SECURE self-checks

- `build.sh debug` — halt / GPR access / resume / single-step over the Debug
  Module.
- `build.sh trigger` — execute breakpoint + load/store watchpoint, with
  near-miss negative controls.
- `build.sh axi` — AXI4-Lite bridge word/sub-word integrity (`OKAY` responses).
- `build.sh priv` — SECURE M/U privilege, user-trap delegation, PMP (including
  atomics) and Smepmp machine-mode-lockdown (`mseccfg.MML`) directed tests.

Every `build.sh` target and `run_isa.sh` exits non-zero unless the testbench
reports its PASS verdict; `run_tests.sh` runs them all and compares exit codes
and PASS/FAIL line counts with `tests/expected.txt`.

## RTOS integration test

`build.sh rtos` boots a real **FreeRTOS** image on the SoC and asserts a
multi-task transcript (queue + semaphore + preemptive timer tick), with a
negative control that disables the tick and confirms preemption is required.

## Performance

CoreMark (`coremark/run_coremark_10.sh`, built for RV32IMC and run on the RTL,
no caches) measures 414,036 cycles per iteration, **2.41 CoreMark/MHz**.
