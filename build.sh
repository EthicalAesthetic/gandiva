#!/usr/bin/env bash
# ============================================================================
# Gandiva build & test driver (Verilator; Icarus Verilog for axi/ecc/rtos).
#
#   ./build.sh [sim|cosim|rvfi|debug|trigger|priv|axi|ecc|rtos|fpga|clean]
#
# Gandiva is the clean, golden-co-simulated 5-stage in-order RV32IMAC(+B) core.
# The datapath leaf cells (ALU / muldiv / regfile / CSR / RVC / immgen / branch
# / decoder / PMP) live in rtl/common; the core, SoC, UART, AXI4-Lite wrapper,
# the hardware-trigger unit and the RISC-V Debug Module live in rtl/.
#
# Every target exits non-zero unless its testbench reports its PASS verdict
# (the testbenches end with $finish either way, so the simulator exit code
# alone cannot be trusted). A FAIL / TIMEOUT / MISMATCH line also fails it.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
VERILATOR="${VERILATOR:-verilator --binary --timing -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN -j 4}"
IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
ACTION="${1:-sim}"

R=rtl
C=rtl/common
DBG=rtl/gandiva_debug.sv

# Shared datapath leaf cells, in elaboration order.
CELLS=( \
  "$C/gandiva_pkg.sv" "$C/gandiva_alu.sv" "$C/gandiva_regfile.sv" \
  "$C/gandiva_muldiv.sv" "$C/gandiva_csr.sv" "$C/gandiva_rvc.sv" \
  "$C/gandiva_immgen.sv" "$C/gandiva_branch.sv" "$C/gandiva_decode.sv" \
  "$C/gandiva_pmp.sv" )

# Core RTL used by the SoC-level testbenches (smoke / rvfi / debug / trigger).
CORE=( "$R/gandiva_trigger.sv" "$R/gandiva_core.sv" )
SOC=(  "$DBG" "$R/gandiva_uart.sv" "$R/gandiva_soc.sv" )

# check_run <name> <PASS regex> <command...>
# Runs the command (output shown and saved in sim/<name>.log) and fails unless
# it exits 0, prints a line matching the PASS regex, and prints no
# FAIL / TIMEOUT / MISMATCH / %Error line.
check_run() {
  local name="$1" pat="$2" rc=0; shift 2
  "$@" 2>&1 | tee "sim/$name.log" || rc=$?     # pipefail: the command's status
  if [[ $rc -ne 0 ]]; then echo "$name: FAILED (exit $rc)"; exit 1; fi
  if grep -aqE '\bFAIL|TIMEOUT|MISMATCH|%Error' "sim/$name.log"; then
    echo "$name: FAILED (failure reported)"; exit 1
  fi
  if ! grep -aqE "$pat" "sim/$name.log"; then
    echo "$name: FAILED (no PASS verdict)"; exit 1
  fi
}

# RISC-V GCC for the assembly tests (priv). RISCV_TC=<bin dir> selects one.
find_gcc() {
  local pfx
  for pfx in "${RISCV_TC:+$RISCV_TC/}riscv-none-elf" riscv-none-elf riscv64-unknown-elf riscv32-unknown-elf; do
    if command -v "$pfx-gcc" > /dev/null 2>&1; then echo "$pfx"; return 0; fi
  done
  echo "ERROR: no RISC-V GCC found (set RISCV_TC)" >&2; return 1
}

if [[ "$ACTION" == "clean" ]]; then
  rm -rf sim programs/build rtos/build build *.vcd
  echo "Cleaned"; exit 0
fi
mkdir -p sim programs/build

if [[ "$ACTION" == "priv" ]]; then
  # Directed M/U + PMP + N user-trap tests on a SECURE=1 core. The priv
  # testbench instantiates gandiva_core #(.SECURE(1)) directly (no SoC).
  echo "Building Gandiva SECURE priv/PMP/N sim..."
  python3 programs/build_priv.py
  python3 programs/build_ntrap.py
  # Assembly tests (Smepmp MML, U-mode CSR/MRET privilege, PMP on AMOs)
  TCP=$(find_gcc)
  for t in mml upriv pmp_amo; do
    "$TCP-gcc" -march=rv32imac_zicsr -mabi=ilp32 -nostdlib -nostartfiles -static \
      -fno-pic -Wl,--no-relax -T sw/link.ld "sw/priv/${t}_test.S" -o "programs/build/asm_$t.elf"
    "$TCP-objcopy" -O binary -j .text "programs/build/asm_$t.elf" "programs/build/asm_$t.bin"
    python3 sw/bin2hex.py "programs/build/asm_$t.bin" "programs/build/asm_$t.hex" > /dev/null
  done
  $VERILATOR -I"$C" -I"$R" --Mdir sim -o tb_gandiva_priv \
    "${CELLS[@]}" "${CORE[@]}" tb/tb_gandiva_priv.sv > sim/priv_build.log 2>&1 \
    || { tail -20 sim/priv_build.log; echo "priv: build FAILED"; exit 1; }
  fail=0
  for t in ustore_fault ustore_ok ecall_u ecall_m ifetch_fault ifetch_ok ucsr_u ucsr_m \
           udeleg nodel mml upriv pmp_amo; do
    hex=""
    [[ -f programs/build/priv_$t.hex  ]] && hex=programs/build/priv_$t.hex
    [[ -f programs/build/ntrap_$t.hex ]] && hex=programs/build/ntrap_$t.hex
    [[ -f programs/build/asm_$t.hex   ]] && hex=programs/build/asm_$t.hex
    r=$(sim/tb_gandiva_priv +IMEM="$hex" 2>&1 | grep RESULT || true)
    printf "  %-16s %s\n" "$t" "${r:-RESULT: FAIL (no verdict)}"
    [[ "$r" == "RESULT: PASS" ]] || fail=1
  done
  [[ $fail -eq 0 ]] && echo "priv: ALL PASS" || { echo "priv: FAILURES"; exit 1; }
  exit 0
