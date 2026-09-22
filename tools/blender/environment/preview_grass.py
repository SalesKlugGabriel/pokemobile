"""Cena de inspeção dos três tufos, para render ortogonal da biblioteca."""
import os

import bpy

ROOT = os.environ.get("POKEMOBILE_ROOT", os.getcwd())
for index, variant in enumerate(["short", "mid", "tall"]):
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/models/environment/grass/grass_%s.glb" % variant))
    obj = bpy.context.selected_objects[0]
    obj.location.x = (index - 1) * 1.25
