"""Shared helpers for the Blender (bpy) art build scripts.

Run the build scripts with Blender's Python module (pip package `bpy`, Python 3.11), for example:
    python3.11 tools/art/build_characters.py -- <sources dir> <output dir>
See tools/art/README.md for how to get the source packs.
"""
import math
import os

import bmesh
import bpy
import mathutils


def srgb(r, g, b):
    """Convert an sRGB color (0-1) to Blender's linear color."""
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


def hexc(h):
    h = h.lstrip("#")
    return srgb(int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255)


def open_blend(path):
    bpy.ops.wm.open_mainfile(filepath=path)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _surface_source(mat):
    """Find the color (and image, if any) that the material actually shows."""
    color = tuple(mat.diffuse_color)
    image = None
    if mat.use_nodes and mat.node_tree:
        out = mat.node_tree.get_output_node("ALL") or mat.node_tree.get_output_node("CYCLES") or mat.node_tree.get_output_node("EEVEE")
        if out and out.inputs["Surface"].is_linked:
            shader = out.inputs["Surface"].links[0].from_node
            key = "Base Color" if shader.type == "BSDF_PRINCIPLED" else "Color"
            if key in shader.inputs:
                inp = shader.inputs[key]
                if inp.is_linked and inp.links[0].from_node.type == "TEX_IMAGE":
                    image = inp.links[0].from_node.image
                else:
                    color = tuple(inp.default_value)
                    # Old Quaternius files keep the real color in the viewport color when the node is left white.
                    if shader.type == "BSDF_PRINCIPLED" and max(color[:3]) > 0.79 and mat.diffuse_color[:3] != (0.8, 0.8, 0.8):
                        color = tuple(mat.diffuse_color)
    return color, image


def simple_material(mat, color=None, image=None, emission=0.0, roughness=1.0):
    """Rebuild a material as a plain Principled BSDF so it exports cleanly to glTF."""
    if color is None and image is None:
        color, image = _surface_source(mat)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = color
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = color if color else (1, 1, 1, 1)
    return mat


def normalize_materials():
    for m in list(bpy.data.materials):
        if m.users:
            simple_material(m)


def recolor(colors, emission=None):
    """colors: {material name: (r,g,b,a) linear}. emission: {material name: strength}."""
    emission = emission or {}
    for name, c in colors.items():
        m = bpy.data.materials.get(name)
        if m:
            simple_material(m, color=c, emission=emission.get(name, 0.0))


def armature():
    return [o for o in bpy.data.objects if o.type == "ARMATURE"][0]


def body():
    arm = armature()
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]
    return max(meshes, key=lambda o: len(o.data.vertices))


def keep_actions(names):
    for a in list(bpy.data.actions):
        if a.name not in names:
            bpy.data.actions.remove(a)
    for a in bpy.data.actions:
        a.use_fake_user = True


def delete_faces(obj, material, zmin=-1e9, zmax=1e9, keep=False):
    """Delete the faces using `material` whose center lies between zmin and zmax (world space).
    With keep=True, delete every face that does NOT match instead."""
    idx = material_index(obj, material)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    doomed = []
    for f in bm.faces:
        z = (mw @ f.calc_center_median()).z
        hit = f.material_index == idx and zmin <= z <= zmax
        if hit != keep:
            doomed.append(f)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def material_index(obj, name):
    """Index of the slot whose material is `name` (or `name.001` etc. after an append)."""
    for i, m in enumerate(obj.data.materials):
        if m and (m.name == name or (m.name.startswith(name + ".") and m.name[len(name) + 1:].isdigit())):
            return i
    return -1


