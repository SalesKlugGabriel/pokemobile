"""Exporta o Player V1 validado como pacote GLB para importação no Godot."""

import os

import bpy

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
OUTPUT = os.path.join(PROJECT_DIR, "assets/characters/player_v1/player_v1.glb")

def main():
    armature = bpy.data.objects.get("PLAYER_V1_ARMATURE")
    if armature is None:
        raise RuntimeError("PLAYER_V1_ARMATURE ausente: execute rig_player.py")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("PLAYER_V1_")]
    if not {"PLAYER_V1_IDLE", "PLAYER_V1_WALK", "PLAYER_V1_RUN"} <= set(bpy.data.actions.keys()):
        raise RuntimeError("Actions MVP ausentes: execute animate_player.py")
    # The source .blend intentionally keeps every garment/accessory modular.
    # Runtime should not pay one draw call per button, however. Build temporary
    # copies and merge only copies with the same material before exporting.
    runtime_collection = bpy.data.collections.new("PLAYER_V1_RUNTIME_EXPORT")
    bpy.context.scene.collection.children.link(runtime_collection)
    by_material = {}
    for source in meshes:
        clone = source.copy()
        clone.data = source.data.copy()
        runtime_collection.objects.link(clone)
        clone.parent = armature
        clone.matrix_parent_inverse = armature.matrix_world.inverted()
        material_name = clone.data.materials[0].name if clone.data.materials else "NO_MATERIAL"
        by_material.setdefault(material_name, []).append(clone)
    runtime_meshes = []
    for material_name, clones in by_material.items():
        bpy.ops.object.select_all(action="DESELECT")
        for clone in clones:
            clone.select_set(True)
        bpy.context.view_layer.objects.active = clones[0]
        bpy.ops.object.join()
        merged = bpy.context.view_layer.objects.active
        merged.name = "PLAYER_V1_RUNTIME_" + material_name.removeprefix("PLAYER_V1_MAT_")
        runtime_meshes.append(merged)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for mesh in runtime_meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_nla_strips=False,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
    )
    print(f"PLAYER_V1_EXPORT path={OUTPUT} bytes={os.path.getsize(OUTPUT)} source_meshes={len(meshes)} runtime_meshes={len(runtime_meshes)}")


if __name__ == "__main__":
    main()
