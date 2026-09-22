"""Sete Actions in-place, inclusive voo e corrida com articulação própria."""
import bpy
import math


def rad(value):
    return math.radians(value)


CLIPS = {
    "IDLE": (40, {1:{},20:{"body":(rad(2),0,0),"head":(rad(-2),0,0),"tail":(0,0,rad(3))},40:{}}),
    "WALK": (24, {1:{"leg_l":(rad(25),0,0),"leg_r":(rad(-25),0,0),"wing_upper_l":(0,rad(-3),0),"wing_upper_r":(0,rad(3),0)},
                  7:{"foot_l":(rad(-12),0,0),"body":(rad(2),0,0)},
                  13:{"leg_l":(rad(-25),0,0),"leg_r":(rad(25),0,0),"wing_upper_l":(0,rad(3),0),"wing_upper_r":(0,rad(-3),0)},
                  19:{"foot_r":(rad(-12),0,0),"body":(rad(2),0,0)},
                  25:{"leg_l":(rad(25),0,0),"leg_r":(rad(-25),0,0),"wing_upper_l":(0,rad(-3),0),"wing_upper_r":(0,rad(3),0)}}),
    "RUN": (16, {1:{"leg_l":(rad(43),0,0),"leg_r":(rad(-39),0,0),"body":(rad(8),0,0),"wing_upper_l":(0,rad(-9),0),"wing_upper_r":(0,rad(9),0)},
                 5:{"leg_l":(rad(7),0,0),"leg_r":(rad(-8),0,0),"foot_l":(rad(-20),0,0),"body":(rad(11),0,0)},
                 9:{"leg_l":(rad(-39),0,0),"leg_r":(rad(43),0,0),"body":(rad(8),0,0),"wing_upper_l":(0,rad(9),0),"wing_upper_r":(0,rad(-9),0)},
                 13:{"leg_l":(rad(-8),0,0),"leg_r":(rad(7),0,0),"foot_r":(rad(-20),0,0),"body":(rad(11),0,0)},
                 17:{"leg_l":(rad(43),0,0),"leg_r":(rad(-39),0,0),"body":(rad(8),0,0),"wing_upper_l":(0,rad(-9),0),"wing_upper_r":(0,rad(9),0)}}),
    "FLY": (24, {1:{"wing_upper_l":(0,rad(-9),rad(33)),"wing_upper_r":(0,rad(9),rad(-33)),"wing_outer_l":(0,0,rad(11)),"wing_outer_r":(0,0,rad(-11))},
                 7:{"wing_upper_l":(0,0,rad(7)),"wing_upper_r":(0,0,rad(-7))},
                 13:{"wing_upper_l":(0,rad(10),rad(-34)),"wing_upper_r":(0,rad(-10),rad(34)),"wing_outer_l":(0,0,rad(-18)),"wing_outer_r":(0,0,rad(18)),"tail":(rad(5),0,0)},
                 19:{"wing_upper_l":(0,0,rad(7)),"wing_upper_r":(0,0,rad(-7))},
                 25:{"wing_upper_l":(0,rad(-9),rad(33)),"wing_upper_r":(0,rad(9),rad(-33)),"wing_outer_l":(0,0,rad(11)),"wing_outer_r":(0,0,rad(-11))}}),
    "ATTACK_01": (20, {1:{"head":(rad(6),0,0)},6:{"head":(rad(18),0,0),"wing_upper_l":(0,0,rad(15)),"wing_upper_r":(0,0,rad(-15))},
                       11:{"head":(rad(-26),0,0),"wing_upper_l":(0,0,rad(-20)),"wing_upper_r":(0,0,rad(20))},21:{}}),
    "HIT": (14, {1:{},5:{"body":(rad(-12),0,rad(-12)),"head":(rad(9),0,0)},15:{}}),
    "FAINT": (30, {1:{},14:{"root":(0,rad(12),rad(-34)),"wing_upper_l":(0,0,rad(22)),"wing_upper_r":(0,0,rad(-22))},
                   31:{"root":(0,rad(16),rad(-72)),"head":(rad(-15),0,0)}}),
}


def create(arm):
    arm.animation_data_create()
    for label,(_,poses) in CLIPS.items():
        name="PKM_PIDGEOT_"+label
        action=bpy.data.actions.new(name)
        action.use_fake_user=True
        arm.animation_data.action=action
        for frame,pose in poses.items():
            for bone in arm.pose.bones:
                bone.rotation_mode="XYZ"
                bone.rotation_euler=pose.get(bone.name,(0,0,0))
                bone.keyframe_insert(data_path="rotation_euler",frame=frame,group=bone.name)
        action.frame_start,action.frame_end=min(poses),max(poses)
        track=arm.animation_data.nla_tracks.new()
        track.name=name
        strip=track.strips.new(name,min(poses),action)
        strip.action_frame_start,strip.action_frame_end=min(poses),max(poses)
        arm.animation_data.action=None
