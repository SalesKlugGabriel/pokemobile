"""Malha autoral modular do Player V1. Blender Z-up; frente local em -Y.

É um blockout de ART PASS, não um rig. Os membros usam anéis nas articulações
para que a próxima fase possa refazer o skinning sem depender de peças cúbicas.
"""

import math

import bmesh
import bpy
from mathutils import Vector


def mesh(name, vertices, faces, material, collection):
    data = bpy.data.meshes.new(name + "_GEO")
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(material)
    return obj


def ellipse(name, rings, material, collection, sides=12):
    """Solid skin through horizontal rings (cx, cy, z, radius_x, radius_y)."""
    verts = []
    for x, y, z, rx, ry in rings:
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            verts.append((x + rx * math.cos(angle), y + ry * math.sin(angle), z))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(rings) - 1):
        for i in range(sides):
            a = j * sides + i
            b = j * sides + (i + 1) % sides
            c = (j + 1) * sides + (i + 1) % sides
            d = (j + 1) * sides + i
            faces.append((a, b, c, d))
    faces.append(tuple((len(rings) - 1) * sides + i for i in range(sides)))
    return mesh(name, verts, faces, material, collection)


def bevel_outline(rx, ry, cut=0.18):
    return [
        (-rx * (1 - cut), -ry), (rx * (1 - cut), -ry),
        (rx, -ry * (1 - cut)), (rx, ry * (1 - cut)),
        (rx * (1 - cut), ry), (-rx * (1 - cut), ry),
        (-rx, ry * (1 - cut)), (-rx, -ry * (1 - cut)),
    ]


def chamfer_box(name, x, y, rings, material, collection, cut=0.18):
    """Faceted rounded box; each ring is (z, half_x, half_y)."""
    vertices = []
    for z, rx, ry in rings:
        vertices.extend((x + dx, y + dy, z) for dx, dy in bevel_outline(rx, ry, cut))
    n = 8
    faces = [tuple(reversed(range(n)))]
    for ring in range(len(rings) - 1):
        for i in range(n):
            faces.append((ring * n + i, ring * n + (i + 1) % n,
                          (ring + 1) * n + (i + 1) % n, (ring + 1) * n + i))
    faces.append(tuple((len(rings) - 1) * n + i for i in range(n)))
    return mesh(name, vertices, faces, material, collection)


def tube(name, rings, material, collection, sides=10):
    """Ring centres follow a limb/strap; ring radii are (side, depth)."""
    vertices = []
    for index, (position, radius_side, radius_depth) in enumerate(rings):
        center = Vector(position)
        previous = Vector(rings[max(index - 1, 0)][0])
        following = Vector(rings[min(index + 1, len(rings) - 1)][0])
        tangent = (following - previous).normalized()
        depth = Vector((0, 1, 0))
        side = tangent.cross(depth).normalized()
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            point = center + side * math.cos(angle) * radius_side + depth * math.sin(angle) * radius_depth
            vertices.append(tuple(point))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(rings) - 1):
        for i in range(sides):
            faces.append((j * sides + i, j * sides + (i + 1) % sides,
                          (j + 1) * sides + (i + 1) % sides, (j + 1) * sides + i))
    faces.append(tuple((len(rings) - 1) * sides + i for i in range(sides)))
    return mesh(name, vertices, faces, material, collection)


def polygon_prism(name, outline, low, high, material, collection):
    """A flat XY outline with real thickness, for brim, badge and shoe panels."""
    count = len(outline)
    vertices = [(x, y, low) for x, y in outline] + [(x, y, high) for x, y in outline]
    faces = [tuple(reversed(range(count))), tuple(count + i for i in range(count))]
    for i in range(count):
        nxt = (i + 1) % count
        faces.append((i, nxt, count + nxt, count + i))
    return mesh(name, vertices, faces, material, collection)


