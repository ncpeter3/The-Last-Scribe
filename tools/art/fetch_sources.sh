#!/usr/bin/env bash
# Download the CC0 source packs (all by Quaternius, mirrored on OpenGameArt) into $1 (default: art_sources/).
set -euo pipefail
DEST="${1:-art_sources}"
mkdir -p "$DEST"
B=https://opengameart.org/sites/default/files
for f in \
  "ultimate_animated_character_pack_by_quaternius.zip" \
  "Farm%20Animals%20by%20%40Quaternius.zip" \
  "Animal%20Pack%20Vol.2%20by%20%40Quaternius.zip" \
  "Animals%20Pack%20by%20Quaternius.zip" \
  "stylized_nature_megakitstandard.zip"; do
  out="$DEST/$(echo "$f" | sed 's/%20/_/g; s/%40//g')"
  [ -f "$out" ] || curl -fsSL -o "$out" "$B/$f"
  unzip -oq "$out" -d "$DEST"
done
echo "Sources ready in $DEST"
