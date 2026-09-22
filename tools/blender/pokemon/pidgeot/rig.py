"""Esqueleto de ave com dobradiças independentes para asas e pernas."""
import bpy

BONES = {
    "root": ((0,0,0),(0,0,.2),None),
    "body": ((0,-.09,.49),(0,0,.94),"root"),
    "head": ((0,.08,1.08),(0,.23,1.34),"body"),
    "wing_upper_l": ((-.22,-.015,1.01),(-.72,-.17,1.16),"body"),
    "wing_outer_l": ((-.72,-.17,1.16),(-1.26,-.29,1.15),"wing_upper_l"),
    "wing_upper_r": ((.22,-.015,1.01),(.72,-.17,1.16),"body"),
    "wing_outer_r": ((.72,-.17,1.16),(1.26,-.29,1.15),"wing_upper_r"),
    "leg_l": ((-.145,-.065,.42),(-.17,.09,.11),"body"),
    "leg_r": ((.145,-.065,.42),(.17,.09,.11),"body"),
    "foot_l": ((-.17,.09,.11),(-.17,.27,.04),"leg_l"),
    "foot_r": ((.17,.09,.11),(.17,.27,.04),"leg_r"),
    "tail": ((0,-.18,.49),(0,-.65,.39),"body"),
}


def create(geometry, materials):
    data = bpy.data.meshes.new("PKM_PIDGEOT_BODY_MESH")
    data.from_pydata(geometry.vertices, [], geometry.faces)
    data.update()
    for material in materials:
        data.materials.append(material)
    for polygon, index in zip(data.polygons, geometry.materials):
        polygon.material_index = index
        polygon.use_smooth = index not in (3,)
    mesh = bpy.data.objects.new("PKM_PIDGEOT_BODY", data)
    bpy.context.collection.objects.link(mesh)

    arm_data = bpy.data.armatures.new("PKM_PIDGEOT_RIG")
    arm = bpy.data.objects.new("PKM_PIDGEOT_ARMATURE", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name,(head,tail,_) in BONES.items():
        bone=arm_data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
    for name,(_,_,parent) in BONES.items():
        if parent:
            arm_data.edit_bones[name].parent=arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    groups={name:mesh.vertex_groups.new(name=name) for name in BONES}
    for index, mapping in enumerate(geometry.weights):
        for name, weight in mapping.items():
            groups[name].add([index],weight,"REPLACE")
    mesh.parent=arm
    modifier=mesh.modifiers.new("PKM_PIDGEOT_SKIN","ARMATURE")
    modifier.object=arm
    return arm,mesh
