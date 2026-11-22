#!/usr/bin/env bash
# Runs the tests without a window. Fails on a failed test, on any script error
# in the output, and when the runner does not reach its last line.
#
#   tools/test.sh              every test
#   tools/test.sh rating       only test files whose name contains "rating"
#   tools/test.sh bots -v      verbose
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

FILTER=""
VERBOSE=""
for word in "$@"; do
	case "$word" in
		-v|--verbose) VERBOSE="--verbose" ;;
		*) FILTER="$word" ;;
	esac
done

godot_import

LOG="$(mktemp)"
run_godot_isolated --headless --path "$PROJECT_PATH" --script res://tests/run_tests.gd -- "--filter=$FILTER" $VERBOSE 2>&1 | tee "$LOG"
CODE=${PIPESTATUS[0]}

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	echo "FAILED: script errors appear in the output above." >&2
	CODE=1
fi
if [ "$CODE" -eq 124 ]; then
	echo "FAILED: the run passed its time limit of $GODOT_RUN_LIMIT seconds." >&2
	CODE=1
elif ! grep -qE "^[0-9]+ tests, [0-9]+ failed" "$LOG"; then
	echo "FAILED: the test runner did not finish." >&2
	CODE=1
fi
rm -f "$LOG"
exit "$CODE"
