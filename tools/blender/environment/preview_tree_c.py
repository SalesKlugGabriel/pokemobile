"""Cena mínima de inspeção da árvore C pelo render ortogonal do projeto."""
import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
bpy.ops.import_scene.gltf(
    filepath=os.path.join(ROOT, "assets/models/environment/trees/tree_c.glb"))
