#!/usr/bin/env python3
"""
gerar_variacoes_terreno.py — Cria variações REAIS dos tiles de terreno.

PROBLEMA (visto em jogo, 04/09): o chão tem repetição óbvia. Já existia um
sistema de variação (`MapLayouts._variety_alt`), mas ele só ESPELHA o mesmo
tile — e espelhar a mesma textura não disfarça repetição, piora: cria aqueles
padrões simétricos em "borboleta" que o olho pega na hora.

SOLUÇÃO: variação de verdade, por ROLAGEM CIRCULAR. Medi as bordas dos tiles de
terreno e eles são seamless (diferença de 3 a 10 numa escala onde >40 já seria
costura visível). Num tile seamless, deslocar o conteúdo circularmente gera
outro tile igualmente seamless, com arranjo diferente e — o ponto principal —
EXATAMENTE o mesmo estilo/paleta, porque é a mesma arte. Nada de gerar textura
nova que destoaria do resto do tileset.

Os deslocamentos são propositalmente irregulares (não múltiplos de 32/64) pra
não gerar um segundo padrão perceptível.
"""

from PIL import Image

ATLAS = "assets/tilesets/overworld.png"
T = 128

# tiles isotrópicos que recebem variação (mesma lista do VARIETY_CHARS do jogo,
# + mato alto). Paredes/portas/telhados ficam de fora: têm direção.
# ⚠️ SÓ entram tiles verificados: seamless E sem elemento ancorado (tira de
# borda, tufo centralizado). Mato alto (0,2) fica de FORA — tem as folhas
# ancoradas na base, e rolar corta elas ao meio (apareceu em jogo como "tile
# partido"). A areia só voltou depois de o tile ser consertado (ver abaixo).
BASES = {
    ".": (0, 0),   # grama com tufos — seamless (dif de borda 4.3)
    "P": (1, 0),   # caminho de terra — seamless (dif 10.0)
    "G": (4, 0),   # grama clara — mesma família da (0,0)
    "S": (3, 0),   # areia — voltou em 04/09 DEPOIS de o tile ser consertado:
                   # ele tinha uma tira preta ocupando 40 das 128 colunas (recorte
                   # ruim da referência), refeita por espelhamento da parte boa,
                   # o que zerou a costura horizontal. Com a praia agora sendo uma
                   # área grande de verdade, variar a areia importa.
}

# 3 variações por tile, deslocamentos irregulares de propósito
OFFSETS = [(43, 71), (85, 29), (21, 96)]


def rolar(img, dx, dy):
    """Deslocamento circular: o que sai de um lado entra pelo outro."""
    w, h = img.size
    out = Image.new("RGBA", (w, h))
    out.paste(img, (dx - w, dy - h))
    out.paste(img, (dx, dy - h))
    out.paste(img, (dx - w, dy))
    out.paste(img, (dx, dy))
    return out


def main():
    atlas = Image.open(ATLAS).convert("RGBA")
    cols = atlas.size[0] // T
    linhas_atuais = atlas.size[1] // T

    total = len(BASES) * len(OFFSETS)
    linhas_novas = (total + cols - 1) // cols
    novo = Image.new("RGBA", (atlas.size[0], (linhas_atuais + linhas_novas) * T), (0, 0, 0, 0))
    novo.paste(atlas, (0, 0))

    mapa = {}   # char -> lista de (col,row) das variantes
    i = 0
    for ch, (bx, by) in BASES.items():
        base = atlas.crop((bx * T, by * T, (bx + 1) * T, (by + 1) * T))
        variantes = []
        for dx, dy in OFFSETS:
            c = i % cols
            r = linhas_atuais + i // cols
            novo.paste(rolar(base, dx, dy), (c * T, r * T))
            variantes.append((c, r))
            i += 1
        mapa[ch] = variantes

    novo.save(ATLAS)
    print(f"atlas: {atlas.size} -> {novo.size} ({total} variações novas)")
    print()
    print("--- linhas pra registrar no overworld.tres ---")
    for ch, vs in mapa.items():
        for c, r in vs:
            print(f"{c}:{r}/0 = 0")
    print()
    print("--- dicionário pro MapLayouts.gd ---")
    for ch, vs in mapa.items():
        coords = ", ".join(f"Vector2i({c}, {r})" for c, r in vs)
        base = BASES[ch]
        print(f'\t"{ch}": [Vector2i({base[0]}, {base[1]}), {coords}],')


if __name__ == "__main__":
    main()
