#!/bin/bash
# Run all tests sequentially and print a final summary

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0
RESULTS=()

cleanup() {
    cd "$BIN_DIR" 2>/dev/null
    rm -f fifo_runner_to_controller fifo_controller_to_runner_*
    pkill -f "./controller" 2>/dev/null
    sleep 0.2
}

run_test() {
    local NAME=$1
    local FILE="$SCRIPT_DIR/$2"

    cleanup  # ensure clean state before each test

    echo -e "${BOLD}>>> $NAME${NC}"
    OUTPUT=$(bash "$FILE" 2>/dev/null)
    EXIT=$?

    PASS=$(echo "$OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
    FAIL=$(echo "$OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+")
    PASS=${PASS:-0}
    FAIL=${FAIL:-0}

    TOTAL_PASS=$(( TOTAL_PASS + PASS ))
    TOTAL_FAIL=$(( TOTAL_FAIL + FAIL ))

    if [ "$EXIT" -eq 0 ]; then
        echo -e "    ${GREEN}PASS${NC} ($PASS passed, $FAIL failed)"
        RESULTS+=("${GREEN}PASS${NC}  $NAME ($PASS/$((PASS+FAIL)))")
    else
        echo -e "    ${RED}FAIL${NC} ($PASS passed, $FAIL failed)"
        echo "$OUTPUT" | grep "\[FAIL\]" | sed 's/^/      /'
        RESULTS+=("${RED}FAIL${NC}  $NAME ($PASS/$((PASS+FAIL)))")
    fi
    echo ""
}

echo ""
echo -e "${BOLD}===============================${NC}"
echo -e "${BOLD}       Running all tests       ${NC}"
echo -e "${BOLD}===============================${NC}"
echo ""

run_test "Simple execution"       "test_simple_execution.sh"
run_test "Stdout redirect (>)"    "test_redirect_stdout.sh"
run_test "Stdin redirect (<)"     "test_redirect_stdin.sh"
run_test "Stderr redirect (2>)"   "test_redirect_stderr.sh"
run_test "Pipe (|)"               "test_pipe.sh"
run_test "Pipe + redirect"        "test_pipe_+_redirect.sh"
run_test "Status (-c)"            "test_-c_status.sh"
run_test "Parallel execution"     "test_parallel_execution.sh"
run_test "Shutdown (-s)"          "test_-s_shutdown.sh"
run_test "Persistent log"         "test_persistent_logs.sh"
run_test "Fairness 2 users"       "test_fairness.sh"
run_test "Fairness 3 users"       "test_fairness_3users.sh"
run_test "Scalability"            "test_scalability.sh"


cleanup  # final cleanup

echo -e "${BOLD}===============================${NC}"
echo -e "${BOLD}            Summary            ${NC}"
echo -e "${BOLD}===============================${NC}"
for R in "${RESULTS[@]}"; do
    echo -e "  $R"
done
echo ""
TOTAL=$(( TOTAL_PASS + TOTAL_FAIL ))
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All tests passed ($TOTAL_PASS/$TOTAL)${NC}"
else
    echo -e "  ${RED}${BOLD}$TOTAL_FAIL failed, $TOTAL_PASS passed ($TOTAL_PASS/$TOTAL)${NC}"
fi
echo -e "${BOLD}===============================${NC}"
echo ""

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1