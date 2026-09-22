"""Rig de Charizard: nomes antigos preservados, articulações adicionais."""
import bpy

BONES = {
    "root":((0,0,0),(0,0,.22),None),
    "pelvis":((0,-.04,.48),(0,-.04,.69),"root"),
    "spine":((0,-.04,.68),(0,0,1.00),"pelvis"),
    "chest":((0,0,1.00),(0,.04,1.23),"spine"),
    "neck":((0,.06,1.22),(0,.16,1.40),"chest"),
    "head":((0,.18,1.42),(0,.31,1.58),"neck"),
    "jaw":((0,.34,1.43),(0,.54,1.44),"head"),
    "arm_l":((-.25,.02,1.14),(-.38,.09,1.02),"chest"),
    "arm_r":((.25,.02,1.14),(.38,.09,1.02),"chest"),
    "forearm_l":((-.38,.09,1.02),(-.43,.25,.91),"arm_l"),
    "forearm_r":((.38,.09,1.02),(.43,.25,.91),"arm_r"),
    "hand_l":((-.43,.25,.91),(-.43,.36,.87),"forearm_l"),
    "hand_r":((.43,.25,.91),(.43,.36,.87),"forearm_r"),
    "leg_l":((-.20,-.04,.53),(-.24,.02,.36),"pelvis"),
    "leg_r":((.20,-.04,.53),(.24,.02,.36),"pelvis"),
    "shin_l":((-.24,.02,.36),(-.23,.16,.15),"leg_l"),
    "shin_r":((.24,.02,.36),(.23,.16,.15),"leg_r"),
    "foot_l":((-.23,.16,.15),(-.23,.39,.07),"shin_l"),
    "foot_r":((.23,.16,.15),(.23,.39,.07),"shin_r"),
    "wing_l":((-.27,-.12,1.22),(-.85,-.30,1.47),"chest"),
    "wing_r":((.27,-.12,1.22),(.85,-.30,1.47),"chest"),
    "tail":((0,-.20,.62),(0,-.87,.52),"pelvis"),
    "tail_tip":((0,-.87,.52),(0,-1.48,.82),"tail"),
}


def create(geometry, materials):
    mesh_data = bpy.data.meshes.new("PKM_CHARIZARD_BODY_MESH")
    mesh_data.from_pydata(geometry.vertices, [], geometry.faces)
    mesh_data.update()
    for value in materials: mesh_data.materials.append(value)
    for polygon, index in zip(mesh_data.polygons, geometry.face_materials):
        polygon.material_index = index
        polygon.use_smooth = index not in (1, 3, 5)
    mesh = bpy.data.objects.new("PKM_CHARIZARD_BODY", mesh_data)
    bpy.context.collection.objects.link(mesh)

    arm_data = bpy.data.armatures.new("PKM_CHARIZARD_RIG")
    arm = bpy.data.objects.new("PKM_CHARIZARD_ARMATURE", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (start, end, _) in BONES.items():
        bone = arm_data.edit_bones.new(name)
        bone.head, bone.tail = start, end
    for name, (_, _, parent) in BONES.items():
        if parent: arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {name: mesh.vertex_groups.new(name=name) for name in BONES}
    for index, mapping in enumerate(geometry.weights):
        total = sum(weight for weight in mapping.values() if weight > 0.0)
        for name, weight in mapping.items():
            if weight > 0.0: groups[name].add([index], weight / total, "REPLACE")
    mesh.parent = arm
    modifier = mesh.modifiers.new("PKM_CHARIZARD_SKIN", "ARMATURE")
    modifier.object = arm
    return arm, mesh
