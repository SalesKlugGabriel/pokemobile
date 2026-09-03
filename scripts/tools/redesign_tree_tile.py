#!/usr/bin/env python3
"""Redesenha o tile de Árvore (T, atlas col2/row1 de overworld.png) — pedido
do Gabriel (02/09, mesmo dia do ajuste de zoom): "as árvores em uma
proporção que pareça uma árvore e não um arbusto".

Achado ao comparar lado a lado com o tile de Arbusto (col7/row1): não são
o mesmo desenho confundido — o Arbusto é uma textura de folhagem que
preenche o quadro INTEIRO (parede de sebe), enquanto a Árvore já tinha
copa redonda + tronco. O problema real: a copa da árvore preenchia quase
o quadro 32×32 todo, sem margem de grama visível — lado a lado, viravam
uma "parede verde contínua" (copas se tocando) em vez de árvores
individuais separadas por um vão de grama, que é o que faz um objeto
LER como árvore isolada em vez de sebe/arbusto.

Correção: copa mais estreita (deixa margem de grama nítida nas bordas),
tronco mais alto e visível, fundo de grama copiado pixel a pixel do
próprio tile de Grama (garante 100% de continuidade de textura com os
tiles vizinhos, não é uma cor aproximada).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TILESET = ROOT / "assets" / "tilesets" / "overworld.png"
TILE = 32

# Paleta extraída do próprio tile de árvore atual (overworld.png col2/row1),
# pra manter consistência de estilo em vez de inventar cores novas.
OUTLINE = (24, 58, 16)
CANOPY_DARK = (39, 91, 24)
CANOPY_MID = (56, 115, 17)
CANOPY_LIGHT = (68, 126, 30)
CANOPY_HILITE = (110, 170, 60)
TRUNK_DARK = (74, 46, 24)
TRUNK_LIGHT = (110, 72, 40)


def build_tree_tile(grass_bg: Image.Image) -> Image.Image:
    im = grass_bg.copy().convert("RGB")
    d = ImageDraw.Draw(im)

    # Tronco — mais alto e visível que antes (base do tile).
    d.rectangle([13, 22, 18, 30], fill=TRUNK_DARK)
    d.rectangle([14, 22, 15, 30], fill=TRUNK_LIGHT)

    # Copa — oval mais ALTO que largo, com margem de grama visível nas
    # bordas do tile (não encosta nas bordas, diferente da versão antiga).
    d.ellipse([5, 3, 27, 24], fill=CANOPY_MID, outline=OUTLINE, width=1)
    d.ellipse([6, 2, 22, 16], fill=CANOPY_LIGHT)
    d.ellipse([8, 4, 16, 11], fill=CANOPY_HILITE)
    d.ellipse([9, 15, 26, 25], fill=CANOPY_DARK)
    d.ellipse([9, 15, 20, 23], fill=CANOPY_MID)

    # Textura leve (pontinhos) pra não ficar um degradê liso demais,
    # mesmo espírito do tile antigo.
    import random
    rng = random.Random(42)
    for _ in range(24):
        x = rng.randint(6, 26)
        y = rng.randint(3, 23)
        px = im.getpixel((x, y))
        if px in (CANOPY_MID, CANOPY_DARK):
            im.putpixel((x, y), CANOPY_LIGHT)

    return im


def main() -> None:
    sheet = Image.open(TILESET).convert("RGB")
    grass = sheet.crop((0, 0, TILE, TILE))  # col0/row0 = Grama
    new_tree = build_tree_tile(grass)

    tx, ty = 2 * TILE, 1 * TILE  # col2/row1 = Árvore
    sheet.paste(new_tree, (tx, ty))
    sheet.save(TILESET)
    print("Tile de árvore redesenhado e salvo em", TILESET)


if __name__ == "__main__":
    main()
