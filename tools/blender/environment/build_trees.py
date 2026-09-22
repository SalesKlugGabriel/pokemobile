"""Exporta TREE_A..E com troncos ramificados e copas em lobos orgânicos."""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from tree_library import VARIANTS, append_lobe, append_tube

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
OUT = os.path.join(ROOT, "assets/models/environment/trees")
SOURCE = os.path.join(OUT, "source")

def material(name, color):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = .88
    return mat

MATERIALS = [material("TREE_BARK_DARK", (.10, .045, .018)), material("TREE_BARK_WARM", (.27, .10, .035)), material("TREE_LEAF_DEEP", (.025, .15, .055)), material("TREE_LEAF_SUN", (.13, .39, .09))]

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)

def make_tree(spec, index):
    vertices, faces, face_materials = [], [], []
    h, lean = spec["height"], spec["lean"]
    trunk = [(0,0,0), (lean*.18, .03, h*.24), (lean*.58, -.05, h*.58), (lean, 0, h*.82)]
    append_tube(vertices, faces, face_materials, trunk, [.48,.40,.27,.16], 0)
    for root in range(5):
        angle = root * 1.256 + index*.43
        append_tube(vertices, faces, face_materials, [(0,0,.16), (math.cos(angle)*.62, math.sin(angle)*.62, .055), (math.cos(angle)*1.10, math.sin(angle)*1.10, 0)], [.14,.07,.018], 1, 6)
    crown = spec["crown"]
    for branch, target in enumerate(crown):
        base = Vector((lean * (.35 + branch*.055), 0, h*(.38 + (branch%3)*.08)))
        end = Vector(target) * .77 + Vector((lean*.25, 0, 0))
        middle = (base + end) * .5 + Vector((0, 0, .18 + (branch%2)*.12))
        append_tube(vertices, faces, face_materials, [base, middle, end], [.16,.095,.038], 1, 6)
    # Duas camadas de lóbulo evitam a copa "guarda-chuva": a massa baixa
    # entra entre os galhos e a alta quebra a linha superior em vez de formar
    # uma esfera isolada sobre um tronco reto.
    for lobe, center in enumerate(crown):
        center = Vector(center)
        append_lobe(vertices, faces, face_materials, center,
                    Vector((1.14 + (lobe%2)*.18, .94 + (lobe%3)*.12, .84 + (lobe%2)*.13)),
                    index*101+lobe, 2 if lobe%3 else 3)
        lower = center * .70 + Vector((lean * .2, 0, h * .10))
        append_lobe(vertices, faces, face_materials, lower,
                    Vector((.74, .66, .58)), index*211+lobe, 2 if lobe%2 else 3)
    append_lobe(vertices, faces, face_materials, Vector((lean*.72, 0, h*.64)),
                Vector((1.22, 1.08, .78)), index*509, 2)
    mesh = bpy.data.meshes.new("TREE_%s_MESH" % spec["id"].upper())
    mesh.from_pydata(vertices, [], faces); mesh.materials.clear()
    for mat in MATERIALS: mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, face_materials): polygon.material_index = material_index
    mesh.update()
    obj = bpy.data.objects.new("TREE_%s" % spec["id"].upper(), mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def export_tree(obj, variant):
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "tree_%s.glb" % variant), export_format="GLB", use_selection=True, export_apply=True)

if __name__ == "__main__":
    clear(); os.makedirs(OUT, exist_ok=True); os.makedirs(SOURCE, exist_ok=True)
    for index, spec in enumerate(VARIANTS):
        obj = make_tree(spec, index); export_tree(obj, spec["id"])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "tree_library.blend"))
    print("TREE_LIBRARY_READY", len(VARIANTS))
