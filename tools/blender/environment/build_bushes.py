"""Gera três arbustos orgânicos, leves e reutilizáveis para o WORLD_LAB."""
import math, os, random, sys
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
sys.path.insert(0, os.path.dirname(__file__))
from tree_library import append_lobe
OUT = os.path.join(ROOT, "assets/models/environment/bushes")
SOURCE = os.path.join(OUT, "source/bush_library.blend")
DATA = {"01": (0.78, 1.05, 5, (0.10, .31, .07, 1)), "02": (1.12, .86, 6, (.13, .37, .08, 1)), "03": (.96, 1.38, 7, (.08, .27, .055, 1))}

def mat(key, color):
    value = bpy.data.materials.new("MAT_BUSH_" + key); value.use_nodes = True
    bsdf = value.node_tree.nodes.get("Principled BSDF"); bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = .86; return value

def build(key, data):
    height, radius, count, color = data; rng = random.Random("bush-" + key)
    verts, faces, materials = [], [], []
    for i in range(count):
        angle = math.tau * i / count + rng.uniform(-.28, .28)
        distance = radius * rng.uniform(.16, .57)
        center = Vector((math.cos(angle)*distance, rng.uniform(height*.28, height*.52), math.sin(angle)*distance))
        scale = Vector((radius*rng.uniform(.55,.78), height*rng.uniform(.46,.70), radius*rng.uniform(.48,.74)))
        append_lobe(verts, faces, materials, center, scale, 0, i + int(key)*17)
    mesh = bpy.data.meshes.new("BUSH_%s_MESH" % key); mesh.from_pydata(verts, [], faces); mesh.materials.append(mat(key, color)); mesh.update()
    obj = bpy.data.objects.new("BUSH_%s" % key, mesh); bpy.context.collection.objects.link(obj); return obj

def main():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    for key, data in DATA.items():
        obj = build(key, data); bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "bush_%s.glb" % key), export_format="GLB", use_selection=True, export_apply=True)
        print("WROTE", key, "triangles", len(obj.data.polygons))
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE)

if __name__ == "__main__": main()
