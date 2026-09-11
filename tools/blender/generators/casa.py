"""
casa.py — Exemplo de script de CENA para `render_ortogonal.py`.

Um script de cena só monta geometria. Não toca em câmera, luz nem render — quem
cuida disso é o renderizador, pra todas as peças saírem com a mesma perspectiva
e a mesma luz. É isso que resolve a queixa de "consistência de perspectiva e
escala" que motivou a RFC-005.

Esta casa existe pra provar o caso concreto do Gabriel: a pendência dele,
reportada duas vezes, é *"paredes laterais de casa usando a mesma sprite da
frente"*. Um modelo 3D dá as quatro faces coerentes de graça.
"""

# Corpo: caixa levemente mais larga que funda.
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
corpo = bpy.context.object
corpo.scale = (1.2, 1.0, 1.0)

# Telhado: cone de 4 lados girado 45° vira uma pirâmide alinhada à caixa.
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.9, depth=1.4,
                                location=(0, 0, 2.7), rotation=(0, 0, math.pi / 4))
telhado = bpy.context.object

# Porta: um bloco raso saliente na face SUL (a que o jogador vê primeiro).
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -1.02, 0.55))
porta = bpy.context.object
porta.scale = (0.35, 0.06, 0.55)

# Janela: só na face LESTE, pra as quatro direções serem mesmo diferentes.
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.22, 0, 1.25))
janela = bpy.context.object
janela.scale = (0.06, 0.3, 0.3)

def cor(nome, rgba):
    m = bpy.data.materials.new(nome)
    m.diffuse_color = rgba
    return m

corpo.data.materials.append(cor("parede", (0.85, 0.78, 0.62, 1)))
telhado.data.materials.append(cor("telha", (0.65, 0.25, 0.20, 1)))
porta.data.materials.append(cor("madeira", (0.40, 0.26, 0.15, 1)))
janela.data.materials.append(cor("vidro", (0.55, 0.75, 0.85, 1)))
