import bpy, math, os
from mathutils import Vector

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

def finish(parts, target_height, filename, kind):
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
    if kind=="gyarados":
        prefix="PKM_GYARADOS"; bone_specs={
            "root":((0,0,0),(0,0,.3)),"body_01":((0,-.5,.65),(0,.1,.85)),"body_02":((0,.1,.85),(0,.8,1.05)),
            "body_03":((0,.8,1.05),(0,1.45,1.25)),"neck":((0,1.45,1.25),(0,2.0,1.42)),"head":((0,2.0,1.42),(0,2.55,1.42)),
            "jaw":((0,2.35,1.18),(0,2.65,1.18)),"fin_l":((-.2,.4,1.05),(-.9,.55,1.15)),"fin_r":((.2,.4,1.05),(.9,.55,1.15))}
    else:
        prefix="PKM_PIDGEOT"; bone_specs={
            "root":((0,0,0),(0,0,.25)),"body":((0,0,.45),(0,0,.95)),"neck":((0,.1,.95),(0,.24,1.25)),
            "head":((0,.24,1.25),(0,.42,1.48)),"wing_l":((-.2,0,.95),(-1.0,.05,1.15)),"wing_r":((.2,0,.95),(1.0,.05,1.15)),
            "tail":((0,-.2,.65),(0,-.8,.65))}
    bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0)); arm=bpy.context.object; arm.name=prefix+"_ARMATURE"
    for b in list(arm.data.edit_bones):arm.data.edit_bones.remove(b)
    for name,(head,tail) in bone_specs.items():
        b=arm.data.edit_bones.new(name); b.head=head; b.tail=tail
        if name!="root":b.parent=arm.data.edit_bones["root"]
    bpy.ops.object.mode_set(mode='OBJECT')
    groups={name:mesh.vertex_groups.new(name=name) for name in bone_specs}; points={name:Vector(spec[0]) for name,spec in bone_specs.items()}
    neighbors=[[] for _ in mesh.data.vertices]
    for poly in mesh.data.polygons:
        for a in poly.vertices:neighbors[a].extend(b for b in poly.vertices if b!=a)
    seen=set()
    for start in range(len(neighbors)):
        if start in seen:continue
        stack=[start]; seen.add(start); component=[]
        while stack:
            vertex=stack.pop(); component.append(vertex)
            for neighbor in neighbors[vertex]:
                if neighbor not in seen:seen.add(neighbor); stack.append(neighbor)
        center=sum((mesh.data.vertices[i].co for i in component),Vector())/len(component)
        nearest=min(points,key=lambda name:(center-points[name]).length); groups[nearest].add(component,1.0,'REPLACE')
    mesh.parent=arm; modifier=mesh.modifiers.new(prefix+"_ARMATURE_MODIFIER",'ARMATURE'); modifier.object=arm
    def action(name,frames,poses):
        act=bpy.data.actions.new(prefix+"_"+name); arm.animation_data_create(); arm.animation_data.action=act
        for frame,pose in zip(frames,poses):
            for bone_name,rot in pose.items():
                pb=arm.pose.bones[bone_name]; pb.rotation_mode='XYZ'; pb.rotation_euler=rot; pb.keyframe_insert('rotation_euler',frame=frame)
        tr=arm.animation_data.nla_tracks.new(); tr.name=act.name; st=tr.strips.new(act.name,frames[0],act); st.action_frame_start=frames[0]; st.action_frame_end=frames[-1]; arm.animation_data.action=None
    zero={}
    if kind=="gyarados":
        action("IDLE",[1,20,40],[zero,{"body_02":(0,0,.08),"body_03":(0,0,-.08)},zero]); action("SWIM",[1,12,24],[{"body_01":(0,0,.14),"body_03":(0,0,-.18)},zero,{"body_01":(0,0,-.14),"body_03":(0,0,.18)}]); action("ATTACK_01",[1,8,18],[zero,{"neck":(-.25,0,0),"jaw":(-.28,0,0)},zero]); action("HIT",[1,5,12],[zero,{"head":(0,0,-.24)},zero]); action("FAINT",[1,15,32],[zero,{"root":(0,0,-.5)},{"root":(0,0,-1.1)}])
    else:
        action("IDLE",[1,20,40],[zero,{"head":(.04,0,0)},zero]); action("WALK",[1,10,20],[{"body":(.08,0,0),"tail":(0,.12,0)},zero,{"body":(-.08,0,0),"tail":(0,-.12,0)}]); action("FLY",[1,8,16],[{"wing_l":(.55,0,0),"wing_r":(-.55,0,0)},zero,{"wing_l":(-.55,0,0),"wing_r":(.55,0,0)}]); action("ATTACK_01",[1,7,16],[zero,{"head":(-.25,0,0),"wing_l":(.25,0,0),"wing_r":(-.25,0,0)},zero]); action("HIT",[1,5,12],[zero,{"body":(0,0,-.22)},zero]); action("FAINT",[1,14,30],[zero,{"root":(0,0,-.55)},{"root":(0,0,-1.1)}])
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
    finish(p,6.5,"130.glb","gyarados")

def pidgeot():
    brown=material("pidgeot_brown",(.48,.25,.10)); cream=material("pidgeot_cream",(.86,.72,.46)); p=[]
    uv("body",(0,.78,.05),(.34,.55,.28),brown,p); uv("chest",(0,1.02,-.22),(.27,.38,.22),cream,p); uv("head",(0,1.42,-.30),(.25,.25,.24),brown,p); cone("beak",(0,1.39,-.63),.14,.02,.38,cream,p,(math.pi/2,0,0))
    for s in (-1,1):
        uv("eye",(.12*s,1.48,-.49),(.04,.05,.03),dark if False else brown,p); wing("wing",s,brown,p,1.2,1.2)
    for s in (-1,1):
        for i in range(3): cone("tail_feather",(.20*s*i, .76, .48+.20*i),.09,.015,.62,cream,p,(math.pi/2,0,.15*s))
    finish(p,1.5,"18.glb","pidgeot")

reset(); gyarados(); reset(); pidgeot()
