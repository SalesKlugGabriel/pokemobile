"""Fase 4 — rig humano reutilizável e pesos determinísticos do Player V1.

Uso:
  blender --background assets/characters/player_v1/player_v1.blend \
    --python tools/blender/player/rig_player.py

O player é construído em peças modulares. Em vez de confiar em Automatic
Weights numa coleção procedural, este script atribui grupos explícitos a cada
região e interpola ombros/cotovelos, quadris/joelhos e tornozelos. Assim a
fonte continua reproduzível e as deformações podem ser auditadas.
"""

import os

import bpy

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
BLEND_PATH = os.path.join(PROJECT_DIR, "assets/characters/player_v1/player_v1.blend")


def frente_godot(point):
    """Espelha Y para manter o rig alinhado à malha exportada para Godot."""
    return (point[0], -point[1], point[2])


def bone(edit_bones, name, head, tail, parent=None):
    result = edit_bones.new(name)
    result.head = head
    result.tail = tail
    if parent:
        result.parent = edit_bones[parent]
    return result


def build_armature():
    old = bpy.data.objects.get("PLAYER_V1_ARMATURE")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    data = bpy.data.armatures.new("PLAYER_V1_ARMATURE_DATA")
    armature = bpy.data.objects.new("PLAYER_V1_ARMATURE", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = armature.data.edit_bones
    bone(bones, "root", (0, 0, 0), (0, 0, .10))
    bone(bones, "pelvis", (0, 0, .74), (0, 0, .86), "root")
    bone(bones, "spine_01", (0, 0, .86), (0, 0, 1.00), "pelvis")
    bone(bones, "spine_02", (0, 0, 1.00), (0, 0, 1.14), "spine_01")
    bone(bones, "chest", (0, 0, 1.14), (0, 0, 1.25), "spine_02")
    bone(bones, "neck", (0, 0, 1.25), (0, 0, 1.34), "chest")
    bone(bones, "head", (0, 0, 1.34), (0, 0, 1.56), "neck")
    bone(bones, "backpack", frente_godot((0, .05, 1.05)), frente_godot((0, .20, 1.19)), "chest")
    bone(bones, "cap", (0, 0, 1.53), (0, 0, 1.62), "head")
    for sign, suffix in ((-1, "L"), (1, "R")):
        bone(bones, f"clavicle_{suffix}", (0, 0, 1.20), (sign * .20, 0, 1.19), "chest")
        bone(bones, f"upperarm_{suffix}", (sign * .20, 0, 1.19), (sign * .25, 0, .95), f"clavicle_{suffix}")
        bone(bones, f"lowerarm_{suffix}", (sign * .25, 0, .95), (sign * .273, 0, .70), f"upperarm_{suffix}")
        bone(bones, f"hand_{suffix}", frente_godot((sign * .273, 0, .70)), frente_godot((sign * .287, -.01, .57)), f"lowerarm_{suffix}")
        bone(bones, f"thigh_{suffix}", (sign * .10, 0, .80), (sign * .115, 0, .47), "pelvis")
        bone(bones, f"shin_{suffix}", (sign * .115, 0, .47), (sign * .11, 0, .18), f"thigh_{suffix}")
        bone(bones, f"foot_{suffix}", frente_godot((sign * .11, 0, .18)), frente_godot((sign * .11, -.16, .08)), f"shin_{suffix}")
        bone(bones, f"toe_{suffix}", frente_godot((sign * .11, -.16, .08)), frente_godot((sign * .11, -.25, .07)), f"foot_{suffix}")
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.show_in_front = True
    return armature


def group(obj, name):
    existing = obj.vertex_groups.get(name)
    return existing if existing else obj.vertex_groups.new(name=name)


def weighted(obj, bone_a, bone_b=None, split_z=None):
    """Assign all vertices to one bone or linearly across a joint height."""
    first = group(obj, bone_a)
    second = group(obj, bone_b) if bone_b else None
    for vertex in obj.data.vertices:
        z = (obj.matrix_world @ vertex.co).z
        if second and split_z is not None:
            # 14 cm blend zone avoids a rigid kink at elbow/knee.
            mix = max(0.0, min(1.0, (z - (split_z - .07)) / .14))
            first.add([vertex.index], mix, "REPLACE")
            second.add([vertex.index], 1.0 - mix, "REPLACE")
        else:
            first.add([vertex.index], 1.0, "REPLACE")


def bind_meshes(armature):
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("PLAYER_V1_")]
    for obj in meshes:
        obj.parent = armature
        modifier = obj.modifiers.get("PLAYER_V1_ARMATURE")
        if not modifier:
            modifier = obj.modifiers.new("PLAYER_V1_ARMATURE", "ARMATURE")
        modifier.object = armature
        name = obj.name
        side = "L" if name.endswith("_-1") or "_-1_" in name else "R"
        if "SLEEVE" in name:
            weighted(obj, f"upperarm_{side}", f"lowerarm_{side}", .95)
        elif any(token in name for token in ("CUFF", "WRIST")):
            weighted(obj, f"lowerarm_{side}")
        elif any(token in name for token in ("GLOVE", "PALM", "FINGER")):
            weighted(obj, f"hand_{side}")
        elif "CARGO_LEG" in name:
            weighted(obj, f"thigh_{side}", f"shin_{side}", .47)
        elif any(token in name for token in ("CARGO_", "POCKET_", "KNEE_")):
            # Cargo pieces are rigid accessories over one leg segment.  Their
            # previous fallback to pelvis was visible only in animation, where
            # they floated through the moving thighs.
            center_z = sum((obj.matrix_world @ vertex.co).z for vertex in obj.data.vertices) / len(obj.data.vertices)
            weighted(obj, f"thigh_{side}" if center_z >= .47 else f"shin_{side}")
        elif any(token in name for token in ("ANKLE", "CARGO_CUFF")):
            weighted(obj, f"shin_{side}")
        elif "SHOE" in name:
            weighted(obj, f"foot_{side}", f"toe_{side}", .09)
        elif "BACKPACK" in name or "BAG_" in name or "ROLL_MAT" in name or "SHOULDER_STRAP" in name:
            weighted(obj, "backpack")
        elif "CAP_" in name:
            weighted(obj, "cap")
        elif any(token in name for token in ("JACKET", "SHIRT", "BELT", "COLLAR", "LAPEL")):
            weighted(obj, "spine_01", "chest", 1.08)
        elif any(token in name for token in ("FACE", "HAIR", "EAR", "EYE", "BROW", "NOSE", "MOUTH", "FRINGE", "NAPE")):
            weighted(obj, "head")
        elif name in ("PLAYER_V1_NECK",):
            weighted(obj, "neck", "head", 1.31)
        else:
            weighted(obj, "pelvis", "spine_01", .82)
    return meshes


def main():
    armature = build_armature()
    meshes = bind_meshes(armature)
    bpy.context.view_layer.objects.active = armature
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    armature.select_set(True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print(f"PLAYER_V1_RIG bones={len(armature.data.bones)} meshes={len(meshes)} path={BLEND_PATH}")


if __name__ == "__main__":
    main()
