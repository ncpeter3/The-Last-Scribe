# Art: the low-poly kit

Everything you see in the game is built in code, in one flat-shaded low-poly style, from one small
palette. There are no model files to download or rebuild.

| File | What it makes |
| --- | --- |
| `core/lowpoly/low_poly.gd` (`LowPoly`) | The palette and a mesh builder (box, prism, ball, dome, wedge, ring, hoop) that merges many shapes into one mesh with one shared material. Colors with alpha below 1 glow: `LowPoly.glow(color, strength)`. |
| `core/lowpoly/low_poly_person.gd` (`LowPolyPerson`) | People from a look Dictionary (presets: both scribes, the family, Adam, Eve, their coats of skins, the cherub), animated in code: walk, sit, and gestures (talk, wave, cheer, hug, ...). |
| `core/lowpoly/low_poly_animal.gd` (`LowPolyAnimal`) | 15 animals plus the serpent. Land animals wander and graze (never into water), birds fly in loops or perch, fish and whales swim inside their water. |
| `core/lowpoly/low_poly_dog.gd` (`LowPolyDog`) | Biscuit, the family dog. |
| `core/world/props.gd` (`Props`) | Trees, rocks, grass, flowers, bushes, water, flames, and creatures placed in the world. Repeated plants share meshes. |
| `core/lowpoly/*.gdshader` | The shared material (with glow and fade-near-camera), flat-lit simple shapes, and faceted moving water. |

`CharacterFactory.make(id, ...)` builds any named character. `tools/test/lowpoly_lineup.tscn` saves a
screenshot of the people for checking the art; `tools/test/scenery_shots.tscn` saves each part of
chapter 1.
