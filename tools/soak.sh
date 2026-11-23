#!/usr/bin/env bash
# Booth endurance check. Plays whole sessions back to back with the demo
# player, with the clock stepped at a fixed 60 frames a second so it runs far
# faster than real time, then checks that nothing grew.
#
#   tools/soak.sh                  300 sessions, no window (about 1.5 s each)
#   tools/soak.sh 1000             as many as you like
#   tools/soak.sh 30 render        with the real renderer, in a window parked
#                                  beside the desktop (about 40 s each)
#
# The plain run covers the game logic and the scene tree. The "render" run is
# slower and also covers what only a real renderer holds, such as font and
# texture memory. Fails when the scene tree grew, when stray nodes appeared,
# or when objects, memory or texture memory kept climbing after the first
# sessions.
set -uo pipefail
RUNS="${1:-300}"
MODE="${2:-plain}"
PER_RUN=4
[ "$MODE" = "render" ] && PER_RUN=90
export GODOT_RUN_LIMIT="${GODOT_RUN_LIMIT:-$(( 300 + RUNS * PER_RUN ))}"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

godot_import

LOG="$(mktemp)"
START=$(date +%s)
if [ "$MODE" = "render" ]; then
	run_godot_isolated --fixed-fps 60 --path "$PROJECT_PATH" -- \
		--offscreen --autoplay --mute --soak-log "--quit-after-runs=$RUNS" > "$LOG" 2>&1
else
	run_godot_isolated --headless --fixed-fps 60 --path "$PROJECT_PATH" -- \
		--autoplay --mute --soak-log "--quit-after-runs=$RUNS" > "$LOG" 2>&1
fi
TOOK=$(( $(date +%s) - START ))

if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG" | head -10
	echo "FAILED: script errors during the soak run." >&2
	rm -f "$LOG"
	exit 1
fi

grep "^soak run=" "$LOG" | awk -v runs="$RUNS" -v took="$TOOK" -v mode="$MODE" '
function field(name,   i, kv) {
	for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == name) return kv[2] + 0 }
	return 0
}
{
	n++
	nodes = field("nodes"); objects = field("objects"); orphans = field("orphans")
	mem = field("static_mb"); tex = field("texture_mb")
	# Compare against the state after a few sessions, once caches have filled.
	base = (runs >= 20) ? 10 : 3
	if (n == base) { nodes0 = nodes; objects0 = objects; mem0 = mem; tex0 = tex }
	if (orphans > max_orphans) max_orphans = orphans
	last_nodes = nodes; last_objects = objects; last_mem = mem; last_tex = tex
}
END {
	base = (runs >= 20) ? 10 : 3
	if (n < runs || n <= base) { printf "FAILED: only %d of %d sessions finished.\n", n, runs; exit 1 }
	per_run = (last_objects - objects0) / (n - base)
	printf "%d sessions in %d s, %s renderer\n", n, took, (mode == "render") ? "real" : "no"
	printf "scene nodes:    %d after %d sessions, %d at the end\n", nodes0, base, last_nodes
	printf "objects:        %d after %d sessions, %d at the end (%.2f per session)\n", objects0, base, last_objects, per_run
	printf "static memory:  %.1f MB after %d sessions, %.1f MB at the end\n", mem0, base, last_mem
	if (mode == "render") printf "texture memory: %.1f MB after %d sessions, %.1f MB at the end\n", tex0, base, last_tex
	printf "stray nodes:    %d at most\n", max_orphans
	bad = 0
	if (last_nodes != nodes0) { print "FAILED: the scene tree changed size."; bad = 1 }
	if (max_orphans > 0) { print "FAILED: nodes were left outside the tree."; bad = 1 }
	# With a real renderer the engine keeps a bounded cache of laid-out text,
	# which fills by a few objects a session before it levels off.
	limit = (mode == "render") ? 12 : 1.5
	if (per_run > limit) { print "FAILED: objects keep growing."; bad = 1 }
	if (last_mem - mem0 > 24) { print "FAILED: memory keeps growing."; bad = 1 }
	if (mode == "render" && last_tex - tex0 > 16) { print "FAILED: texture memory keeps growing."; bad = 1 }
	if (!bad) print "PASSED"
	exit bad
}'
RESULT=$?
rm -f "$LOG"
exit "$RESULT"
