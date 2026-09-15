"""Gera cinco rochas estilizadas e determinísticas para a Golden Scene."""
import bpy
import math
import os
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
OUT_DIR = os.path.join(ROOT, "assets/models/environment/rocks")
SPECS = [
    ("rock_small", (.55,.42,.48), 11), ("rock_round", (.90,.68,.82), 23),
    ("rock_angular", (1.15,.95,.76), 37), ("rock_flat", (1.35,.42,1.05), 51),
    ("rock_large", (1.65,1.45,1.28), 79),
]


def material(name, color):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    bsdf=m.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value=(*color,1)
    bsdf.inputs["Roughness"].default_value=.92; return m


ROCK_MATS=[material("ROCK_COOL",(.25,.28,.27)), material("ROCK_MOSS",(.28,.31,.23)), material("ROCK_WARM",(.35,.29,.24))]


def build(name, scale, seed, index):
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0,0,0))
    obj=bpy.context.object; obj.name=name.upper(); obj.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for v in obj.data.vertices:
        direction=v.co.normalized(); variation=.82+rng.random()*.32
        v.co*=variation
        if v.co.z < -.18: v.co.z=max(v.co.z,-.38)  # stable contact plane
    bevel=obj.modifiers.new("ROCK_EDGE_TREATMENT","BEVEL"); bevel.width=.045; bevel.segments=2
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(ROCK_MATS[index%len(ROCK_MATS)])
    min_z=min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices: v.co.z-=min_z
    obj.location=(0,0,0); obj.data.update()
    os.makedirs(OUT_DIR,exist_ok=True)
    path=os.path.join(OUT_DIR,name+".glb")
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path,export_format="GLB",use_selection=True,export_apply=True)
    print("WROTE",path)


if __name__=="__main__":
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for i,spec in enumerate(SPECS): build(*spec,i)
