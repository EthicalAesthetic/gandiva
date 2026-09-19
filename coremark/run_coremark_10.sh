#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Building CoreMark for simulation (10 iterations)..."
./src/build_coremark.sh 10
echo "Running CoreMark on Gandiva simulation..."
# The testbench ends with $finish either way: fail unless it reported PASS,
# CoreMark validated its results, and no failure was reported.
LOG=src/coremark_sim.log
../sim/tb_gandiva +IMEM=src/coremark.hex | tee "$LOG"
if grep -aqE '\[TB\] (FAIL|TIMEOUT)|Errors detected' "$LOG" \
   || ! grep -aqE '^\[TB\] PASS$' "$LOG" \
   || ! grep -aq 'Correct operation validated' "$LOG"; then
  echo "CoreMark: FAIL"; exit 1
fi
echo "CoreMark: PASS"
