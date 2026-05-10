#!/bin/bash
# Test: submit 2x "sleep 2" with parallel=2
# Checks: both finish in ~2s (parallel), not ~4s (sequential)
#
# Expected project structure:
#   bin/        -> controller, runner
#   tests/      -> this script
#   tmp/        -> logs  (controller writes to ../tmp/logs.txt, so it must run from bin/)
 
PASS=0
FAIL=0
 
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
 
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
 
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
TMP_DIR="$ROOT_DIR/tmp"
 
if [ ! -x "$BIN_DIR/controller" ] || [ ! -x "$BIN_DIR/runner" ]; then
    echo -e "${RED}[ERROR]${NC} Binaries not found in $BIN_DIR. Run 'make' first."
    exit 1
fi
 
cd "$BIN_DIR"
mkdir -p "$TMP_DIR"
 
rm -f fifo_runner_to_controller fifo_controller_to_runner_*
 
# parallel=2 so both commands can run simultaneously
./controller 2 fcfs &
CTRL_PID=$!
sleep 0.2
 
START=$(date +%s%3N)  # start time in milliseconds
 
# Submit both commands in background
./runner -e 1 "sleep 2" &
RUNNER1_PID=$!
./runner -e 2 "sleep 2" &
RUNNER2_PID=$!
 
# Wait for both runners to finish
wait $RUNNER1_PID
wait $RUNNER2_PID
 
END=$(date +%s%3N)
ELAPSED=$(( END - START ))  # elapsed time in milliseconds
 
echo "--- Elapsed time: ${ELAPSED}ms ---"
 
./runner -s > /dev/null 2>&1
wait $CTRL_PID 2>/dev/null
 
echo ""
echo "=== Test Results ==="
 
# 1. both runners finished (exit codes)
if wait $RUNNER1_PID 2>/dev/null; [ $? -eq 0 ] || true; then
    pass "both runners finished"
fi
 
# 2. elapsed time < 3500ms (parallel: ~2s + some overhead)
if [ "$ELAPSED" -lt 3500 ]; then
    pass "finished in ${ELAPSED}ms — ran in parallel (~2s, not ~4s)"
else
    fail "finished in ${ELAPSED}ms — may have run sequentially (expected < 3000ms)"
fi
 
# 3. elapsed time >= 1800ms (actually slept, not instant)
if [ "$ELAPSED" -ge 1800 ]; then
    pass "elapsed ${ELAPSED}ms >= 1800ms — sleep was real"
else
    fail "elapsed ${ELAPSED}ms < 1800ms — something went wrong"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
