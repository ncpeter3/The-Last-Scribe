"""Build the game's people (scribes, Adam, Eve, cherubim) from Quaternius' CC0
"Ultimate Animated Character Pack" and export them as .glb files for Godot.

Usage (Blender's Python module, `pip install bpy`, Python 3.11):
    python3.11 tools/art/build_characters.py -- <sources dir> <output dir> [only_id ...]

Every character keeps the pack's skeleton and these animations: Idle, Walk, Run, PickUp, SitDown, Victory.
Faces point toward +Z in Godot (the factory turns them to face +X like the rest of the game).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from artlib import (bbox, body, delete_faces, export_glb, graft, hexc, join, keep_actions,  # noqa: E402
                    new_material, normalize_materials, open_blend, prop, recolor, section_extent, set_height)

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = ARGS[0], ARGS[1]
ONLY = set(ARGS[2:])
PACK = os.path.join(SRC, "Ultimate Animated Character Pack - Nov 2019", "Blends")
ANIMS = ["Idle", "Walk", "Run", "PickUp", "SitDown", "Victory"]


def blend(name):
    return os.path.join(PACK, name + ".blend")


def base(name):
    open_blend(blend(name))
    keep_actions(ANIMS)
    normalize_materials()
    return body()


def eyes():
    # The pack's characters have black skin with white eyes. With real skin tones, dark eyes read better.
    recolor({"Face": hexc("#1d140f")})


def satchel_and_scroll(b):
    """2060 scribe kit: a leather satchel on the right hip, a strap across the chest, and a scroll."""
    leather = new_material("Leather", hexc("#7a4b26"))
    strap_m = new_material("Strap", hexc("#4f3018"))
    parchment = new_material("Parchment", hexc("#f1e4bd"))
    wood = new_material("ScrollWood", hexc("#5b3b1f"))
    glow = new_material("ScribeGlow", hexc("#3fe0cf"), emission=1.2)
    parts = []
    # Satchel (character's right side is -X, front is -Y).
    parts.append(prop(bpy.ops.mesh.primitive_cube_add, leather, "Hips", loc=(-0.5, 0.02, 1.02), scale=(0.09, 0.24, 0.2)))
    parts.append(prop(bpy.ops.mesh.primitive_cube_add, strap_m, "Hips", loc=(-0.5, -0.02, 1.17), rot=(0.25, 0, 0), scale=(0.1, 0.25, 0.06)))
    parts.append(prop(bpy.ops.mesh.primitive_cube_add, glow, "Hips", loc=(-0.6, 0.02, 1.02), scale=(0.01, 0.12, 0.025)))
    # Strap from the right hip over the left shoulder, front and back.
    y0, y1 = section_extent(b, 1.65)
    for y in (y0 - 0.03, y1 + 0.03):
        parts.append(prop(bpy.ops.mesh.primitive_cube_add, strap_m, "Torso", loc=(-0.05, y, 1.55), rot=(0, math.radians(-40), 0), scale=(0.06, 0.02, 0.6)))
    # Scroll sticking up out of the satchel.
    parts.append(prop(bpy.ops.mesh.primitive_cylinder_add, parchment, "Hips", vertices=10, radius=0.075, depth=0.5,
                      loc=(-0.52, 0.1, 1.3), rot=(math.radians(-15), math.radians(-10), 0)))
    for dz in (0.27, -0.27):
        parts.append(prop(bpy.ops.mesh.primitive_cylinder_add, wood, "Hips", vertices=8, radius=0.04, depth=0.12,
                          loc=(-0.52 + dz * math.sin(math.radians(-10)) * -1, 0.1 + dz * math.sin(math.radians(15)), 1.3 + dz),
                          rot=(math.radians(-15), math.radians(-10), 0)))
    join(b, parts)


def remove_headband(b):
    delete_faces(b, "Band", zmin=2.05)


def wings(b):
    feather = new_material("Wing", hexc("#fbf3dc"), emission=0.35)
    tips = new_material("WingTip", hexc("#e6c766"), emission=0.6)
    y = section_extent(b, 1.8)[1]
    parts = []
    for side in (1, -1):
        for i, (length, lift, mat) in enumerate([(1.3, 0.55, feather), (1.05, 0.25, feather), (0.8, -0.05, tips)]):
            ang = math.radians(35 - i * 18)
            cx = side * (0.25 + length * 0.5 * math.cos(ang))
            cz = 1.85 + lift + length * 0.5 * math.sin(ang)
            parts.append(prop(bpy.ops.mesh.primitive_uv_sphere_add, mat, "Torso", segments=8, ring_count=5,
                              loc=(cx, y + 0.12 + i * 0.03, cz), rot=(0, -side * ang, 0), scale=(length * 0.5, 0.04, 0.16)))
    join(b, parts)


SKIN = {"scribe_f": "#c48b62", "scribe_m": "#a8724c", "adam": "#a06a44", "eve": "#b98159", "cherub": "#ead0ad"}
SCRIBE_ROBE = "#33475f"


def scribe_female():
    b = base("Kimono_Female")
    delete_faces(b, "Band", zmin=2.05)
    recolor({"Skin": hexc(SKIN["scribe_f"]), "Clothes": hexc(SCRIBE_ROBE), "Hair": hexc("#3a2214")})
    recolor({"Band": hexc("#2bbfb0")}, emission={"Band": 0.5})
    eyes()
    satchel_and_scroll(b)
    set_height(1.65)
    return b


def scribe_male():
    b = base("Kimono_Male")
    remove_headband(b)
    graft(b, blend("Casual_Male"), "Hair")
    recolor({"Skin": hexc(SKIN["scribe_m"]), "Clothes": hexc(SCRIBE_ROBE), "Hair": hexc("#2b1a10")})
    recolor({"Band": hexc("#2bbfb0")}, emission={"Band": 0.5})
    eyes()
    satchel_and_scroll(b)
    set_height(1.75)
    return b


def adam():
    # In Eden: a simple leaf-green garment (kept modest for ages 10+).
    b = base("Kimono_Male")
    remove_headband(b)
    graft(b, blend("Casual3_Male"), "Hair")
    recolor({"Skin": hexc(SKIN["adam"]), "Clothes": hexc("#5d8a37"), "Band": hexc("#3b5f22"), "Hair": hexc("#2a180c")})
    eyes()
    set_height(1.8)
    return b


def eve():
    b = base("Kimono_Female")
    delete_faces(b, "Hair")
    delete_faces(b, "Band", zmin=2.05)
    graft(b, blend("Casual3_Female"), "Hair", rename="LongHair")
    recolor({"Skin": hexc(SKIN["eve"]), "Clothes": hexc("#7aa84a"), "Band": hexc("#40652a"), "LongHair": hexc("#43200f")})
    eyes()
    set_height(1.7)
    return b


def adam_skins():
    # After the fall: "coats of skins" (Genesis 3:21). Full-length hide garment with a fur mantle and a beard.
    b = base("Kimono_Male")
    remove_headband(b)
    graft(b, blend("Casual3_Male"), "Hair")
    graft(b, blend("Viking_Male"), "Hair", zmax=2.62, rename="Beard")
    graft(b, blend("Viking_Male"), "Light", rename="Fur")
    recolor({"Skin": hexc(SKIN["adam"]), "Clothes": hexc("#7a5434"), "Band": hexc("#3f2a19"), "Fur": hexc("#c2a173"),
             "Hair": hexc("#2a180c"), "Beard": hexc("#2a180c")})
    eyes()
    set_height(1.8)
    return b


def eve_skins():
    b = base("Kimono_Female")
    delete_faces(b, "Hair")
    delete_faces(b, "Band", zmin=2.05)
    graft(b, blend("Casual3_Female"), "Hair", rename="LongHair")
    graft(b, blend("Viking_Female"), "Light", rename="Fur")
    recolor({"Skin": hexc(SKIN["eve"]), "Clothes": hexc("#80593a"), "Band": hexc("#3f2a19"), "Fur": hexc("#c9ab7f"),
             "LongHair": hexc("#43200f")})
    eyes()
    set_height(1.7)
    return b


def cherub():
    b = base("Kimono_Male")
    remove_headband(b)
    graft(b, blend("Casual2_Male"), "Hair")
    recolor({"Skin": hexc(SKIN["cherub"]), "Hair": hexc("#f2e2b0"), "Clothes": hexc("#f5f1e4"), "Band": hexc("#d8ad35")},
            emission={"Clothes": 0.25, "Band": 0.8, "Hair": 0.3})
    recolor({"Face": hexc("#6a4a12")})
    wings(b)
    set_height(2.2)
    return b


BUILDERS = {
    "scribe_female": scribe_female, "scribe_male": scribe_male, "adam": adam, "eve": eve,
    "adam_skins": adam_skins, "eve_skins": eve_skins, "cherub": cherub,
}

for cid, fn in BUILDERS.items():
    if ONLY and cid not in ONLY:
        continue
    fn()
    lo, hi = bbox()
    print("BUILT", cid, "size", tuple(round(v, 2) for v in (hi - lo)))
    export_glb(os.path.join(OUT, cid + ".glb"))
