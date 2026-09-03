#!/usr/bin/env python3
"""Expande a categoria "Terreno base" do tileset — pedido do Gabriel de
diversidade de tiles (docs/tileset-referencia-visual.md), retomado depois
do ajuste de zoom/árvore de 02/09. Completa a categoria que a árvore
redesenhada já começou: Grama Alta, Árvore Pinho, Árvore Outono, Toco.

Desenhado por código (não por IA), mesmo raciocínio do redesenho da
árvore: paleta extraída dos tiles existentes garante consistência de
estilo sem depender de geração/cota.

Adiciona uma 3ª linha ao atlas `overworld.png` (extend de 256×64 pra
256×96) — as 2 linhas antigas (walkable/bloqueado) continuam intocadas.
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TILESET = ROOT / "assets" / "tilesets" / "overworld.png"
TILE = 32

# Paleta reaproveitada do tile de árvore (garante o mesmo "verde do jogo").
TRUNK_DARK = (74, 46, 24)
TRUNK_LIGHT = (110, 72, 40)
OUTLINE = (24, 58, 16)

PINE_DARK = (22, 66, 30)
PINE_MID = (33, 87, 40)
PINE_LIGHT = (48, 105, 50)

AUTUMN_RED = (168, 64, 32)
AUTUMN_ORANGE = (214, 122, 36)
AUTUMN_YELLOW = (226, 176, 60)
AUTUMN_OUTLINE = (90, 40, 20)

GRASS_BLADE_DARK = (33, 87, 22)
GRASS_BLADE_LIGHT = (86, 148, 44)

STUMP_TOP = (168, 122, 74)
STUMP_RING = (138, 96, 56)
STUMP_SIDE = (98, 66, 36)
STUMP_SIDE_DARK = (78, 50, 26)


def tall_grass_tile(bg: Image.Image) -> Image.Image:
    im = bg.copy().convert("RGB")
    d = ImageDraw.Draw(im)
    rng = random.Random(7)
    # Tufos de grama alta espalhados, mais densos que a grama comum —
    # lê como "mato alto onde Pokémon selvagem se esconde".
    for _ in range(9):
        x = rng.randint(3, 27)
        y = rng.randint(6, 27)
        h = rng.randint(5, 9)
        d.line([(x, y + h), (x - 2, y)], fill=GRASS_BLADE_DARK, width=2)
        d.line([(x + 2, y + h), (x + 1, y - 1)], fill=GRASS_BLADE_DARK, width=2)
        d.line([(x, y + h), (x, y)], fill=GRASS_BLADE_LIGHT, width=1)
    return im


def pine_tree_tile(bg: Image.Image) -> Image.Image:
    im = bg.copy().convert("RGB")
    d = ImageDraw.Draw(im)
    # Tronco fino e alto.
    d.rectangle([14, 24, 17, 30], fill=TRUNK_DARK)
    d.rectangle([15, 24, 15, 30], fill=TRUNK_LIGHT)
    # Copa cônica em 3 camadas (silhueta de pinheiro, bem diferente do
    # oval largo da árvore comum).
    d.polygon([(16, 2), (5, 13), (27, 13)], fill=PINE_DARK, outline=OUTLINE)
    d.polygon([(16, 8), (7, 18), (25, 18)], fill=PINE_MID, outline=OUTLINE)
    d.polygon([(16, 14), (4, 25), (28, 25)], fill=PINE_LIGHT, outline=OUTLINE)
    # Reflexo de luz de um lado só, pra não ficar chapado.
    d.line([(16, 4), (10, 12)], fill=(70, 130, 65), width=1)
    d.line([(16, 10), (11, 17)], fill=(70, 130, 65), width=1)
    return im


def autumn_tree_tile(bg: Image.Image) -> Image.Image:
    im = bg.copy().convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([13, 22, 18, 30], fill=TRUNK_DARK)
    d.rectangle([14, 22, 15, 30], fill=TRUNK_LIGHT)
    # Mesma composição oval da árvore comum, paleta quente de outono.
    d.ellipse([5, 3, 27, 24], fill=AUTUMN_RED, outline=AUTUMN_OUTLINE, width=1)
    d.ellipse([6, 2, 22, 16], fill=AUTUMN_ORANGE)
    d.ellipse([8, 4, 16, 11], fill=AUTUMN_YELLOW)
    d.ellipse([9, 15, 26, 25], fill=(132, 46, 26))
    d.ellipse([9, 15, 20, 23], fill=AUTUMN_RED)
    return im


def stump_tile(bg: Image.Image) -> Image.Image:
    im = bg.copy().convert("RGB")
    d = ImageDraw.Draw(im)
    # Toco baixo e largo — sem copa, só o corte de tronco visto de cima.
    d.rectangle([9, 18, 23, 29], fill=STUMP_SIDE)
    d.rectangle([9, 24, 23, 29], fill=STUMP_SIDE_DARK)
    d.ellipse([8, 12, 24, 22], fill=STUMP_TOP, outline=(60, 40, 20), width=1)
    d.ellipse([11, 15, 21, 19], outline=STUMP_RING, width=1)
    d.ellipse([13, 16, 19, 18], outline=STUMP_RING, width=1)
    return im


def main() -> None:
    sheet = Image.open(TILESET).convert("RGB")
    w, h = sheet.size
    grass_bg = sheet.crop((0, 0, TILE, TILE))

    new_row_y = h  # linha nova, logo abaixo da última existente
    expanded = Image.new("RGB", (w, h + TILE), (0, 0, 0))
    expanded.paste(sheet, (0, 0))

    tiles = [tall_grass_tile(grass_bg), pine_tree_tile(grass_bg),
             autumn_tree_tile(grass_bg), stump_tile(grass_bg)]
    for col, tile_im in enumerate(tiles):
        expanded.paste(tile_im, (col * TILE, new_row_y))

    expanded.save(TILESET)
    print(f"Tileset expandido: {w}x{h} -> {expanded.width}x{expanded.height} (linha 2 adicionada)")


if __name__ == "__main__":
    main()
