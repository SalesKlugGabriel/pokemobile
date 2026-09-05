#!/usr/bin/env python3
"""
gerar_arvores_grandes.py — Árvores de 2x3 tiles (05/09).

Pedido do Gabriel: "ajuste todas as árvores (pode usar até 2x3 (LxA) para todas
as árvores, estruturas etc, não precisa se prender aos tiles individuais)".

Por que isso muda tanto: até aqui cada árvore era UM tile de 128x128 — do mesmo
tamanho da cabeça do personagem, que ocupa 1x2 tiles. O jogador parecia um
gigante andando entre arbustos, e uma "floresta" era uma grade de bolinhas
verdes iguais. Com 2x3 (256 x 384 px) a árvore fica mais alta que o treinador,
que é a proporção do Pokémon original e o que faz a mata parecer mata.

Cada árvore é desenhada INTEIRA numa tela de 256x384 e só depois fatiada nos 6
tiles — é por isso que a copa fica contínua entre os tiles, sem emenda. Desenhar
tile a tile era o que produzia as árvores "cortadas" que já tinham dado problema.

Espécies (4), todas com a mesma direção de luz da Art Bible (cima-esquerda):
  carvalho  — copa larga e redonda
  pinheiro  — cônica, em camadas
  outono    — copa redonda alaranjada
  frondosa  — copa larga e baixa, verde-escura

Saída: linhas 11, 12 e 13 do atlas (2 colunas por espécie).
  carvalho (0-1)  pinheiro (2-3)  outono (4-5)  frondosa (6-7)

Roda com:  python3 tools/gerar_arvores_grandes.py
"""

import math

from PIL import Image, ImageDraw, ImageFilter

ATLAS = "assets/tilesets/overworld.png"
T = 128
LARG, ALT = 2 * T, 3 * T      # 256 x 384
LINHA_BASE = 11               # primeira linha do atlas usada

# Paletas: (claro, base, escuro, contorno). Contorno é sempre o tom mais escuro
# do PRÓPRIO material — nunca preto puro (regra da Art Bible).
# Amostradas dos tiles de árvore que já existiam no atlas (a antiga árvore em
# (2,1), o pinheiro em (1,2), o outono em (2,2)) — assim a mata nova encaixa
# com o resto do mundo em vez de parecer de outro jogo.
PALETAS = {
    "carvalho": ((122, 176, 60), (74, 126, 40), (40, 78, 26), (28, 57, 14)),
    "pinheiro": ((96, 150, 74), (52, 104, 52), (30, 66, 34), (20, 49, 20)),
    "outono":   ((240, 196, 74), (215, 162, 35), (140, 96, 12), (72, 47, 5)),
    "frondosa": ((104, 158, 56), (60, 112, 38), (32, 72, 24), (22, 48, 14)),
}
TRONCO = ((140, 100, 56), (104, 70, 36), (68, 44, 20), (42, 27, 10))
SOMBRA = (16, 26, 18, 96)


def _hash(x, y, sal=0):
    h = ((x * 0x9E3779B1) ^ (y * 0x85EBCA77) ^ (sal * 0xC2B2AE35)) & 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
    return (h ^ (h >> 13)) & 0xFFFFFFFF


def _sombra_no_chao(img, cx, base_y, raio):
    """Elipse achatada sob a árvore. É ela que 'assenta' o objeto no chão —
    sem sombra de contato, qualquer sprite grande parece adesivo colado."""
    camada = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    d.ellipse((cx - raio, base_y - raio * 0.30, cx + raio, base_y + raio * 0.30),
              fill=SOMBRA)
    camada = camada.filter(ImageFilter.GaussianBlur(7))
    return Image.alpha_composite(camada, img)


def _tronco(d, cx, topo, base, largura, inclinacao=0):
    claro, meio, escuro, contorno = TRONCO
    for y in range(topo, base):
        t = (y - topo) / max(1, base - topo)
        w = largura * (0.72 + 0.28 * t)          # alarga na raiz
        x = cx + inclinacao * (1 - t)
        d.line([(x - w / 2, y), (x + w / 2, y)], fill=meio)
        d.line([(x - w / 2, y), (x - w / 2 + 3, y)], fill=claro)     # luz à esquerda
        d.line([(x + w / 2 - 4, y), (x + w / 2, y)], fill=escuro)
    # raízes
    d.polygon([(cx - largura, base), (cx + largura, base),
               (cx + largura * 0.55, base - 12), (cx - largura * 0.55, base - 12)],
              fill=escuro)
    d.line([(cx - largura, base), (cx + largura, base)], fill=contorno, width=3)


