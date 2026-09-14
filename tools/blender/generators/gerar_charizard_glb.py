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
             (0.78*x,0.72,0.34),(0.36*x,0.86,0.18)]
    faces = [(0,1,4),(1,2,3,4),(0,4,3)]
    me = bpy.data.meshes.new(name+"Mesh"); me.from_pydata(verts, [], faces); me.materials.append(BLUE)
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); parts.append(o); return o

# Compact, deliberately low-poly silhouette: body, neck, head, muzzle, limbs, wings and tail.
add_uv("body", (0,0.86,0.08), (0.38,0.56,0.30))
add_uv("chest", (0,1.10,-0.18), (0.28,0.37,0.24))
add_uv("head", (0,1.43,-0.23), (0.27,0.27,0.25))
add_uv("muzzle", (0,1.35,-0.47), (0.20,0.15,0.16))
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
mesh.data.update()

# One-bone rig; actions prove the required four animation states without coupling gameplay to species.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
arm = bpy.context.object; arm.name = "CharizardRig"
bone = arm.data.edit_bones[0]; bone.name = "root"; bone.head=(0,0,0); bone.tail=(0,1,0)
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones["root"]
mesh.parent = arm
mod = mesh.modifiers.new("CharizardArmature", 'ARMATURE'); mod.object = arm

def action(name, frames, rotations=None, locations=None):
    act = bpy.data.actions.new(name); arm.animation_data_create(); arm.animation_data.action = act
    pb.rotation_mode='XYZ'
    for f in frames:
        pb.rotation_euler = rotations.get(f, (0,0,0)) if rotations else (0,0,0)
        pb.location = locations.get(f, (0,0,0)) if locations else (0,0,0)
        pb.keyframe_insert("rotation_euler", frame=f); pb.keyframe_insert("location", frame=f)
    act.frame_start=min(frames); act.frame_end=max(frames)
    # Exporter picks up all actions when NLA strips are present.
    track = arm.animation_data.nla_tracks.new(); track.name=name
    strip = track.strips.new(name, int(act.frame_start), act); strip.action_frame_start=act.frame_start; strip.action_frame_end=act.frame_end
    arm.animation_data.action = None

action("idle", [1,20,40], locations={1:(0,0,0),20:(0,0.015,0),40:(0,0,0)})
action("walk", [1,10,20], rotations={1:(0,0,0),10:(0,0.08,0),20:(0,0,0)})
action("attack", [1,8,16], rotations={1:(0,0,0),8:(-0.18,0,0),16:(0,0,0)})
action("hurt", [1,5,12], rotations={1:(0,0,0),5:(0,0,-0.20),12:(0,0,0)})
bpy.ops.object.mode_set(mode='OBJECT')

# Export only the rig and its mesh. GLB keeps the two materials and animations.
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True, export_nla_strips=True, export_apply=True)
print("WROTE", OUT)
