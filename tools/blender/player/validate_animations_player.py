"""Valida Actions MVP sem assumir que uma Action existente é uma animação útil."""

import bpy

EXPECTED = {"PLAYER_V1_IDLE": 72, "PLAYER_V1_WALK": 24, "PLAYER_V1_RUN": 18}


def main():
    armature = bpy.data.objects.get("PLAYER_V1_ARMATURE")
    if armature is None:
        raise RuntimeError("PLAYER_V1_ARMATURE ausente")
    failures = []
    for name, expected_end in EXPECTED.items():
        action = bpy.data.actions.get(name)
        if action is None:
            failures.append(f"Action ausente: {name}")
            continue
        if round(action.frame_range[1]) != expected_end:
            failures.append(f"Range inválido: {name}={tuple(action.frame_range)}")
        curves = [curve for curve in action.fcurves if "pose.bones" in curve.data_path]
        if not curves:
            failures.append(f"Sem pose bones: {name}")
        if any('pose.bones["root"]' in curve.data_path and ".location" in curve.data_path for curve in action.fcurves):
            failures.append(f"Root motion proibido: {name}")
        if name != "PLAYER_V1_IDLE":
            required = ("thigh_L", "thigh_R", "upperarm_L", "upperarm_R")
            for bone in required:
                if not any(f'pose.bones["{bone}"]' in curve.data_path for curve in curves):
                    failures.append(f"{name} sem movimento de {bone}")
    if failures:
        raise RuntimeError(" | ".join(failures))
    print("PLAYER_V1_ANIMATION_VALIDATE actions=3 root_motion=NONE status=PASS")


if __name__ == "__main__":
    main()
