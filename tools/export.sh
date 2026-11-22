#!/usr/bin/env bash
# Exports the release builds into build/.
#
#   tools/export.sh                 Windows, Linux and Web
#   tools/export.sh windows web     only the ones named
#
# Needs the Godot export templates for the pinned version.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

TARGETS="${*:-windows linux web}"
mkdir -p "$REPO_DIR/build"
touch "$REPO_DIR/build/.gdignore"
godot_import

export_one() {
	local preset="$1" out="$2" log
	mkdir -p "$(dirname "$REPO_DIR/$out")"
	log="$(mktemp)"
	echo "== $preset -> $out"
	run_godot --headless --path "$PROJECT_PATH" --export-release "$preset" "$(win_path "$REPO_DIR/$out")" > "$log" 2>&1
	if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error|No export template found|Cannot export" "$log"; then
		grep -E "ERROR|Error|template" "$log" | head -12
		echo "FAILED: the $preset export reported errors." >&2
		rm -f "$log"
		return 1
	fi
	rm -f "$log"
	if [ ! -s "$REPO_DIR/$out" ]; then
		echo "FAILED: $out was not written." >&2
		return 1
	fi
}

# The files a booth operator wants beside the game.
add_extras() {
	local dir="$REPO_DIR/build/$1"
	cp "$REPO_DIR/booth.example.cfg" "$REPO_DIR/LICENSE" "$dir/" 2>/dev/null
	if [ -f "$REPO_DIR/docs/BOOTH.md" ]; then
		cp "$REPO_DIR/docs/BOOTH.md" "$dir/BOOTH.md"
	fi
}

CODE=0
for target in $TARGETS; do
	case "$target" in
		windows)
			rm -rf "$REPO_DIR/build/windows"
			export_one "Windows" "build/windows/Tryout.exe" || CODE=1
			add_extras windows
			;;
		linux)
			rm -rf "$REPO_DIR/build/linux"
			export_one "Linux" "build/linux/Tryout.x86_64" || CODE=1
			add_extras linux
			;;
		web)
			rm -rf "$REPO_DIR/build/web"
			export_one "Web" "build/web/index.html" || CODE=1
			;;
		*)
			echo "Unknown target: $target (use windows, linux or web)" >&2
			CODE=2
			;;
	esac
done
ls -la "$REPO_DIR"/build/*/ 2>/dev/null | grep -v "^total" | head -40
exit "$CODE"
