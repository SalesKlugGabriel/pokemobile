#!/usr/bin/env python3
"""
gerar_fundo_do_mar.py — O terreno do bioma submarino (11/09/2026).

Pedido do Gabriel: *"ali será um bioma 100% submarino com algas, corais,
profundidades diferentes"*. O mapa existe, a mecânica de mergulho existe — só
não havia chão pra desenhar nada disso.

Reaproveita o MESMO motor de textura de `gerar_biomas.py` (`_chao`,
`_ruido_ladrilhavel`, `_sombra`) em vez de inventar um estilo novo — peça
desenhada por outro caminho fica visivelmente de outra origem.

Cada tile passa por `tools/pixelart/conferir_asset.py`, a mesma régua que vale
pra qualquer arte do jogo. Três deles reprovaram na primeira geração por
ficarem lisos demais e tiveram o granulado aumentado; o abismo precisou do
maior de todos, porque o olho enxerga menos variação no escuro e a mesma
quantidade de ruído lê como superfície chapada.

  Linha 25 do atlas — três profundidades e o que vive nelas:
     0  areia clara       o recife raso: chão base, claro, ondulado
     1  areia com coral   variação do raso
     2  jardim de algas   o meio: chão mais escuro, verde
     3  abismo            o fundo: azul profundo, quase sem luz
     4  coral (bloqueia)  ramificado, colorido — o obstáculo do raso
     5  rocha submersa    (bloqueia) o obstáculo do fundo
     6  alga alta         atravessável, esconde o que está atrás
     7  respiradouro      bolhas subindo — devolve ar (ver Mergulho.gd)

⚠️ Estes tiles são BASE FUNCIONAL, não arte final. Foram feitos para a mecânica
poder ser construída e testada hoje. O refino visual é do Codex — ver o handoff.

Roda com:  python3 tools/gerar_fundo_do_mar.py
"""

import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageDraw
from gerar_biomas import _chao, _hash, _ruido_ladrilhavel, _sombra, T, COLS, ATLAS

LINHA_FUNDO_DO_MAR = 25          # o atlas cresce pra 26 linhas


# ── as três profundidades ────────────────────────────────────────────────────

def areia_clara(sal=1):
    """Recife raso: areia batida pela luz que ainda desce até aqui."""
    # granulado 0,44: a areia clara saía em 0,05, abaixo do piso do validador.
    return _chao((206, 196, 160), (228, 220, 190), (168, 158, 126),
                 sal=sal, celulas=7, forca=0.6, granulado=0.44)


