"""Previews Workbench para inspeção humana das poses exportadas do Rattata."""
import bpy
import os
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
OUT = os.path.join(ROOT, "assets/models/pokemon/previews/rattata_19")
POSES = {
    "idle": ("PKM_RATTATA_IDLE", 20),
    "walk": ("PKM_RATTATA_WALK", 1),
    "run": ("PKM_RATTATA_RUN", 1),
    "attack": ("PKM_RATTATA_ATTACK_01", 7),
    "hit": ("PKM_RATTATA_HIT", 5),
    "faint": ("PKM_RATTATA_FAINT", 30),
}


def main():
    armature = bpy.data.objects.get("PKM_RATTATA_ARMATURE")
    if armature is None:
        raise RuntimeError("PKM_RATTATA_ARMATURE ausente")
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 560
    scene.render.resolution_y = 420
    scene.render.image_settings.file_format = "PNG"
    camera_data = bpy.data.cameras.new("RATTATA_PREVIEW_CAMERA")
    camera = bpy.data.objects.new("RATTATA_PREVIEW_CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    # Inclui cauda e focinho no quadro: a revisão de silhueta não vale se a
    # câmera cortar justamente os dois extremos que distinguem um roedor.
    camera_data.ortho_scale = 0.85
    # Vista lateral revela as quatro patas e a cauda; uma vista longitudinal
    # fazia a silhueta parecer uma pilha de volumes e escondia defeitos.
    camera.location = (0.78, -0.04, 0.42)
    camera.rotation_euler = (Vector((0, 0, .15)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    os.makedirs(OUT, exist_ok=True)
    armature.animation_data_create()
    # Actions são exportadas pelas faixas NLA, mas a inspeção precisa isolar UMA
    # Action por vez; somar todas as faixas mascara deformações e cria poses falsas.
    armature.animation_data.use_nla = False
    for nome, (acao, quadro) in POSES.items():
        armature.animation_data.action = bpy.data.actions[acao]
        scene.frame_set(quadro)
        scene.render.filepath = os.path.join(OUT, nome + ".png")
        bpy.ops.render.render(write_still=True)
        print("RATTATA_PREVIEW", nome, acao, quadro)
    armature.animation_data.action = None
    armature.animation_data.use_nla = True
    scene.frame_set(1)


if __name__ == "__main__":
    main()
