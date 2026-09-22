"""Gate Blender do Charizard Golden. Uso: blender -b Working.blend -P validate.py."""
import bpy

mesh = bpy.data.objects.get("PKM_CHARIZARD_BODY")
arm = bpy.data.objects.get("PKM_CHARIZARD_ARMATURE")
assert mesh is not None and mesh.type == "MESH", "malha ausente"
assert arm is not None and arm.type == "ARMATURE", "rig ausente"
assert len(arm.data.bones) >= 23, "articulações de deformação ausentes"
assert len(mesh.data.materials) == 7, "paleta PBR não corresponde à exportada"
assert not mesh.data.validate(verbose=True), "geometria inválida"
assert 0.0 <= min(vertex.co.z for vertex in mesh.data.vertices) <= .02, "pés fora da origem"
assert 1.64 <= max(vertex.co.z for vertex in mesh.data.vertices) <= 1.75, "altura fora do contrato"
assert len(mesh.data.polygons) < 1800, "fonte excedeu orçamento geométrico"
assert all(vertex.groups for vertex in mesh.data.vertices), "vértice sem skin weight"
assert all(mod.type != "ARMATURE" or mod.object == arm for mod in mesh.modifiers), "Armature Modifier inválido"
for suffix in ["IDLE", "WALK", "RUN", "ATTACK_01", "HIT", "FAINT", "FLY"]:
    name = "PKM_CHARIZARD_" + suffix
    action = bpy.data.actions.get(name)
    assert action is not None and action.frame_end > action.frame_start, "Action inválida: " + name
    assert not any('location' in curve.data_path for curve in action.fcurves), "root motion inesperado: " + name
print("CHARIZARD_GOLDEN_VALIDADO vertices=%d faces=%d bones=%d materials=%d actions=7" %
      (len(mesh.data.vertices), len(mesh.data.polygons), len(arm.data.bones), len(mesh.data.materials)))
