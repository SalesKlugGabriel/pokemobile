#!/usr/bin/env python3
"""
gerar_transicoes.py — Beira da praia: os tiles que faltavam entre areia e mar.

Por que existe: no teste de gameplay de 04/09 a costa era uma LINHA RETA — uma
faixa verde, uma marrom e uma azul, sem nada entre elas. "Parece uma bandeira."
O mapa já tinha praia e mar de verdade (a costa de 03/09), só faltavam os tiles
de encontro dos dois.

O que gera (8 tiles, exatamente os slots livres da linha 9 do atlas):
  4 bordas  — mar com a areia entrando por cima/baixo/esquerda/direita
  4 cantos  — o encontro de duas bordas

Como desenha: mar como base, areia por cima até uma linha ONDULADA (não reta),
e uma faixa de espuma clara na quebra. A ondulação vem de um hash determinístico
— o mesmo tile sai igual toda vez que o script roda.

Também reduz o contraste dos borrões da AREIA. Motivo: mesmo com 3 variantes, a
repetição da areia continuava óbvia em tela, porque os borrões escuros são
marcantes demais e o olho reencontra o mesmo desenho a cada 4 tiles.

Roda com:  python3 tools/gerar_transicoes.py
"""

import math

from PIL import Image

ATLAS = "assets/tilesets/overworld.png"
T = 128

AREIA = (3, 0)
AGUA = (1, 1)

# slots livres, conferidos antes de gravar
# Linha 10, NOVA. A linha 9 parece livre pelo nome mas é do KIT DA CASA
# (cumeeira/beiral/cantos/paredes laterais, gerado em 04/09) — a primeira
# versão deste script gravou por cima dele e apagou o kit inteiro. Antes de
# escolher slot no atlas: conferir o CHAR_MAP, não o "parece vazio".
SLOTS = {
    "praia_n": (0, 10), "praia_s": (1, 10), "praia_o": (2, 10), "praia_l": (3, 10),
    "praia_no": (4, 10), "praia_ne": (5, 10), "praia_so": (6, 10), "praia_se": (7, 10),
}
LINHAS_NECESSARIAS = 11

ESPUMA = (232, 240, 238, 255)
ESPUMA_2 = (198, 218, 222, 255)


def onda(i, semente, amplitude=9.0):
    """Perturbação determinística da linha da água: duas senoides + hash."""
    h = ((i * 0x9E3779B1) ^ (semente * 0x85EBCA77)) & 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
    ruido = ((h >> 8) % 100) / 100.0 - 0.5
    return (math.sin(i / 15.0 + semente) * amplitude
            + math.sin(i / 6.3 + semente * 2.0) * amplitude * 0.35
            + ruido * 3.0)


def borda(areia, agua, lado, semente):
    """Tile de beira: areia de um lado, mar do outro, com espuma na quebra."""
    img = agua.copy()
    ap, sp = img.load(), areia.load()
    corte = T * 0.52
    for i in range(T):
        limite = corte + onda(i, semente)
        for j in range(T):
            # (x, y) conforme o lado que tem areia
            if lado == "n":
                x, y, dentro = i, j, j < limite
            elif lado == "s":
                x, y, dentro = i, T - 1 - j, j < limite
            elif lado == "o":
                x, y, dentro = j, i, j < limite
            else:  # "l"
                x, y, dentro = T - 1 - j, i, j < limite
            if dentro:
                ap[x, y] = sp[x, y]
            elif j < limite + 3:
                ap[x, y] = ESPUMA
            elif j < limite + 7:
                ap[x, y] = ESPUMA_2
    return img


def canto(areia, agua, lado_a, lado_b, semente):
    """Canto: areia nos DOIS lados; a água ocupa só o quadrante oposto."""
    a = borda(areia, agua, lado_a, semente)
    b = borda(areia, agua, lado_b, semente + 7)
    fora = a.copy()
    ap, bp, sp = fora.load(), b.load(), areia.load()
    for y in range(T):
        for x in range(T):
            # é areia no tile A ou no tile B -> é areia no canto
            if _e_areia(ap[x, y], sp[x, y]) or _e_areia(bp[x, y], sp[x, y]):
                ap[x, y] = sp[x, y]
    return fora


def _e_areia(pixel, referencia):
    return pixel == referencia


def suavizar_areia(im):
    """Puxa os borrões escuros da areia pra perto da média: menos contraste,
    repetição bem menos visível, sem perder a textura."""
    for c, r in [AREIA, (1, 8), (2, 8), (3, 8)]:
        tile = im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T))
        px = tile.load()
        soma = [0, 0, 0]
        for y in range(T):
            for x in range(T):
                p = px[x, y]
                for k in range(3):
                    soma[k] += p[k]
        media = [s / (T * T) for s in soma]
        for y in range(T):
            for x in range(T):
                p = px[x, y]
                novo = tuple(int(media[k] + (p[k] - media[k]) * 0.55) for k in range(3))
                px[x, y] = novo + (p[3],)
        im.paste(tile, (c * T, r * T))


def main():
    im = Image.open(ATLAS).convert("RGBA")
    if im.size[1] // T < LINHAS_NECESSARIAS:
        maior = Image.new("RGBA", (im.size[0], LINHAS_NECESSARIAS * T), (0, 0, 0, 0))
        maior.paste(im, (0, 0))
        im = maior
    suavizar_areia(im)

    def tile(cr):
        c, r = cr
        return im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T)).copy()

    areia, agua = tile(AREIA), tile(AGUA)

    pecas = {
        "praia_n": borda(areia, agua, "n", 1),
        "praia_s": borda(areia, agua, "s", 2),
        "praia_o": borda(areia, agua, "o", 3),
        "praia_l": borda(areia, agua, "l", 4),
        "praia_no": canto(areia, agua, "n", "o", 5),
        "praia_ne": canto(areia, agua, "n", "l", 6),
        "praia_so": canto(areia, agua, "s", "o", 7),
        "praia_se": canto(areia, agua, "s", "l", 8),
    }
    for nome, img in pecas.items():
        c, r = SLOTS[nome]
        im.paste(img, (c * T, r * T))
    im.save(ATLAS)
    print(f"areia suavizada + {len(pecas)} tiles de beira gravados")
    for nome, (c, r) in SLOTS.items():
        print(f'  {nome}: ({c}, {r})')


if __name__ == "__main__":
    main()
