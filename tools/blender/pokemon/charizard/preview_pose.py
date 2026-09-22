"""Preview de pose controlada por PKM_PREVIEW_ACTION=IDLE|WALK|RUN."""
import os
import bpy

root = os.environ.get("POKEMOBILE_ROOT", os.getcwd())
path = os.path.join(root, "assets/models/pokemon/source/charizard_golden/Charizard_Golden_Working.glb")
bpy.ops.import_scene.gltf(filepath=path)
arm = bpy.data.objects.get("PKM_CHARIZARD_ARMATURE")
label = os.environ.get("PKM_PREVIEW_ACTION", "IDLE")
name = "PKM_CHARIZARD_%s_PKM_CHARIZARD_ARMATURE" % label
action = bpy.data.actions.get(name)
if arm is None or action is None:
    raise RuntimeError("Action ausente no GLB: " + name)
arm.animation_data_create()
arm.animation_data.action = action
bpy.context.scene.frame_set(1)
