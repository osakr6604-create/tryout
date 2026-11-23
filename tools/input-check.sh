#!/usr/bin/env bash
# Checks the paths a person's mouse takes, without a person.
#
#   tools/input-check.sh
#
# The demo player normally talks to the drills directly. Here it sends real
# mouse events through the engine's input system instead: it works the booth
# menu (export, clear today with its second click, a volume step, back),
# clicks the start button, plays two sessions, types the tag on the on-screen
# keys and clicks "next player". No window is needed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

godot_import

LOG="$(mktemp)"
run_godot_isolated --headless --fixed-fps 60 --path "$PROJECT_PATH" -- \
	--autoplay-input --menu-test --demo-board=5 --mute --soak-log --skill=0.8 --tag=MOUSE7 --quit-after-runs=2 > "$LOG" 2>&1
CODE=0

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG" | head -10
	echo "FAILED: script errors." >&2
	CODE=1
fi

MENU="$(grep -m1 '^menu-test ' "$LOG" || true)"
echo "${MENU:-menu-test line missing}"
if [ "$MENU" != "menu-test exported=true today=0 music=0.25 open=false" ]; then
	echo "FAILED: the booth menu did not do what the clicks asked for." >&2
	CODE=1
fi

RUNS="$(grep -c '^soak run=' "$LOG" || true)"
grep '^soak run=' "$LOG" | cut -d' ' -f1-3
if [ "$RUNS" -ne 2 ]; then
	echo "FAILED: $RUNS of 2 sessions finished through mouse events." >&2
	CODE=1
fi
# A session played through the mouse path must actually score.
if grep '^soak run=' "$LOG" | grep -qE 'score=([0-9]|[0-9]{2}|[0-9]{3}) '; then
	echo "FAILED: a session scored under 1,000, so clicks are not reaching the drills." >&2
	CODE=1
fi

rm -f "$LOG"
[ "$CODE" -eq 0 ] && echo "PASSED"
exit "$CODE"
