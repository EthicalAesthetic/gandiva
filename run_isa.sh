#!/usr/bin/env bash
# run_isa.sh -- build and run the OFFICIAL riscv-tests ISA suites on Gandiva.
#
# The riscv-tests sources are vendored in third_party/riscv-tests (BSD license,
# see its LICENSE; isa/ sources from riscv-tests commit 34e6b6d1e793, only the
# suites run here plus the rv64 files they include and the scalar macros).
# env/ holds the "p" environment adapted to Gandiva (result
# written to the tohost register at 0x2000_0000; PASS = the test writes 1).
# Each test runs on two configurations:
#
#   default  the default core (SECURE=0, M-mode only) in gandiva_soc, through
#            tb/tb_gandiva.sv. gandiva_soc is Harvard: code at 0x0 (IMEM),
#            data at 0x8000_0000 (DRAM), so tests are linked with env/link.ld
#            and loaded as +IMEM / +DMEM images. The tests listed in UNIFIED
#            below need one unified code+data memory: they are linked at 0x0
#            (env/link_unified.ld) and run with the testbench's +IMEM_RW option.
#   secure   the SECURE=1 core (M + U modes, 8-region PMP, Smepmp) through
#            tb/tb_gandiva_priv.sv, whose low memory is one unified RAM; all
#            tests are linked with env/link_unified.ld. In this configuration
#            the user-level tests (rv32u*) really run in U-mode, as the "p"
#            environment enters them with mstatus.MPP = U.
#
#   ./run_isa.sh                         all claimed suites, both configurations
#   ./run_isa.sh rv32ui rv32um           selected suites
#   CONFIGS=default ./run_isa.sh         one configuration
#
# The test list of each suite is taken from its official Makefrag. Tests that
# cannot run in a configuration are listed as SKIP with the reason. A negative
# control (a copy of rv32ui/add with one expected value corrupted) must FAIL in
# each configuration, which proves a broken test cannot pass silently.
# Exit status: 0 only if every non-skipped test passed and every negative
# control was detected.
set -uo pipefail
cd "$(dirname "$0")"

find_gcc() {
  local pfx
  for pfx in "${RISCV_TC:+$RISCV_TC/}riscv-none-elf" riscv-none-elf riscv64-unknown-elf riscv32-unknown-elf; do
    if command -v "$pfx-gcc" > /dev/null 2>&1; then echo "$pfx"; return 0; fi
  done
  return 1
}
TCP=$(find_gcc) || { echo "ERROR: no RISC-V GCC found (set RISCV_TC)"; exit 1; }
GCC="${GCC:-$TCP-gcc}"
OBJCOPY="${OBJCOPY:-$TCP-objcopy}"
VERILATOR="${VERILATOR:-verilator --binary --timing -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN -j 4}"
RT=third_party/riscv-tests
ENV=$RT/env
B=build/isa
MAXCYC="${MAXCYC:-500000}"
SUITES="${*:-rv32ui rv32um rv32ua rv32uc rv32uzba rv32uzbb rv32uzbc rv32uzbs rv32mi}"
CONFIGS="${CONFIGS:-default secure}"

# Tests that cannot run in a configuration, with the reason. Never silently
# dropped: each one is printed as SKIP and counted.
declare -A SKIP=(
  [default:rv32mi/pmpaddr]="needs PMP; the default (SECURE=0) core has none (runs in the secure configuration)"
)

# default configuration: tests that write their own code region or execute
# from their data region (gandiva_soc cannot store to IMEM or fetch from DRAM).
declare -A UNIFIED=(
  [rv32ui/fence_i]="copies instructions into .data and executes them"
  [rv32uc/rvc]="test 6 stores to a data word placed in .text"
)

# -march per suite, as in the official riscv-tests Makefile (C only for rv32uc)
march() {
  case "$1" in
    rv32uc)   echo rv32imac_zicsr_zifencei ;;
    rv32uzba) echo rv32ima_zicsr_zifencei_zba ;;
    rv32uzbb) echo rv32ima_zicsr_zifencei_zbb ;;
    rv32uzbc) echo rv32ima_zicsr_zifencei_zbc ;;
    rv32uzbs) echo rv32ima_zicsr_zifencei_zbs ;;
    *)        echo rv32ima_zicsr_zifencei ;;
  esac
}

