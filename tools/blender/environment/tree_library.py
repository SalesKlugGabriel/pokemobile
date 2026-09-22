"""Malhas orgânicas reutilizáveis para a biblioteca de árvores do WORLD_LAB."""
import math
import random
from mathutils import Vector


def append_tube(vertices, faces, materials, points, radii, material_index, sides=7):
    """Galho de anéis irregulares; não usa cilindro como geometria final."""
    start = len(vertices)
    for i, point in enumerate(points):
        tangent = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        sideways = tangent.cross(Vector((0, 1, 0)))
        if sideways.length_squared < 0.001:
            sideways = tangent.cross(Vector((1, 0, 0)))
        sideways.normalize()
        upwards = sideways.cross(tangent).normalized()
        for side in range(sides):
            angle = math.tau * side / sides + i * 0.19
            vertices.append(Vector(point) + (sideways * math.cos(angle) + upwards * math.sin(angle)) * radii[i])
    for ring in range(len(points) - 1):
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((start + ring * sides + side, start + ring * sides + next_side,
                          start + (ring + 1) * sides + next_side, start + (ring + 1) * sides + side))
            materials.append(material_index)


def append_lobe(vertices, faces, materials, center, scale, seed, material_index):
    """Volume foliar facetado e assimétrico, em vez de esfera/copa única."""
    rng = random.Random(seed)
    center = Vector(center)
    rings, sides = 5, 7
    start = len(vertices)
    profile = [0.08, 0.78, 1.0, 0.72, 0.16]
    for ring in range(rings):
        height = (ring / (rings - 1) - .5) * 2.0
        for side in range(sides):
            angle = math.tau * side / sides + rng.uniform(-.10, .10)
            wobble = 1.0 + rng.uniform(-.16, .16)
            vertices.append(center + Vector((math.cos(angle) * scale.x * profile[ring] * wobble,
                                              math.sin(angle) * scale.y * profile[ring] * wobble,
                                              height * scale.z * (1.0 + rng.uniform(-.07, .07)))))
    for ring in range(rings - 1):
        for side in range(sides):
            n = (side + 1) % sides
            faces.append((start + ring * sides + side, start + ring * sides + n,
                          start + (ring + 1) * sides + n, start + (ring + 1) * sides + side))
            materials.append(material_index)


VARIANTS = [
    {"id": "a", "height": 6.4, "lean": -.32, "crown": [(0, 0, 4.9), (-.8, .2, 4.5), (.8, -.3, 4.35), (-.25, .8, 5.4), (.35, -.7, 5.35)]},
    {"id": "b", "height": 5.4, "lean": .38, "crown": [(0, 0, 4.1), (-.9, -.1, 3.85), (.75, .5, 4.45), (.3, -.8, 4.8)]},
    {"id": "c", "height": 7.2, "lean": -.12, "crown": [(0, 0, 5.7), (-1.0, .3, 5.1), (1.05, -.25, 5.2), (-.5, -.9, 6.05), (.55, .85, 6.0), (0, .2, 6.75)]},
    {"id": "d", "height": 5.9, "lean": .52, "crown": [(0, 0, 4.4), (-.9, .5, 4.5), (.75, -.4, 4.1), (.15, .9, 5.1), (-.3, -.75, 5.0)]},
    {"id": "e", "height": 6.7, "lean": .08, "crown": [(0, 0, 5.1), (-1.05, -.2, 4.7), (.95, .35, 4.8), (-.45, .85, 5.65), (.55, -.8, 5.7), (0, 0, 6.35)]},
]
