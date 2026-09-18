"""Fase 3 — turnaround Workbench, sem render de apresentação enganoso.

Uso: blender --background assets/characters/player_v1/player_v1.blend \
       --python tools/blender/player/preview_player.py
"""

import os

import bpy
from mathutils import Vector

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
PREVIEW_DIR = os.path.join(PROJECT_DIR, "assets/characters/player_v1/previews")
VIEWS = {
    "front": (0.0, -4.0, 1.05),
    "front_3_4": (2.6, -3.2, 1.08),
    "side": (4.0, 0.0, 1.05),
    "back_3_4": (2.6, 3.2, 1.08),
    "back": (0.0, 4.0, 1.05),
}


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.curvature_ridge_factor = 1.1
    scene.display.shading.curvature_valley_factor = 1.0
    scene.render.resolution_x = 560
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("PLAYER_V1_PREVIEW_WORLD")
    scene.world.color = (0.16, 0.18, 0.22)
    scene.display.shading.background_type = "WORLD"
    camera_data = bpy.data.cameras.new("PLAYER_V1_PREVIEW_CAMERA")
    camera = bpy.data.objects.new("PLAYER_V1_PREVIEW_CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 1.85
    scene.camera = camera
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    target = Vector((0.0, 0.0, 0.8))
    for name, location in VIEWS.items():
        camera.location = location
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"PLAYER_V1_PREVIEW {name} {scene.render.filepath}")


if __name__ == "__main__":
    render()
