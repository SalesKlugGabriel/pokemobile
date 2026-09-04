#!/usr/bin/env python3
"""
gerar_pokebola.py — A Pokébola, em 3 estados (05/09).

Por que existe: o Gabriel pediu que a escolha do inicial deixe de ser uma tela
de cartões e vire o ENCONTRO com o Prof. Carvalho, com as três pokébolas na
mesa — como nos jogos originais. Não havia sprite de pokébola no projeto.

Estados (um arquivo cada, 128x128):
  fechada  — a bola parada na mesa
  brilhando — a mesma bola com halo, pro item selecionado
  aberta   — as duas metades separadas e a luz saindo do meio

Desenhada seguindo a Art Bible: luz vindo de CIMA-ESQUERDA (por isso o brilho
especular fica no quadrante superior esquerdo), contorno derivado do tom escuro
do próprio material — nunca preto puro.

Roda com:  python3 tools/gerar_pokebola.py
"""

import math

from PIL import Image, ImageDraw, ImageFilter

SAIDA = "assets/sprites/itens"
LADO = 128
R = 46                       # raio da bola
CENTRO = (LADO // 2, LADO // 2 + 4)

VERMELHO = (214, 58, 48, 255)
VERMELHO_LUZ = (240, 104, 92, 255)
VERMELHO_SOMBRA = (150, 34, 28, 255)
BRANCO = (238, 238, 234, 255)
BRANCO_SOMBRA = (176, 178, 176, 255)
CONTORNO = (46, 26, 24, 255)
FAIXA = (40, 34, 34, 255)
BOTAO = (246, 246, 242, 255)
BOTAO_BORDA = (120, 120, 118, 255)
HALO = (255, 236, 150, 255)


def _base(desenho, cx, cy, r, abertura=0):
    """Metade de cima vermelha, metade de baixo branca, faixa preta no meio.
    `abertura` afasta as duas metades em px (usado no estado aberto)."""
    topo = (cx - r, cy - r - abertura, cx + r, cy + r - abertura)
    baixo = (cx - r, cy - r + abertura, cx + r, cy + r + abertura)

    # metade de baixo (branca)
    desenho.pieslice(baixo, 0, 180, fill=BRANCO, outline=CONTORNO, width=3)
    # sombra de contato dentro da metade branca
    desenho.pieslice((baixo[0] + 8, baixo[1] + 10, baixo[2] - 8, baixo[3] - 4),
                     25, 155, fill=BRANCO_SOMBRA)
    desenho.pieslice((baixo[0] + 6, baixo[1] + 4, baixo[2] - 6, baixo[3] - 12),
                     0, 180, fill=BRANCO)
    # metade de cima (vermelha)
    desenho.pieslice(topo, 180, 360, fill=VERMELHO, outline=CONTORNO, width=3)
    # brilho: luz de cima-esquerda
    desenho.pieslice((topo[0] + 10, topo[1] + 8, cx + 4, cy - abertura - 6),
                     190, 300, fill=VERMELHO_LUZ)
    desenho.pieslice((topo[0] + 4, topo[1] + 16, topo[2] - 4, cy - abertura),
                     255, 285, fill=VERMELHO_SOMBRA)

    # faixa central
    if abertura == 0:
        desenho.rectangle((cx - r, cy - 6, cx + r, cy + 6), fill=FAIXA)
    else:
        desenho.rectangle((cx - r, cy - abertura - 6, cx + r, cy - abertura + 2), fill=FAIXA)
        desenho.rectangle((cx - r, cy + abertura - 2, cx + r, cy + abertura + 6), fill=FAIXA)


def _botao(desenho, cx, cy):
    desenho.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill=FAIXA)
    desenho.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=BOTAO, outline=BOTAO_BORDA, width=2)
    desenho.ellipse((cx - 6, cy - 7, cx - 1, cy - 2), fill=(255, 255, 255, 255))


def _sombra_no_chao(img, cx, cy, r):
    sombra = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sombra)
    d.ellipse((cx - r + 4, cy + r - 10, cx + r - 4, cy + r + 8), fill=(20, 16, 14, 110))
    sombra = sombra.filter(ImageFilter.GaussianBlur(3))
    return Image.alpha_composite(sombra, img)


def fechada():
    img = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = CENTRO
    _base(d, cx, cy, R)
    _botao(d, cx, cy)
    return _sombra_no_chao(img, cx, cy, R)


def brilhando():
    """Mesma bola com halo dourado — é o feedback de 'esta é a que você
    escolheria agora'. Sem isso, o teclado seleciona e nada muda na tela."""
    img = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = CENTRO
    halo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    dh = ImageDraw.Draw(halo)
    for i in range(10, 0, -1):
        a = int(16 + i * 8)
        rr = R + i * 2
        dh.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=HALO[:3] + (a,))
    halo = halo.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, halo)
    d = ImageDraw.Draw(img)
    _base(d, cx, cy, R)
    _botao(d, cx, cy)
    return _sombra_no_chao(img, cx, cy, R)


def aberta():
    """Metades afastadas + o flash saindo do meio.

    A luz vai POR CIMA das metades, não por baixo: desenhada atrás, ela só
    preenchia o vão e lia como uma faixa bege parada, em vez de um clarão."""
    img = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    cx, cy = CENTRO
    d = ImageDraw.Draw(img)
    _base(d, cx, cy, R, abertura=18)
    img = _sombra_no_chao(img, cx, cy, R)

    luz = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    dl = ImageDraw.Draw(luz)
    # núcleo branco no vão + raios verticais, que é o que dá leitura de "abriu"
    dl.ellipse((cx - 30, cy - 20, cx + 30, cy + 20), fill=(255, 255, 252, 255))
    for k in range(-3, 4):
        larg = 7 - abs(k)
        dl.polygon([(cx + k * 9 - larg, cy), (cx + k * 9 + larg, cy),
                    (cx + k * 16, cy - 58), (cx + k * 16 - larg * 2, cy - 58)],
                   fill=(255, 252, 225, 190))
    luz = luz.filter(ImageFilter.GaussianBlur(5))
    return Image.alpha_composite(img, luz)


def main():
    import os
    os.makedirs(SAIDA, exist_ok=True)
    for nome, fn in [("pokebola_fechada", fechada),
                     ("pokebola_brilhando", brilhando),
                     ("pokebola_aberta", aberta)]:
        caminho = f"{SAIDA}/{nome}.png"
        fn().save(caminho)
        print(f"  {caminho}")


if __name__ == "__main__":
    main()
