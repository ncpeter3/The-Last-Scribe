"""Build scenery (from Quaternius' CC0 Stylized Nature MegaKit) and the serpent (made here) as .glb files.

Usage: python3.11 tools/art/build_nature.py -- <sources dir> <output dir>

Textures are shrunk to 512 px and normal maps are dropped to keep the Android download small.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import mathutils  # noqa: E402
from artlib import bbox, export_glb, hexc, new_material, reset  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = ARGS[0], ARGS[1]
KIT = os.path.join(SRC, "glTF")
TEX_SIZE = 512
DECIMATE = 0.45  # keep this share of triangles on big models (phones draw many of them)

# Output name: (source model, scale)
NATURE = {
    "tree_1": ("CommonTree_1", 1.0), "tree_2": ("CommonTree_2", 1.0), "tree_3": ("CommonTree_3", 1.0),
    "tree_4": ("CommonTree_4", 1.0), "tree_5": ("CommonTree_5", 1.0),
    "twisted_tree": ("TwistedTree_1", 1.0), "dead_tree": ("DeadTree_1", 1.0), "pine": ("Pine_1", 1.0),
    "bush": ("Bush_Common", 1.0), "bush_flowers": ("Bush_Common_Flowers", 1.0),
    "flowers_1": ("Flower_3_Group", 1.0), "flowers_2": ("Flower_4_Group", 1.0),
    "grass_short": ("Grass_Common_Short", 1.0), "grass_tall": ("Grass_Wispy_Tall", 1.0),
    "fern": ("Fern_1", 1.0), "plant": ("Plant_1_Big", 1.0), "clover": ("Clover_1", 1.0),
    "rock_1": ("Rock_Medium_1", 1.0), "rock_2": ("Rock_Medium_2", 1.0), "rock_3": ("Rock_Medium_3", 1.0),
    "pebble": ("Pebble_Round_2", 1.0),
}


# The free kit's plain bush uses the red autumn leaves; give it the green leaf texture (same layout).
RETEXTURE = {"Bush_Common": {"Leaves_TwistedTree_C.png": "Leaves_NormalTree_C.png"}}


def convert(src_name):
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, src_name + ".gltf"))
    for old, new in RETEXTURE.get(src_name, {}).items():
        for img in list(bpy.data.images):
            if img.filepath.endswith(old) or img.name in (old, os.path.splitext(old)[0]):
                img.filepath = os.path.join(KIT, new)
                img.name = os.path.splitext(new)[0]
                img.reload()
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type == "NORMAL_MAP":
                nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.name.lower().endswith("_normal.png"):
                nt.nodes.remove(n)
    for o in bpy.data.objects:
        if o.type == "MESH" and len(o.data.polygons) > 1500:
            md = o.modifiers.new("decimate", "DECIMATE")
            md.ratio = DECIMATE
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=md.name)
    for img in bpy.data.images:
        if img.users and img.size[0] > TEX_SIZE:
            w, h = img.size
            img.scale(TEX_SIZE, max(1, int(TEX_SIZE * h / w)))


def serpent():
    """The serpent in the garden: a coiled, upright snake made of a beveled curve."""
    reset()
    body_m = new_material("SerpentBody", hexc("#4f8f3a"))
    belly = new_material("SerpentBelly", hexc("#d9c75a"))
    eye_m = new_material("SerpentEye", hexc("#f2d23c"), emission=0.6)
    curve = bpy.data.curves.new("serpent", "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("NURBS")
    pts = []
    # Two loose coils on the ground, then the neck rising up.
    for i in range(18):
        t = i / 17.0
        ang = t * math.pi * 4.0
        r = 0.45 - 0.2 * t
        pts.append((r * math.cos(ang), r * math.sin(ang), 0.07 + 0.05 * t))
    for i in range(1, 7):
        t = i / 6.0
        pts.append((0.25 + 0.05 * t, 0.05 * math.sin(t * 3), 0.12 + 0.75 * math.sin(t * math.pi / 2)))
    spline.points.add(len(pts) - 1)
    for p, c in zip(spline.points, pts):
        p.co = (c[0], c[1], c[2], 1.0)
    spline.order_u = 4
    spline.use_endpoint_u = True
    curve.bevel_depth = 0.065
    curve.bevel_resolution = 1
    curve.resolution_u = 4
    taper = bpy.data.curves.new("taper", "CURVE")
    ts = taper.splines.new("POLY")
    ts.points.add(3)
    for p, c in zip(ts.points, [(0, 0.25), (0.15, 1.0), (0.85, 1.0), (1.0, 0.85)]):
        p.co = (c[0], c[1], 0, 1)
    taper_obj = bpy.data.objects.new("taper", taper)
    bpy.context.scene.collection.objects.link(taper_obj)
    curve.taper_object = taper_obj
    obj = bpy.data.objects.new("Serpent", curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.data.objects.remove(taper_obj)
    obj.data.materials.append(body_m)
    # Head: a flattened, pointed sphere looking forward (-Y in Blender = toward the viewer in Godot +Z).
    end = mathutils.Vector(pts[-1])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, location=end + mathutils.Vector((0, -0.08, 0.02)), scale=(0.11, 0.17, 0.08))
    head = bpy.context.active_object
    head.data.materials.append(body_m)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, location=end + mathutils.Vector((0, -0.06, -0.035)), scale=(0.08, 0.13, 0.03))
    jaw = bpy.context.active_object
    jaw.data.materials.append(belly)
    eyes = []
    for s in (1, -1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, location=end + mathutils.Vector((s * 0.075, -0.15, 0.06)), scale=(0.025, 0.025, 0.025))
        e = bpy.context.active_object
        e.data.materials.append(eye_m)
        eyes.append(e)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [head, jaw] + eyes:
        o.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    for p in obj.data.polygons:
        p.use_smooth = False


for out_name, (src, _scale) in NATURE.items():
    convert(src)
    lo, hi = bbox()
    print("BUILT", out_name, "size", tuple(round(v, 2) for v in (hi - lo)))
    export_glb(os.path.join(OUT, out_name + ".glb"), animations=False, separate_textures=True)

serpent()
lo, hi = bbox()
print("BUILT serpent size", tuple(round(v, 2) for v in (hi - lo)))
export_glb(os.path.join(OUT, "serpent.glb"), animations=False)
