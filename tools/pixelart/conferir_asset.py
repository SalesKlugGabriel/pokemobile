#!/usr/bin/env python3
"""
conferir_asset.py — O asset gerado combina com o jogo? Responde com NÚMERO.

── Por que este arquivo existe ────────────────────────────────────────────────

É a peça que faltava pra um agente operar o pipeline de arte sozinho.

Em 11/09/2026 rodei o MVP do Blender: gerei uma casa 3D, renderizei as 4 faces,
pixelizei. Só descobri que o resultado estava ruim **olhando a imagem e
comparando com o jogo na mão**. Um agente não consegue fazer isso de forma
confiável — e um pipeline que precisa de um humano olhando cada tentativa não é
um pipeline automatizado, é um humano com passos a mais.

Este script transforma "parece do mesmo jogo?" em medidas que qualquer um —
pessoa ou agente — confere sem opinar.

── O que descobri medindo, e que inverteu meu diagnóstico ────────────────────

Olhando, eu disse "mancha marrom, a paleta está errada". Medindo:

    distância de paleta   casa do Blender  30,8   ·  tile real do jogo  23,0

A paleta estava **certa**. O problema era outro:

    densidade de detalhe  tiles do jogo    0,51 (até 0,96)
                          casa pixelizada  0,01      ← 50x mais chapada

**A arte deste jogo é DENSA** — quase um tom por pixel, porque nasceu de
geração procedural com ruído. Meu pixelizador quantizou pra 10 cores e achatou
exatamente o que dá identidade ao estilo.

Eu não teria achado isso olhando. A medida achou.

── Uso ───────────────────────────────────────────────────────────────────────

    python3 tools/pixelart/conferir_asset.py assets/buildings/casa_sul.png
    python3 tools/pixelart/conferir_asset.py --grupo assets/buildings/casa_*.png
    python3 tools/pixelart/conferir_asset.py --json a.png     # pra script ler

Sai com código 0 se passou, 1 se reprovou — pra encaixar em teste e CI.
"""
import argparse
import glob
import json
import math
import os
import random
import sys
from collections import Counter
from PIL import Image

ATLAS = "assets/tilesets/overworld.png"

# ── As réguas, medidas contra o próprio jogo em 11/09 ─────────────────────────
# Não são gosto: saíram de amostrar tiles reais do atlas.

## Distância média até a cor mais próxima da paleta do jogo. Tile real do jogo
## mediu 23. Acima de 45 a peça começa a parecer de outro lugar.
PALETA_LIMITE = 45.0

## Cores distintas por pixel opaco. Os tiles do jogo medem 0,51 em média
## (min 0,00 em superfície chapada de propósito, max 0,96). Abaixo de 0,15 a
## peça fica visivelmente mais lisa que a vizinhança — foi o caso da casa do
## Blender, em 0,01.
DETALHE_MINIMO = 0.15

## Quanto do quadro o sprite ocupa. Muito pouco = sumiu; muito = vai encostar
## nos vizinhos no tile ao lado.
OCUPACAO_MINIMA = 0.10
OCUPACAO_MAXIMA = 0.95

## Entre direções do mesmo objeto: a área opaca não pode variar demais, senão
## o sprite "cresce e encolhe" ao virar.
VARIACAO_ENTRE_DIRECOES = 0.35


def _paleta_do_jogo(caminho_atlas, quantas=64):
    """As cores que o jogo mais usa. É contra ela que tudo é comparado."""
    if not os.path.exists(caminho_atlas):
        return []
    atlas = Image.open(caminho_atlas).convert("RGBA")
    cores = Counter(p[:3] for p in atlas.getdata() if p[3] > 200)
    return [c for c, _ in cores.most_common(quantas)]


