import bpy


def criar(nome, cor, roughness=0.78):
    material = bpy.data.materials.new(nome)
    material.diffuse_color = (*cor, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*cor, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def criar_materiais():
    # Dois materiais PBR: pelagem e detalhes. Mantém o custo baixo no WebGL.
    return {
        "pelagem": criar("PKM_RATTATA_MAT_FUR", (0.35, 0.16, 0.50)),
        "detalhe": criar("PKM_RATTATA_MAT_DETAIL", (0.12, 0.055, 0.18), 0.66),
    }
