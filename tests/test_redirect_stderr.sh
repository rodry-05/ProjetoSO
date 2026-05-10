#!/bin/bash
# Test: ./runner -e 1 "ls /dir_inexistente 2> ficheiro"
# Checks: stderr is redirected to ficheiro (not printed to terminal)
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
ERROR_FILE="$BIN_DIR/ficheiro"
 
if [ ! -x "$BIN_DIR/controller" ] || [ ! -x "$BIN_DIR/runner" ]; then
    echo -e "${RED}[ERROR]${NC} Binaries not found in $BIN_DIR. Run 'make' first."
    exit 1
fi
 
cd "$BIN_DIR"
mkdir -p "$TMP_DIR"
 
# Clean up from previous runs
rm -f fifo_runner_to_controller fifo_controller_to_runner_* "$ERROR_FILE"
 
./controller 1 fcfs &
CTRL_PID=$!
sleep 0.2
 
OUTPUT=$(./runner -e 1 "ls /dir_inexistente 2> ficheiro" 2>&1)
RUNNER_EXIT=$?
sleep 0.2
 
./runner -s > /dev/null 2>&1
wait $CTRL_PID 2>/dev/null
 
echo "--- Runner output ---"
echo "$OUTPUT"
echo "---------------------"
echo "--- ficheiro contents ---"
cat "$ERROR_FILE" 2>/dev/null || echo "(file missing)"
echo "-------------------------"
 
echo ""
echo "=== Test Results ==="
 
# 1. runner exited successfully
if [ $RUNNER_EXIT -eq 0 ]; then
    pass "runner exited with code 0"
else
    fail "runner exited with code $RUNNER_EXIT (expected 0)"
fi
 
# 2. ficheiro was created
if [ -f "$ERROR_FILE" ]; then
    pass "'ficheiro' was created"
else
    fail "'ficheiro' was not created"
fi
 
# 3. ficheiro contains an error message about the missing directory
if [ -f "$ERROR_FILE" ] && grep -qi "dir_inexistente" "$ERROR_FILE"; then
    pass "'ficheiro' contains the error message referencing 'dir_inexistente'"
else
    ACTUAL=$(cat "$ERROR_FILE" 2>/dev/null || echo "(file missing)")
    fail "'ficheiro' does not contain expected error (got: '$ACTUAL')"
fi
 
# 4. the error did NOT appear in runner's stdout/stderr
if echo "$OUTPUT" | grep -qi "dir_inexistente"; then
    fail "error message leaked to terminal output (should be in file only)"
else
    pass "error message did not leak to terminal output"
fi
 
# Cleanup
rm -f "$ERROR_FILE"
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