def _distancia(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def medir(caminho, paleta):
    """As medidas de um PNG. Devolve dicionário — nada de opinião aqui."""
    im = Image.open(caminho).convert("RGBA")
    px = list(im.getdata())
    opacos = [p for p in px if p[3] > 200]
    total = im.size[0] * im.size[1]

    if not opacos:
        return {"arquivo": os.path.basename(caminho), "tamanho": im.size,
                "vazio": True}

    unicas = set(p[:3] for p in opacos)
    if paleta:
        ds = [min(_distancia(c, p) for p in paleta) for c in unicas]
        paleta_media = sum(ds) / len(ds)
        paleta_pior = max(ds)
    else:
        paleta_media = paleta_pior = 0.0

    return {
        "arquivo": os.path.basename(caminho),
        "tamanho": im.size,
        "vazio": False,
        "px_opacos": len(opacos),
        "ocupacao": len(opacos) / total,
        "cores": len(unicas),
        "detalhe": len(unicas) / len(opacos),
        "paleta_media": paleta_media,
        "paleta_pior": paleta_pior,
    }


def avaliar(m):
    """Das medidas pros problemas. Cada item é uma frase que diz o que fazer."""
    problemas = []
    if m.get("vazio"):
        problemas.append(
            "IMAGEM VAZIA — nenhum pixel opaco. No Blender isso quase sempre é "
            "a câmera não ter sido girada pra olhar o objeto (ela nasce olhando "
            "pra baixo e filma o chão).")
        return problemas

    if m["detalhe"] < DETALHE_MINIMO:
        problemas.append(
            f"CHAPADO DEMAIS — densidade {m['detalhe']:.2f}, mínimo {DETALHE_MINIMO:.2f} "
            f"(os tiles do jogo medem ~0,51). Quantizou demais, ou o modelo 3D usa "
            f"cor lisa sem textura.")

    if m["paleta_media"] > PALETA_LIMITE:
        problemas.append(
            f"FORA DA PALETA — distância média {m['paleta_media']:.1f}, limite "
            f"{PALETA_LIMITE:.0f} (tile real do jogo mede ~23). As cores não são as "
            f"que o jogo usa.")

    # 🔴 A régua de ocupação só vale pra SPRITE (peça com fundo transparente).
    # Um tile de terreno é opaco de ponta a ponta por definição — a primeira
    # versão reprovava os tiles do próprio jogo por "ocupar 100%".
    e_sprite = m["ocupacao"] < 0.999
    if e_sprite and m["ocupacao"] < OCUPACAO_MINIMA:
        problemas.append(
            f"PEQUENO DEMAIS — ocupa {m['ocupacao']*100:.0f}% do quadro, mínimo "
            f"{OCUPACAO_MINIMA*100:.0f}%. Aumente `--escala` no render ou corte a margem.")
    elif e_sprite and m["ocupacao"] > OCUPACAO_MAXIMA:
        problemas.append(
            f"GRANDE DEMAIS — ocupa {m['ocupacao']*100:.0f}% do quadro, máximo "
            f"{OCUPACAO_MAXIMA*100:.0f}%. Vai encostar no tile vizinho.")

    return problemas


def avaliar_grupo(medidas):
    """Problemas que só aparecem comparando as direções do MESMO objeto."""
    problemas = []
    areas = [m["px_opacos"] for m in medidas if not m.get("vazio")]
    if len(areas) < 2:
        return problemas
    media = sum(areas) / len(areas)
    pior = max(abs(a - media) / media for a in areas)
    if pior > VARIACAO_ENTRE_DIRECOES:
        problemas.append(
            f"INCONSISTENTE ENTRE DIREÇÕES — a área muda até {pior*100:.0f}% de uma "
            f"face pra outra (limite {VARIACAO_ENTRE_DIRECOES*100:.0f}%). O sprite "
            f"cresce e encolhe ao virar. Quase sempre é a CÂMERA tendo sido girada "
            f"em vez do objeto.")

    tamanhos = set(tuple(m["tamanho"]) for m in medidas)
    if len(tamanhos) > 1:
        problemas.append(f"TAMANHOS DIFERENTES entre as faces: {tamanhos}")
    return problemas


def main():
    p = argparse.ArgumentParser()
    p.add_argument("arquivos", nargs="+")
    p.add_argument("--grupo", action="store_true",
                   help="tratar os arquivos como direções do mesmo objeto")
    p.add_argument("--json", action="store_true")
    p.add_argument("--atlas", default=ATLAS)
    a = p.parse_args()

    caminhos = []
    for padrao in a.arquivos:
        caminhos.extend(sorted(glob.glob(padrao)) or [padrao])

    paleta = _paleta_do_jogo(a.atlas)
    if not paleta and not a.json:
        print(f"  aviso: atlas não encontrado em {a.atlas} — pulei a conferência de paleta")

    medidas = [medir(c, paleta) for c in caminhos]
    todos = []
    for m in medidas:
        m["problemas"] = avaliar(m)
        todos.extend(m["problemas"])
    grupo = avaliar_grupo(medidas) if a.grupo else []
    todos.extend(grupo)

    if a.json:
        print(json.dumps({"medidas": medidas, "grupo": grupo,
                          "passou": not todos}, ensure_ascii=False, indent=2))
    else:
        for m in medidas:
            if m.get("vazio"):
                print(f"  {m['arquivo']:<24} {m['tamanho'][0]}x{m['tamanho'][1]}  VAZIO")
            else:
                print(f"  {m['arquivo']:<24} {m['tamanho'][0]}x{m['tamanho'][1]}  "
                      f"ocupa {m['ocupacao']*100:3.0f}%  "
                      f"detalhe {m['detalhe']:.2f}  "
                      f"paleta {m['paleta_media']:5.1f}  "
                      f"{len(m['problemas'])} problema(s)")
        print()
        if todos:
            for t in todos:
                print(f"  ✗ {t}")
        else:
            print("  ✓ passou em todas as réguas")

    return 1 if todos else 0


if __name__ == "__main__":
    sys.exit(main())
