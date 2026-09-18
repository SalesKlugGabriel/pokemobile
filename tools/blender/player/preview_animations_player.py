"""Render Workbench de poses de validação das Actions do Player V1."""

import os

import bpy
from mathutils import Vector

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
OUTPUT_DIR = os.path.join(PROJECT_DIR, "assets/characters/player_v1/previews")
POSES = {
    "idle": ("PLAYER_V1_IDLE", 37),
    "walk": ("PLAYER_V1_WALK", 1),
    "run": ("PLAYER_V1_RUN", 1),
}


def main():
    armature = bpy.data.objects.get("PLAYER_V1_ARMATURE")
    if armature is None:
        raise RuntimeError("PLAYER_V1_ARMATURE ausente")
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 560
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PLAYER_V1_ANIMATION_PREVIEW_WORLD")
    scene.world.color = (.16, .18, .22)
    camera_data = bpy.data.cameras.new("PLAYER_V1_ANIMATION_PREVIEW_CAMERA")
    camera = bpy.data.objects.new("PLAYER_V1_ANIMATION_PREVIEW_CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 1.85
    camera.location = (2.6, -3.2, 1.08)
    camera.rotation_euler = (Vector((0, 0, .80)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    armature.animation_data_create()
    for label, (action_name, frame) in POSES.items():
        armature.animation_data.action = bpy.data.actions[action_name]
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(OUTPUT_DIR, f"{label}.png")
        bpy.ops.render.render(write_still=True)
        print(f"PLAYER_V1_ANIMATION_PREVIEW {label} action={action_name} frame={frame}")
    armature.animation_data.action = None
    scene.frame_set(1)


if __name__ == "__main__":
    main()