def _folhagem_redonda(d, cx, cy, raio, paleta, sal, achatada=1.0):
    """Copa como AGLOMERADOS DE FOLHA, não como uma bola lisa.

    A primeira versão usava poucas bolhas grandes e o resultado era um montinho
    liso — dava a escala certa mas não parecia a mesma arte do tileset, que tem
    grumos bem visíveis. Aqui são muitos aglomerados pequenos, cada um com seu
    contorno e seus 3 tons, desenhados de trás pra frente (os de cima por
    último): é a sobreposição que cria a textura de folhagem.
    """
    claro, base, escuro, contorno = paleta
    grumos = []
    n = 120
    for i in range(n):
        # distribuição em disco (raiz do aleatório = densidade uniforme; sem
        # isso tudo se acumula no meio e a borda fica rala)
        a = (_hash(i, sal, 3) % 10000) / 10000.0 * math.tau
        t = math.sqrt((_hash(i, sal, 5) % 10000) / 10000.0)
        bx = cx + math.cos(a) * raio * t
        by = cy + math.sin(a) * raio * t * achatada
        rr = 13 + (_hash(i, sal, 7) % 9)
        grumos.append((bx, by, rr))
    grumos.sort(key=lambda g: g[1])          # de cima pra baixo

    for bx, by, rr in grumos:
        d.ellipse((bx - rr - 2, by - rr - 2, bx + rr + 2, by + rr + 2), fill=contorno)
    for bx, by, rr in grumos:
        d.ellipse((bx - rr, by - rr, bx + rr, by + rr), fill=escuro)
    for bx, by, rr in grumos:
        # a face virada pra luz (cima-esquerda) recebe o tom base
        d.ellipse((bx - rr * 0.80, by - rr * 0.86, bx + rr * 0.72, by + rr * 0.62), fill=base)
    for bx, by, rr in grumos:
        # e um brilho pequeno, só nos grumos do quadrante iluminado
        if bx < cx + raio * 0.25 and by < cy + raio * 0.12 * achatada:
            d.ellipse((bx - rr * 0.46, by - rr * 0.52, bx + rr * 0.30, by + rr * 0.22), fill=claro)


def carvalho(paleta, sal):
    img = Image.new("RGBA", (LARG, ALT), (0, 0, 0, 0))
    img = _sombra_no_chao(img, LARG / 2, ALT - 26, 82)
    d = ImageDraw.Draw(img)
    _tronco(d, LARG / 2, 214, ALT - 22, 40)
    _folhagem_redonda(d, LARG / 2, 148, 96, paleta, sal)
    return img


def frondosa(paleta, sal):
    img = Image.new("RGBA", (LARG, ALT), (0, 0, 0, 0))
    img = _sombra_no_chao(img, LARG / 2, ALT - 24, 92)
    d = ImageDraw.Draw(img)
    _tronco(d, LARG / 2, 232, ALT - 20, 46)
    _folhagem_redonda(d, LARG / 2, 158, 104, paleta, sal, achatada=0.80)
    return img


def outono(paleta, sal):
    img = Image.new("RGBA", (LARG, ALT), (0, 0, 0, 0))
    img = _sombra_no_chao(img, LARG / 2, ALT - 26, 78)
    d = ImageDraw.Draw(img)
    _tronco(d, LARG / 2 + 4, 206, ALT - 22, 36, inclinacao=-8)
    _folhagem_redonda(d, LARG / 2, 144, 92, paleta, sal)
    return img


