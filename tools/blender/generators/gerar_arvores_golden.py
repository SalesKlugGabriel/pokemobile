"""Gera cinco árvores stylized/organic para a Golden Test Scene.

Cada variante é um GLB game-ready: uma malha combinada, materiais PBR simples,
origem no solo e silhueta distinta. A distribuição/instancing fica no Godot.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
OUT_DIR = os.path.join(ROOT, "assets/models/environment/trees")
parts = []


def mat(name, color, roughness):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return m


BARK = mat("TREE_BARK", (0.20, 0.075, 0.028), 0.94)
BARK_LIGHT = mat("TREE_BARK_LIGHT", (0.34, 0.14, 0.045), 0.90)
LEAVES = [
    mat("TREE_LEAF_DEEP", (0.035, 0.18, 0.055), 0.88),
    mat("TREE_LEAF_MID", (0.08, 0.34, 0.095), 0.84),
    mat("TREE_LEAF_LIGHT", (0.22, 0.48, 0.12), 0.82),
]


def segment(name, a, b, ra, rb, material):
    a = Vector(a); b = Vector(b); direction = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=ra, radius2=rb,
                                    depth=direction.length, location=(a + b) * 0.5)
    o = bpy.context.object; o.name = name
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = direction.to_track_quat("Z", "Y")
    o.data.materials.append(material); parts.append(o)
    return o


def cluster(name, center, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=center)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material); parts.append(o)
    return o


VARIANTS = [
    # height, trunk lean, branch angle, canopy count, seed-like offset
    (6.2, -0.15, 0.75, 8, 0.0),
    (5.3, 0.22, 0.62, 7, 1.3),
    (7.0, -0.28, 0.90, 10, 2.7),
    (5.8, 0.34, 0.55, 9, 4.1),
    (6.6, 0.05, 1.02, 11, 5.4),
]


def clear_objects():
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    parts.clear()


def build(index):
    height, lean, branch_angle, canopy_count, phase = VARIANTS[index]
    clear_objects()
    trunk_top = height * 0.64
    trunk_end = Vector((lean, 0.0, trunk_top))
    segment("TREE_TRUNK", (0, 0, 0), trunk_end, 0.48, 0.22, BARK)
    # Exposed roots give the base an organic contact with the ground.
    for r in range(5):
        ang = phase + r * math.tau / 5.0
        root_end = Vector((math.cos(ang) * 0.95, math.sin(ang) * 0.95, 0.08))
        segment("TREE_ROOT", (0, 0, 0.18), root_end, 0.16, 0.025, BARK_LIGHT)

    branches = []
    for b in range(5):
        t = 0.34 + b * 0.11
        base = trunk_end * t
        ang = phase + b * 2.399
        length = 1.25 + (b % 3) * 0.28
        end = base + Vector((math.cos(ang) * length, math.sin(ang) * length, branch_angle * (0.7 + 0.15 * b)))
        segment("TREE_BRANCH", base, end, 0.18 - b * 0.018, 0.055, BARK_LIGHT)
        branches.append(end)

    for c in range(canopy_count):
        anchor = branches[c % len(branches)]
        ang = phase + c * 2.17
        center = anchor + Vector((math.cos(ang) * 0.32, math.sin(ang) * 0.32, 0.22 + (c % 3) * 0.18))
        scale = Vector((0.72 + (c % 3) * 0.12, 0.58 + (c % 2) * 0.16, 0.62 + (c % 4) * 0.09))
        cluster("TREE_FOLIAGE_CLUSTER", center, scale, LEAVES[c % len(LEAVES)])
    # Crown cap closes the silhouette without creating one perfect sphere.
    cluster("TREE_FOLIAGE_CROWN", trunk_end + Vector((0, 0, 0.55)), Vector((1.0, .82, .72)), LEAVES[(index + 1) % 3])

    bpy.ops.object.select_all(action="DESELECT")
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh = bpy.context.object; mesh.name = "TREE_%s" % chr(ord("A") + index)
    # Ensure the contact plane is exactly the origin and keep runtime scale in
    # meters. Trees intentionally remain between 5 and 7 m for the golden scale.
    min_z = min(v.co.z for v in mesh.data.vertices)
    for v in mesh.data.vertices: v.co.z -= min_z
    # Joined parts inherit the first primitive's origin; reset it after the
    # vertex rebase so the exported node itself sits on the ground plane.
    mesh.location = (0.0, 0.0, 0.0)
    mesh.data.update()
    bpy.ops.object.select_all(action="DESELECT"); mesh.select_set(True); bpy.context.view_layer.objects.active = mesh
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "tree_%s.glb" % chr(ord("a") + index))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("WROTE", path)


if __name__ == "__main__":
    # Keep the materials created above; clear only scene objects so reruns are
    # idempotent without invalidating their datablocks.
    clear_objects()
    for i in range(len(VARIANTS)):
        build(i)
