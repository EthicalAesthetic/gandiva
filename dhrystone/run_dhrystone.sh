#!/usr/bin/env bash
# run_dhrystone.sh — build Dhrystone and run it on Gandiva simulation.
# Usage: ./run_dhrystone.sh [NUMBER_OF_RUNS]
set -euo pipefail
cd "$(dirname "$0")"

RUNS="${1:-2000000}"

echo "Building Dhrystone for simulation (${RUNS} runs)..."
./src/build_dhrystone.sh "${RUNS}"

echo "Running Dhrystone on Gandiva simulation..."
# The testbench ends with $finish either way: fail unless it reported PASS.
LOG=src/dhrystone_sim.log
../sim/tb_gandiva +IMEM=src/dhrystone.hex | tee "$LOG"
if grep -aqE '\[TB\] (FAIL|TIMEOUT)' "$LOG" || ! grep -aqE '^\[TB\] PASS$' "$LOG"; then
  echo "Dhrystone: FAIL"; exit 1
fi
echo "Dhrystone: PASS"