def pinheiro(paleta, sal):
    """Cônica, em 5 camadas — a silhueta tem que ser reconhecível na miniatura
    do minimapa, não só de perto."""
    claro, base, escuro, contorno = paleta
    img = Image.new("RGBA", (LARG, ALT), (0, 0, 0, 0))
    img = _sombra_no_chao(img, LARG / 2, ALT - 24, 62)
    d = ImageDraw.Draw(img)
    _tronco(d, LARG / 2, 286, ALT - 20, 30)
    cx = LARG / 2
    camadas = 5
    for i in range(camadas):
        t = i / (camadas - 1.0)
        cy = 62 + t * 232
        meia = 26 + t * 92
        alto = 58 + t * 22
        pontos = []
        passos = 22
        for k in range(passos + 1):
            fx = -1.0 + 2.0 * k / passos
            ruido = ((_hash(i, k, sal) % 100) / 100.0 - 0.5) * 12
            pontos.append((cx + fx * meia + ruido, cy + alto * 0.55))
        pontos.append((cx + meia * 0.20, cy - alto * 0.5))
        pontos.append((cx - meia * 0.20, cy - alto * 0.5))
        d.polygon(pontos, fill=contorno)
        menores = [(x * 0.985 + cx * 0.015, y - 4) for x, y in pontos]
        d.polygon(menores, fill=escuro)
        claros = [(cx + (x - cx) * 0.72, y - 10) for x, y in pontos]
        d.polygon(claros, fill=base)
        # highlight só do lado esquerdo (luz de cima-esquerda)
        esq = [(x, y) for x, y in claros if x <= cx]
        if len(esq) >= 3:
            d.polygon(esq + [(cx, cy)], fill=claro)
        # Tufos na borda de baixo de cada camada. Sem eles o pinheiro ficava
        # geométrico ao lado das outras três, que são feitas de aglomerados —
        # a mesma árvore em duas linguagens de desenho diferentes.
        for k in range(11):
            fx = -1.0 + 2.0 * k / 10.0
            tx = cx + fx * meia * 0.96
            ty = cy + alto * 0.55 - 3
            rr = 9 + (_hash(i, k, sal + 40) % 7)
            d.ellipse((tx - rr - 2, ty - rr - 2, tx + rr + 2, ty + rr + 2), fill=contorno)
            d.ellipse((tx - rr, ty - rr, tx + rr, ty + rr), fill=escuro)
            d.ellipse((tx - rr * 0.72, ty - rr * 0.82, tx + rr * 0.62, ty + rr * 0.42),
                      fill=base if fx > -0.2 else claro)
    return img


ESPECIES = [
    ("carvalho", carvalho, 0),
    ("pinheiro", pinheiro, 0),
    ("outono", outono, 0),
    ("frondosa", frondosa, 0),
]


def main():
    im = Image.open(ATLAS).convert("RGBA")
    linhas_necessarias = LINHA_BASE + 3
    if im.size[1] // T < linhas_necessarias:
        maior = Image.new("RGBA", (im.size[0], linhas_necessarias * T), (0, 0, 0, 0))
        maior.paste(im, (0, 0))
        im = maior

    # Fundo de grama assado em cada tile. Necessário porque os dois tiles de
    # baixo da árvore são quase todos transparentes (só o tronco): sem grama
    # atrás, eles abririam um buraco no mapa, já que a camada 0 do TileMap não
    # tem nada por trás. Usa as variantes de grama pra floresta não virar um
    # xadrez do mesmo tile.
    variantes = [(0, 0), (0, 7), (1, 7), (2, 7)]

    def fundo_de_grama(indice):
        fundo = Image.new("RGBA", (LARG, ALT))
        for lin in range(3):
            for col in range(2):
                h = _hash(indice * 7 + col, lin, 61) % len(variantes)
                gc, gr = variantes[h]
                fundo.paste(im.crop((gc * T, gr * T, (gc + 1) * T, (gr + 1) * T)),
                            (col * T, lin * T))
        return fundo

    print("árvores 2x3 (256x384 cada), fatiadas em 6 tiles:")
    for i, (nome, fn, sal) in enumerate(ESPECIES):
        arvore = Image.alpha_composite(fundo_de_grama(i), fn(PALETAS[nome], sal + i * 17))
        col0 = i * 2
        for lin in range(3):
            for col in range(2):
                pedaco = arvore.crop((col * T, lin * T, (col + 1) * T, (lin + 1) * T))
                im.paste(pedaco, ((col0 + col) * T, (LINHA_BASE + lin) * T))
        print(f"  {nome:9s} -> colunas {col0}-{col0+1}, linhas "
              f"{LINHA_BASE}-{LINHA_BASE+2}")
    im.save(ATLAS)
    print(f"atlas: {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
