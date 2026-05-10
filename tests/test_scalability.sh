
#!/bin/bash
# Test: Parallelism scalability
# Setup: 6x "sleep 2" with FCFS, measure wall time with parallel=1, 2, 4
# Expected: parallel=1 ~12s | parallel=2 ~6s | parallel=4 ~4s
# Checks: wall time decreases as parallelism increases
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
 
run_scenario() {
    local PARALLEL=$1
 
    cd "$BIN_DIR"
    mkdir -p "$TMP_DIR"
    rm -f fifo_runner_to_controller fifo_controller_to_runner_* "$LOG_FILE"
 
    ./controller "$PARALLEL" fcfs &
    local CTRL_PID=$!
    sleep 0.2
 
    local START=$(date +%s%3N)
 
    local PIDS=()
    for i in $(seq 1 6); do
        ./runner -e 1 "sleep 2" > /dev/null 2>&1 &
        PIDS+=($!)
    done
 
    wait "${PIDS[@]}"
 
    local END=$(date +%s%3N)
    local ELAPSED=$(( END - START ))
 
    ./runner -s > /dev/null 2>&1
    wait $CTRL_PID 2>/dev/null
 
    echo "$ELAPSED"
}
 
echo "Running parallel=1 (expect ~12s)..."
T1=$(run_scenario 1)
echo "  wall time: ${T1}ms"
 
echo "Running parallel=2 (expect ~6s)..."
T2=$(run_scenario 2)
echo "  wall time: ${T2}ms"
 
echo "Running parallel=4 (expect ~4s)..."
T4=$(run_scenario 4)
echo "  wall time: ${T4}ms"
 
echo ""
echo "--- Results ---"
printf "  parallel=1 : %dms  (6 x 2s sequential)\n"      "$T1"
printf "  parallel=2 : %dms  (3 batches of 2 x 2s)\n"    "$T2"
printf "  parallel=4 : %dms  (2 batches: 4+2 x 2s)\n"    "$T4"
echo "---------------"
echo ""
echo "=== Test Results ==="
 
# 1. parallel=1: 6 commands run one at a time -> ~12s
if [ "$T1" -ge 11000 ] && [ "$T1" -lt 14000 ]; then
    pass "parallel=1 wall time ${T1}ms in range [11000, 14000ms] (~12s)"
else
    fail "parallel=1 wall time ${T1}ms out of expected range [11000, 14000ms]"
fi
 
# 2. parallel=2: 3 batches of 2 -> ~6s
if [ "$T2" -ge 5500 ] && [ "$T2" -lt 8000 ]; then
    pass "parallel=2 wall time ${T2}ms in range [5500, 8000ms] (~6s)"
else
    fail "parallel=2 wall time ${T2}ms out of expected range [5500, 8000ms]"
fi
 
# 3. parallel=4: 2 batches (4+2) -> ~4s
if [ "$T4" -ge 3500 ] && [ "$T4" -lt 6000 ]; then
    pass "parallel=4 wall time ${T4}ms in range [3500, 6000ms] (~4s)"
else
    fail "parallel=4 wall time ${T4}ms out of expected range [3500, 6000ms]"
fi
 
# 4. wall time strictly decreases as parallelism increases
if [ "$T1" -gt "$T2" ] && [ "$T2" -gt "$T4" ]; then
    pass "wall time decreases as parallelism increases (${T1}ms > ${T2}ms > ${T4}ms)"
else
    fail "wall time does not decrease monotonically (parallel=1: ${T1}ms, parallel=2: ${T2}ms, parallel=4: ${T4}ms)"
fi
 
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
