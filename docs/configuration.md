# Configuration Reference

Gandiva is configured at build time. The most important switch is the `SECURE`
configuration; individual features can be included or omitted to trade area for
capability.

## Configurations

| Configuration | Privilege | PMP / Smepmp | Register file | Use case |
|---------------|-----------|------------|---------------|----------|
| **Default** | Machine only | — | plain | smallest footprint |
| **`SECURE`** | Machine + User (+ user-trap delegation) | 8-region PMP + Smepmp | Standard (ECC module not yet integrated) | isolation |

Enable the secure configuration with the `SECURE` RTL parameter, or at compile
time with `-DGANDIVA_SECURE`.

## Always present

- 5-stage in-order pipeline (IF/ID/EX/MEM/WB) with forwarding + load-use interlock
- RV32IMAC + full `B` (Zba/Zbb/Zbc/Zbs)
- gshare + BTB + RAS branch predictor
- hardware misaligned load/store
- machine-mode traps, timers, and interrupts
- hardware debug triggers (`mcontrol6`)
- RISC-V External Debug (JTAG DTM + Debug Module)
- native memory interface

## Optional / configurable

| Feature | How | Notes |
|---------|-----|-------|
| User mode + user-trap delegation | `SECURE` | M/U privilege; delegation follows the withdrawn `N` draft (never ratified) |
| PMP + Smepmp | `SECURE` | 8 regions, TOR/NA4/NAPOT, `mseccfg` |
| Register-file SECDED ECC | not yet integrated | standalone module, unit-tested with `build.sh ecc` |
| AXI4-Lite bus | instantiate `gandiva_axi_lite` | optional; default SoC uses the native interface |
| FreeRTOS | `rtos/` | preemptive RTOS port + demo |

## Build-driver targets

| Target | Meaning |
|--------|---------|
| `sim` | compile + smoke (default) |
| `cosim` | + golden-model co-simulation |
| `rvfi` | RVFI self-check |
| `debug` | JTAG / Debug-Module self-check |
| `trigger` | hardware breakpoint / watchpoint self-check |
| `axi` | AXI4-Lite master BFM test |
| `priv` | `SECURE`: M/U privilege, user-trap delegation + PMP tests |
| `rtos` | FreeRTOS preemptive multitasking demo |
| `clean` | remove build artifacts |

See [Getting Started](getting-started.md) to run them.