# official test list from the suite's Makefrag (<suite>_sc_tests = ...)
tests_of() {
  tr -d '\r' < "$RT/isa/$1/Makefrag" | sed -n "/^$1_sc_tests *=/,/^\s*\$/p" \
    | sed -e "s/^$1_sc_tests *=//" -e 's/\\//g' | tr -s ' \t' '\n\n' | sed '/^$/d'
}

C=rtl/common R=rtl
CELLS=( "$C/gandiva_pkg.sv" "$C/gandiva_alu.sv" "$C/gandiva_regfile.sv"
        "$C/gandiva_muldiv.sv" "$C/gandiva_csr.sv" "$C/gandiva_rvc.sv"
        "$C/gandiva_immgen.sv" "$C/gandiva_branch.sv" "$C/gandiva_decode.sv"
        "$C/gandiva_pmp.sv" "$R/gandiva_trigger.sv" "$R/gandiva_core.sv" )
mkdir -p "$B" sim/isa

# build_sim <config> -> sim/isa/tb_<config>
build_sim() {
  local cfg="$1" top=()
  case "$cfg" in
    default) top=("$R/gandiva_debug.sv" "$R/gandiva_uart.sv" "$R/gandiva_soc.sv" tb/tb_gandiva.sv) ;;
    secure)  top=(tb/tb_gandiva_priv.sv) ;;
  esac
  echo "Building Gandiva ISA-test sim, $cfg configuration (Verilator)..."
  if ! $VERILATOR -I"$C" -I"$R" --Mdir "sim/isa/$cfg" -o "../tb_$cfg" \
       "${CELLS[@]}" "${top[@]}" > "$B/verilator_$cfg.log" 2>&1; then
    tail -20 "$B/verilator_$cfg.log"; echo "ISA sim build failed ($cfg)"; exit 1
  fi
}

# build_one <src.S> <march> <out-base> <split|unified>
#   split:   code -> <out>.imem.hex, data (0x8000_0000) -> <out>.dmem.hex
#   unified: everything at 0x0 -> <out>.imem.hex
build_one() {
  local src="$1" arch="$2" o="$3" mode="$4" ld="$ENV/link.ld"
  [ "$mode" = unified ] && ld="$ENV/link_unified.ld"
  "$GCC" -march="$arch" -mabi=ilp32 -nostdlib -nostartfiles -static -fno-pic \
    -Wl,--no-relax -I "$ENV" -I "$RT/isa/macros/scalar" -I "$(dirname "$src")" \
    -T "$ld" "$src" -o "$o.elf" > "$o.log" 2>&1 || return 1
  rm -f "$o.dmem.hex" "$o.dmem.bin"
  if [ "$mode" = unified ]; then
    "$OBJCOPY" -O binary "$o.elf" "$o.imem.bin" || return 1
  else
    "$OBJCOPY" -O binary -j .text.init -j .text -j .rodata "$o.elf" "$o.imem.bin" || return 1
    "$OBJCOPY" -O binary -j .data -j .tohost "$o.elf" "$o.dmem.bin" || return 1
  fi
  python3 sw/bin2hex.py "$o.imem.bin" "$o.imem.hex" > /dev/null || return 1
  if [ -s "$o.dmem.bin" ]; then
    python3 sw/bin2hex.py "$o.dmem.bin" "$o.dmem.hex" > /dev/null || return 1
  fi
}

