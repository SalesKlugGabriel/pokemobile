"""Gera três famílias de coral estilizado para o ambiente submerso."""
import bpy
import math
import os
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../"))
OUT_DIR=os.path.join(ROOT,"assets/models/environment/corals")
parts=[]


def mat(name,color):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    bsdf=m.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value=(*color,1); bsdf.inputs["Roughness"].default_value=.78
    return m


MATS=[mat("CORAL_SUNSET",(.82,.20,.14)),mat("CORAL_ROSE",(.72,.18,.42)),mat("CORAL_GOLD",(.88,.52,.12))]


def segment(a,b,ra,rb,material):
    a=Vector(a); b=Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=ra,radius2=rb,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object; o.rotation_mode="QUATERNION"; o.rotation_quaternion=d.to_track_quat("Z","Y"); o.data.materials.append(material); parts.append(o)


def build(index):
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); parts.clear()
    material=MATS[index]
    branches=5+index*2
    for i in range(branches):
        ang=i*math.tau/branches+index*.43; radius=.12+.02*index
        base=(math.cos(ang)*.12,math.sin(ang)*.12,0)
        mid=(math.cos(ang)*(.24+.04*i),math.sin(ang)*(.24+.04*i),.42+.07*(i%3))
        tip=(math.cos(ang)*(.38+.05*(i%2)),math.sin(ang)*(.38+.05*(i%2)),.82+.13*(i%4))
        segment(base,mid,radius,radius*.72,material); segment(mid,tip,radius*.72,.025,material)
        if i%2==0:
            fork=(tip[0]+math.cos(ang+.8)*.22,tip[1]+math.sin(ang+.8)*.22,tip[2]+.18)
            segment(mid,fork,radius*.52,.02,material)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); obj=bpy.context.object; obj.name=["CORAL_BRANCH","CORAL_FAN","CORAL_CROWN"][index]
    min_z=min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:v.co.z-=min_z
    obj.location=(0,0,0); obj.data.update(); os.makedirs(OUT_DIR,exist_ok=True)
    path=os.path.join(OUT_DIR,["coral_branch.glb","coral_fan.glb","coral_crown.glb"][index])
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.ops.export_scene.gltf(filepath=path,export_format="GLB",use_selection=True,export_apply=True)
    print("WROTE",path)


if __name__=="__main__":
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for i in range(3):build(i)
