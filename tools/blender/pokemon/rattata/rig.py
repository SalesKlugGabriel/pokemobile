import bpy


PREFIXO = "PKM_RATTATA"


def criar(malha):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = PREFIXO + "_ARMATURE"
    for osso in list(armature.data.edit_bones):
        armature.data.edit_bones.remove(osso)

    # Coordenadas já convertidas: Z é altura; frente visual do asset é -Z Godot.
    ossos = {
        "root": ((0, 0, 0), (0, 0, .05)),
        "pelvis": ((0, .02, .07), (0, .01, .13)),
        "spine": ((0, .01, .12), (0, -.02, .18)),
        "chest": ((0, -.03, .16), (0, -.07, .21)),
        "head": ((0, -.12, .21), (0, -.19, .25)),
        "jaw": ((0, -.19, .18), (0, -.25, .18)),
        "ear_l": ((-.05, -.14, .23), (-.07, -.14, .30)),
        "ear_r": ((.05, -.14, .23), (.07, -.14, .30)),
        "front_l": ((-.06, -.10, .12), (-.07, -.12, .025)),
        "front_r": ((.06, -.10, .12), (.07, -.12, .025)),
        "back_l": ((-.07, .08, .12), (-.07, .08, .025)),
        "back_r": ((.07, .08, .12), (.07, .08, .025)),
        "tail_01": ((0, .14, .12), (0, .25, .13)),
        "tail_02": ((0, .25, .13), (0, .39, .18)),
    }
    pais = {
        "pelvis": "root", "spine": "pelvis", "chest": "spine", "head": "chest",
        "jaw": "head", "ear_l": "head", "ear_r": "head",
        "front_l": "chest", "front_r": "chest", "back_l": "pelvis", "back_r": "pelvis",
        "tail_01": "pelvis", "tail_02": "tail_01",
    }
    for nome, (cabeca, cauda) in ossos.items():
        osso = armature.data.edit_bones.new(nome)
        osso.head = cabeca
        osso.tail = cauda
        if nome in pais:
            osso.parent = armature.data.edit_bones[pais[nome]]
    bpy.ops.object.mode_set(mode="OBJECT")
    malha.parent = armature
    modificador = malha.modifiers.new(PREFIXO + "_ARMATURE_MODIFIER", "ARMATURE")
    modificador.object = armature
    return armature
