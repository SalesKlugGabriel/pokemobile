"""Valida estrutura de rig e pesos úteis antes de criar Actions."""

import os

import bpy

REQUIRED = {
    "root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
    "backpack", "cap",
    "clavicle_L", "upperarm_L", "lowerarm_L", "hand_L",
    "clavicle_R", "upperarm_R", "lowerarm_R", "hand_R",
    "thigh_L", "shin_L", "foot_L", "toe_L",
    "thigh_R", "shin_R", "foot_R", "toe_R",
}


def main():
    armature = bpy.data.objects.get("PLAYER_V1_ARMATURE")
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("PLAYER_V1_ARMATURE ausente")
    names = {bone.name for bone in armature.data.bones}
    missing = sorted(REQUIRED - names)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("PLAYER_V1_")]
    unbound = []
    empty_groups = []
    for mesh in meshes:
        modifier = mesh.modifiers.get("PLAYER_V1_ARMATURE")
        if not modifier or modifier.object != armature:
            unbound.append(mesh.name)
            continue
        has_influence = False
        for vertex in mesh.data.vertices:
            for assignment in vertex.groups:
                group_name = mesh.vertex_groups[assignment.group].name
                if group_name in names and assignment.weight > 0.0:
                    has_influence = True
                    break
            if has_influence:
                break
        if not has_influence:
            empty_groups.append(mesh.name)
    if missing or unbound or empty_groups:
        raise RuntimeError(f"Rig inválido missing={missing} unbound={unbound} empty={empty_groups}")
    print(f"PLAYER_V1_RIG_VALIDATE bones={len(names)} meshes={len(meshes)} status=PASS")


if __name__ == "__main__":
    main()
