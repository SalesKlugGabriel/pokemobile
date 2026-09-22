"""Exporta a biblioteca de rochas estilizadas da World Factory V1."""
import os, sys
import bpy
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../..")); sys.path.insert(0,os.path.dirname(__file__))
from rock_library import VARIANTS, build
OUT=os.path.join(ROOT,"assets/models/environment/rocks"); SOURCE=os.path.join(OUT,"source/rock_library.blend")
COLORS={"small":(.28,.31,.29,1),"round":(.31,.33,.31,1),"angular":(.36,.31,.27,1),"flat":(.34,.32,.28,1),"large":(.29,.30,.28,1)}
def main():
 bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); os.makedirs(os.path.dirname(SOURCE),exist_ok=True)
 for key in VARIANTS:
  verts,faces=build(key); mesh=bpy.data.meshes.new("ROCK_%s_MESH"%key.upper()); mesh.from_pydata(verts,[],faces); mesh.update()
  material=bpy.data.materials.new("MAT_ROCK_%s"%key.upper()); material.use_nodes=True; bsdf=material.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value=COLORS[key]; bsdf.inputs["Roughness"].default_value=.9; mesh.materials.append(material)
  obj=bpy.data.objects.new("ROCK_%s"%key.upper(),mesh); bpy.context.collection.objects.link(obj); bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
  bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,"rock_%s.glb"%key),export_format="GLB",use_selection=True,export_apply=True); print("WROTE",key,"triangles",len(mesh.polygons))
 bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
if __name__=="__main__": main()
