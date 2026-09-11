#!/usr/bin/env python3
"""
render_ortogonal.py — Renderiza um objeto 3D nas 4 (ou 8) direções, em tamanho
de sprite, com câmera ortográfica.

É a base do pipeline da RFC-005: 3D low-poly -> render -> pixel art -> /assets.

USO — uma peça
    blender --background --python tools/blender/render_ortogonal.py -- \\
        --cena  tools/blender/generators/casa.py \\
        --saida assets/buildings/casa \\
        --tamanho 256 --direcoes 4

USO — LOTE (é assim que vale a pena)
    blender --background --python tools/blender/render_ortogonal.py -- \\
        --lote tools/blender/lotes/construcoes.json

🔴 **Sempre prefira o lote.** Medido nesta VPS: abrir o Blender custa **4,85 s**
e renderizar 4 faces custa **0,47 s** — ou seja, **91% do custo é ligar a
máquina**. Dez peças em dez processos levam 53 s; as mesmas dez num processo só,
9,6 s. **5,5x mais rápido, sem mudar nada do resultado.**

O arquivo de lote é uma lista, um objeto por peça:

    [
      {"cena": "tools/blender/generators/casa.py",
       "saida": "assets/buildings/casa", "tamanho": 256, "direcoes": 4},
      {"cena": "tools/blender/generators/arvore.py",
       "saida": "assets/environment/arvore", "tamanho": 256, "direcoes": 1}
    ]

Campos que faltarem usam o padrão (tamanho 256, 4 direções, escala 5.5).

🔴 **Renderize GRANDE (256) e reduza depois com `tools/pixelart/pixelizar.py`.**
Medido: descer de 256 pra 32 com LANCZOS dá densidade 0,44, contra 0,09 se você
renderizar direto em 64 e usar NEAREST. A arte deste jogo mede 0,51 — render
pequeno nasce chapado demais e não tem como recuperar.

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
    p.add_argument("--lote", help="JSON com a lista de peças — o caminho recomendado")
    p.add_argument("--cena", help="script .py que monta a geometria")
    p.add_argument("--saida", help="prefixo do caminho de saída")
    p.add_argument("--tamanho", type=int, default=256, help="lado do PNG em px")
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


def renderizar_peca(peca):
    """Uma peça: monta a cena, prepara o render e roda as direções.

    Cada chamada recomeça a cena do zero (`read_factory_settings`), então uma
    peça não contamina a seguinte — é o que torna o lote seguro.
    """
    cena_py = peca["cena"]
    saida = peca["saida"]
    tamanho = int(peca.get("tamanho", 256))
    n_dir = int(peca.get("direcoes", 4))
    escala = float(peca.get("escala", 5.5))
    inclinacao = float(peca.get("inclinacao", INCLINACAO_GRAUS))

    pivo = montar_cena(cena_py)
    cena = preparar_render(tamanho, escala, inclinacao)
    direcoes = {1: [("unico", 0)], 4: DIRECOES_4, 8: DIRECOES_8}[n_dir]
    os.makedirs(os.path.dirname(saida) or ".", exist_ok=True)

    total = 0.0
    for nome, graus in direcoes:
        # Ver nota 3: gira o OBJETO, não a câmera.
        pivo.rotation_euler = (0, 0, math.radians(graus))
        sufixo = "" if nome == "unico" else "_" + nome
        cena.render.filepath = f"{saida}{sufixo}.png"
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        dt = time.time() - t0
        total += dt
        print(f"[render] {os.path.basename(saida):<16} {nome:<10} "
              f"{tamanho}x{tamanho}  {dt:.2f}s")
    return len(direcoes), total


def main():
    a = argumentos()

    if a.lote:
        import json
        with open(a.lote, "r", encoding="utf-8") as f:
            pecas = json.load(f)
        n = 0
        total = 0.0
        for peca in pecas:
            q, t = renderizar_peca(peca)
            n += q
            total += t
        print(f"[render] LOTE: {len(pecas)} peças, {n} imagens, {total:.2f}s de render "
              f"(1 arranque de Blender em vez de {len(pecas)})")
        return

    if not a.cena or not a.saida:
        print("erro: use --lote, ou --cena junto com --saida")
        sys.exit(2)
    q, total = renderizar_peca({"cena": a.cena, "saida": a.saida,
                                "tamanho": a.tamanho, "direcoes": a.direcoes,
                                "escala": a.escala, "inclinacao": a.inclinacao})
    print(f"[render] {q} imagens em {total:.2f}s")


if __name__ == "__main__":
    main()
