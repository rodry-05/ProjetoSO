#!/bin/bash
# Test: Fairness comparison between FCFS and LEF
# Setup: parallel=1, User 1 submits 4x "sleep 1", then User 2 submits 2x "sleep 0"
# Checks: User 2's average duration is lower under LEF than FCFS
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

# Run one scenario, wait for all runners with explicit PIDs, return User 2 avg duration in ms
run_scenario() {
    local POLICY=$1

    cd "$BIN_DIR"
    mkdir -p "$TMP_DIR"
    rm -f fifo_runner_to_controller fifo_controller_to_runner_* "$LOG_FILE"

    ./controller 1 "$POLICY" &
    local CTRL_PID=$!
    sleep 0.2

    # User 1: 4x sleep 1 — fills the queue
    ./runner -e 1 "sleep 1" > /dev/null 2>&1 &  local P1=$!
    ./runner -e 1 "sleep 1" > /dev/null 2>&1 &  local P2=$!
    ./runner -e 1 "sleep 1" > /dev/null 2>&1 &  local P3=$!
    ./runner -e 1 "sleep 1" > /dev/null 2>&1 &  local P4=$!
    sleep 0.5  # give User 1's commands time to reach the controller first

    # User 2: 2x sleep 0 — arrives after queue is full
    ./runner -e 2 "sleep 0" > /dev/null 2>&1 &  local P5=$!
    ./runner -e 2 "sleep 0" > /dev/null 2>&1 &  local P6=$!

    wait $P1 $P2 $P3 $P4 $P5 $P6

    ./runner -s > /dev/null 2>&1
    wait $CTRL_PID 2>/dev/null

    echo "  [$POLICY] log:" >&2
    cat "$LOG_FILE" >&2

    # Extract durations for user_id 2, sum in ms, return average
    local SUM=0
    local COUNT=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "user_id: 2"; then
            DUR=$(echo "$line" | grep -oE "duration: [0-9]+\.[0-9]+" | grep -oE "[0-9]+\.[0-9]+")
            MS=$(awk "BEGIN {printf \"%d\", $DUR * 1000}")
            SUM=$(( SUM + MS ))
            COUNT=$(( COUNT + 1 ))
        fi
    done < "$LOG_FILE"

    if [ "$COUNT" -eq 0 ]; then echo "0"
    else awk "BEGIN {printf \"%d\", $SUM / $COUNT}"
    fi
}

echo "Running FCFS scenario..."
AVG_FCFS=$(run_scenario fcfs)
echo ""
echo "Running LEF scenario..."
AVG_LEF=$(run_scenario lef)

echo ""
echo "--- Results ---"
echo "User 2 avg duration under FCFS : ${AVG_FCFS}ms"
echo "User 2 avg duration under LEF  : ${AVG_LEF}ms"
echo "---------------"
echo ""
echo "=== Test Results ==="

# 1. both averages are positive (User 2 commands were logged in both scenarios)
if [ "$AVG_FCFS" -gt 0 ] && [ "$AVG_LEF" -gt 0 ]; then
    pass "User 2 commands logged in both scenarios (FCFS=${AVG_FCFS}ms, LEF=${AVG_LEF}ms)"
else
    fail "User 2 commands missing from log (FCFS=${AVG_FCFS}ms, LEF=${AVG_LEF}ms)"
fi

# 2. LEF avg is lower than FCFS avg — core fairness assertion
if [ "$AVG_LEF" -lt "$AVG_FCFS" ]; then
    pass "LEF avg (${AVG_LEF}ms) < FCFS avg (${AVG_FCFS}ms) — LEF is fairer for User 2"
else
    fail "Expected LEF avg < FCFS avg, got LEF=${AVG_LEF}ms FCFS=${AVG_FCFS}ms"
fi

# 3. under FCFS, User 2 waited behind User 1's sleeps (> 1000ms)
if [ "$AVG_FCFS" -gt 1000 ]; then
    pass "FCFS avg (${AVG_FCFS}ms) > 1000ms — User 2 queued behind User 1"
else
    fail "FCFS avg (${AVG_FCFS}ms) <= 1000ms — User 2 should have waited longer"
fi

# 4. under LEF, User 2 was prioritised (< 1500ms — got in before all of User 1's commands)
if [ "$AVG_LEF" -lt 1500 ]; then
    pass "LEF avg (${AVG_LEF}ms) < 1500ms — User 2 was prioritised over User 1"
else
    fail "LEF avg (${AVG_LEF}ms) >= 1500ms — User 2 was not prioritised as expected"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1