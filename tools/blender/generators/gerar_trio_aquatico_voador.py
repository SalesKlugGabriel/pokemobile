import bpy, math, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/models/pokemon"))

def material(name, color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(*color,1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.78
    return m

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def uv(name, loc, scale, mat, parts):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat); parts.append(o); return o

def cone(name, loc, r1, r2, depth, mat, parts, rot=(0,0,0), verts=10):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name; o.data.materials.append(mat); parts.append(o); return o

def wing(name, side, mat, parts, y=1.0, span=1.0):
    x=side
    verts=[(0.16*x,y,0),(0.50*x,y+.28,0.10),(span*x,y+.42,0.22),(span*.82*x,y-.40,0.30),(span*.36*x,y-.18,0.10)]
    faces=[(0,1,4),(1,2,3,4),(0,4,3)]
    me=bpy.data.meshes.new(name+"Mesh"); me.from_pydata(verts,[],faces); me.materials.append(mat)
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); parts.append(o)

def finish(parts, target_height, filename):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); mesh=bpy.context.object
    bpy.context.view_layer.update()
    min_y=min(v.co.y for v in mesh.data.vertices); max_y=max(v.co.y for v in mesh.data.vertices)
    mesh.location.y-=min_y; mesh.scale*=target_height/(max_y-min_y)
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
    # Convert source +Y-up geometry to Godot's imported +Y height axis.
    mesh.rotation_euler.x=math.radians(90); bpy.context.view_layer.objects.active=mesh; bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    min_h=min(v.co.z for v in mesh.data.vertices)
    for v in mesh.data.vertices: v.co.z-=min_h
    min_d=min(v.co.y for v in mesh.data.vertices); max_d=max(v.co.y for v in mesh.data.vertices)
    for v in mesh.data.vertices: v.co.y-=(min_d+max_d)*.5
    min_x=min(v.co.x for v in mesh.data.vertices); max_x=max(v.co.x for v in mesh.data.vertices)
    for v in mesh.data.vertices: v.co.x-=(min_x+max_x)*.5
    mesh.data.update(); mesh.name=os.path.splitext(os.path.basename(filename))[0]
    bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0)); arm=bpy.context.object; arm.name="Rig"; arm.data.edit_bones[0].head=(0,0,0); arm.data.edit_bones[0].tail=(0,1,0); bpy.ops.object.mode_set(mode='POSE'); pb=arm.pose.bones[0]
    for name, frames, rots in [("idle",[1,20,40],[(0,0,0),(0,.02,0),(0,0,0)]),("walk",[1,10,20],[(0,0,0),(0,.08,0),(0,0,0)]),("attack",[1,8,16],[(0,0,0),(-.18,0,0),(0,0,0)]),("hurt",[1,5,12],[(0,0,0),(0,0,-.20),(0,0,0)])]:
        act=bpy.data.actions.new(name); arm.animation_data_create(); arm.animation_data.action=act; pb.rotation_mode='XYZ'
        for f,r in zip(frames,rots): pb.rotation_euler=r; pb.keyframe_insert("rotation_euler",frame=f)
        tr=arm.animation_data.nla_tracks.new(); tr.name=name; st=tr.strips.new(name,int(frames[0]),act); st.action_frame_start=frames[0]; st.action_frame_end=frames[-1]
    arm.animation_data.action=None; bpy.ops.object.mode_set(mode='OBJECT'); mesh.parent=arm
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
    os.makedirs(ROOT,exist_ok=True); bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,filename),export_format='GLB',use_selection=True,export_animations=True,export_nla_strips=True,export_apply=True)

def gyarados():
    blue=material("gyarados_blue",(.035,.22,.42)); dark=material("gyarados_fin",(.02,.07,.13)); p=[]
    # Long serpentine silhouette, head at -Z (front).
    for i in range(9): uv("body",(0,.55+.10*i,.55-.32*i),(.42-.018*i,.34,.43),blue,p)
    uv("head",(0,1.42,-2.05),(.62,.52,.62),blue,p); uv("jaw",(0,1.18,-2.50),(.48,.20,.38),dark,p)
    for s in (-1,1):
        uv("eye",(.24*s,1.58,-2.48),(.10,.09,.04),dark,p); cone("whisker",(.48*s,1.40,-2.72),.045,.008,.85,dark,p,(0,math.pi/2,0)); wing("fin",s,dark,p,1.06,.95)
    for i in range(4): cone("crest",(0,1.82+i*.13,-2.02+i*.13),.17-.025*i,.02,.34,dark,p,(0,0,0))
    finish(p,6.5,"130.glb")

def pidgeot():
    brown=material("pidgeot_brown",(.48,.25,.10)); cream=material("pidgeot_cream",(.86,.72,.46)); p=[]
    uv("body",(0,.78,.05),(.34,.55,.28),brown,p); uv("chest",(0,1.02,-.22),(.27,.38,.22),cream,p); uv("head",(0,1.42,-.30),(.25,.25,.24),brown,p); cone("beak",(0,1.39,-.63),.14,.02,.38,cream,p,(math.pi/2,0,0))
    for s in (-1,1):
        uv("eye",(.12*s,1.48,-.49),(.04,.05,.03),dark if False else brown,p); wing("wing",s,brown,p,1.2,1.2)
    for s in (-1,1):
        for i in range(3): cone("tail_feather",(.20*s*i, .76, .48+.20*i),.09,.015,.62,cream,p,(math.pi/2,0,.15*s))
    finish(p,1.5,"18.glb")

reset(); gyarados(); reset(); pidgeot()
