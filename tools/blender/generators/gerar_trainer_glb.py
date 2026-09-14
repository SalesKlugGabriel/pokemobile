import bpy, math, os
from mathutils import Vector

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/models/trainer/player.glb"))

def material(name, color):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1.0); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1.0)
    return m

BLUE = material("trainer_blue", (0.04, 0.22, 0.55))
RED = material("trainer_red", (0.78, 0.06, 0.04))
parts = []

def sphere(name, loc, scale, mat=BLUE):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(mat); parts.append(o)

def cube(name, loc, scale, mat=BLUE, bevel=0.05):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(mat); parts.append(o)
    if bevel:
        mod=o.modifiers.new("soft_edges", "BEVEL"); mod.width=bevel; mod.segments=2

def cyl(name, loc, radius, depth, mat=BLUE, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name; o.data.materials.append(mat); parts.append(o)

# Godot-style construction coordinates: +Y up, -Z is the player's front.
sphere("head", (0,1.50,-0.04), (0.22,0.24,0.20))
cyl("cap", (0,1.72,-0.04), 0.25, 0.10, RED)
cube("cap_brim", (0,1.69,-0.22), (0.18,0.035,0.13), RED, 0.02)
cube("torso", (0,1.02,0.0), (0.27,0.38,0.16), BLUE, 0.08)
cube("backpack", (0,1.08,0.22), (0.22,0.28,0.10), RED, 0.05)
for s in (-1,1):
    sphere("arm", (0.34*s,1.06,-0.02), (0.09,0.30,0.09))
    sphere("hand", (0.34*s,0.76,-0.04), (0.10,0.10,0.10), RED)
    cube("leg", (0.13*s,0.43,0.0), (0.11,0.32,0.12), BLUE, 0.04)
    cube("boot", (0.13*s,0.10,-0.07), (0.14,0.10,0.20), RED, 0.04)

bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
mesh=bpy.context.object; mesh.name="Trainer_Player"
bpy.context.view_layer.update()
min_y=min(v.co.y for v in mesh.data.vertices); max_y=max(v.co.y for v in mesh.data.vertices)
mesh.location.y -= min_y; mesh.scale *= 1.75/(max_y-min_y)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
feet=min(v.co.y for v in mesh.data.vertices)
for v in mesh.data.vertices: v.co.y -= feet
mesh.data.update()
# Convert the authored +Y construction frame to Blender's +Z-up frame before
# rigging. glTF/Godot then receives +Y as height without a runtime correction.
mesh.rotation_euler.x=math.radians(90)
bpy.context.view_layer.objects.active=mesh
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

# Anatomical armature. Mesh components are rigidly weighted to their nearest
# bone; the low-poly parts remain clean while still deforming through an
# Armature Modifier (no whole-object bobbing).
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
arm=bpy.context.object; arm.name="PKM_TRAINER_ARMATURE"
for b in list(arm.data.edit_bones): arm.data.edit_bones.remove(b)
bone_specs = {
    "root": ((0,0,0),(0,0,.25)), "pelvis": ((0,0,.35),(0,0,.65)),
    "spine": ((0,0,.65),(0,0,1.05)), "chest": ((0,0,1.02),(0,0,1.30)),
    "neck": ((0,0,1.30),(0,0,1.45)), "head": ((0,0,1.45),(0,0,1.72)),
    "arm_l": ((-.30,0,1.08),(-.42,0,.80)), "arm_r": ((.30,0,1.08),(.42,0,.80)),
    "leg_l": ((-.13,0,.38),(-.13,0,.08)), "leg_r": ((.13,0,.38),(.13,0,.08)),
}
for name, (head, tail) in bone_specs.items():
    b=arm.data.edit_bones.new(name); b.head=head; b.tail=tail
    if name != "root": b.parent=arm.data.edit_bones["root"]
bpy.ops.object.mode_set(mode='OBJECT')
arm.rotation_euler.x=0.0

groups = {name: mesh.vertex_groups.new(name=name) for name in bone_specs}
points = {name: Vector(spec[0]) for name, spec in bone_specs.items()}
for vertex in mesh.data.vertices:
    nearest = min(points, key=lambda name: (vertex.co - points[name]).length)
    groups[nearest].add([vertex.index], 1.0, 'REPLACE')
mesh.parent=arm
modifier=mesh.modifiers.new("PKM_TRAINER_ARMATURE_MODIFIER", 'ARMATURE'); modifier.object=arm

def action(name, frames, poses):
    act=bpy.data.actions.new(name); arm.animation_data_create(); arm.animation_data.action=act
    for frame, pose in zip(frames, poses):
        for bone_name, rotation in pose.items():
            pb=arm.pose.bones[bone_name]; pb.rotation_mode='XYZ'; pb.rotation_euler=rotation; pb.keyframe_insert('rotation_euler', frame=frame)
    act.frame_start=frames[0]; act.frame_end=frames[-1]
    track=arm.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name, frames[0], act); strip.action_frame_start=frames[0]; strip.action_frame_end=frames[-1]
    arm.animation_data.action=None

zero={}
action("PKM_TRAINER_IDLE", [1,20,40], [zero, {"chest":(math.radians(2),0,0)}, zero])
action("PKM_TRAINER_WALK", [1,10,20], [{"leg_l":(.45,0,0),"leg_r":(-.45,0,0),"arm_l":(-.35,0,0),"arm_r":(.35,0,0)}, zero, {"leg_l":(-.45,0,0),"leg_r":(.45,0,0),"arm_l":(.35,0,0),"arm_r":(-.35,0,0)}])
action("PKM_TRAINER_RUN", [1,8,16], [{"leg_l":(.75,0,0),"leg_r":(-.75,0,0),"arm_l":(-.55,0,0),"arm_r":(.55,0,0)}, zero, {"leg_l":(-.75,0,0),"leg_r":(.75,0,0),"arm_l":(.55,0,0),"arm_r":(-.55,0,0)}])
action("PKM_TRAINER_HIT", [1,5,12], [zero, {"chest":(0,0,math.radians(-18)),"head":(0,0,math.radians(-10))}, zero])
action("PKM_TRAINER_FAINT", [1,12,30], [zero, {"root":(0,0,math.radians(-35))}, {"root":(0,0,math.radians(-70))}])

bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True)
print("WROTE", OUT)
