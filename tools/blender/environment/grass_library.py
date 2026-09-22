"""Geometria reutilizável de tufos de grama para o WORLD_LAB.

As lâminas usam duas seções com curvatura e largura variável: são cards de
vegetação, não cilindros ou espinhos triangulares isolados.
"""
import math
import random


VARIANTS = {
    "short": {"height": 0.30, "radius": 0.20, "blades": 8, "color": (0.13, 0.34, 0.07, 1.0)},
    "mid": {"height": 0.56, "radius": 0.27, "blades": 10, "color": (0.11, 0.31, 0.055, 1.0)},
    "tall": {"height": 0.88, "radius": 0.34, "blades": 12, "color": (0.19, 0.43, 0.085, 1.0)},
}


def append_blade(vertices, faces, angle, radius, height, width, lean):
    """Acrescenta um card curvo, com frente e verso para materiais cull-back."""
    direction = (math.cos(angle), math.sin(angle))
    side = (-direction[1], direction[0])
    base = (direction[0] * radius, 0.0, direction[1] * radius)
    mid = (base[0] + direction[0] * lean * .32, height * .54, base[2] + direction[1] * lean * .32)
    tip = (base[0] + direction[0] * lean, height, base[2] + direction[1] * lean)
    # Cada lâmina possui base larga, joelho estreito e ponta; duas faces por seção.
    start = len(vertices)
    vertices.extend([
        (base[0] + side[0] * width, base[1], base[2] + side[1] * width),
        (base[0] - side[0] * width, base[1], base[2] - side[1] * width),
        (mid[0] + side[0] * width * .62, mid[1], mid[2] + side[1] * width * .62),
        (mid[0] - side[0] * width * .62, mid[1], mid[2] - side[1] * width * .62),
        tip,
    ])
    for tri in [(0, 1, 2), (1, 3, 2), (2, 3, 4)]:
        a, b, c = [start + index for index in tri]
        faces.extend([(a, b, c), (c, b, a)])


def build_cluster(variant):
    """Retorna vértices/faces de um tufo determinístico em coordenadas Blender."""
    data = VARIANTS[variant]
    rng = random.Random("pokemobile-grass-%s" % variant)
    vertices, faces = [], []
    for index in range(data["blades"]):
        angle = math.tau * index / data["blades"] + rng.uniform(-.22, .22)
        height = data["height"] * rng.uniform(.72, 1.08)
        radius = data["radius"] * rng.uniform(.08, .96)
        width = data["radius"] * rng.uniform(.075, .12)
        lean = data["radius"] * rng.uniform(.20, .72)
        append_blade(vertices, faces, angle, radius, height, width, lean)
    return vertices, faces
