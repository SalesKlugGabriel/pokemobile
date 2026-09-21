import bpy
import math


def _peso(objeto, osso):
    grupo = objeto.vertex_groups.new(name=osso)
    grupo.add(list(range(len(objeto.data.vertices))), 1.0, "REPLACE")


def _esfera(partes, nome, local, escala, material, osso, segmentos=10, aneis=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segmentos, ring_count=aneis, location=local)
    objeto = bpy.context.object
    objeto.name = nome
    objeto.scale = escala
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    objeto.data.materials.append(material)
    _peso(objeto, osso)
    partes.append(objeto)


def _cone(partes, nome, local, raio_base, raio_ponta, profundidade, material, osso,
        rotacao=(0.0, 0.0, 0.0), vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=raio_base, radius2=raio_ponta,
        depth=profundidade, location=local, rotation=rotacao)
    objeto = bpy.context.object
    objeto.name = nome
    objeto.data.materials.append(material)
    _peso(objeto, osso)
    partes.append(objeto)


def criar_rattata(materiais):
    """Blockout orgânico baixo-polígono; +Y é altura nesta etapa de construção."""
    partes = []
    pelo = materiais["pelagem"]
    detalhe = materiais["detalhe"]

    # Silhueta de roedor: corpo baixo, cabeça grande, focinho e orelhas legíveis.
    _esfera(partes, "PKM_RATTATA_BODY", (0.0, 0.125, 0.055), (0.105, 0.075, 0.125), pelo, "spine")
    _esfera(partes, "PKM_RATTATA_CHEST", (0.0, 0.145, -0.045), (0.082, 0.075, 0.080), pelo, "chest")
    _esfera(partes, "PKM_RATTATA_HEAD", (0.0, 0.205, -0.145), (0.090, 0.078, 0.085), pelo, "head")
    _esfera(partes, "PKM_RATTATA_MUZZLE", (0.0, 0.172, -0.218), (0.063, 0.040, 0.052), pelo, "jaw", 9, 6)
    _esfera(partes, "PKM_RATTATA_NOSE", (0.0, 0.178, -0.267), (0.020, 0.015, 0.012), detalhe, "jaw", 8, 6)

    for lado in (-1.0, 1.0):
        sufixo = "L" if lado < 0.0 else "R"
        _cone(partes, "PKM_RATTATA_EAR_%s" % sufixo,
            (lado * 0.055, 0.279, -0.145), 0.043, 0.006, 0.098, pelo,
            "ear_%s" % sufixo.lower(),
            (math.radians(90.0), lado * math.radians(17.0), 0.0), 8)
        _esfera(partes, "PKM_RATTATA_EYE_%s" % sufixo,
            (lado * 0.055, 0.218, -0.211), (0.016, 0.018, 0.010), detalhe, "head", 8, 6)

        perna_frente = "front_%s" % sufixo.lower()
        perna_tras = "back_%s" % sufixo.lower()
        _esfera(partes, "PKM_RATTATA_FRONT_LEG_%s" % sufixo,
            (lado * 0.066, 0.075, -0.105), (0.031, 0.055, 0.032), pelo, perna_frente, 8, 6)
        _esfera(partes, "PKM_RATTATA_FRONT_PAW_%s" % sufixo,
            (lado * 0.066, 0.023, -0.125), (0.038, 0.018, 0.052), detalhe, perna_frente, 8, 6)
        _esfera(partes, "PKM_RATTATA_BACK_LEG_%s" % sufixo,
            (lado * 0.071, 0.070, 0.090), (0.044, 0.056, 0.052), pelo, perna_tras, 8, 6)
        _esfera(partes, "PKM_RATTATA_BACK_PAW_%s" % sufixo,
            (lado * 0.071, 0.022, 0.075), (0.047, 0.018, 0.060), detalhe, perna_tras, 8, 6)

    # Cauda longa em dois segmentos, para ficar clara na silhueta e animável.
    _cone(partes, "PKM_RATTATA_TAIL_BASE", (0.0, 0.105, 0.190), 0.030, 0.018, 0.145,
        pelo, "tail_01", (0.0, 0.0, 0.0), 8)
    _cone(partes, "PKM_RATTATA_TAIL_TIP", (0.0, 0.147, 0.310), 0.020, 0.004, 0.175,
        pelo, "tail_02", (math.radians(-23.0), 0.0, 0.0), 8)

    bpy.ops.object.select_all(action="DESELECT")
    for parte in partes:
        parte.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    malha = bpy.context.object
    malha.name = "PKM_RATTATA_BODY"
    return malha


def normalizar_para_godot(malha, altura=0.30):
    """Replica a conversão já aprovada pelos três GLBs V3: Godot recebe +Y up."""
    bpy.context.view_layer.update()
    minimo = min((malha.matrix_world @ vert.co).y for vert in malha.data.vertices)
    maximo = max((malha.matrix_world @ vert.co).y for vert in malha.data.vertices)
    malha.location.y -= minimo
    malha.scale *= altura / (maximo - minimo)
    bpy.context.view_layer.objects.active = malha
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)

    for vert in malha.data.vertices:
        vert.co.y -= min(vertice.co.y for vertice in malha.data.vertices)
    min_x = min(vert.co.x for vert in malha.data.vertices)
    max_x = max(vert.co.x for vert in malha.data.vertices)
    min_z = min(vert.co.z for vert in malha.data.vertices)
    max_z = max(vert.co.z for vert in malha.data.vertices)
    for vert in malha.data.vertices:
        vert.co.x -= (min_x + max_x) * 0.5
        vert.co.z -= (min_z + max_z) * 0.5
    malha.data.update()

    # Fonte usa Y como altura; a conversão aplicada no próprio mesh evita
    # correção silenciosa em Godot. Depois Z é altura e Y é profundidade Blender.
    malha.rotation_euler.x = math.radians(90.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    min_height = min(vert.co.z for vert in malha.data.vertices)
    min_depth = min(vert.co.y for vert in malha.data.vertices)
    max_depth = max(vert.co.y for vert in malha.data.vertices)
    for vert in malha.data.vertices:
        vert.co.z -= min_height
        vert.co.y -= (min_depth + max_depth) * 0.5
    malha.data.update()

    # Marcador sem geometria: a régua Godot verifica o eixo por ele, em vez de
    # tentar inferir frente pela silhueta. Depois do export Blender→glTF, este
    # ponto deve chegar no -Z de Godot, à frente do focinho.
    frente = bpy.data.objects.new("PKM_RATTATA_FRONT_REFERENCE", None)
    bpy.context.collection.objects.link(frente)
    frente.location = (0.0, (max_depth - min_depth) * 0.5 + 0.012, altura * 0.56)
    return frente