fi

if [[ "$ACTION" == "rtos" ]]; then
  # Port + run a REAL preemptive RTOS (FreeRTOS) on Gandiva. Builds the kernel
  # + RISC-V port + Gandiva BSP into an IMEM image, runs it on the SoC sim
  # (CLINT tick + UART console) and asserts the transcript plus a negative
  # control (tick disabled -> demo stalls). See rtos/run_rtos.py, which exits
  # non-zero unless both the positive run and the negative control behave.
  echo "Building Gandiva FreeRTOS demo (positive + negative-control images)..."
  bash rtos/build_rtos.sh
  bash rtos/build_rtos.sh neg
  echo "Running FreeRTOS demo + assertions..."
  IVERILOG="$IVERILOG" VVP="$VVP" python3 rtos/run_rtos.py
  exit $?
fi

if [[ "$ACTION" == "debug" ]]; then
  echo "Building Gandiva debug (JTAG DM) sim..."
  $VERILATOR -I"$C" -I"$R" --Mdir sim -o tb_gandiva_debug \
    "${CELLS[@]}" "${CORE[@]}" "${SOC[@]}" tb/tb_gandiva_debug.sv
  check_run debug '^DEBUG: PASS$' sim/tb_gandiva_debug
  exit 0
fi

if [[ "$ACTION" == "trigger" ]]; then
  # Hardware debug triggers (Sdtrig / mcontrol6): PC-match + store-address
  # watchpoints driven over the JTAG TAP, with negative controls.
  echo "Building Gandiva hardware-trigger (Sdtrig/mcontrol6) sim..."
  $VERILATOR -I"$C" -I"$R" --Mdir sim -o tb_gandiva_trigger \
    "${CELLS[@]}" "${CORE[@]}" "${SOC[@]}" tb/tb_gandiva_trigger.sv
  check_run trigger '^TRIGGER: PASS$' sim/tb_gandiva_trigger
  exit 0
fi

if [[ "$ACTION" == "axi" ]]; then
  # OPTIONAL AXI4-Lite MASTER bridge — standalone leaf cell + slave-mem BFM tb.
  # The default gandiva_soc + compliance path never instantiate it (unchanged).
  # Runs under Icarus: the task-driven testbench times out under Verilator 5.020.
  echo "Building Gandiva AXI4-Lite MASTER bridge sim (Icarus)..."
  "$IVERILOG" -g2012 -I"$C" -I"$R" -o sim/tb_gandiva_axi.vvp \
    "$C/gandiva_pkg.sv" "$R/gandiva_axi_lite.sv" tb/tb_gandiva_axi.sv
  check_run axi '^AXI: PASS$' "$VVP" -n sim/tb_gandiva_axi.vvp
  exit 0
fi

if [[ "$ACTION" == "ecc" ]]; then
  # SECDED-protected register file leaf cell: single-bit correct, double detect.
  # Runs under Icarus: Verilator 5.020 aborts with an internal error on this cell.
  echo "Building Gandiva regfile ECC (SECDED) unit sim (Icarus)..."
  "$IVERILOG" -g2012 -I"$C" -o sim/tb_regfile_ecc.vvp \
    "$C/gandiva_pkg.sv" "$C/gandiva_regfile_ecc.sv" tb/tb_regfile_ecc.sv
  check_run ecc '^ECC: PASS$' "$VVP" -n sim/tb_regfile_ecc.vvp
  exit 0
fi

if [[ "$ACTION" == "fpga" ]]; then
  echo "Building FPGA SoC sim (UART banner + LED blink)..."
  bash sw/build_fpga_hello.sh
  $VERILATOR -DSIMULATION -I"$C" -I"$R" --Mdir sim -o tb_gandiva_fpga \
    "${CELLS[@]}" "${CORE[@]}" "$R/gandiva_uart.sv" \
    fpga/gandiva_fpga.sv fpga/tb_gandiva_fpga.sv
  check_run fpga '^FPGA: PASS$' sim/tb_gandiva_fpga
  exit 0
fi

# ---- default: smoke (+ optional cosim / rvfi) ------------------------------
python3 programs/build_smoke.py
echo "Compiling..."
$VERILATOR -I"$C" -I"$R" --Mdir sim -o tb_gandiva \
  "${CELLS[@]}" "${CORE[@]}" "${SOC[@]}" tb/tb_gandiva.sv
echo "Running smoke..."
check_run smoke '^\[TB\] PASS$' sim/tb_gandiva +IMEM=programs/build/smoke.hex

if [[ "$ACTION" == "cosim" ]]; then
  echo "Co-simulating against golden model..."
  # tools/cosim.py exits non-zero on any mismatch or an empty trace
  check_run cosim '^\[cosim\] MATCH' env VVP="" VERILATOR="$VERILATOR" python3 tools/cosim.py \
      --hex programs/build/smoke.hex --sim sim/tb_gandiva
fi

if [[ "$ACTION" == "rvfi" ]]; then
  echo "Building RVFI (riscv-formal interface) self-check..."
  $VERILATOR -DRISCV_FORMAL -I"$C" -I"$R" --Mdir sim -o tb_gandiva_rvfi \
    "${CELLS[@]}" "${CORE[@]}" "${SOC[@]}" tb/tb_gandiva_rvfi.sv
  check_run rvfi '^RVFI: PASS$' sim/tb_gandiva_rvfi +IMEM=programs/build/smoke.hex
fi
exit 0
