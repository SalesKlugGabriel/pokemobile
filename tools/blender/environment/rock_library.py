"""Volumes rochosos facetados; não parte de UV/ico sphere deformada."""
import math
import random

VARIANTS = {
    "small": ((.55, .42, .48), 7, 31), "round": ((.90, .68, .82), 8, 47),
    "angular": ((1.15, .95, .76), 6, 73), "flat": ((1.35, .42, 1.05), 9, 97),
    "large": ((1.65, 1.45, 1.28), 8, 131),
}

def build(variant):
    scale, sides, seed = VARIANTS[variant]; rng = random.Random(seed)
    verts, faces = [], []
    # Três anéis assimétricos + ápice e base geram planos geológicos legíveis.
    rings = [(0.0, .76), (scale[1] * .47, 1.0), (scale[1] * .86, .63)]
    angles = [math.tau * i / sides + rng.uniform(-.13,.13) for i in range(sides)]
    for height, radius in rings:
        for i, angle in enumerate(angles):
            irregular = rng.uniform(.78, 1.18)
            verts.append((math.cos(angle)*scale[0]*radius*irregular, height, math.sin(angle)*scale[2]*radius*irregular))
    for ring in range(len(rings)-1):
        for i in range(sides):
            a=ring*sides+i; b=ring*sides+(i+1)%sides; c=(ring+1)*sides+(i+1)%sides; d=(ring+1)*sides+i
            faces.extend([(a,b,c),(a,c,d)])
    top=len(verts); verts.append((rng.uniform(-.12,.12)*scale[0], scale[1], rng.uniform(-.12,.12)*scale[2]))
    bottom=len(verts); verts.append((0,0,0))
    for i in range(sides):
        faces.append((2*sides+i,2*sides+(i+1)%sides,top)); faces.append((bottom,(i+1)%sides,i))
    return verts, faces
