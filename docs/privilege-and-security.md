# Privilege & Security

Gandiva runs in **Machine mode** by default. The **`SECURE`** configuration adds
a full privilege split, memory protection, and register-file error correction —
turning the core into a small isolation- and reliability-capable processor.

## Privilege modes (`SECURE`)

- **Machine (M)** — full access; the reset mode and trap-handling mode.
- **User (U)** — reduced privilege for application code; M-only CSR access and
  privileged instructions trap to Machine mode.
- **N (user traps)** — selected exceptions can be *delegated* to User mode via
  `medeleg`, handled through the user trap CSRs (`utvec`/`uepc`/`ucause`/…) and
  returned with `URET`, all without leaving User mode.

`mret` drops to the privilege recorded in `mstatus.MPP`; a U-mode `ecall`
returns to Machine mode with cause 8.

## Physical Memory Protection (PMP)

The `SECURE` core includes an **8-region PMP**:

- **Matching:** TOR (top-of-range), NA4, and NAPOT.
- **Permissions:** read / write / execute, checked on instruction fetch and on
  load/store *after* address generation.
- **Locking:** locked entries apply to Machine mode too.
- **Smepmp (`mseccfg`):** Machine Mode Lockdown (`MML`: the Smepmp 1.0
  permission table, where locked rules are M-mode-only, unlocked rules are
  U-mode-only, and M-mode may not execute from memory that matches no rule;
  new executable M-mode rules cannot be added while `RLB` is 0), Machine-mode
  whitelisting (`MMWP`) and rule-lock bypass (`RLB`, which cannot be set while
  any rule is locked). Tested by `sw/priv/mml_test.S` (`build.sh priv`).
- **Atomics:** `LR.W` is checked as a load, `SC.W` and `AMO*.W` as stores.
- **User-mode CSR access:** a CSR above User level (address bits `[9:8]` != 00)
  or `MRET` executed in U-mode raises an illegal-instruction exception.

A U-mode access that violates a PMP region raises a precise access fault
(instruction = cause 1, load = cause 5, store/AMO = cause 7) with the faulting
address in `mtval`; the Machine handler can inspect and recover.

## Register-file ECC (SECDED)

A **SECDED** (single-error-correct, double-error-detect) register file module,
`rtl/common/gandiva_regfile_ecc.sv`, stores each register with ECC check bits,
corrects single-bit errors on read and detects double-bit errors. It is
unit-tested on its own (`build.sh ecc`) but is **not yet integrated** into the
Gandiva core: every configuration, including `SECURE`, currently uses the
standard register file.

## What the tests prove

The `build.sh priv` target runs directed tests that demonstrate, each with a
load-bearing negative control:

- entering User mode and returning via `ecall` (correct cause);
- a U-mode M-CSR access trapping as illegal;
- a PMP store violation and an instruction-fetch violation faulting precisely,
  then recovering;
- an `N`-delegated user trap vectoring to `utvec` and returning with `URET`.

See [Debug](debug.md) for the hardware trigger (breakpoint/watchpoint) support.
