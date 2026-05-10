#!/bin/bash
# Test: submit 2 commands with parallel=1, check -c shows one Executing and one Scheduled
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
 
# parallel=1 so only one command runs at a time
./controller 1 fcfs &
CTRL_PID=$!
sleep 0.2
 
# Submit command 1: sleeps long enough for us to query status
./runner -e 1 "sleep 5" &
RUNNER1_PID=$!
sleep 0.3  # give it time to be picked up and start executing
 
# Submit command 2: will be queued since parallel=1
./runner -e 2 "sleep 5" &
RUNNER2_PID=$!
sleep 0.3  # give it time to reach the controller and be scheduled
 
# Query status while both are in flight
STATUS=$(./runner -c 2>&1)
 
echo "--- Status output ---"
echo "$STATUS"
echo "---------------------"
 
echo ""
echo "=== Test Results ==="
 
# 1. status output contains "Executing" section
if echo "$STATUS" | grep -q "Executing"; then
    pass "'Executing' section present"
else
    fail "'Executing' section missing"
fi
 
# 2. status output contains "Scheduled" section
if echo "$STATUS" | grep -q "Scheduled"; then
    pass "'Scheduled' section present"
else
    fail "'Scheduled' section missing"
fi
 
# 3. exactly one command in Executing
EXECUTING_COUNT=$(echo "$STATUS" | awk '/Executing/{found=1; next} /Scheduled/{found=0} found && /command-id/' | wc -l)
if [ "$EXECUTING_COUNT" -eq 1 ]; then
    pass "exactly 1 command in Executing (got $EXECUTING_COUNT)"
else
    fail "expected 1 command in Executing, got $EXECUTING_COUNT"
fi
 
# 4. exactly one command in Scheduled
SCHEDULED_COUNT=$(echo "$STATUS" | awk '/Scheduled/{found=1; next} found && /command-id/' | wc -l)
if [ "$SCHEDULED_COUNT" -eq 1 ]; then
    pass "exactly 1 command in Scheduled (got $SCHEDULED_COUNT)"
else
    fail "expected 1 command in Scheduled, got $SCHEDULED_COUNT"
fi
 
# Cleanup: kill the sleep commands and shutdown controller
kill $RUNNER1_PID $RUNNER2_PID 2>/dev/null
./runner -s > /dev/null 2>&1 &
# wait a moment then force kill controller if still running
sleep 1
kill $CTRL_PID 2>/dev/null
wait $CTRL_PID 2>/dev/null
wait $RUNNER1_PID $RUNNER2_PID 2>/dev/null
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
