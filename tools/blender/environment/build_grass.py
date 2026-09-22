"""Exporta GRASS_SHORT, GRASS_MID e GRASS_TALL e guarda sua fonte Blender."""
import math
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
sys.path.insert(0, os.path.dirname(__file__))
from grass_library import VARIANTS, build_cluster

OUT_DIR = os.path.join(ROOT, "assets/models/environment/grass")
SOURCE_PATH = os.path.join(OUT_DIR, "source/grass_library.blend")


def material(name, color):
    value = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    value.use_nodes = True
    bsdf = value.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = .88
    bsdf.inputs["Specular IOR Level"].default_value = .18
    return value


def make_variant(variant):
    vertices, faces = build_cluster(variant)
    mesh = bpy.data.meshes.new("GRASS_%s_MESH" % variant.upper())
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material("MAT_GRASS_%s" % variant.upper(), VARIANTS[variant]["color"]))
    mesh.update()
    obj = bpy.data.objects.new("GRASS_%s" % variant.upper(), mesh)
    bpy.context.collection.objects.link(obj)
    # Mantém a convenção validada pela biblioteca anterior: Blender Z-up → Godot Y-up.
    obj.rotation_euler.x = math.radians(90.0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def export_variant(obj, variant):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT_DIR, "grass_%s.glb" % variant)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("WROTE", path, "triangles", len(obj.data.polygons))


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    os.makedirs(os.path.dirname(SOURCE_PATH), exist_ok=True)
    objects = {variant: make_variant(variant) for variant in VARIANTS}
    for variant, obj in objects.items():
        export_variant(obj, variant)
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_PATH)
    print("WROTE", SOURCE_PATH)


if __name__ == "__main__":
    main()
