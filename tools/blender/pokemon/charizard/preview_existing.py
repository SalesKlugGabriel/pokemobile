"""Baseline visual do GLB canônico, usando o render ortogonal do projeto."""
import os
import bpy

root = os.environ.get("POKEMOBILE_ROOT", os.getcwd())
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "assets/models/pokemon/6.glb"))
