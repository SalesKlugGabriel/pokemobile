"""Gera LOD1 reutilizável para as árvores da World Factory V1.

As fontes GLB LOD0 não são alteradas. Cada saída preserva origem, orientação e
materiais, reduzindo geometria por Decimate para uso fora da faixa próxima.
Uso: blender --background --python tools/blender/generators/gerar_lod_arvores.py
"""
import bpy
import os


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
TREE_DIR = os.path.join(ROOT, "assets/models/environment/trees")
VARIANTS = ("a", "b", "c", "d", "e")
DECIMATE_RATIO = 0.38


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def active_mesh():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError("Esperava exatamente uma malha importada; recebi %d" % len(meshes))
    return meshes[0]


def export_lod(variant):
    clear_scene()
    source = os.path.join(TREE_DIR, "tree_%s.glb" % variant)
    target = os.path.join(TREE_DIR, "tree_%s_lod1.glb" % variant)
    bpy.ops.import_scene.gltf(filepath=source)
    tree = active_mesh()
    original_triangles = sum(len(poly.vertices) - 2 for poly in tree.data.polygons)
    modifier = tree.modifiers.new("WORLD_FACTORY_LOD1", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = DECIMATE_RATIO
    bpy.context.view_layer.objects.active = tree
    tree.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    lod_triangles = sum(len(poly.vertices) - 2 for poly in tree.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    tree.select_set(True)
    bpy.context.view_layer.objects.active = tree
    bpy.ops.export_scene.gltf(
        filepath=target,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print("LOD", variant, "triangles", original_triangles, "->", lod_triangles, "wrote", target)


if __name__ == "__main__":
    for variant_name in VARIANTS:
        export_lod(variant_name)
