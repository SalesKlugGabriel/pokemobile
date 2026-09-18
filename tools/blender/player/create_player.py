"""Fase 2 — cria apenas a MALHA do treinador, sem rig ou GLB oficial.

Uso: blender --background --python tools/blender/player/create_player.py
Reexecutar substitui somente a cena gerada neste arquivo; não toca no player.glb
existente nem em cenas do Godot.
"""

import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../../.."))
OUTPUT_DIR = os.path.join(PROJECT_DIR, "assets/characters/player_v1")
sys.path.insert(0, SCRIPT_DIR)

from geometry_player import build_player  # noqa: E402
from materials_player import create_materials  # noqa: E402


def create():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    parent = bpy.data.collections.new("PLAYER_V1_CHARACTER")
    bpy.context.scene.collection.children.link(parent)
    meshes = bpy.data.collections.new("PLAYER_V1_MESH")
    parent.children.link(meshes)
    materials = create_materials()
    build_player(meshes, materials)
    for obj in meshes.objects:
        obj.display_type = "TEXTURED"
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    blend_path = os.path.join(OUTPUT_DIR, "player_v1.blend")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    triangle_count = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes.objects)
    print(f"PLAYER_V1_MODEL objects={len(meshes.objects)} triangles={triangle_count} materials={len(materials)} path={blend_path}")


if __name__ == "__main__":
    create()
