"""Gate da fonte Blender, independente da importação no Godot."""
import bpy

mesh=bpy.data.objects.get("PKM_PIDGEOT_BODY")
arm=bpy.data.objects.get("PKM_PIDGEOT_ARMATURE")
assert mesh and mesh.type=="MESH", "malha ausente"
assert arm and arm.type=="ARMATURE", "rig ausente"
assert not mesh.data.validate(verbose=True), "malha inválida"
assert len(arm.data.bones)==12, "rig não corresponde ao contrato"
assert len(mesh.data.materials)==5, "paleta incompleta"
assert all(vertex.groups for vertex in mesh.data.vertices), "vértice sem peso"
assert abs(min(v.co.z for v in mesh.data.vertices))<.005, "pés fora da origem"
assert 1.49<=max(v.co.z for v in mesh.data.vertices)<=1.505, "altura fora do contrato"
assert sum(len(p.vertices)-2 for p in mesh.data.polygons)<=2500, "orçamento excedido"
for suffix in ("IDLE","WALK","RUN","FLY","ATTACK_01","HIT","FAINT"):
    action=bpy.data.actions.get("PKM_PIDGEOT_"+suffix)
    assert action and action.frame_end>action.frame_start, "Action inválida: "+suffix
    assert not any("location" in curve.data_path for curve in action.fcurves), "root motion: "+suffix
print("PIDGEOT_GOLDEN_VALIDADO triangles=%d bones=12 materials=5 actions=7" %
      sum(len(p.vertices)-2 for p in mesh.data.polygons))
