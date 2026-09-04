#!/usr/bin/env python3
"""
gerar_kit_casa.py — Kit modular de construção (regra obrigatória 2).

Pedido do Gabriel: "as estruturas atuais só têm uma faixa de telhado e uma faixa
de parede empilhadas — sem paredes laterais. Isso só permite construir uma
fachada reta infinita, nunca uma casa fechada de verdade."

Gera as peças que faltam, DERIVADAS da arte que já existe (telhado 6,1 e parede
lisa 4,8) em vez de desenhar textura nova — assim o kit casa perfeitamente com
o que já está no mapa, que é o mesmo princípio que fez a parede lisa funcionar.

Peças (10):
  telhado: borda superior (cumeeira), inferior (beiral), esquerda, direita,
           e os 4 cantos
  parede:  lateral esquerda e lateral direita (com aresta de profundidade)

Luz da Art Bible: vem de CIMA-ESQUERDA. Então a cumeeira e a aresta esquerda
recebem highlight; beiral e aresta direita recebem sombra. É isso que dá volume
à casa vista de cima em vez de uma chapa lisa.
"""

from PIL import Image

ATLAS = "assets/tilesets/overworld.png"
T = 128

TELHADO_SRC = (6, 1)
PAREDE_SRC  = (4, 8)

# tons tirados da própria arte (amostrados do tile de telhado)
CUMEEIRA_CLARO = (206, 96, 52, 255)
CUMEEIRA_BASE  = (174, 62, 30, 255)
BEIRAL_ESCURO  = (74, 30, 18, 255)
BEIRAL_SOMBRA  = (46, 20, 13, 255)
TRIM_CLARO     = (196, 86, 44, 255)
TRIM_ESCURO    = (96, 40, 22, 255)

PAREDE_ARESTA_CLARA = (168, 160, 150, 255)
PAREDE_ARESTA_ESC   = (58, 54, 48, 255)

ESP = 14   # espessura da borda, em px


def _tile(im, cr):
    c, r = cr
    return im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T)).copy()


def _faixa(img, lado, cor_ext, cor_int, esp=ESP):
    """Pinta uma faixa de borda num dos lados, com 2 tons (aresta + interior)."""
    px = img.load()
    for i in range(esp):
        cor = cor_ext if i < esp // 3 else cor_int
        for j in range(T):
            if lado == "topo":      px[j, i] = cor
            elif lado == "baixo":   px[j, T - 1 - i] = cor
            elif lado == "esq":     px[i, j] = cor
            elif lado == "dir":     px[T - 1 - i, j] = cor
    return img


def gerar():
    im = Image.open(ATLAS).convert("RGBA")
    telhado = _tile(im, TELHADO_SRC)
    parede  = _tile(im, PAREDE_SRC)

    pecas = {}

    # ── bordas de telhado ──────────────────────────────────────────────────
    # cumeeira (topo): recebe a luz -> tom claro
    pecas["q"] = _faixa(telhado.copy(), "topo", CUMEEIRA_CLARO, CUMEEIRA_BASE)
    # beiral (baixo): sombra projetada -> tom escuro
    pecas["r"] = _faixa(telhado.copy(), "baixo", BEIRAL_SOMBRA, BEIRAL_ESCURO)
    # aresta esquerda: iluminada
    pecas["s"] = _faixa(telhado.copy(), "esq", TRIM_CLARO, CUMEEIRA_BASE)
    # aresta direita: na sombra
    pecas["t"] = _faixa(telhado.copy(), "dir", TRIM_ESCURO, BEIRAL_ESCURO)

    # ── cantos de telhado: duas bordas no mesmo tile ───────────────────────
    tl = _faixa(_faixa(telhado.copy(), "topo", CUMEEIRA_CLARO, CUMEEIRA_BASE),
                "esq", TRIM_CLARO, CUMEEIRA_BASE)
    tr = _faixa(_faixa(telhado.copy(), "topo", CUMEEIRA_CLARO, CUMEEIRA_BASE),
                "dir", TRIM_ESCURO, BEIRAL_ESCURO)
    bl = _faixa(_faixa(telhado.copy(), "baixo", BEIRAL_SOMBRA, BEIRAL_ESCURO),
                "esq", TRIM_CLARO, CUMEEIRA_BASE)
    br = _faixa(_faixa(telhado.copy(), "baixo", BEIRAL_SOMBRA, BEIRAL_ESCURO),
                "dir", TRIM_ESCURO, BEIRAL_ESCURO)
    pecas["u"], pecas["v"], pecas["x"], pecas["y"] = tl, tr, bl, br

    # ── paredes laterais: aresta vertical dá a profundidade que faltava ────
    pecas["a"] = _faixa(parede.copy(), "esq", PAREDE_ARESTA_CLARA, PAREDE_ARESTA_ESC, esp=10)
    pecas["p"] = _faixa(parede.copy(), "dir", PAREDE_ARESTA_ESC, PAREDE_ARESTA_ESC, esp=10)

    # ── grava nos slots livres do atlas ────────────────────────────────────
    livres = [(5, 8), (6, 8), (7, 8)] + [(c, 9) for c in range(8)]
    cols = im.size[0] // T
    linhas_necessarias = 10
    if im.size[1] // T < linhas_necessarias:
        novo = Image.new("RGBA", (im.size[0], linhas_necessarias * T), (0, 0, 0, 0))
        novo.paste(im, (0, 0))
        im = novo

    mapa = {}
    for i, (ch, img) in enumerate(pecas.items()):
        c, r = livres[i]
        im.paste(img, (c * T, r * T))
        mapa[ch] = (c, r)

    im.save(ATLAS)
    print(f"atlas: {im.size[0]}x{im.size[1]} — {len(pecas)} peças de kit gravadas")
    print()
    print("--- CHAR_MAP ---")
    for ch, (c, r) in mapa.items():
        print(f'\t"{ch}": Vector2i({c}, {r}),')
    print()
    print("--- overworld.tres (todas bloqueadas: são construção) ---")
    for ch, (c, r) in mapa.items():
        print(f"{c}:{r}/0 = 0")
        print(f"{c}:{r}/0/custom_data_0 = true")


if __name__ == "__main__":
    gerar()
