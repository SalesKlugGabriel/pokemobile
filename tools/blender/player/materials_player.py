"""Paleta PBR simples do Player V1; cores-base do briefing, não da prancha sombreada."""

import bpy

PALETTE = {
    "RED": (0xB8, 0x42, 0x42),
    "BLUE": (0x31, 0x5F, 0xA8),
    "DARK": (0x25, 0x28, 0x31),
    # The trouser cloth must separate from gloves, backpack and shoe rubber.
    "PANTS": (0x36, 0x3A, 0x46),
    "LIGHT": (0xE5, 0xE3, 0xDF),
    "SKIN": (0xD1, 0x9A, 0x82),
    "HAIR": (0x20, 0x1D, 0x1D),
    "TRIM": (0x47, 0x50, 0x61),
    "BLACK": (0x12, 0x14, 0x19),
}


def srgb_to_linear(channel):
    value = channel / 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def create_materials():
    result = {}
    for label, color in PALETTE.items():
        name = f"PLAYER_V1_MAT_{label}"
        material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        rgba = tuple(srgb_to_linear(channel) for channel in color) + (1.0,)
        material.diffuse_color = rgba
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = rgba
        principled.inputs["Roughness"].default_value = 0.78 if label != "BLACK" else 0.68
        principled.inputs["Metallic"].default_value = 0.0
        result[label] = material
    return result
