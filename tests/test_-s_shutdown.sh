#!/bin/bash
# Test: ./runner -s
# Checks: correct messages appear and controller process terminates
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
 
# Send shutdown and capture output
OUTPUT=$(./runner -s 2>&1)
RUNNER_EXIT=$?
 
# Give controller time to terminate
sleep 0.5
 
echo "--- Runner output ---"
echo "$OUTPUT"
echo "---------------------"
 
echo ""
echo "=== Test Results ==="
 
# 1. runner -s exited successfully
if [ $RUNNER_EXIT -eq 0 ]; then
    pass "runner -s exited with code 0"
else
    fail "runner -s exited with code $RUNNER_EXIT (expected 0)"
fi
 
# 2. "shutdown notification" message present
if echo "$OUTPUT" | grep -q "shutdown notification"; then
    pass "'shutdown notification' message present"
else
    fail "'shutdown notification' message missing"
fi
 
# 3. "waiting" message present
if echo "$OUTPUT" | grep -q "waiting"; then
    pass "'waiting' message present"
else
    fail "'waiting' message missing"
fi
 
# 4. "controller exited" message present
if echo "$OUTPUT" | grep -q "controller exited"; then
    pass "'controller exited' message present"
else
    fail "'controller exited' message missing"
fi
 
# 5. controller process is no longer running
if ! kill -0 $CTRL_PID 2>/dev/null; then
    pass "controller process ($CTRL_PID) has terminated"
else
    kill $CTRL_PID 2>/dev/null
    fail "controller process ($CTRL_PID) is still running"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
