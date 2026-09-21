import bpy
import math


PREFIXO = "PKM_RATTATA"


def _acao(armature, nome, quadros, poses, loop=False):
    acao = bpy.data.actions.new(PREFIXO + "_" + nome)
    armature.animation_data_create()
    armature.animation_data.action = acao
    for quadro, pose in zip(quadros, poses):
        for osso, rotacao in pose.items():
            pose_bone = armature.pose.bones[osso]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = rotacao
            pose_bone.keyframe_insert("rotation_euler", frame=quadro)
    acao.frame_start = quadros[0]
    acao.frame_end = quadros[-1]
    if loop:
        for curva in acao.fcurves:
            for ponto in curva.keyframe_points:
                ponto.interpolation = "BEZIER"
            curva.modifiers.new("CYCLES")
    trilha = armature.animation_data.nla_tracks.new()
    trilha.name = acao.name
    faixa = trilha.strips.new(acao.name, quadros[0], acao)
    faixa.action_frame_start = quadros[0]
    faixa.action_frame_end = quadros[-1]
    armature.animation_data.action = None


def criar(armature):
    zero = {}
    _acao(armature, "IDLE", [1, 20, 40], [
        zero,
        {"spine": (math.radians(2), 0, 0), "head": (math.radians(-2), 0, 0),
         "tail_01": (0, math.radians(6), 0), "tail_02": (0, math.radians(10), 0)},
        zero,
    ], True)
    _acao(armature, "WALK", [1, 10, 20], [
        {"front_l": (math.radians(25), 0, 0), "front_r": (math.radians(-25), 0, 0),
         "back_l": (math.radians(-22), 0, 0), "back_r": (math.radians(22), 0, 0),
         "tail_01": (0, math.radians(12), 0)},
        zero,
        {"front_l": (math.radians(-25), 0, 0), "front_r": (math.radians(25), 0, 0),
         "back_l": (math.radians(22), 0, 0), "back_r": (math.radians(-22), 0, 0),
         "tail_01": (0, math.radians(-12), 0)},
    ], True)
    _acao(armature, "RUN", [1, 8, 16], [
        {"spine": (math.radians(7), 0, 0), "front_l": (math.radians(43), 0, 0),
         "front_r": (math.radians(-43), 0, 0), "back_l": (math.radians(-38), 0, 0),
         "back_r": (math.radians(38), 0, 0), "tail_02": (0, math.radians(18), 0)},
        zero,
        {"spine": (math.radians(-5), 0, 0), "front_l": (math.radians(-43), 0, 0),
         "front_r": (math.radians(43), 0, 0), "back_l": (math.radians(38), 0, 0),
         "back_r": (math.radians(-38), 0, 0), "tail_02": (0, math.radians(-18), 0)},
    ], True)
    _acao(armature, "ATTACK_01", [1, 7, 16], [
        zero,
        {"spine": (math.radians(-15), 0, 0), "head": (math.radians(-22), 0, 0),
         "jaw": (math.radians(-18), 0, 0)},
        zero,
    ])
    _acao(armature, "HIT", [1, 5, 12], [zero, {"spine": (0, 0, math.radians(-18))}, zero])
    _acao(armature, "FAINT", [1, 14, 30], [zero, {"root": (0, 0, math.radians(-42))},
        {"root": (0, 0, math.radians(-78))}])
