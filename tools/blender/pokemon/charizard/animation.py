"""Actions in-place; walk e run têm ciclo e amplitudes próprios."""
import math
import bpy


def r(degrees):
    return math.radians(degrees)


CLIPS = {
    "IDLE": (40, {
        1:{},20:{"chest":(r(2),0,0),"head":(r(-2),0,0),"wing_l":(0,r(2),0),"wing_r":(0,r(-2),0),"tail_tip":(0,0,r(5))},40:{}}),
    "WALK": (24, {
        1:{"leg_l":(r(24),0,0),"leg_r":(r(-24),0,0),"shin_l":(r(-11),0,0),"shin_r":(r(16),0,0),"arm_l":(r(-13),0,0),"arm_r":(r(13),0,0),"tail":(0,0,r(4))},
        7:{"leg_l":(r(8),0,0),"leg_r":(r(-8),0,0),"shin_l":(r(19),0,0),"shin_r":(r(-5),0,0),"chest":(r(2),0,0)},
        13:{"leg_l":(r(-24),0,0),"leg_r":(r(24),0,0),"shin_l":(r(16),0,0),"shin_r":(r(-11),0,0),"arm_l":(r(13),0,0),"arm_r":(r(-13),0,0),"tail":(0,0,r(-4))},
        19:{"leg_l":(r(-8),0,0),"leg_r":(r(8),0,0),"shin_l":(r(-5),0,0),"shin_r":(r(19),0,0),"chest":(r(2),0,0)},
        25:{"leg_l":(r(24),0,0),"leg_r":(r(-24),0,0),"shin_l":(r(-11),0,0),"shin_r":(r(16),0,0),"arm_l":(r(-13),0,0),"arm_r":(r(13),0,0),"tail":(0,0,r(4))}}),
    "RUN": (16, {
        1:{"leg_l":(r(41),0,0),"leg_r":(r(-37),0,0),"shin_l":(r(-19),0,0),"shin_r":(r(24),0,0),"arm_l":(r(-28),0,0),"arm_r":(r(28),0,0),"chest":(r(8),0,0),"tail":(r(-6),0,0)},
        5:{"leg_l":(r(12),0,0),"leg_r":(r(-10),0,0),"shin_l":(r(32),0,0),"shin_r":(r(12),0,0),"chest":(r(12),0,0),"wing_l":(0,r(-7),0),"wing_r":(0,r(7),0)},
        9:{"leg_l":(r(-37),0,0),"leg_r":(r(41),0,0),"shin_l":(r(24),0,0),"shin_r":(r(-19),0,0),"arm_l":(r(28),0,0),"arm_r":(r(-28),0,0),"chest":(r(8),0,0),"tail":(r(6),0,0)},
        13:{"leg_l":(r(-10),0,0),"leg_r":(r(12),0,0),"shin_l":(r(12),0,0),"shin_r":(r(32),0,0),"chest":(r(12),0,0),"wing_l":(0,r(-7),0),"wing_r":(0,r(7),0)},
        17:{"leg_l":(r(41),0,0),"leg_r":(r(-37),0,0),"shin_l":(r(-19),0,0),"shin_r":(r(24),0,0),"arm_l":(r(-28),0,0),"arm_r":(r(28),0,0),"chest":(r(8),0,0),"tail":(r(-6),0,0)}}),
    "ATTACK_01":(22,{1:{"head":(r(7),0,0)},7:{"chest":(r(-9),0,0),"jaw":(r(-12),0,0)},12:{"chest":(r(18),0,0),"jaw":(r(23),0,0),"arm_l":(r(-30),0,0),"arm_r":(r(-30),0,0)},23:{}}),
    "HIT":(14,{1:{},5:{"chest":(r(-11),0,r(-12)),"head":(r(-8),0,r(-9)),"wing_l":(0,r(8),0)},15:{}}),
    "FAINT":(30,{1:{},14:{"root":(0,r(13),r(-35)),"wing_l":(0,r(24),0),"wing_r":(0,r(-24),0)},31:{"root":(0,r(18),r(-72)),"head":(r(-16),0,0)}}),
    "FLY":(20,{1:{"wing_l":(0,r(-12),0),"wing_r":(0,r(12),0)},11:{"wing_l":(0,r(18),0),"wing_r":(0,r(-18),0),"tail_tip":(0,0,r(6))},21:{"wing_l":(0,r(-12),0),"wing_r":(0,r(12),0)}}),
}


def create(arm):
    arm.animation_data_create()
    for label, (_, poses) in CLIPS.items():
        name = "PKM_CHARIZARD_" + label
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for frame, pose in poses.items():
            for bone in arm.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = pose.get(bone.name, (0,0,0))
                bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
        action.frame_start, action.frame_end = min(poses), max(poses)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, min(poses), action)
        strip.action_frame_start, strip.action_frame_end = min(poses), max(poses)
        arm.animation_data.action = None
