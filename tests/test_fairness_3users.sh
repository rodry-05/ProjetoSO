#!/bin/bash
# Test: Fairness with 3 users, parallel=2
# Setup: User 1 submits 4x "sleep 2", then Users 2 and 3 each submit 2x "sleep 0"
# Checks: avg duration of Users 2 and 3 is lower under LEF than FCFS
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
 
# Returns avg duration in ms for a given user_id from the log
avg_duration_ms() {
    local USER_ID=$1
    local SUM=0
    local COUNT=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "user_id: $USER_ID"; then
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
 
run_scenario() {
    local POLICY=$1
 
    cd "$BIN_DIR"
    mkdir -p "$TMP_DIR"
    rm -f fifo_runner_to_controller fifo_controller_to_runner_* "$LOG_FILE"
 
    ./controller 2 "$POLICY" &
    local CTRL_PID=$!
    sleep 0.2
 
    # User 1: 4x sleep 2 — dominates the queue
    local P1=$!; ./runner -e 1 "sleep 2" > /dev/null 2>&1 & P1=$!
    local P2=$!; ./runner -e 1 "sleep 2" > /dev/null 2>&1 & P2=$!
    local P3=$!; ./runner -e 1 "sleep 2" > /dev/null 2>&1 & P3=$!
    local P4=$!; ./runner -e 1 "sleep 2" > /dev/null 2>&1 & P4=$!
    sleep 0.5  # let User 1 fill the queue before Users 2 and 3 arrive
 
    # Users 2 and 3: 2x sleep 0 each — arrive late
    local P5=$!; ./runner -e 2 "sleep 0" > /dev/null 2>&1 & P5=$!
    local P6=$!; ./runner -e 2 "sleep 0" > /dev/null 2>&1 & P6=$!
    local P7=$!; ./runner -e 3 "sleep 0" > /dev/null 2>&1 & P7=$!
    local P8=$!; ./runner -e 3 "sleep 0" > /dev/null 2>&1 & P8=$!
 
    wait $P1 $P2 $P3 $P4 $P5 $P6 $P7 $P8
 
    ./runner -s > /dev/null 2>&1
    wait $CTRL_PID 2>/dev/null
 
    echo "  [$POLICY] log:" >&2
    cat "$LOG_FILE" >&2
    echo "" >&2
}
 
echo "Running FCFS scenario..."
run_scenario fcfs
AVG_FCFS_U2=$(avg_duration_ms 2)
AVG_FCFS_U3=$(avg_duration_ms 3)
AVG_FCFS=$(awk "BEGIN {printf \"%d\", ($AVG_FCFS_U2 + $AVG_FCFS_U3) / 2}")
 
echo "Running LEF scenario..."
run_scenario lef
AVG_LEF_U2=$(avg_duration_ms 2)
AVG_LEF_U3=$(avg_duration_ms 3)
AVG_LEF=$(awk "BEGIN {printf \"%d\", ($AVG_LEF_U2 + $AVG_LEF_U3) / 2}")
 
echo ""
echo "--- Results ---"
printf "  FCFS: User 2 avg=%dms  User 3 avg=%dms  combined avg=%dms\n" "$AVG_FCFS_U2" "$AVG_FCFS_U3" "$AVG_FCFS"
printf "  LEF:  User 2 avg=%dms  User 3 avg=%dms  combined avg=%dms\n" "$AVG_LEF_U2"  "$AVG_LEF_U3"  "$AVG_LEF"
echo "---------------"
echo ""
echo "=== Test Results ==="
 

# 1. LEF combined avg < FCFS combined avg — core fairness assertion
if [ "$AVG_LEF" -lt "$AVG_FCFS" ]; then
    pass "LEF combined avg (${AVG_LEF}ms) < FCFS combined avg (${AVG_FCFS}ms) — LEF is fairer"
else
    fail "Expected LEF avg < FCFS avg, got LEF=${AVG_LEF}ms FCFS=${AVG_FCFS}ms"
fi
 
# 2. under FCFS, Users 2 and 3 waited behind User 1 (> 1000ms)
if [ "$AVG_FCFS_U2" -gt 1000 ] && [ "$AVG_FCFS_U3" -gt 1000 ]; then
    pass "FCFS: both users waited > 1000ms (U2=${AVG_FCFS_U2}ms, U3=${AVG_FCFS_U3}ms)"
else
    fail "FCFS: expected both users > 1000ms (U2=${AVG_FCFS_U2}ms, U3=${AVG_FCFS_U3}ms)"
fi
 
# 3. under LEF, both Users 2 and 3 were prioritised (< 2000ms)
if [ "$AVG_LEF_U2" -lt 2000 ] && [ "$AVG_LEF_U3" -lt 2000 ]; then
    pass "LEF: both users finished < 2000ms (U2=${AVG_LEF_U2}ms, U3=${AVG_LEF_U3}ms)"
else
    fail "LEF: expected both users < 2000ms (U2=${AVG_LEF_U2}ms, U3=${AVG_LEF_U3}ms)"
fi
 
# 4. under LEF, Users 2 and 3 have similar avg (neither starved)
DIFF=$(( AVG_LEF_U2 - AVG_LEF_U3 ))
DIFF=${DIFF#-}  # absolute value
if [ "$DIFF" -lt 1500 ]; then
    pass "LEF: Users 2 and 3 have similar avg (diff=${DIFF}ms) — no starvation between late users"
else
    fail "LEF: Users 2 and 3 differ by ${DIFF}ms — possible starvation"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 