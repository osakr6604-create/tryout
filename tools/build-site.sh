#!/usr/bin/env bash
# Assembles the public site into build/site:
#   /          the web build of the game (when build/web exists)
#   /card/     the scouting card page the QR code opens
#   /fonts/    the two open fonts the card page uses
#
#   tools/build-site.sh
set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
SITE="$REPO_DIR/build/site"

# Empty the folder rather than remove it: a local preview server may be
# running from inside it.
mkdir -p "$SITE" "$REPO_DIR/build"
find "$SITE" -mindepth 1 -delete
mkdir -p "$SITE/card" "$SITE/fonts"
touch "$REPO_DIR/build/.gdignore"

if [ -f "$REPO_DIR/build/web/index.html" ]; then
	cp -r "$REPO_DIR/build/web/." "$SITE/"
else
	echo "No web build in build/web yet; the site will only have the card page." >&2
fi
cp "$REPO_DIR/site/card/index.html" "$SITE/card/index.html"
cp "$REPO_DIR/assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf" \
   "$REPO_DIR/assets/fonts/BarlowCondensed-SemiBold.ttf" \
   "$REPO_DIR/assets/fonts/JetBrainsMono-ExtraBold.ttf" \
   "$REPO_DIR/assets/fonts/OFL-BarlowCondensed.txt" \
   "$REPO_DIR/assets/fonts/OFL-JetBrainsMono.txt" "$SITE/fonts/"
# Pages serves files as they are; this stops it running them through Jekyll.
touch "$SITE/.nojekyll"
echo "site ready in $SITE"
ls "$SITE"