# run_one <config> <out-base> [extra plusargs] -> prints the tohost value
# (or "none") and returns 0 on PASS (tohost == 1)
run_one() {
  local cfg="$1" o="$2" dm=() th=""; shift 2
  [ -f "$o.dmem.hex" ] && dm=("+DMEM=$o.dmem.hex")
  if [ "$cfg" = default ]; then
    sim/isa/tb_default +IMEM="$o.imem.hex" "${dm[@]}" +MAXCYC="$MAXCYC" "$@" > "$o.sim.log" 2>&1
    th=$(grep -aoE 'tohost write: 0x[0-9a-f]+' "$o.sim.log" | head -1 | awk '{print $3}')
    echo "${th:-none}"
    grep -aqE '^\[TB\] PASS$' "$o.sim.log" && [ "$th" = "0x00000001" ]
  else
    sim/isa/tb_secure +IMEM="$o.imem.hex" "$@" > "$o.sim.log" 2>&1
    grep -aqE '^RESULT: PASS$' "$o.sim.log" && th=1
    [ -z "$th" ] && th=$(grep -aoE 'RESULT: FAIL code=[0-9]+' "$o.sim.log" | head -1 | sed 's/.*code=//')
    echo "${th:-none}"
    grep -aqE '^RESULT: PASS$' "$o.sim.log"
  fi
}

pass=0; fail=0; skip=0; failed=""; neg_bad=0
for cfg in $CONFIGS; do
  build_sim "$cfg"
  for d in $SUITES; do
    [ -f "$RT/isa/$d/Makefrag" ] || { echo "unknown suite $d"; exit 1; }
    arch=$(march "$d")
    for t in $(tests_of "$d"); do
      id="$d/$t"; tag=$(printf "%-7s %s" "$cfg" "$id")
      if [ -n "${SKIP[$cfg:$id]:-}" ]; then
        printf "  %-30s SKIP  (%s)\n" "$tag" "${SKIP[$cfg:$id]}"; skip=$((skip+1)); continue
      fi
      o="$B/${cfg}_${d}_$t"
      mode=split; extra=(); note=""
      if [ "$cfg" = secure ]; then
        mode=unified
      elif [ -n "${UNIFIED[$id]:-}" ]; then
        mode=unified; extra=(+IMEM_RW); note="  (unified memory, +IMEM_RW: ${UNIFIED[$id]})"
      fi
      if ! build_one "$RT/isa/$d/$t.S" "$arch" "$o" "$mode"; then
        printf "  %-30s FAIL  (build error, see %s.log)\n" "$tag" "$o"
        fail=$((fail+1)); failed="$failed $cfg:$id"; continue
      fi
      if th=$(run_one "$cfg" "$o" "${extra[@]}"); then
        printf "  %-30s PASS%s\n" "$tag" "$note"; pass=$((pass+1))
      else
        printf "  %-30s FAIL  (tohost=%s, see %s.sim.log)\n" "$tag" "$th" "$o"
        fail=$((fail+1)); failed="$failed $cfg:$id"
      fi
    done
  done

  # Negative control: rv32ui/add with the expected result of test 2 corrupted
  # (0+0 expected 1). It must be reported as failing with tohost = (2<<1)|1 = 5.
  neg="$B/neg_add.S"; o="$B/${cfg}_neg_add"
  sed 's/TEST_RR_OP( 2,  add, 0x00000000, 0x00000000, 0x00000000 );/TEST_RR_OP( 2,  add, 0x00000001, 0x00000000, 0x00000000 );/' \
    "$RT/isa/rv64ui/add.S" > "$neg"
  mode=split; [ "$cfg" = secure ] && mode=unified
  if cmp -s "$neg" "$RT/isa/rv64ui/add.S"; then
    echo "  $cfg negative control: could not create the corrupted test"; neg_bad=1
  elif ! build_one "$neg" rv32ima_zicsr_zifencei "$o" "$mode"; then
    echo "  $cfg negative control: build error"; neg_bad=1
  elif th=$(run_one "$cfg" "$o"); then
    echo "  $cfg negative control (corrupted rv32ui/add): NOT detected"; neg_bad=1
  elif [ "$th" = "0x00000005" ] || [ "$th" = "5" ]; then
    echo "  $cfg negative control (corrupted rv32ui/add): detected, tohost=$th as expected"
  else
    echo "  $cfg negative control (corrupted rv32ui/add): unexpected tohost=$th"; neg_bad=1
  fi
done

echo "==== $pass passed, $fail failed, $skip skipped of $((pass+fail+skip)) ===="
[ -n "$failed" ] && echo "FAILED:$failed"
[ "$fail" -eq 0 ] && [ "$neg_bad" -eq 0 ] || exit 1
exit 0
