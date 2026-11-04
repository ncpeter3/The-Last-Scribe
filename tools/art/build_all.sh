#!/usr/bin/env bash
# Rebuild every model in shared_assets from the source packs.
# Needs Blender's Python module:  python3.11 -m pip install bpy pillow
# Usage: tools/art/build_all.sh [sources dir] [python]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${1:-$ROOT/art_sources}"
PY="${2:-python3.11}"
[ -d "$SRC/glTF" ] || "$ROOT/tools/art/fetch_sources.sh" "$SRC"
OUT="$ROOT/shared_assets"
"$PY" "$ROOT/tools/art/build_characters.py" -- "$SRC" "$OUT/characters"
"$PY" "$ROOT/tools/art/build_animals.py" -- "$SRC" "$OUT/animals"
"$PY" "$ROOT/tools/art/build_nature.py" -- "$SRC" "$OUT/nature"
mv -f "$OUT/nature/serpent.glb" "$OUT/characters/serpent.glb"
du -sh "$OUT"/*
