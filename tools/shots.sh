#!/usr/bin/env bash
# Runs the real game in a window with the bot playing and saves screenshots,
# so a change can be looked at without a person at the mouse.
#
#   tools/shots.sh [out-dir] [seconds] [seconds-between-shots] [extra game flags...]
#   tools/shots.sh out/shots 85 1.0
#   tools/shots.sh out/attract 6 1.0 --no-autoplay
#
# The run uses a private, empty user folder, so it never touches real scores.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

OUT="${1:-out/shots}"
LENGTH="${2:-85}"
EVERY="${3:-1.0}"
shift $(( $# < 3 ? $# : 3 ))

case "$OUT" in
	/*|[A-Za-z]:*) ;;
	*) OUT="$REPO_DIR/$OUT" ;;
esac
mkdir -p "$REPO_DIR/out" && touch "$REPO_DIR/out/.gdignore"
rm -rf "$OUT"
mkdir -p "$OUT"

AUTOPLAY="--autoplay"
EXTRA=()
for flag in "$@"; do
	if [ "$flag" = "--no-autoplay" ]; then
		AUTOPLAY=""
	else
		EXTRA+=("$flag")
	fi
done

godot_import

LOG="$(mktemp)"
run_godot_isolated --path "$PROJECT_PATH" --resolution 1280x720 --position 60,60 -- \
	--windowed --mute $AUTOPLAY "--shots=$(win_path "$OUT")" "--shot-every=$EVERY" "--quit-after=$LENGTH" "${EXTRA[@]}" 2>&1 | tee "$LOG"
CODE=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$LOG"; then
	echo "FAILED: script errors appear in the output above." >&2
	CODE=1
fi
rm -f "$LOG"
echo "$(ls "$OUT" | wc -l) screenshots in $OUT"
exit "$CODE"