def jacket_shell(collection, materials):
    # The open sector faces -Y: white shirt remains visible between the lapels.
    rings = [(.79, .18, .101), (.86, .20, .115), (1.02, .19, .119),
             (1.17, .205, .118), (1.24, .155, .090)]
    sections = 22
    gap = .39
    start = -math.pi / 2 + gap
    sweep = 2 * math.pi - 2 * gap
    verts = []
    for inner in (False, True):
        for z, rx, ry in rings:
            factor = .93 if inner else 1.0
            for i in range(sections):
                angle = start + sweep * i / (sections - 1)
                verts.append((factor * rx * math.cos(angle), factor * ry * math.sin(angle), z))
    half = len(rings) * sections
    faces = []
    for r in range(len(rings) - 1):
        for i in range(sections - 1):
            a = r * sections + i
            b = a + 1
            c = (r + 1) * sections + i + 1
            d = c - 1
            faces.append((a, b, c, d))
            faces.append((half + d, half + c, half + b, half + a))
    for r in range(len(rings) - 1):
        for i in (0, sections - 1):
            a = r * sections + i
            b = (r + 1) * sections + i
            faces.append((a, b, half + b, half + a))
    for r in (0, len(rings) - 1):
        for i in range(sections - 1):
            a = r * sections + i
            faces.append((a, a + 1, half + a + 1, half + a))
    mesh("PLAYER_V1_JACKET_SHELL", verts, faces, materials["BLUE"], collection)
    # Small folded collar, not square epaulettes.
    for sign in (-1, 1):
        mesh(f"PLAYER_V1_COLLAR_{sign}", [
            (sign * .045, -.066, 1.245), (sign * .142, -.051, 1.235),
            (sign * .141, -.034, 1.284), (sign * .075, -.055, 1.292),
            (sign * .045, -.032, 1.245), (sign * .142, -.020, 1.235),
            (sign * .141, -.011, 1.284), (sign * .075, -.030, 1.292),
        ], [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
            (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
            materials["BLUE"], collection)
        tube(f"PLAYER_V1_LAPEL_{sign}", [
            ((sign * .083, -.111, 1.20), .012, .008),
            ((sign * .092, -.129, 1.07), .014, .009),
            ((sign * .133, -.126, .89), .013, .008),
        ], materials["BLUE"], collection, sides=6)


def head_and_hat(collection, materials):
    ellipse("PLAYER_V1_FACE", [
        (0, -.018, 1.295, .034, .042), (0, -.014, 1.327, .068, .061),
        (0, -.005, 1.377, .092, .081), (0, 0, 1.438, .111, .094),
        (0, .002, 1.500, .108, .093), (0, .01, 1.535, .083, .069),
    ], materials["SKIN"], collection, sides=14)
    # Dark crown at the back, angular pointed locks around cheeks/nape.
    ellipse("PLAYER_V1_HAIR_CROWN", [
        (0, .042, 1.487, .101, .071), (0, .029, 1.533, .115, .088),
        (0, .014, 1.551, .081, .073),
    ], materials["HAIR"], collection, sides=12)
    for sign in (-1, 1):
        tube(f"PLAYER_V1_EAR_{sign}", [
            ((sign * .108, .004, 1.443), .023, .026),
            ((sign * .117, .006, 1.474), .027, .025),
            ((sign * .108, .004, 1.492), .019, .020),
        ], materials["SKIN"], collection, sides=8)
        for idx, shift in enumerate((0.0, .035)):
            mesh(f"PLAYER_V1_SIDE_HAIR_{sign}_{idx}", [
                (sign * (.082 + shift), -.064, 1.523),
                (sign * (.128 + shift * .18), -.032, 1.516),
                (sign * (.115 + shift * .25), -.012, 1.396 + shift),
                (sign * (.087 + shift), .009, 1.527),
                (sign * (.132 + shift * .18), .025, 1.506),
                (sign * (.115 + shift * .25), .028, 1.396 + shift),
            ], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1),
                (1, 4, 5, 2), (2, 5, 3, 0)], materials["HAIR"], collection)
        # Light almond-shaped eye under a narrow brow, then dark pupil.
        chamfer_box(f"PLAYER_V1_EYE_WHITE_{sign}", sign * .043, -.097,
                    [(1.447, .022, .007), (1.478, .022, .008)], materials["LIGHT"], collection)
        chamfer_box(f"PLAYER_V1_PUPIL_{sign}", sign * .045, -.107,
                    [(1.451, .011, .007), (1.474, .011, .007)], materials["BLACK"], collection)
        chamfer_box(f"PLAYER_V1_BROW_{sign}", sign * .046, -.099,
                    [(1.492, .028, .006), (1.496, .029, .006)], materials["HAIR"], collection)
    polygon_prism("PLAYER_V1_NOSE", [(-.013, -.100), (.013, -.100),
                                        (.004, -.133), (-.004, -.133)],
                  1.418, 1.441, materials["SKIN"], collection)
    chamfer_box("PLAYER_V1_MOUTH", 0, -.093,
                [(1.370, .019, .004), (1.373, .018, .004)], materials["HAIR"], collection)
    # Three broad fringe wedges are a silhouette, not individual hairs.
    for idx, x in enumerate((-.070, .002, .067)):
        mesh(f"PLAYER_V1_FRINGE_{idx}", [
            (x - .035, -.078, 1.532), (x + .028, -.077, 1.526),
            (x - .002, -.112, 1.485 - idx * .004),
            (x - .035, -.067, 1.533), (x + .028, -.066, 1.527),
            (x - .002, -.099, 1.485 - idx * .004),
        ], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1),
            (1, 4, 5, 2), (2, 5, 3, 0)], materials["HAIR"], collection)
    ellipse("PLAYER_V1_CAP_CROWN", [
        (0, .005, 1.514, .119, .105), (0, .006, 1.551, .142, .123),
        (0, .015, 1.591, .125, .105), (0, .020, 1.600, .073, .064),
    ], materials["RED"], collection, sides=12)
    # Cream front panel and an original compass mark (not a Poké Ball logo).
    chamfer_box("PLAYER_V1_CAP_PANEL", 0, -.116,
                [(1.539, .067, .011), (1.581, .078, .013)], materials["LIGHT"], collection)
    polygon_prism("PLAYER_V1_CAP_BRIM", [
        (-.137, -.078), (.137, -.078), (.157, -.165),
        (.111, -.223), (-.111, -.223), (-.157, -.165),
    ], 1.527, 1.544, materials["RED"], collection)
    chamfer_box("PLAYER_V1_CAP_COMPASS", 0, -.134,
                [(1.552, .010, .005), (1.576, .010, .005)], materials["BLACK"], collection)


