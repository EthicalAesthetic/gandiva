#!/usr/bin/env bash
# run_tests.sh -- run every test entry listed in tests/expected.txt and compare
# its exit code and PASS/FAIL verdict-line counts with the recorded baseline.
# The testbenches end with $finish, so exit codes alone could not be trusted in
# the past; counting verdict lines also catches silent failures and silently
# removed tests.
#
# An entry is a script path, optionally with one argument after a colon:
#   build.sh:cosim  ->  bash build.sh cosim
#
#   ./run_tests.sh             check against tests/expected.txt (CI mode)
#   ./run_tests.sh --baseline  re-record tests/expected.txt from this run
#
# Lines of tests/expected.txt ending in '# KNOWN: <reason>' are documented
# known failures (reported as KNOWN when they still match the baseline).
set -u
cd "$(dirname "$0")"
mkdir -p build/test-logs
mode="${1:-check}"

# Entries run by --baseline, in order (build.sh:sim builds sim/tb_gandiva,
# which the CoreMark entry reuses).
ENTRIES=(
  build.sh:sim build.sh:cosim build.sh:rvfi build.sh:debug build.sh:trigger
  build.sh:priv build.sh:axi build.sh:ecc build.sh:fpga build.sh:rtos
  run_isa.sh coremark/run_coremark_10.sh
)

count() {  # $1 = log -> "pass fail"
  local p f
  p=$(grep -aE '\bPASS(ED)?\b' "$1" | wc -l)
  f=$(grep -aE '\bFAIL(ED|URES?)?\b' "$1" | grep -avE 'FAIL=0x' | wc -l)
  echo "$p $f"
}

run_entry() {  # $1 = entry -> sets rc, log
  local e="$1" s a
  s="${e%%:*}"; a=""; [[ "$e" == *:* ]] && a="${e#*:}"
  log="build/test-logs/$(echo "$e" | tr '/:' '__').log"
  if [ -n "$a" ]; then timeout 3600 bash "$s" "$a" > "$log" 2>&1; rc=$?
  else                 timeout 3600 bash "$s" > "$log" 2>&1; rc=$?; fi
}

if [ "$mode" = "--baseline" ]; then
  : > tests/expected.txt.new
  for e in "${ENTRIES[@]}"; do
    run_entry "$e"
    read -r p f < <(count "$log")
    known=$(grep -E "^$e " tests/expected.txt 2>/dev/null | sed -n 's/.*# KNOWN: //p')
    printf '%s %s %s %s%s\n' "$e" "$rc" "$p" "$f" "${known:+ # KNOWN: $known}" | tee -a tests/expected.txt.new
  done
  mv tests/expected.txt.new tests/expected.txt
  exit 0
fi

status=0
while read -r e erc ep ef rest; do
  case "$e" in ''|\#*) continue ;; esac
  run_entry "$e"
  read -r p f < <(count "$log")
  known=$(echo "$rest" | sed -n 's/.*# KNOWN: //p')
  if [ "$rc" = "$erc" ] && [ "$p" = "$ep" ] && [ "$f" = "$ef" ]; then
    if [ -n "$known" ]; then echo "KNOWN   $e  ($known)"; else echo "PASS    $e"; fi
  else
    echo "FAIL    $e  exit=$rc (expected $erc)  PASS lines=$p (expected $ep)  FAIL lines=$f (expected $ef)  log: $log"
    status=1
  fi
done < tests/expected.txt
exit $status
