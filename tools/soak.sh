#!/usr/bin/env bash
# Booth endurance check. Plays whole sessions back to back with the bot, with
# no window and the clock stepped at a fixed 60 frames a second so it runs far
# faster than real time, then checks that nothing grew.
#
#   tools/soak.sh          300 sessions
#   tools/soak.sh 1000     as many as you like
#
# Fails when the scene tree grew, when stray nodes appeared, or when objects
# or memory kept climbing after the first sessions.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

RUNS="${1:-300}"
GODOT_RUN_LIMIT="${GODOT_RUN_LIMIT:-3600}"
godot_import

LOG="$(mktemp)"
START=$(date +%s)
run_godot_isolated --headless --fixed-fps 60 --path "$PROJECT_PATH" -- \
	--autoplay --mute --soak-log "--quit-after-runs=$RUNS" > "$LOG" 2>&1
CODE=$?
TOOK=$(( $(date +%s) - START ))

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG" | head -10
	echo "FAILED: script errors during the soak run." >&2
	rm -f "$LOG"
	exit 1
fi

grep "^soak run=" "$LOG" | awk -v runs="$RUNS" -v took="$TOOK" '
function field(name,   i, kv) {
	for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == name) return kv[2] + 0 }
	return 0
}
{
	n++
	nodes = field("nodes"); objects = field("objects"); orphans = field("orphans"); mem = field("static_mb")
	if (n == 10) { nodes0 = nodes; objects0 = objects; mem0 = mem }
	if (orphans > max_orphans) max_orphans = orphans
	last_nodes = nodes; last_objects = objects; last_mem = mem
}
END {
	if (n < runs || n < 20) { printf "FAILED: only %d of %d sessions finished.\n", n, runs; exit 1 }
	per_run = (last_objects - objects0) / (n - 10)
	printf "%d sessions in %d s (%.1f s of play each, simulated)\n", n, took, 77.0
	printf "scene nodes:   %d after 10 sessions, %d at the end\n", nodes0, last_nodes
	printf "objects:       %d after 10 sessions, %d at the end (%.2f per session)\n", objects0, last_objects, per_run
	printf "static memory: %.1f MB after 10 sessions, %.1f MB at the end\n", mem0, last_mem
	printf "stray nodes:   %d at most\n", max_orphans
	bad = 0
	if (last_nodes != nodes0) { print "FAILED: the scene tree changed size."; bad = 1 }
	if (max_orphans > 0) { print "FAILED: nodes were left outside the tree."; bad = 1 }
	if (per_run > 1.5) { print "FAILED: objects keep growing."; bad = 1 }
	if (last_mem - mem0 > 24) { print "FAILED: memory keeps growing."; bad = 1 }
	if (!bad) print "PASSED"
	exit bad
}'
RESULT=$?
rm -f "$LOG"
exit "$RESULT"
