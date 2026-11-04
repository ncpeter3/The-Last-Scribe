# The Last Scribe

A 2.5D Android game (Godot 4) about scribes from the year 2060, when physical books are gone and no digital copy of scripture can be trusted. A scribe travels back to witness each Bible story as the hero's aide and record it faithfully. Stories are played in chronological order, starting with Adam and Eve.

Scripture quotes use the KJV. Target audience: ages 10+. No blood; enemies are driven off or knocked down.

## Status
Early scaffold. Chapter 1 (Genesis 1-3) is a greybox: walk with on-screen buttons and tap through the story beats. Verses unlock into a saved journal list.

## Run
Open the folder in Godot 4.3+ and press Play. Android export: install the Android SDK and export templates, then use Project > Export.

## Layout
- `core/` shared systems (player, dialogue, game state)
- `chapters/NN_name/` one folder per story; text lives in `data/*.json`
- `docs/` design notes

Design plan: see `docs/design.md`.
