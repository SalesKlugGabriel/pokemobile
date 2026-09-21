import bpy
import os


def salvar_e_exportar(armature, malha, frente, raiz):
    destino_fonte = os.path.join(raiz, "assets/models/pokemon/source/rattata_19.blend")
    destino_glb = os.path.join(raiz, "assets/models/pokemon/19.glb")
    os.makedirs(os.path.dirname(destino_fonte), exist_ok=True)
    os.makedirs(os.path.dirname(destino_glb), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=destino_fonte)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    malha.select_set(True)
    frente.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(filepath=destino_glb, export_format="GLB", use_selection=True,
        export_animations=True, export_nla_strips=True, export_apply=True,
        export_cameras=False, export_lights=False)
    return destino_fonte, destino_glb
