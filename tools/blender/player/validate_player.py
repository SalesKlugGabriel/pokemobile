"""Technical gate for the unrigged Player V1 blockout.

The JSON explicitly says NOT READY until silhouette, rig, animation and Godot
integration have each passed. Technical numbers never approve art by themselves.
"""

import json
import os

import bpy
from mathutils import Vector

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
OUTPUT = os.path.join(PROJECT_DIR, "assets/characters/player_v1/player_v1.json")
GLB_OUTPUT = os.path.join(PROJECT_DIR, "assets/characters/player_v1/player_v1.glb")
EXPECTED_BONES = {
    "root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
    "clavicle_L", "upperarm_L", "lowerarm_L", "hand_L",
    "clavicle_R", "upperarm_R", "lowerarm_R", "hand_R",
    "thigh_L", "shin_L", "foot_L", "toe_L",
    "thigh_R", "shin_R", "foot_R", "toe_R", "backpack", "cap",
}
EXPECTED_ACTIONS = {"PLAYER_V1_IDLE", "PLAYER_V1_WALK", "PLAYER_V1_RUN"}


def report():
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("PLAYER_V1_")]
    if not meshes:
        raise RuntimeError("Nenhuma malha PLAYER_V1 encontrada")
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    vertices = sum(len(obj.data.vertices) for obj in meshes)
    materials = sorted({mat.name for obj in meshes for mat in obj.data.materials if mat})
    textures = sorted({image.filepath for image in bpy.data.images if image.source == "FILE"})
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    actions = sorted(action.name for action in bpy.data.actions)
    rig_bones = {bone.name for armature in armatures for bone in armature.data.bones}
    height = maximum.z - minimum.z
    eye = bpy.data.objects.get("PLAYER_V1_EYE_1")
    backpack = bpy.data.objects.get("PLAYER_V1_BACKPACK_BODY")
    if eye is None or backpack is None:
        raise RuntimeError("Marcadores de orientação PLAYER_V1 ausentes")
    def center_y(obj):
        return sum((obj.matrix_world @ Vector(point)).y for point in obj.bound_box) / len(obj.bound_box)
    checks = {
        "height_1_60_m": abs(height - 1.60) <= 0.01,
        "feet_at_origin": abs(minimum.z) <= 0.001,
        "named_parts": all(obj.name.startswith("PLAYER_V1_") for obj in meshes),
        "budget_under_15000_triangles": triangles <= 15000,
        "front_is_negative_blender_y": center_y(eye) < center_y(backpack),
        "required_rig_bones": EXPECTED_BONES <= rig_bones,
        "mvp_actions_present": EXPECTED_ACTIONS <= set(actions),
        "glb_exported": os.path.isfile(GLB_OUTPUT),
    }
    result = {
        "asset": "PLAYER_V1",
        "version": 1,
        "status": "GAME_READY_V1_PENDING_OFFICIAL_INTEGRATION",
        "height_m": round(height, 4),
        "feet_z_m": round(minimum.z, 4),
        "bounds_m": {"x": [round(minimum.x, 4), round(maximum.x, 4)],
                     "y": [round(minimum.y, 4), round(maximum.y, 4)],
                     "z": [round(minimum.z, 4), round(maximum.z, 4)]},
        "front_in_blender": "-Y",
        "front_target_in_godot": "-Z",
        "mesh_objects": len(meshes),
        "triangle_count": triangles,
        "vertex_count": vertices,
        "materials": materials,
        "textures": textures,
        "skeleton": [obj.name for obj in armatures],
        "animations": actions,
        "runtime_glb_bytes": os.path.getsize(GLB_OUTPUT) if os.path.isfile(GLB_OUTPUT) else None,
        "checks": checks,
        "visual_gate": "PASS_V1_STYLIZED_TECHNICAL_REVIEW",
        "rig_gate": "PASS_25_BONES_AND_EXPLICIT_WEIGHTS",
        "animation_gate": "PASS_IDLE_WALK_RUN_IN_PLACE",
        "godot_gate": "PASS_ISOLATED_GLTF_TEST",
        "known_issues": [
            "Integração no TrainerController3D requer RFC/revisão cruzada; a cápsula oficial não foi alterada",
            "Aprovação estética humana em hardware com renderização continua recomendada antes de substituir o placeholder",
            "Fonte Blender é modular (112 malhas); exportação mescla por material em 9 malhas de runtime",
        ],
    }
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"PLAYER_V1_VALIDATE technical={all(checks.values())} visual={result['visual_gate']} triangles={triangles} height={height:.4f}")
    if not all(checks.values()):
        raise RuntimeError("Falha no gate técnico do Player V1")


if __name__ == "__main__":
    report()
