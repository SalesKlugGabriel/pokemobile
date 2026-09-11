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

🔴 ── A régua estava ERRADA, e o erro produziu uma conclusão falsa ───────────

Vale contar inteiro, porque é a armadilha central de medir arte por script.

A primeira versão media "densidade de detalhe" = cores distintas por pixel
opaco. Calibrei contra o atlas recortando em **32px** — só que o tile deste
jogo tem **128px**. Eu estava medindo PEDAÇOS de tile, não tiles.

E a densidade **depende do tamanho da amostra**: o MESMO tile mede 0,48 em
128px, 0,61 em 64px, 0,74 em 16px. Quanto menor o recorte, maior o número.

Com a régua torta, a conta deu uma história dramática — "a casa do Blender tem
0,01 contra 0,51 do jogo, 50 vezes mais chapada" — e eu reescrevi o
`pixelizar.py` inteiro em cima dela.

**Medindo sempre no mesmo tamanho (64px), a história some:**

    tiles do jogo        mediana 0,24  ·  faixa 0,00 a 0,84
    casa "chapada"       0,26          ← dentro da faixa
    casa "corrigida"     0,28          ← praticamente igual

Os dois estavam dentro do normal do jogo. **A medida não sustentava a
conclusão que eu tirei dela.**

── O que fica de verdade ─────────────────────────────────────────────────────

1. A régua agora mede num **tamanho canônico** e é estável (0,61 / 0,61 / 0,64
   para a mesma imagem entrando em 128, 64 e 32px).
2. Ela pega bem o que é medível: cor fora da paleta, imagem vazia, sprite fora
   de tamanho, faces inconsistentes entre si.
3. Ela **não mede se a peça está bonita**. A casa do Blender parece ruim por
   silhueta e falta de forma — e isso nenhuma dessas contas captura.

O meu olho estava certo e a minha régua estava errada. A lição não é "não
meça": é **calibrar a régua contra a coisa certa, e desconfiar quando ela
contar uma história boa demais**.

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

## Tamanho em que a densidade é SEMPRE medida. Sem isso a medida não é
## comparável entre peças de tamanhos diferentes — ver a nota do cabeçalho.
TAMANHO_CANONICO = 64

## Cores distintas por pixel opaco, medidas em TAMANHO_CANONICO. Amostrando 40
## tiles reais do jogo: mediana 0,24, faixa de 0,00 (superfície chapada de
## propósito) a 0,84.
##
## O piso é baixo de propósito — 0,06 — porque a faixa do jogo é larguíssima e
## uma régua apertada aqui reprova arte legítima. Isto pega peça
## EXTRAORDINARIAMENTE lisa, não peça "menos texturizada que a média".
DETALHE_MINIMO = 0.06
DETALHE_TIPICO = 0.24

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

    # Densidade num tamanho canônico: é o que torna peças de tamanhos
    # diferentes comparáveis entre si (ver a nota do cabeçalho).
    canonica = im if im.size == (TAMANHO_CANONICO, TAMANHO_CANONICO) \
        else im.resize((TAMANHO_CANONICO, TAMANHO_CANONICO), Image.LANCZOS)
    opacos_c = [p for p in canonica.getdata() if p[3] > 200]
    densidade = (len(set(p[:3] for p in opacos_c)) / len(opacos_c)) if opacos_c else 0.0

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
        "detalhe": densidade,
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
            f"(a mediana do jogo é {DETALHE_TIPICO:.2f}). Quantizou demais, ou a peça é "
            f"uma superfície lisa sem textura nenhuma.")

    if m["paleta_media"] > PALETA_LIMITE:
        problemas.append(
            f"FORA DA PALETA — distância média {m['paleta_media']:.1f}, limite "
            f"{PALETA_LIMITE:.0f} (tile real do jogo mede ~23). As cores não são as "
            f"que o jogo usa.")

    # 🔴 A régua de ocupação só vale pra SPRITE (peça com fundo transparente).
    # Um tile de terreno é opaco de ponta a ponta por definição.
    # O corte é 90%, e não 99,9%: um tile de terreno com um canto levemente
    # transparente (anti-serrilhado na borda) continua sendo terreno, e a
    # primeira versão reprovava esses por "ocupar 96%".
    e_sprite = m["ocupacao"] < 0.90
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
