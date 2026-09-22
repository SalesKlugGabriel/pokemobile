"""Importa apenas o GLB de trabalho na régua ortogonal do projeto."""
import os
import bpy

root = os.environ.get("POKEMOBILE_ROOT", os.getcwd())
path = os.path.join(root, "assets/models/pokemon/source/charizard_golden/Charizard_Golden_Working.glb")
bpy.ops.import_scene.gltf(filepath=path)
