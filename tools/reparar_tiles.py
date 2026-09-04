#!/usr/bin/env python3
"""
reparar_tiles.py — Conserta defeitos de RECORTE nos tiles do atlas.

Origem do problema (achada em 04/09): o atlas foi recortado da imagem de
referência `docs/referencias/tileset-visual-referencia.png`, que tem a LEGENDA
escrita embaixo de cada tile. O recorte saiu desalinhado, então vários tiles
ficaram com:
  - faixa PRETA na borda (pedaço do fundo da referência entrou no quadro);
  - TEXTO da legenda preso dentro da arte (o "1"/palavras soltas que o Gabriel
    viu no mapa — regra obrigatória 3 do documento de direção de arte).

Conserto, sem inventar arte nova:
  - faixa preta → preenchida espelhando a parte BOA do próprio tile (mesma
    técnica já usada pra consertar a areia, que zerou a costura);
  - faixa de texto → substituída por conteúdo espelhado de baixo do próprio
    tile, que é a mesma textura.

Regra de processo (regra 3 do documento): esta checagem passa a ser etapa
padrão de todo lote de tile — rodar `--conferir` depois de qualquer mexida no
atlas.
"""

from PIL import Image
import sys

ATLAS = "assets/tilesets/overworld.png"
T = 128

# Só tiles com defeito CONFIRMADO visualmente. Não mexer em tile bom: linha
# escura de argamassa/sombra em parede é arte legítima, não defeito.
FAIXA_PRETA = [(6, 0), (7, 0), (1, 3), (2, 3), (2, 4), (3, 4), (4, 4), (5, 4), (1, 6), (3, 6)]
TEXTO_TOPO  = [(2, 6), (4, 1), (2, 0), (2, 5)]

LIMIAR_ESCURO = 60
LIMIAR_CLARO  = 195


def _escura(px, x, h=T):
    return sum(1 for y in range(h) if sum(px[x, y][:3]) < LIMIAR_ESCURO) > h * 0.85


def reparar_faixa_preta(tile):
    px = tile.load()
    ruins = [x for x in range(T) if _escura(px, x)]
    if not ruins:
        return tile, 0
    # assume faixa contígua numa das bordas
    if min(ruins) > T // 2:            # faixa à direita
        bom_ate = min(ruins)
        bom = tile.crop((0, 0, bom_ate, T))
        falta = T - bom_ate
        faixa = bom.crop((0, 0, min(falta, bom_ate), T)).transpose(Image.FLIP_LEFT_RIGHT)
        tile.paste(faixa, (bom_ate, 0))
    else:                               # faixa à esquerda
        bom_de = max(ruins) + 1
        bom = tile.crop((bom_de, 0, T, T))
        falta = bom_de
        faixa = bom.crop((0, 0, min(falta, T - bom_de), T)).transpose(Image.FLIP_LEFT_RIGHT)
        tile.paste(faixa, (bom_de - faixa.size[0], 0))
    return tile, len(ruins)


def reparar_texto(tile, altura=24):
    """Troca a faixa do topo por conteúdo espelhado logo abaixo dela."""
    px = tile.load()
    claros = sum(1 for y in range(altura) for x in range(T)
                 if px[x, y][0] > LIMIAR_CLARO and px[x, y][1] > LIMIAR_CLARO)
    limpa = tile.crop((0, altura, T, altura * 2)).transpose(Image.FLIP_TOP_BOTTOM)
    tile.paste(limpa, (0, 0))
    return tile, claros


def conferir():
    """Etapa padrão de QA de tile: acusa faixa preta e texto preso."""
    im = Image.open(ATLAS).convert("RGBA")
    achados = []
    for r in range(im.size[1] // T):
        for c in range(im.size[0] // T):
            t = im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T))
            px = t.load()
            if all(sum(px[x, y][:3]) < 30 for x in range(0, T, 8) for y in range(0, T, 8)):
                continue
            pretas = [x for x in range(T) if _escura(px, x)]
            claros = sum(1 for y in range(20) for x in range(T)
                         if px[x, y][0] > LIMIAR_CLARO and px[x, y][1] > LIMIAR_CLARO)
            if pretas:
                achados.append(f"({c},{r}) faixa preta: {len(pretas)} colunas")
            if claros > 40:
                achados.append(f"({c},{r}) suspeita de texto no topo: {claros}px claros")
    for a in achados:
        print("  " + a)
    print(f"{len(achados)} achado(s)")
    return achados


def main():
    if "--conferir" in sys.argv:
        conferir()
        return
    im = Image.open(ATLAS).convert("RGBA")
    for (c, r) in FAIXA_PRETA:
        t = im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T))
        t, n = reparar_faixa_preta(t)
        if n:
            im.paste(t, (c * T, r * T))
            print(f"tile ({c},{r}): faixa preta de {n} colunas preenchida")
    for (c, r) in TEXTO_TOPO:
        t = im.crop((c * T, r * T, (c + 1) * T, (r + 1) * T))
        t, n = reparar_texto(t)
        im.paste(t, (c * T, r * T))
        print(f"tile ({c},{r}): faixa do topo refeita ({n}px claros removidos)")
    im.save(ATLAS)
    print("atlas salvo")


if __name__ == "__main__":
    main()
