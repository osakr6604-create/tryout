#!/usr/bin/env bash
# Records the game with the engine's own movie writer: every frame is rendered
# at a fixed 60 a second and written with the sound, so the footage is exact
# no matter how fast the PC is. The demo player is at the mouse.
#
#   tools/record.sh <name> [seed] [skill] [extra game flags...]
#   tools/record.sh run 7 0.82
#   tools/record.sh attract 1 0.8 --no-autoplay --quit-after=14
#
# Writes out/video/<name>.avi (video and sound), <name>.jsonl (what happened
# and when) and, with --board, the leaderboard window's frames in <name>_board/.
# The window opens beside the desktop, not on it.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

NAME="${1:-run}"
SEED="${2:-7}"
SKILL="${3:-0.82}"
shift $(( $# < 3 ? $# : 3 ))

OUT="$REPO_DIR/out/video"
mkdir -p "$OUT"
touch "$REPO_DIR/out/.gdignore"

AUTOPLAY="--autoplay"
EXTRA=()
for flag in "$@"; do
	case "$flag" in
		--no-autoplay) AUTOPLAY="" ;;
		--board) EXTRA+=("--board" "--board-seq=$(win_path "$OUT/${NAME}_board")") ;;
		*) EXTRA+=("$flag") ;;
	esac
done

godot_import
GODOT_RUN_LIMIT="${GODOT_RUN_LIMIT:-1800}"
LOG="$(mktemp)"
run_godot_isolated --path "$PROJECT_PATH" --write-movie "$(win_path "$OUT/$NAME.avi")" --fixed-fps 60 --resolution 1920x1080 -- \
	--offscreen $AUTOPLAY "--skill=$SKILL" "--seed=$SEED" "--event-log=$(win_path "$OUT/$NAME.jsonl")" "${EXTRA[@]}" > "$LOG" 2>&1
CODE=$?
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG" | head
	echo "FAILED: script errors during the recording." >&2
	CODE=1
fi
grep -E "^soak run=|Movie|movie" "$LOG" | tail -4
rm -f "$LOG"
ls -la "$OUT/$NAME.avi" "$OUT/$NAME.jsonl" 2>/dev/null
exit "$CODE"
