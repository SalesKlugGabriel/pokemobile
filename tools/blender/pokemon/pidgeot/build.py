"""Gera fonte e GLB de trabalho; o canônico 18.glb só muda após validação."""
import os
import sys
import bpy

sys.path.insert(0,os.path.dirname(__file__))
from geometry import Geometry
import materials
import rig
import animation

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../.."))
OUT=os.path.join(ROOT,"assets/models/pokemon/source/pidgeot_golden")
BLEND=os.path.join(OUT,"Pidgeot_Golden_Working.blend")
GLB=os.path.join(OUT,"Pidgeot_Golden_Working.glb")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    os.makedirs(OUT,exist_ok=True)
    geometry=Geometry().build()
    arm,mesh=rig.create(geometry,materials.create())
    if mesh.data.validate(verbose=True):
        raise RuntimeError("Pidgeot Golden possui geometria inválida")
    front=bpy.data.objects.new("PKM_PIDGEOT_FRONT_REFERENCE",None)
    front.empty_display_size=.025
    front.location=(0,.56,1.20)
    bpy.context.collection.objects.link(front)
    animation.create(arm)
    bpy.context.scene.render.fps=30
    bpy.context.view_layer.objects.active=arm
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    for item in (arm,mesh,front): item.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB,export_format="GLB",use_selection=True,
                              export_animations=True,export_nla_strips=True)
    triangles=sum(len(face.vertices)-2 for face in mesh.data.polygons)
    print("PIDGEOT_WORKING",GLB)
    print("PIDGEOT_METRICS",triangles,len(mesh.data.vertices),len(arm.data.bones),len(bpy.data.actions))


if __name__=="__main__":
    main()
