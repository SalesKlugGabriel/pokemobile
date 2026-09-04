#!/usr/bin/env python3
"""
gerar_fundo_titulo.py — Fundo da tela de título, montado com os tiles do jogo.

Por que existe: no teste de gameplay a tela de título era um retângulo preto com
fonte de sistema. Primeira impressão de "o jogo não carregou".

Por que montar com os tiles do próprio jogo, em vez de desenhar arte nova: é a
mesma regra que vale pro resto do projeto — a tela de abertura tem que parecer
o jogo que vem depois. Cada tile aqui é o mesmo arquivo que o mapa usa, então a
capa nunca vai "envelhecer" em relação ao mundo.

Os tiles são desenhados a meia escala (64px), porque a 128px caberiam só 10x5,6
tiles na tela e isso não lê como paisagem — lê como close de chão.

Roda com:  python3 tools/gerar_fundo_titulo.py
"""

from PIL import Image, ImageFilter

ATLAS = "assets/tilesets/overworld.png"
SAIDA = "assets/ui/fundo_titulo.png"
T = 128
LADO = 64                     # tile na tela do título
LARG, ALT = 1280, 720
COLS, LINHAS = LARG // LADO, ALT // LADO + 1   # 20 x 12

# coordenadas no atlas (conferidas tile a tile antes de usar)
GRAMA   = (0, 0)
GRAMA_V = [(0, 0), (0, 7), (1, 7), (2, 7)]
TERRA   = (1, 0)
AREIA   = (3, 0)
AGUA    = (1, 1)
MATO    = (0, 2)
FLOR    = (2, 0)
ARVORES = [(2, 1), (1, 2), (2, 2)]


def espalhar(c, r):
    h = ((c * 0x9E3779B1) ^ (r * 0x85EBCA77)) & 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) & 0xFFFFFFFF
    return h % 20


def cena(c, r):
    """Uma paisagem: mata em cima, campo com trilha no meio, praia e mar embaixo."""
    if r >= LINHAS - 2:
        return AGUA
    if r == LINHAS - 3:
        return AREIA
    if r <= 1:
        return ARVORES[espalhar(c, r) % len(ARVORES)]
    if r == 2 and espalhar(c, r) < 9:
        return ARVORES[espalhar(c, r) % len(ARVORES)]
    # trilha de terra descendo em diagonal suave: dá profundidade e leva o olho
    if abs(c - (5 + r)) <= 1:
        return TERRA
    d = espalhar(c, r)
    if d < 2:
        return FLOR
    if 6 <= r <= 7 and 12 <= c <= 17:
        return MATO
    return GRAMA_V[d % len(GRAMA_V)]


def main():
    atlas = Image.open(ATLAS).convert("RGBA")

    def tile(cr):
        c, r = cr
        return atlas.crop((c * T, r * T, (c + 1) * T, (r + 1) * T)).resize(
            (LADO, LADO), Image.LANCZOS)

    img = Image.new("RGBA", (LARG, LINHAS * LADO))
    for r in range(LINHAS):
        for c in range(COLS):
            img.paste(tile(cena(c, r)), (c * LADO, r * LADO))
    img = img.crop((0, 0, LARG, ALT))

    # Desfoque leve + escurecimento: o fundo tem que ficar ATRÁS do texto, não
    # competir com ele. Sem isso o título fica ilegível sobre a folhagem.
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    escuro = Image.new("RGBA", img.size, (6, 10, 8, 140))
    img = Image.alpha_composite(img, escuro)

    # Vinheta: escurece as bordas e concentra a atenção no centro, onde ficam
    # o logo e os botões.
    vinheta = Image.new("L", img.size, 0)
    px = vinheta.load()
    cx, cy = LARG / 2.0, ALT / 2.0
    raio = (cx ** 2 + cy ** 2) ** 0.5
    for y in range(0, ALT, 2):
        for x in range(0, LARG, 2):
            d = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / raio
            v = int(min(255, max(0, (d - 0.35) / 0.65 * 190)))
            for dy in range(2):
                for dx in range(2):
                    if x + dx < LARG and y + dy < ALT:
                        px[x + dx, y + dy] = v
    img = Image.composite(Image.new("RGBA", img.size, (2, 6, 5, 255)), img, vinheta)

    img.save(SAIDA)
    print(f"{SAIDA}  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
