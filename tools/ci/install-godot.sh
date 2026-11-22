#!/usr/bin/env bash
# Installs the pinned Godot editor and the export templates this project needs
# on a Linux CI runner. Every download is checked against the SHA-512 published
# with the Godot release. Files restored from the cache are not downloaded again.
#
#   tools/ci/install-godot.sh            editor and templates
#   tools/ci/install-godot.sh editor     editor only (tests, soak)
set -euo pipefail

VERSION="4.7.2"
FLAVOR="stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${VERSION}-${FLAVOR}"
EDITOR_ZIP="Godot_v${VERSION}-${FLAVOR}_linux.x86_64.zip"
EDITOR_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
TEMPLATES_TPZ="Godot_v${VERSION}-${FLAVOR}_export_templates.tpz"
TEMPLATES_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
WANTED_TEMPLATES="version.txt windows_release_x86_64.exe windows_release_x86_64_console.exe linux_release.x86_64 web_nothreads_release.zip"

EDITOR_DIR="$HOME/godot-editor"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.${FLAVOR}"
WORK_DIR="${RUNNER_TEMP:-/tmp}/godot-download"
mkdir -p "$EDITOR_DIR" "$TEMPLATES_DIR" "$WORK_DIR"

fetch() {
	local name="$1" want="$2" out="$WORK_DIR/$1" got
	echo "Downloading $name"
	curl --fail --location --silent --show-error --retry 3 --output "$out" "$BASE_URL/$name"
	got="$(sha512sum "$out" | cut -d' ' -f1)"
	if [ "$got" != "$want" ]; then
		echo "SHA-512 mismatch for $name" >&2
		echo "  wanted $want" >&2
		echo "  got    $got" >&2
		exit 4
	fi
}

GODOT_BIN="$EDITOR_DIR/Godot_v${VERSION}-${FLAVOR}_linux.x86_64"
if [ -x "$GODOT_BIN" ]; then
	echo "Editor already present (cache)."
else
	fetch "$EDITOR_ZIP" "$EDITOR_SHA512"
	unzip -q -o "$WORK_DIR/$EDITOR_ZIP" -d "$EDITOR_DIR"
	chmod +x "$GODOT_BIN"
	rm -f "$WORK_DIR/$EDITOR_ZIP"
fi

if [ "${1:-}" != "editor" ]; then
	missing=0
	for file in $WANTED_TEMPLATES; do
		[ -s "$TEMPLATES_DIR/$file" ] || missing=1
	done
	if [ "$missing" -eq 0 ]; then
		echo "Export templates already present (cache)."
	else
		fetch "$TEMPLATES_TPZ" "$TEMPLATES_SHA512"
		for file in $WANTED_TEMPLATES; do
			unzip -q -o -j "$WORK_DIR/$TEMPLATES_TPZ" "templates/$file" -d "$TEMPLATES_DIR"
		done
		rm -f "$WORK_DIR/$TEMPLATES_TPZ"
	fi
fi

if [ -n "${GITHUB_ENV:-}" ]; then
	echo "GODOT_BIN=$GODOT_BIN" >> "$GITHUB_ENV"
fi
"$GODOT_BIN" --version
