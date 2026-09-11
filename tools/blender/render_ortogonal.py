#!/usr/bin/env python3
"""
render_ortogonal.py — Renderiza um objeto 3D nas 4 (ou 8) direções, em tamanho
de sprite, com câmera ortográfica.

É a base do pipeline da RFC-005: 3D low-poly -> render -> pixel art -> /assets.

USO
    blender --background --python tools/blender/render_ortogonal.py -- \\
        --cena  tools/blender/generators/casa.py \\
        --saida assets/buildings/casa \\
        --tamanho 64 --direcoes 4

O script de CENA (`--cena`) é um .py comum que monta a geometria e NÃO mexe em
câmera, luz nem render — isso é trabalho daqui. Ele só precisa deixar os
objetos na cena, centrados na origem. Ver `generators/casa.py` de exemplo.

── Três coisas que custaram tempo pra descobrir, registradas pra não custarem
   de novo ────────────────────────────────────────────────────────────────────

1. **A câmera do Blender nasce olhando pra BAIXO (-Z).** Se você só a
   posiciona e não gira, ela filma o chão e o PNG sai **vazio** — sem erro,
   sem aviso. Perdi duas rodadas de render achando que era o motor.

2. **EEVEE não funciona nesta VPS.** Sem GPU, ele cospe `EGL_BAD_MATCH`,
   leva **43 a 75 segundos** por render de 64x64 e entrega imagem **vazia**.
   O motor certo aqui é o **WORKBENCH**: mesmo render em **0,01 a 0,5s**,
   quatro mil vezes mais rápido, e é justamente o feito pra cor chapada.

3. **Gire o OBJETO, não a câmera.** Girando a câmera, a luz muda junto e as
   quatro faces saem com iluminação diferente — o sprite fica inconsistente.
   Girando o objeto, luz e enquadramento ficam idênticos nas quatro.
"""
import bpy
import sys
import os
import math
import argparse
import time

# As direções na convenção do jogo: "sul" é a face que o jogador vê primeiro
# (o personagem de costas pra câmera anda pro norte).
DIRECOES_4 = [("sul", 0), ("oeste", 90), ("norte", 180), ("leste", 270)]
DIRECOES_8 = [("sul", 0), ("sudoeste", 45), ("oeste", 90), ("noroeste", 135),
              ("norte", 180), ("nordeste", 225), ("leste", 270), ("sudeste", 315)]

## Inclinação da câmera. 60° é a vista 3/4 clássica de RPG de cima — a mesma
## leitura de perspectiva que o resto da arte do jogo já usa.
INCLINACAO_GRAUS = 60.0


def argumentos():
    # O Blender engole tudo antes de "--"; o que interessa vem depois.
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--cena", required=True, help="script .py que monta a geometria")
    p.add_argument("--saida", required=True, help="prefixo do caminho de saída")
    p.add_argument("--tamanho", type=int, default=64, help="lado do PNG em px")
    p.add_argument("--direcoes", type=int, default=4, choices=[1, 4, 8])
    p.add_argument("--escala", type=float, default=5.5,
                   help="ortho_scale: quanto do mundo cabe no quadro")
    p.add_argument("--inclinacao", type=float, default=INCLINACAO_GRAUS)
    return p.parse_args(argv)


def montar_cena(caminho_do_script):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with open(caminho_do_script, "r", encoding="utf-8") as f:
        codigo = f.read()
    escopo = {"bpy": bpy, "math": math, "__name__": "cena"}
    exec(compile(codigo, caminho_do_script, "exec"), escopo)
    # Tudo que o script criou vira filho de um pivô na origem, pra girar junto.
    pivo = bpy.data.objects.new("pivo", None)
    bpy.context.collection.objects.link(pivo)
    for obj in list(bpy.context.scene.objects):
        if obj is pivo or obj.type in {"CAMERA", "LIGHT"} or obj.parent:
            continue
        obj.parent = pivo
    return pivo


def preparar_render(tamanho, escala, inclinacao):
    bpy.ops.object.light_add(type="SUN", location=(4, -4, 8))
    bpy.context.object.data.energy = 3.0

    bpy.ops.object.camera_add(location=(0, -8, 5))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = escala
    # Ver nota 1 do cabeçalho: sem esta linha o PNG sai vazio.
    cam.rotation_euler = (math.radians(inclinacao), 0, 0)
    bpy.context.scene.camera = cam

    cena = bpy.context.scene
    # Ver nota 2: WORKBENCH, nunca EEVEE, nesta VPS.
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.render.resolution_x = tamanho
    cena.render.resolution_y = tamanho
    cena.render.film_transparent = True
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    return cena


def main():
    a = argumentos()
    pivo = montar_cena(a.cena)
    cena = preparar_render(a.tamanho, a.escala, a.inclinacao)

    direcoes = {1: [("unico", 0)], 4: DIRECOES_4, 8: DIRECOES_8}[a.direcoes]
    os.makedirs(os.path.dirname(a.saida) or ".", exist_ok=True)

    total = 0.0
    for nome, graus in direcoes:
        # Ver nota 3: gira o OBJETO, não a câmera.
        pivo.rotation_euler = (0, 0, math.radians(graus))
        sufixo = "" if nome == "unico" else "_" + nome
        cena.render.filepath = f"{a.saida}{sufixo}.png"
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        dt = time.time() - t0
        total += dt
        print(f"[render] {nome:<10} {a.tamanho}x{a.tamanho}  {dt:.2f}s  -> {cena.render.filepath}")
    print(f"[render] {len(direcoes)} imagens em {total:.2f}s")


if __name__ == "__main__":
    main()
