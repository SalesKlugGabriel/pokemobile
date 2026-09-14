import bpy
import math
import os
from mathutils import Vector

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/models/pokemon/6.glb"))

def mat(name, color, roughness=0.8):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return m

ORANGE = mat("charizard_orange", (0.82, 0.20, 0.055))
BLUE = mat("charizard_wing_dark", (0.035, 0.13, 0.24))

parts = []
def add_uv(name, loc, scale, material=ORANGE, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material); parts.append(o); return o

def add_cone(name, loc, radius1, radius2, depth, material=ORANGE, rot=(0,0,0), verts=10):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.data.materials.append(material); parts.append(o); return o

def add_cyl(name, loc, radius, depth, material=ORANGE, rot=(0,0,0), verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.data.materials.append(material); parts.append(o); return o

def add_wing(name, side):
    # A faceted triangular wing, attached behind the shoulders.
    x = side
    verts = [(0.16*x,1.22,0.12),(0.52*x,1.42,0.18),(1.02*x,1.60,0.30),
             (1.20*x,1.45,0.40),(0.78*x,0.72,0.34),(0.36*x,0.86,0.18)]
    faces = [(0,1,5),(1,2,3,4,5),(0,5,4)]
    me = bpy.data.meshes.new(name+"Mesh"); me.from_pydata(verts, [], faces); me.materials.append(BLUE)
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); parts.append(o); return o

# Compact, deliberately low-poly silhouette: body, neck, head, muzzle, limbs, wings and tail.
add_uv("body", (0,0.86,0.08), (0.38,0.56,0.30))
add_uv("chest", (0,1.10,-0.18), (0.28,0.37,0.24))
add_uv("head", (0,1.43,-0.23), (0.27,0.27,0.25))
add_uv("muzzle", (0,1.35,-0.47), (0.20,0.15,0.16))
# Face cues make the -Z front unmistakable in third person. Eyes and nostrils
# share the second material slot to preserve the two-material budget.
add_uv("eye_l", (-0.105,1.49,-0.445), (0.045,0.055,0.025), BLUE, 8, 6)
add_uv("eye_r", (0.105,1.49,-0.445), (0.045,0.055,0.025), BLUE, 8, 6)
add_uv("brow_l", (-0.105,1.545,-0.425), (0.075,0.025,0.035), ORANGE, 8, 6)
add_uv("brow_r", (0.105,1.545,-0.425), (0.075,0.025,0.035), ORANGE, 8, 6)
add_uv("nostril_l", (-0.07,1.39,-0.585), (0.022,0.018,0.012), BLUE, 8, 6)
add_uv("nostril_r", (0.07,1.39,-0.585), (0.022,0.018,0.012), BLUE, 8, 6)
add_cone("horn_l", (-0.13,1.68,-0.23), .055, .005, .22, ORANGE, (0,0,-0.32))
add_cone("horn_r", (0.13,1.68,-0.23), .055, .005, .22, ORANGE, (0,0,0.32))
for s in (-1,1):
    add_uv("arm", (0.30*s,1.12,-0.08), (0.10,0.27,0.10))
    add_uv("hand", (0.34*s,0.88,-0.18), (0.11,0.10,0.11))
    add_uv("leg", (0.19*s,0.48,0.04), (0.15,0.34,0.15))
    add_uv("foot", (0.21*s,0.20,-0.10), (0.18,0.10,0.25))
    add_wing("wing_l" if s < 0 else "wing_r", s)
# Tail: three overlapping tapered segments ending in the flame tip.
add_cone("tail_base", (0,0.60,0.38), .16, .10, .58, ORANGE, (math.pi/2,0,0))
add_cone("tail_mid", (0,0.52,0.82), .11, .065, .48, ORANGE, (math.pi/2,0,0))
add_cone("tail_tip", (0,0.65,1.19), .08, .025, .40, ORANGE, (math.pi/2,0,0))
add_uv("flame", (0,0.86,1.40), (0.12,0.22,0.12), ORANGE)

# Join into one render mesh while retaining the two material slots.
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
mesh = bpy.context.object; mesh.name = "Charizard_6"

# Normalize exact Pokédex height and put the lowest vertex at y=0 (origin at feet).
bpy.context.view_layer.update()
min_y = min((mesh.matrix_world @ v.co).y for v in mesh.data.vertices)
max_y = max((mesh.matrix_world @ v.co).y for v in mesh.data.vertices)
mesh.location.y -= min_y
mesh.scale *= 1.7 / (max_y - min_y)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
# Rebase the render mesh once more after normalization so the exported node's
# local origin is unambiguously at the contact plane (the feet).
feet_y = min(v.co.y for v in mesh.data.vertices)
for v in mesh.data.vertices:
    v.co.y -= feet_y
# Keep the feet on Y=0 while centering the footprint in X/Z, as required by
# the model contract. This prevents a centered collider from looking offset.
min_x = min(v.co.x for v in mesh.data.vertices); max_x = max(v.co.x for v in mesh.data.vertices)
min_z = min(v.co.z for v in mesh.data.vertices); max_z = max(v.co.z for v in mesh.data.vertices)
for v in mesh.data.vertices:
    v.co.x -= (min_x + max_x) * 0.5
    v.co.z -= (min_z + max_z) * 0.5
mesh.data.update()

