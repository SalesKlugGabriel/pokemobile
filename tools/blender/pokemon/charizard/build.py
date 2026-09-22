"""Constrói Charizard Golden em paths de trabalho; não toca no 6.glb."""
import os
import sys
import bpy

sys.path.insert(0, os.path.dirname(__file__))
from geometry import Geometry
import materials
import rig
import animation

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
OUT = os.path.join(ROOT, "assets/models/pokemon/source/charizard_golden")
BLEND = os.path.join(OUT, "Charizard_Golden_Working.blend")
GLB = os.path.join(OUT, "Charizard_Golden_Working.glb")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT, exist_ok=True)
    body = Geometry().build()
    arm, mesh = rig.create(body, materials.create())
    if mesh.data.validate(verbose=True):
        raise RuntimeError("Charizard Golden possui faces inválidas")
    front = bpy.data.objects.new("PKM_CHARIZARD_FRONT_REFERENCE", None)
    front.empty_display_size = .035
    front.location = (0, .66, 1.50)
    bpy.context.collection.objects.link(front)
    animation.create(arm)
    bpy.context.scene.render.fps = 30
    bpy.context.view_layer.objects.active = arm
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    front.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True,
                              export_animations=True, export_nla_strips=True)
    print("WORKING_BLEND", BLEND)
    print("WORKING_GLB", GLB)
    print("METRICS vertices=%d polygons=%d bones=%d materials=%d actions=%d" %
          (len(mesh.data.vertices), len(mesh.data.polygons), len(arm.data.bones),
           len(mesh.data.materials), len(bpy.data.actions)))


if __name__ == "__main__":
    main()