def append_body(blend_path):
    """Append the character mesh from another Quaternius character file (same skeleton)."""
    with bpy.data.libraries.load(blend_path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    meshes = []
    for o in dst.objects:
        if o is None:
            continue
        if o.type == "MESH":
            bpy.context.scene.collection.objects.link(o)
            meshes.append(o)
    return max(meshes, key=lambda o: len(o.data.vertices))


def graft(target, blend_path, material, zmin=-1e9, zmax=1e9, rename=None):
    """Copy the faces of `material` (e.g. hair) from another character onto `target`."""
    src = append_body(blend_path)
    src.parent = None
    src.matrix_world = target.matrix_world.copy()
    delete_faces(src, material, zmin, zmax, keep=True)
    for md in list(src.modifiers):
        src.modifiers.remove(md)
    if rename:
        src.data.materials[material_index(src, material)].name = rename
    join(target, [src])
    # Remove the armature objects that came along with the appended file.
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE" and o is not armature_of(target):
            bpy.data.objects.remove(o)


def armature_of(obj):
    for md in obj.modifiers:
        if md.type == "ARMATURE":
            return md.object
    return obj.parent


def join(target, others):
    bpy.ops.object.select_all(action="DESELECT")
    for o in others:
        o.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()


def new_material(name, color, emission=0.0, roughness=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    return simple_material(m, color=color, emission=emission, roughness=roughness)


def prop(mesh_fn, material, bone, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), **kw):
    """Create a primitive, give it a material, and bind it fully to `bone` so it moves with
    the skeleton. Returns the new object (join it into the body afterwards)."""
    bpy.ops.object.select_all(action="DESELECT")
    mesh_fn(location=loc, rotation=rot, scale=scale, **kw)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    vg = o.vertex_groups.new(name=bone)
    vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def section_extent(obj, z, axis="y", band=0.06, xmax=0.25):
    """Front/back (or side) extent of the body near height z, for wrapping straps around it."""
    mw = obj.matrix_world
    vals = []
    for v in obj.data.vertices:
        w = mw @ v.co
        if abs(w.z - z) < band and abs(w.x) < xmax:
            vals.append(getattr(w, axis))
    return (min(vals), max(vals)) if vals else (-0.3, 0.3)


def set_height(target_height):
    """Scale the armature object (not applied, so animations stay correct) to a real height in meters."""
    arm = armature()
    b = body()
    bpy.context.view_layer.update()
    zs = [(b.matrix_world @ v.co).z for v in b.data.vertices]
    h = max(zs) - min(zs)
    arm.scale = arm.scale * (target_height / h)


def bake_skinned_mesh_transforms():
    """glTF viewers (Godot included) ignore a skinned mesh's own transform and only use the
    skeleton's. Move each skinned mesh's offset from its armature into the vertices."""
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        arm = armature_of(o) if o.type == "MESH" else None
        if arm is None or arm.type != "ARMATURE":
            continue
        m = arm.matrix_world.inverted() @ o.matrix_world
        if all(abs(a - b) < 1e-6 for ra, rb in zip(m, mathutils.Matrix.Identity(4)) for a, b in zip(ra, rb)):
            continue
        o.data.transform(m)
        o.parent = arm
        o.matrix_parent_inverse = mathutils.Matrix.Identity(4)
        o.matrix_basis = mathutils.Matrix.Identity(4)


def _fcurves(action):
    try:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    yield from bag.fcurves
    except AttributeError:
        yield from action.fcurves


def apply_armature_transform():
    """Bake the armature object's own transform (its scale above all) into the bones, meshes and
    animations, so the exported skeleton has an identity root. Godot otherwise folds the root scale
    into the bone rests, and animations that key bone scale or location then come out the wrong size."""
    arm = armature()
    k = arm.matrix_world.to_scale().x
    bake_skinned_mesh_transforms()
    if arm.parent is not None:
        raise RuntimeError("armature with a parent is not supported")
    a = arm.matrix_basis.copy()
    for o in bpy.data.objects:
        if o.type == "MESH" and armature_of(o) is arm:
            o.data.transform(a)
    arm.data.transform(a)
    arm.matrix_basis = mathutils.Matrix.Identity(4)
    bpy.context.view_layer.update()
    if abs(k - 1.0) > 1e-6:
        for a in bpy.data.actions:
            for fc in _fcurves(a):
                if fc.data_path.startswith("pose.bones") and fc.data_path.endswith(".location"):
                    for kp in fc.keyframe_points:
                        kp.co.y *= k
                        kp.handle_left.y *= k
                        kp.handle_right.y *= k


def export_glb(path, animations=True, separate_textures=False):
    """Export a .glb, or with separate_textures a .gltf + .bin whose textures go to a shared
    textures/ folder next to it (so many models can share one copy of each texture)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if any(o.type == "ARMATURE" for o in bpy.data.objects):
        apply_armature_transform()
    for o in bpy.data.objects:
        o.select_set(o.type in ("MESH", "ARMATURE"))
    kw = dict(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=animations,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )
    if separate_textures:
        kw.update(filepath=os.path.splitext(path)[0] + ".gltf", export_format="GLTF_SEPARATE", export_texture_dir="textures")
        path = kw["filepath"]
    if animations:
        kw.update(export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_step=2,
                  export_optimize_animation_size=True, export_def_bones=True)
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, os.path.getsize(path))


def bbox(objs=None):
    objs = objs or [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    pts = []
    for o in objs:
        pts += [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def downscale_images(max_size):
    for img in bpy.data.images:
        if img.size[0] > max_size:
            img.scale(max_size, max_size)
