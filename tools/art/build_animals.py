"""Build the animals from Quaternius' CC0 animal packs and export them as .glb files for Godot.

Usage: python3.11 tools/art/build_animals.py -- <sources dir> <output dir> [only_id ...]

Each animal gets real-world size (longest horizontal side, in meters) and up to two animations,
renamed to Idle and Walk so the game can treat every animal the same way.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from artlib import armature, bbox, export_glb, normalize_materials, open_blend  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = ARGS[0], ARGS[1]
ONLY = set(ARGS[2:])
FARM = os.path.join(SRC, "Farm Animals by @Quaternius", "Blends")
VOL2 = os.path.join(SRC, "Animal Pack Vol.2 by @Quaternius", "Blends")
VOL1 = os.path.join(SRC, "Animals Pack by Quaternius", "Blends")

# id: (file, length in meters, {source action: our name})
ANIMALS = {
    "cow": (os.path.join(FARM, "Cow.blend"), 2.2, {"Idle": "Idle", "Walk": "Walk"}),
    "horse": (os.path.join(FARM, "Horse.blend"), 2.3, {"Idle": "Idle", "Walk": "Walk"}),
    "sheep": (os.path.join(FARM, "Sheep.blend"), 1.3, {"Idle": "Idle", "Walk": "Walk"}),
    "pig": (os.path.join(FARM, "Pig.blend"), 1.3, {"Idle": "Idle", "Walk": "Walk"}),
    "llama": (os.path.join(FARM, "Llama.blend"), 1.7, {"Idle": "Idle", "Walk": "Walk"}),
    "zebra": (os.path.join(FARM, "Zebra.blend"), 2.2, {"Idle": "Idle", "Walk": "Walk"}),
    "wolf": (os.path.join(VOL2, "Wolf.blend"), 1.4, {"Idle": "Idle", "Walking": "Walk"}),
    "dog": (os.path.join(VOL2, "Dog.blend"), 0.9, {"Idle": "Idle", "Walking": "Walk", "Walk": "Walk"}),
    "cat": (os.path.join(VOL2, "Cat.blend"), 0.6, {"Idle": "Idle", "Walking": "Walk", "Walk": "Walk"}),
    "eagle": (os.path.join(VOL2, "Eagle.blend"), 1.8, {"Idle": "Idle", "Flying": "Walk", "Fly": "Walk"}),
    "fox": (os.path.join(VOL1, "Red Fox.blend"), 0.9, {"ArmatureAction": "Walk"}),
    "bird": (os.path.join(VOL1, "Bird.blend"), 0.5, {"ArmatureAction": "Walk"}),
    "chick": (os.path.join(VOL1, "Chick.blend"), 0.25, {"ArmatureAction": "Walk"}),
    "fish": (os.path.join(VOL1, "Fish.blend"), 0.5, {"ArmatureAction": "Walk"}),
    "whale": (os.path.join(VOL1, "Whale.blend"), 7.0, {"ArmatureAction": "Walk"}),
}


def build(path, length, actions):
    open_blend(path)
    print("ACTIONS IN", os.path.basename(path), [a.name for a in bpy.data.actions])
    for a in list(bpy.data.actions):
        key = a.name.split(".")[0]
        if key in actions:
            a.name = "__" + actions[key]
        else:
            bpy.data.actions.remove(a)
    for a in list(bpy.data.actions):
        a.name = a.name[2:]
        a.use_fake_user = True
    # Remove anything that is not part of the animal (cameras, lights, ground planes).
    arm = armature()
    for o in list(bpy.data.objects):
        if o.type not in ("MESH", "ARMATURE") or (o.type == "MESH" and o.parent is None and not any(m.type == "ARMATURE" for m in o.modifiers)):
            bpy.data.objects.remove(o)
    normalize_materials()
    bpy.context.scene.frame_set(0)
    lo, hi = bbox()
    size = hi - lo
    k = length / max(size.x, size.y)
    arm.scale = arm.scale * k
    arm.location = arm.location * k
    bpy.context.view_layer.update()
    lo, hi = bbox()
    # Stand on the ground (z = 0) at the origin.
    arm.location.z -= lo.z
    arm.location.x -= (lo.x + hi.x) / 2
    arm.location.y -= (lo.y + hi.y) / 2


for aid, (path, length, actions) in ANIMALS.items():
    if ONLY and aid not in ONLY:
        continue
    build(path, length, actions)
    lo, hi = bbox()
    print("BUILT", aid, "size", tuple(round(v, 2) for v in (hi - lo)), [a.name for a in bpy.data.actions])
    export_glb(os.path.join(OUT, aid + ".glb"))