def arms_and_hands(collection, materials):
    for sign in (-1, 1):
        shoulder = sign * .225
        tube(f"PLAYER_V1_SLEEVE_{sign}", [
            ((shoulder, .003, 1.183), .077, .082),
            ((sign * .273, .005, 1.116), .079, .078),
            ((sign * .310, -.005, .956), .069, .067),
            ((sign * .317, -.017, .836), .058, .055),
            ((sign * .333, -.020, .728), .049, .048),
        ], materials["BLUE"], collection, sides=12)
        tube(f"PLAYER_V1_CUFF_{sign}", [
            ((sign * .332, -.020, .743), .055, .052),
            ((sign * .338, -.022, .700), .054, .049),
        ], materials["LIGHT"], collection, sides=10)
        tube(f"PLAYER_V1_WRIST_{sign}", [
            ((sign * .338, -.022, .707), .039, .038),
            ((sign * .342, -.026, .661), .041, .038),
        ], materials["SKIN"], collection, sides=10)
        tube(f"PLAYER_V1_GLOVE_{sign}", [
            ((sign * .342, -.025, .677), .051, .044),
            ((sign * .348, -.030, .625), .054, .042),
            ((sign * .354, -.029, .591), .048, .036),
        ], materials["DARK"], collection, sides=10)
        tube(f"PLAYER_V1_GLOVE_RED_{sign}", [
            ((sign * .342, -.024, .679), .053, .046),
            ((sign * .343, -.025, .670), .054, .046),
        ], materials["RED"], collection, sides=10)
        # Four exposed knuckles read as fingerless gloves at close range.
        for finger in range(4):
            x = sign * (.316 + finger * .024)
            tube(f"PLAYER_V1_FINGER_{sign}_{finger}", [
                ((x, -.049, .594), .011, .011),
                ((x, -.053, .563), .010, .010),
            ], materials["SKIN"], collection, sides=6)


def shoe(sign, collection, materials):
    x = sign * .122
    sole = [
        (x - .073, -.273), (x + .073, -.273),
        (x + .093, -.227), (x + .086, .069),
        (x + .062, .119), (x - .062, .119),
        (x - .086, .069), (x - .093, -.227),
    ]
    polygon_prism(f"PLAYER_V1_SHOE_SOLE_{sign}", sole, .000, .034, materials["LIGHT"], collection)
    # An angled upper rather than a rectangular shoe brick.
    lower = [(x + (px - x) * .92, py * .94, .036) for px, py in sole]
    upper = [
        (x - .056, -.219, .098), (x + .056, -.219, .098),
        (x + .069, -.165, .128), (x + .055, .061, .143),
        (x + .040, .097, .156), (x - .040, .097, .156),
        (x - .055, .061, .143), (x - .069, -.165, .128),
    ]
    faces = [tuple(reversed(range(8))), tuple(8 + i for i in range(8))]
    faces.extend((i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8))
    mesh(f"PLAYER_V1_SHOE_UPPER_{sign}", lower + upper, faces, materials["DARK"], collection)
    toe = [(x - .069, -.255), (x + .069, -.255),
           (x + .075, -.203), (x + .050, -.097),
           (x - .050, -.097), (x - .075, -.203)]
    polygon_prism(f"PLAYER_V1_SHOE_TOE_{sign}", toe, .095, .121, materials["RED"], collection)
    chamfer_box(f"PLAYER_V1_SHOE_HEEL_{sign}", x, .080,
                [(.098, .050, .034), (.164, .044, .031)], materials["RED"], collection)
    # Pale laces on the front slope: three intentionally bold strokes.
    for idx in range(3):
        y = -.080 + idx * .041
        polygon_prism(f"PLAYER_V1_SHOE_LACE_{sign}_{idx}", [
            (x - .034, y - .006), (x + .034, y - .006),
            (x + .034, y + .006), (x - .034, y + .006),
        ], .146, .151, materials["LIGHT"], collection)


