"""Paleta PBR contida para Pidgeot; cores funcionam sem texturas externas."""
import bpy

PALETTE = (
    ("PKM_PIDGEOT_MAT_BROWN", (.40, .205, .095, 1), .88),
    ("PKM_PIDGEOT_MAT_CREAM", (.80, .65, .37, 1), .86),
    ("PKM_PIDGEOT_MAT_DARK", (.105, .055, .038, 1), .78),
    ("PKM_PIDGEOT_MAT_GOLD", (.95, .63, .12, 1), .70),
    ("PKM_PIDGEOT_MAT_RED", (.72, .19, .12, 1), .84),
)


def create():
    result = []
    for name, color, roughness in PALETTE:
        material = bpy.data.materials.new(name)
        material.diffuse_color = color
        material.use_nodes = True
        principled = material.node_tree.nodes["Principled BSDF"]
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = 0
        result.append(material)
    return result
