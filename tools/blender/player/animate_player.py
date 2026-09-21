"""Fase 5 — Actions in-place do Player V1: idle, walk e run.

O deslocamento do personagem pertence ao Godot. Nenhuma Action anima o osso
root; os ciclos movem somente pose bones e podem ser reproduzidos a cada build.
"""

import os

import bpy

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
BLEND_PATH = os.path.join(PROJECT_DIR, "assets/characters/player_v1/player_v1.blend")
ARMATURE_NAME = "PLAYER_V1_ARMATURE"
CONTROLS = (
    "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
    "clavicle_L", "upperarm_L", "lowerarm_L", "hand_L",
    "clavicle_R", "upperarm_R", "lowerarm_R", "hand_R",
    "thigh_L", "shin_L", "foot_L", "toe_L",
    "thigh_R", "shin_R", "foot_R", "toe_R",
)


def espelhar_rotacao_y(rotation):
    """Converte a pose para a malha/rig espelhados no eixo de frente.

    A fonte agora usa +Y no Blender para chegar a -Z no Godot. Sob esse
    espelho, rotações locais em X e Z trocam de sinal; preservar isso mantém a
    passada criada originalmente, em vez de inverter o gesto dos membros.
    """
    return (-rotation[0], rotation[1], -rotation[2])


def set_pose(armature, frame, rotations):
    bpy.context.scene.frame_set(frame)
    for name in CONTROLS:
        bone = armature.pose.bones[name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = espelhar_rotacao_y(rotations.get(name, (0.0, 0.0, 0.0)))
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)


def action(armature, name, end, poses):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old, do_unlink=True)
    result = bpy.data.actions.new(name)
    # The armature is intentionally left in bind pose after generation. Keep
    # the Action datablock alive across saves instead of silently losing every
    # clip when it has no active user.
    result.use_fake_user = True
    result.use_frame_range = True
    result.frame_start = 1
    result.frame_end = end
    armature.animation_data_create()
    armature.animation_data.action = result
    for frame, rotations in poses:
        set_pose(armature, frame, rotations)
    for curve in result.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "BEZIER"
    # Exact first/last pose is mandatory for Godot looping.
    return result


def idle(armature):
    breath = {
        "spine_01": (-.015, 0, 0), "spine_02": (-.020, 0, 0),
        "chest": (-.018, 0, 0), "head": (.008, 0, 0),
        "upperarm_L": (.018, 0, -.012), "upperarm_R": (.018, 0, .012),
    }
    rest = {"head": (-.006, 0, 0)}
    return action(armature, "PLAYER_V1_IDLE", 72, [(1, rest), (37, breath), (72, rest)])


def locomotion(armature, name, end, stride, arm_swing, bend, lean):
    # Bone local X swings limbs front/back because the limb chains are vertical.
    left_forward = {
        "pelvis": (0, 0, .028), "spine_01": (lean * .45, 0, -.018),
        "spine_02": (lean, 0, -.020), "chest": (lean * .7, 0, -.016),
        "neck": (-lean * .18, 0, 0), "head": (-lean * .30, 0, 0),
        "thigh_L": (stride, 0, 0), "shin_L": (-bend, 0, 0),
        "foot_L": (bend * .62, 0, 0), "toe_L": (-bend * .20, 0, 0),
        "thigh_R": (-stride, 0, 0), "shin_R": (-bend * .25, 0, 0),
        "foot_R": (bend * .16, 0, 0),
        "upperarm_L": (-arm_swing, 0, -.05), "lowerarm_L": (-arm_swing * .28, 0, 0),
        "upperarm_R": (arm_swing, 0, .05), "lowerarm_R": (arm_swing * .28, 0, 0),
    }
    right_forward = {}
    for key, value in left_forward.items():
        if key.endswith("_L") or key.endswith("_R"):
            sibling = key[:-1] + ("R" if key.endswith("L") else "L")
            right_forward[sibling] = value
        else:
            right_forward[key] = (value[0], value[1], -value[2])
    # Make the left/right stride genuinely alternate instead of merely
    # relabelling the same limb values.
    for stem in ("thigh", "shin", "foot", "toe", "upperarm", "lowerarm"):
        left = left_forward.get(f"{stem}_L", (0, 0, 0))
        right = left_forward.get(f"{stem}_R", (0, 0, 0))
        right_forward[f"{stem}_L"] = right
        right_forward[f"{stem}_R"] = left
    neutral = {"spine_02": (lean * .45, 0, 0), "chest": (lean * .30, 0, 0)}
    return action(armature, name, end, [
        (1, left_forward), (end // 4 + 1, neutral),
        (end // 2 + 1, right_forward), (end * 3 // 4 + 1, neutral),
        (end, left_forward),
    ])


def main():
    armature = bpy.data.objects.get(ARMATURE_NAME)
    if armature is None:
        raise RuntimeError("Execute rig_player.py antes de animate_player.py")
    idle(armature)
    locomotion(armature, "PLAYER_V1_WALK", 24, .14, .13, .20, .020)
    locomotion(armature, "PLAYER_V1_RUN", 18, .26, .24, .36, .060)
    armature.animation_data.action = None
    # Do not persist whichever animated pose happened to be evaluated last.
    # A bind-pose source is required for deterministic dimensions and export.
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)
    bpy.context.scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("PLAYER_V1_ANIMATE actions=PLAYER_V1_IDLE,PLAYER_V1_WALK,PLAYER_V1_RUN root_motion=NONE")


if __name__ == "__main__":
    main()