def legs_and_shoes(collection, materials):
    for sign in (-1, 1):
        x = sign * .116
        ellipse(f"PLAYER_V1_CARGO_LEG_{sign}", [
            (x, .000, .135, .067, .076), (x, .008, .226, .075, .083),
            (x * 1.04, .012, .399, .083, .090),
            (x * 1.04, .012, .464, .092, .099),
            (x * .98, .006, .562, .101, .106),
            (x * .97, .004, .720, .113, .114),
            (x * .88, .008, .815, .118, .118),
        ], materials["DARK"], collection, sides=12)
        # Tapered cargo pocket is outside the thigh, not painted on it.
        pocket_x = sign * .222
        chamfer_box(f"PLAYER_V1_CARGO_POCKET_{sign}", pocket_x, -.003,
                    [(.536, .024, .047), (.588, .029, .052), (.637, .026, .049)],
                    materials["DARK"], collection)
        chamfer_box(f"PLAYER_V1_POCKET_FLAP_{sign}", pocket_x, -.003,
                    [(.621, .031, .053), (.638, .030, .052)], materials["TRIM"], collection)
        chamfer_box(f"PLAYER_V1_KNEE_SEAM_{sign}", x * 1.04, -.090,
                    [(.423, .060, .007), (.437, .064, .007)], materials["TRIM"], collection)
        shoe(sign, collection, materials)


def backpack(collection, materials):
    # Offset from torso; no shared vertices with the body.
    chamfer_box("PLAYER_V1_BACKPACK_BODY", 0, .208,
                [(.850, .118, .071), (.904, .153, .101),
                 (1.185, .160, .107), (1.273, .143, .092),
                 (1.305, .104, .073)], materials["DARK"], collection)
    chamfer_box("PLAYER_V1_BACKPACK_POCKET", 0, .328,
                [(.888, .102, .045), (.959, .116, .057),
                 (1.100, .112, .052)], materials["TRIM"], collection)
    for sign in (-1, 1):
        chamfer_box(f"PLAYER_V1_BAG_RED_STRIP_{sign}", sign * .126, .309,
                    [(.938, .013, .018), (1.195, .014, .018)], materials["RED"], collection)
        tube(f"PLAYER_V1_SHOULDER_STRAP_{sign}", [
            ((sign * .120, .231, 1.256), .022, .013),
            ((sign * .147, .100, 1.235), .022, .013),
            ((sign * .168, -.073, 1.160), .022, .012),
            ((sign * .159, -.116, .946), .023, .012),
        ], materials["BLACK"], collection, sides=6)
    chamfer_box("PLAYER_V1_BAG_FLAP", 0, .323,
                [(1.174, .136, .026), (1.274, .143, .030)], materials["DARK"], collection)
    chamfer_box("PLAYER_V1_BAG_RED_FLAP", 0, .353,
                [(1.227, .118, .014), (1.256, .130, .014)], materials["RED"], collection)
    # Roll mat on top — a useful readable silhouette from behind.
    tube("PLAYER_V1_ROLL_MAT", [
        ((-.119, .218, 1.314), .033, .042),
        (( .119, .218, 1.314), .033, .042),
    ], materials["TRIM"], collection, sides=10)


def build_player(collection, materials):
    # Shirt and neck remain visible in the opening of the jacket.
    ellipse("PLAYER_V1_SHIRT", [
        (0, -.012, .799, .178, .096), (0, -.012, .874, .179, .099),
        (0, -.010, 1.081, .176, .102), (0, -.006, 1.204, .146, .087),
        (0, -.009, 1.259, .075, .065),
    ], materials["LIGHT"], collection, sides=14)
    ellipse("PLAYER_V1_NECK", [
        (0, -.012, 1.250, .052, .050), (0, -.012, 1.326, .050, .049),
    ], materials["SKIN"], collection, sides=10)
    jacket_shell(collection, materials)
    chamfer_box("PLAYER_V1_BELT", 0, 0,
                [(.793, .176, .097), (.822, .182, .102)], materials["BLACK"], collection)
    legs_and_shoes(collection, materials)
    arms_and_hands(collection, materials)
    head_and_hat(collection, materials)
    backpack(collection, materials)
