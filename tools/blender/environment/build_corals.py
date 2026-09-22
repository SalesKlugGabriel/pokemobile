"""Exporta corais ramificados game-ready sem cones/cilindros de primitive."""
import math, os, sys
import bpy
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../..")); sys.path.insert(0,os.path.dirname(__file__))
from tree_library import append_tube
OUT=os.path.join(ROOT,"assets/models/environment/corals"); SOURCE=os.path.join(OUT,"source/coral_library.blend")
DATA={"branch":(5,(.82,.20,.14,1)),"fan":(7,(.72,.18,.42,1)),"crown":(9,(.88,.52,.12,1))}
def main():
 bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); os.makedirs(os.path.dirname(SOURCE),exist_ok=True)
 for key,(count,color) in DATA.items():
  verts=[]; faces=[]; mats=[]
  for i in range(count):
   angle=math.tau*i/count + (0.22 if key=="fan" else 0); base=Vector((math.cos(angle)*.10,0,math.sin(angle)*.10)); mid=Vector((math.cos(angle)*(.18+.025*(i%3)),.34+.06*(i%2),math.sin(angle)*(.18+.025*(i%3)))); tip=Vector((math.cos(angle)*(.34+.04*(i%2)),.72+.10*(i%3),math.sin(angle)*(.34+.04*(i%2))))
   append_tube(verts,faces,mats,[base,mid,tip],[.105,.072,.025],0,6)
   if i%2==0:
    fork=mid.lerp(tip,.55)+Vector((math.cos(angle+.72)*.18,.15,math.sin(angle+.72)*.18)); append_tube(verts,faces,mats,[mid,fork],[.055,.018],0,6)
  mesh=bpy.data.meshes.new("CORAL_%s_MESH"%key.upper()); mesh.from_pydata(verts,[],faces); mesh.update(); material=bpy.data.materials.new("MAT_CORAL_%s"%key.upper()); material.use_nodes=True; bsdf=material.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value=color; bsdf.inputs["Roughness"].default_value=.76; mesh.materials.append(material)
  obj=bpy.data.objects.new("CORAL_%s"%key.upper(),mesh); bpy.context.collection.objects.link(obj); bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj; bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,"coral_%s.glb"%key),export_format="GLB",use_selection=True,export_apply=True); print("WROTE",key,"triangles",len(mesh.polygons))
 bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
if __name__=="__main__": main()