# Apply the Blender->glTF axis conversion to the mesh geometry itself. Parenting
# an unskinned mesh under a rotated armature is not baked by every importer;
# applying it here makes Godot receive +Y as the height axis deterministically.
mesh.rotation_euler.x = math.radians(90.0)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
# After the conversion Blender Z becomes Godot Y (height), while Blender Y
# becomes Godot Z (depth). Rebase those axes in that order: feet at height 0,
# footprint centered in depth. Do not center Blender Z, or the feet move.
min_height = min(v.co.z for v in mesh.data.vertices)
for v in mesh.data.vertices:
    v.co.z -= min_height
min_depth = min(v.co.y for v in mesh.data.vertices); max_depth = max(v.co.y for v in mesh.data.vertices)
for v in mesh.data.vertices:
    v.co.y -= (min_depth + max_depth) * 0.5
mesh.data.update()

# Species-adapted rig in the converted Blender Z-up frame.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
arm = bpy.context.object; arm.name = "PKM_CHARIZARD_ARMATURE"
for b in list(arm.data.edit_bones): arm.data.edit_bones.remove(b)
bone_specs = {
    "root": ((0,0,0),(0,0,.25)), "pelvis": ((0,.05,.45),(0,.04,.72)),
    "spine": ((0,.03,.72),(0,-.02,1.05)), "chest": ((0,-.04,1.02),(0,-.05,1.25)),
    "neck": ((0,-.12,1.22),(0,-.15,1.40)), "head": ((0,-.20,1.40),(0,-.28,1.62)),
    "jaw": ((0,-.35,1.32),(0,-.48,1.32)),
    "arm_l": ((-.25,-.08,1.08),(-.42,-.03,.88)), "arm_r": ((.25,-.08,1.08),(.42,-.03,.88)),
    "leg_l": ((-.18,.04,.52),(-.20,-.05,.18)), "leg_r": ((.18,.04,.52),(.20,-.05,.18)),
    "wing_l": ((-.45,.15,1.15),(-.95,.24,1.42)), "wing_r": ((.45,.15,1.15),(.95,.24,1.42)),
    "tail": ((0,.30,.62),(0,.92,.78)),
}
for name, (head, tail) in bone_specs.items():
    b=arm.data.edit_bones.new(name); b.head=head; b.tail=tail
    if name != "root": b.parent=arm.data.edit_bones["root"]
bpy.ops.object.mode_set(mode='OBJECT')
groups = {name: mesh.vertex_groups.new(name=name) for name in bone_specs}
points = {name: Vector(spec[0]) for name, spec in bone_specs.items()}
for vertex in mesh.data.vertices:
    nearest = min(points, key=lambda name: (vertex.co - points[name]).length)
    groups[nearest].add([vertex.index], 1.0, 'REPLACE')
mesh.parent=arm
mod = mesh.modifiers.new("PKM_CHARIZARD_ARMATURE_MODIFIER", 'ARMATURE'); mod.object = arm

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
action("PKM_CHARIZARD_IDLE", [1,20,40], [zero, {"chest":(math.radians(2),0,0)}, zero])
action("PKM_CHARIZARD_WALK", [1,10,20], [{"leg_l":(.35,0,0),"leg_r":(-.35,0,0),"arm_l":(-.20,0,0),"arm_r":(.20,0,0),"tail":(0,.12,0)}, zero, {"leg_l":(-.35,0,0),"leg_r":(.35,0,0),"arm_l":(.20,0,0),"arm_r":(-.20,0,0),"tail":(0,-.12,0)}])
action("PKM_CHARIZARD_RUN", [1,8,16], [{"leg_l":(.65,0,0),"leg_r":(-.65,0,0),"arm_l":(-.35,0,0),"arm_r":(.35,0,0),"wing_l":(.18,0,0),"wing_r":(-.18,0,0)}, zero, {"leg_l":(-.65,0,0),"leg_r":(.65,0,0),"arm_l":(.35,0,0),"arm_r":(-.35,0,0),"wing_l":(-.18,0,0),"wing_r":(.18,0,0)}])
action("PKM_CHARIZARD_ATTACK_01", [1,8,16], [zero, {"chest":(math.radians(-18),0,0),"jaw":(math.radians(-14),0,0),"arm_l":(math.radians(-20),0,0),"arm_r":(math.radians(-20),0,0)}, zero])
action("PKM_CHARIZARD_HIT", [1,5,12], [zero, {"chest":(0,0,math.radians(-18)),"head":(0,0,math.radians(-10))}, zero])
action("PKM_CHARIZARD_FAINT", [1,12,30], [zero, {"root":(0,0,math.radians(-35))}, {"root":(0,0,math.radians(-70))}])
action("PKM_CHARIZARD_FLY", [1,8,16], [{"wing_l":(.35,0,0),"wing_r":(-.35,0,0)}, zero, {"wing_l":(-.35,0,0),"wing_r":(.35,0,0)}])

# Blender's native up axis is +Z, while the construction above deliberately
# uses Godot-style +Y coordinates. Bake the conversion into the asset so Godot
# receives an upright model and does not need the runtime correction fallback.
# Coordinate conversion is handled by Blender's glTF exporter; the source
# mesh is already built in the Godot-style +Y frame.

# Export only the rig and its mesh. GLB keeps the two materials and animations.
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True, export_nla_strips=True, export_apply=True)
print("WROTE", OUT)