def areia_com_coral(sal=2):
    """A mesma areia com manchas de coral morto — variação do raso, pra o chão
    não repetir visivelmente a cada tile."""
    img = areia_clara(sal)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(7):
        h = _hash(i, sal, 91)
        x, y = h % T, (h >> 8) % T
        r = 6 + (h >> 16) % 10
        d.ellipse([x - r, y - r // 2, x + r, y + r // 2], fill=(196, 150, 140, 90))
    return img


def jardim_de_algas(sal=3):
    """A faixa do meio: menos luz, verde, fundo mais orgânico."""
    return _chao((92, 118, 96), (120, 150, 118), (58, 78, 64),
                 sal=sal, celulas=6, forca=0.65, granulado=0.38)


def abismo(sal=4):
    """O fundo: azul profundo. Escuro o bastante pra ler como 'fundo', claro o
    bastante pra o jogador ver onde pisa — arte que esconde o chão vira
    frustração, não tensão."""
    # 🔴 granulado subiu de 0,20 pra 0,42: medido, o abismo saía com densidade
    # 0,05 contra o piso de 0,06 do validador. Fundo escuro precisa de MAIS
    # ruído, não menos — o olho enxerga menos variação no escuro, então a
    # mesma quantidade de ruído lê como superfície lisa.
    return _chao((28, 44, 74), (46, 66, 104), (16, 26, 46),
                 sal=sal, celulas=5, forca=0.75, granulado=0.42)


# ── o que ocupa o fundo ──────────────────────────────────────────────────────

def coral():
    """Coral ramificado. BLOQUEIA. Colorido de propósito: é o que dá cor ao
    raso e o que faz o recife parecer um lugar, não um corredor."""
    img = areia_clara(5)
    d = ImageDraw.Draw(img, "RGBA")
    _sombra(img, T // 2, T - 16, 34, alpha=90)
    base_y = T - 18
    # três ramos, cada um com galhos — desenhado inteiro e centrado (regra 1)
    for ramo, (dx, altura, cor) in enumerate([
            (-24, 62, (214, 106, 120)), (2, 82, (232, 138, 96)), (26, 58, (196, 96, 150))]):
        x = T // 2 + dx
        d.line([x, base_y, x, base_y - altura], fill=cor + (255,), width=9)
        for g in range(3):
            gy = base_y - altura * (0.4 + 0.22 * g)
            lado = -1 if (ramo + g) % 2 == 0 else 1
            d.line([x, gy, x + lado * (12 + 3 * g), gy - 14], fill=cor + (255,), width=6)
        # ponta clara: o toque de luz que faz o coral não parecer plástico
        d.ellipse([x - 6, base_y - altura - 6, x + 6, base_y - altura + 6],
                  fill=tuple(min(255, c + 40) for c in cor) + (255,))
    return img


def rocha_submersa():
    """Pedra coberta de limo. BLOQUEIA. É o obstáculo do fundo, onde não há
    coral — a profundidade muda o que atrapalha, não só a cor."""
    img = abismo(6)
    d = ImageDraw.Draw(img, "RGBA")
    _sombra(img, T // 2, T - 14, 40, alpha=110)
    d.polygon([(20, T - 16), (36, 52), (66, 30), (98, 54), (110, T - 16)],
              fill=(70, 78, 86, 255))
    d.polygon([(36, 52), (66, 30), (74, 60), (48, 74)], fill=(94, 104, 112, 255))
    # limo: a mesma cor do jardim de algas, pra os dois biomas conversarem
    for i in range(22):
        h = _hash(i, 7, 33)
        x, y = 24 + h % 84, 40 + (h >> 8) % (T - 60)
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(96, 124, 98, 150))
    return img


def alga_alta():
    """Alga que o jogador ATRAVESSA. Esconde parcialmente o que está atrás —
    é o mato alto do fundo do mar, e serve à mesma função: encontro escondido."""
    img = jardim_de_algas(7)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(9):
        h = _hash(i, 8, 55)
        x = 10 + (h % (T - 20))
        altura = 54 + (h >> 8) % 48
        curva = -14 + (h >> 16) % 28
        pontos = [(x, T - 8)]
        for p in range(1, 6):
            t = p / 5.0
            pontos.append((x + curva * t * t, T - 8 - altura * t))
        d.line(pontos, fill=(74, 132, 88, 235), width=7, joint="curve")
        d.line(pontos, fill=(112, 176, 120, 190), width=3, joint="curve")
    return img


def respiradouro():
    """Fenda que solta bolhas. ATRAVESSÁVEL, e devolve oxigênio.

    Existe porque o fundo do mar sem a roupa é cronometrado: sem nenhum ponto
    de fôlego, o mapa vira corredor de ida e volta. Com eles, vira rota a
    planejar — que é a diferença entre pressa e tensão."""
    img = abismo(9)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([T // 2 - 26, T - 40, T // 2 + 26, T - 8], fill=(14, 20, 34, 255))
    d.ellipse([T // 2 - 18, T - 34, T // 2 + 18, T - 14], fill=(58, 92, 120, 255))
    for i in range(11):
        h = _hash(i, 10, 77)
        r = 4 + h % 8
        x = T // 2 - 22 + (h >> 6) % 44
        y = T - 40 - (h >> 12) % (T - 56)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(190, 225, 240, 210), width=2)
    return img


def main():
    tiles = [areia_clara(), areia_com_coral(), jardim_de_algas(), abismo(),
             coral(), rocha_submersa(), alga_alta(), respiradouro()]

    atlas = Image.open(ATLAS).convert("RGBA")
    precisa = (LINHA_FUNDO_DO_MAR + 1) * T
    if atlas.size[1] < precisa:
        maior = Image.new("RGBA", (atlas.size[0], precisa), (0, 0, 0, 0))
        maior.paste(atlas, (0, 0))
        atlas = maior
        print(f"  atlas crescido para {atlas.size[0]}x{precisa}")

    for c, t in enumerate(tiles[:COLS]):
        atlas.paste(t, (c * T, LINHA_FUNDO_DO_MAR * T))
    atlas.save(ATLAS)
    print(f"  {len(tiles)} tiles gravados na linha {LINHA_FUNDO_DO_MAR} de {ATLAS}")


if __name__ == "__main__":
    main()
