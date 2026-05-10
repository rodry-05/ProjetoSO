#!/bin/bash
# Test: persistent log
# Checks: tmp/logs.txt is created with user_id, command_id and duration after a command runs
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
LOG_FILE="$TMP_DIR/logs.txt"
 
if [ ! -x "$BIN_DIR/controller" ] || [ ! -x "$BIN_DIR/runner" ]; then
    echo -e "${RED}[ERROR]${NC} Binaries not found in $BIN_DIR. Run 'make' first."
    exit 1
fi
 
cd "$BIN_DIR"
mkdir -p "$TMP_DIR"
 
rm -f fifo_runner_to_controller fifo_controller_to_runner_* "$LOG_FILE"
 
./controller 1 fcfs &
CTRL_PID=$!
sleep 0.2
 
./runner -e 1 "echo hello" > /dev/null 2>&1
sleep 0.2
 
./runner -s > /dev/null 2>&1
wait $CTRL_PID 2>/dev/null
 
echo "--- logs.txt contents ---"
cat "$LOG_FILE" 2>/dev/null || echo "(file missing)"
echo "-------------------------"
 
echo ""
echo "=== Test Results ==="
 
# 1. logs.txt was created
if [ -f "$LOG_FILE" ]; then
    pass "tmp/logs.txt was created"
else
    fail "tmp/logs.txt was not created"
    echo ""
    echo "=== Summary: $PASS passed, $FAIL failed ==="
    exit 1
fi
 
LOG_LINE=$(cat "$LOG_FILE")
 
# 2. contains user_id field
if echo "$LOG_LINE" | grep -qE "user_id: [0-9]+"; then
    USER_ID=$(echo "$LOG_LINE" | grep -oE "user_id: [0-9]+" | grep -oE "[0-9]+")
    pass "log contains 'user_id' field ($USER_ID)"
else
    fail "log missing 'user_id' field"
fi
 
# 3. contains command_id field
if echo "$LOG_LINE" | grep -qE "command_id: [0-9]+"; then
    CMD_ID=$(echo "$LOG_LINE" | grep -oE "command_id: [0-9]+" | grep -oE "[0-9]+")
    pass "log contains 'command_id' field ($CMD_ID)"
else
    fail "log missing 'command_id' field"
fi
 
# 4. contains duration field with a numeric value
if echo "$LOG_LINE" | grep -qE "duration: [0-9]+\.[0-9]+"; then
    DURATION=$(echo "$LOG_LINE" | grep -oE "duration: [0-9]+\.[0-9]+")
    pass "log contains numeric duration ($DURATION)"
else
    fail "log missing or malformed 'duration' field"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
