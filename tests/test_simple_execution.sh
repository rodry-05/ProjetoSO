#!/bin/bash
# Test: ./runner -e 1 "echo hello"
# Checks: output "hello", and messages "submitted", "executing", "finished"
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
 
# Paths relative to project root (one level above tests/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
TMP_DIR="$ROOT_DIR/tmp"
 
# Validate binaries exist
if [ ! -x "$BIN_DIR/controller" ] || [ ! -x "$BIN_DIR/runner" ]; then
    echo -e "${RED}[ERROR]${NC} Binaries not found in $BIN_DIR. Run 'make' first."
    exit 1
fi
 
# The controller opens "../tmp/logs.txt" relative to its working directory.
# Running from bin/ makes ../tmp/ resolve correctly to the project's tmp/.
cd "$BIN_DIR"
mkdir -p "$TMP_DIR"
 
# Clean up any leftover FIFOs from previous runs
rm -f fifo_runner_to_controller fifo_controller_to_runner_*
 
# Start controller (parallel=1, policy=fcfs)
./controller 1 fcfs &
CTRL_PID=$!
sleep 0.2  # give controller time to create the FIFO
 
# Run runner and capture all output (stdout + stderr combined)
OUTPUT=$(./runner -e 1 "echo hello" 2>&1)
RUNNER_EXIT=$?
 
# Give the controller a moment to finish logging
sleep 0.2
 
# Shutdown controller
./runner -s > /dev/null 2>&1
wait $CTRL_PID 2>/dev/null
 
echo "--- Captured output ---"
echo "$OUTPUT"
echo "-----------------------"
 
# Assertions
echo ""
echo "=== Test Results ==="
 
# 1. runner exited successfully
if [ $RUNNER_EXIT -eq 0 ]; then
    pass "runner exited with code 0"
else
    fail "runner exited with code $RUNNER_EXIT (expected 0)"
fi
 
# 2. "hello" appears in output (the echo command result)
if echo "$OUTPUT" | grep -q "^hello$"; then
    pass "'hello' appears in output"
else
    fail "'hello' not found in output"
fi
 
# 3. "submitted" message present
if echo "$OUTPUT" | grep -q "submitted"; then
    pass "'submitted' message present"
else
    fail "'submitted' message missing"
fi
 
# 4. "executing" message present
if echo "$OUTPUT" | grep -q "executing"; then
    pass "'executing' message present"
else
    fail "'executing' message missing"
fi
 
# 5. "finished" message present
if echo "$OUTPUT" | grep -q "finished"; then
    pass "'finished' message present"
else
    fail "'finished' message missing"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
