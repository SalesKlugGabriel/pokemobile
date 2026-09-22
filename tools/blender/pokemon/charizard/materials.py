"""Paleta Principled de tempo real do Charizard Golden."""
import bpy

PALETTE = [
    ("PKM_CHARIZARD_MAT_ORANGE", (0.68, 0.19, 0.055, 1), .83),
    ("PKM_CHARIZARD_MAT_SHADOW", (0.43, 0.105, 0.038, 1), .86),
    ("PKM_CHARIZARD_MAT_CREAM", (0.83, 0.58, 0.30, 1), .79),
    ("PKM_CHARIZARD_MAT_WING", (0.075, 0.20, 0.27, 1), .81),
    ("PKM_CHARIZARD_MAT_EYE", (0.045, 0.085, 0.105, 1), .50),
    ("PKM_CHARIZARD_MAT_CLAW", (0.83, 0.78, 0.62, 1), .74),
    ("PKM_CHARIZARD_MAT_FLAME", (0.98, 0.32, 0.025, 1), .48),
]


def create():
    values = []
    for name, color, roughness in PALETTE:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = 0.0
        if name.endswith("WING"):
            material.use_backface_culling = False
        if name.endswith("FLAME"):
            bsdf.inputs["Emission Color"].default_value = (1.0, .18, .01, 1)
            bsdf.inputs["Emission Strength"].default_value = .20
        values.append(material)
    return values
