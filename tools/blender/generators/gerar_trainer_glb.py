import bpy, math, os

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

# Bake Blender Z-up -> Godot Y-up conversion around an origin at the feet.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0)); arm=bpy.context.object; arm.name="TrainerRig"; arm.data.edit_bones[0].head=(0,0,0); arm.data.edit_bones[0].tail=(0,1,0); bpy.ops.object.mode_set(mode='OBJECT')
arm.rotation_euler.x=math.radians(90); mesh.parent=arm
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True)
print("WROTE", OUT)
