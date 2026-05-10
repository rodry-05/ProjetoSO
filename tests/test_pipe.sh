#!/bin/bash
# Test: ./runner -e 1 "echo linha | wc -l"
# Checks: pipe works and result is 1
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
 
./controller 1 fcfs &
CTRL_PID=$!
sleep 0.2
 
OUTPUT=$(./runner -e 1 "echo linha | wc -l" 2>&1)
RUNNER_EXIT=$?
sleep 0.2
 
./runner -s > /dev/null 2>&1
wait $CTRL_PID 2>/dev/null
 
echo "--- Runner output ---"
echo "$OUTPUT"
echo "---------------------"
 
echo ""
echo "=== Test Results ==="
 
# 1. runner exited successfully
if [ $RUNNER_EXIT -eq 0 ]; then
    pass "runner exited with code 0"
else
    fail "runner exited with code $RUNNER_EXIT (expected 0)"
fi
 
# 2. output contains "1" (wc -l result)
if echo "$OUTPUT" | grep -qx "1"; then
    pass "wc -l output is 1"
else
    fail "wc -l output is not 1 (got: '$(echo "$OUTPUT" | grep -v runner)' )"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
