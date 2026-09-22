"""Cena mínima de inspeção da árvore C pelo render ortogonal do projeto."""
import os

import bpy

ROOT = os.environ.get("POKEMOBILE_ROOT", os.getcwd())
bpy.ops.import_scene.gltf(
    filepath=os.path.join(ROOT, "assets/models/environment/trees/tree_c.glb"))
