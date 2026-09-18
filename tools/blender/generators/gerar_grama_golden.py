"""Gera clusters de grama game-ready para a Golden Test Scene."""
import bpy
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
OUT_DIR = os.path.join(ROOT, "assets/models/environment/grass")


def material(name, color):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.86
    return m


GRASS = [material("GRASS_SHORT", (0.16, 0.38, 0.08)),
         material("GRASS_MID", (0.11, 0.31, 0.055)),
         material("GRASS_TALL", (0.24, 0.48, 0.09))]


def build(index, height, width, color):
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    verts = []; faces = []
    # Six blades in a radial cluster. Each blade is a tapered diamond/card,
    # keeping the silhouette readable while remaining cheap to instance.
    for i in range(6):
        ang = i * math.tau / 6.0 + index * 0.37
        dx, dz = math.cos(ang), math.sin(ang)
        side_x, side_z = -dz * width * 0.5, dx * width * 0.5
        base_x, base_z = dx * 0.035, dz * 0.035
        lean = (0.10 + index * 0.025) * dx
        tip_x, tip_z = base_x + lean, base_z + (0.10 + index * 0.02) * dz
        n = len(verts)
        verts.extend([(base_x-side_x, 0, base_z-side_z),
                      (base_x+side_x, 0, base_z+side_z),
                      (tip_x, height, tip_z)])
        faces.append((n, n+1, n+2))
        # back-facing triangle for compatibility with cull-back materials
        faces.append((n+2, n+1, n))
    mesh = bpy.data.meshes.new("GRASS_CLUSTER_MESH")
    mesh.from_pydata(verts, [], faces); mesh.materials.append(color); mesh.update()
    obj = bpy.data.objects.new(["GRASS_SHORT", "GRASS_MID", "GRASS_TALL"][index], mesh)
    bpy.context.collection.objects.link(obj)
    # Convert the authored Z-up blade to the project's Godot Y-up runtime
    # convention before exporting.
    obj.rotation_euler.x = math.radians(90.0)
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, ["grass_short.glb", "grass_mid.glb", "grass_tall.glb"][index])
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("WROTE", path)


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    build(0, 0.32, 0.26, GRASS[0])
    build(1, 0.58, 0.34, GRASS[1])
    build(2, 0.92, 0.42, GRASS[2])
