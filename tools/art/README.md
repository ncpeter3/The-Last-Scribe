# Art pipeline

The models in `shared_assets/` are built by these Blender scripts from free CC0 packs (see
`shared_assets/CREDITS.md`). You only need this to change or add art; the game uses the built files.

## Rebuild everything

```bash
python3.11 -m pip install bpy        # Blender as a Python module (needs Python 3.11)
tools/art/build_all.sh               # downloads the packs into art_sources/ (git-ignored), then builds
```

| Script | Makes |
| --- | --- |
| `build_characters.py` | `characters/*.glb`: scribe_female, scribe_male, adam, eve, adam_skins, eve_skins, cherub |
| `build_animals.py` | `animals/*.glb`: 15 animals with Idle and/or Walk animations |
| `build_nature.py` | `nature/*.gltf` (+ shared `nature/textures/`) and `characters/serpent.glb` |

Each script takes `-- <sources dir> <output dir> [ids...]`, so you can rebuild one model, for example
`python3.11 tools/art/build_characters.py -- art_sources shared_assets/characters eve`.

## How the game uses them

- `CharacterFactory.make(id, ...)` loads `characters/<id>.glb`, turns it to face +X and plays `Idle`
  (`CharacterFactory.play(node, "Walk")` switches animation). Missing models fall back to simple shapes.
- `Props.tree/rock/grass/flower/bird/creature/nature` place nature and animals the same way.
- Characters share one skeleton with these animations: Idle, Walk, Run, PickUp, SitDown, Victory.

## Adding a new person

Add a function to `build_characters.py` that starts from one of the pack's 50 characters
(`base("Kimono_Male")`), recolors materials, grafts hair or clothing from another character
(`graft(...)`), and adds props bound to a bone (`prop(...)`). Then add it to `BUILDERS`.
