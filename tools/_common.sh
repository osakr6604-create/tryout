# Shared by the tools scripts. Source it; do not run it.
#
# Finds Godot: the GODOT_BIN environment variable, else tools/local.env (not in
# git, one line: GODOT_BIN="/path/to/godot"), else "godot" on the PATH.
# Use the console build on Windows so output reaches the terminal.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd)"

if [ -z "${GODOT_BIN:-}" ] && [ -f "$TOOLS_DIR/local.env" ]; then
	# shellcheck disable=SC1091
	source "$TOOLS_DIR/local.env"
fi
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -f "$GODOT_BIN" ]; then
	echo "Godot was not found. Set GODOT_BIN, or put it in tools/local.env." >&2
	exit 127
fi

# Git Bash rewrites arguments that look like Unix paths. Godot needs them untouched.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

win_path() {
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -m "$1"
	else
		printf '%s' "$1"
	fi
}

PROJECT_PATH="$(win_path "$REPO_DIR")"
GODOT_RUN_LIMIT="${GODOT_RUN_LIMIT:-600}"

# Runs Godot with a time limit. Exit code 124 means the limit was hit.
run_godot() {
	if command -v timeout >/dev/null 2>&1; then
		timeout -k 10 "$GODOT_RUN_LIMIT" "$GODOT_BIN" "$@"
	else
		"$GODOT_BIN" "$@"
	fi
}

# Like run_godot, with a private, empty user:// folder that is deleted afterwards,
# so a test or a capture never touches the real leaderboard.
run_godot_isolated() {
	local home code
	home="$(mktemp -d)"
	APPDATA="$(win_path "$home")" XDG_DATA_HOME="$home" HOME="$home" run_godot "$@"
	code=$?
	rm -rf "$home"
	return "$code"
}

# Refreshes the import cache and the list of named scripts. Needed after adding files.
godot_import() {
	run_godot --headless --path "$PROJECT_PATH" --import >/dev/null 2>&1 || true
}
