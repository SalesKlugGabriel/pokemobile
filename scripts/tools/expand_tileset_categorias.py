#!/usr/bin/env python3
"""Completa as 4 categorias restantes de docs/tileset-referencia-visual.md
(a 1ª, Terreno base, já foi feita em expand_tileset_terreno.py). Mesma
técnica: desenhado por código, paleta derivada dos tiles existentes.

Adiciona 4 linhas novas ao atlas overworld.png:
  linha 3 — Água/gelo/rocha:      água c/ lírios, gelo, gelo trincado,
                                    parede de rocha, entrada de caverna,
                                    água c/ praia
  linha 4 — Terrenos especiais:    solo envenenado, lama, lama funda,
                                    poça d'água, rocha vulcânica, trilhos,
                                    piso de pedra
  linha 5 — Interior/decoração:    piso de pedra clara, pedra c/ musgo,
                                    cogumelos, folhas caídas, junco
  linha 6 — Estrutura:             janela, canto de casa, caixa
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TILESET = ROOT / "assets" / "tilesets" / "overworld.png"
TILE = 32


def crop(sheet, col, row):
    return sheet.crop((col * TILE, row * TILE, col * TILE + TILE, row * TILE + TILE))


# ── linha 3: Água/gelo/rocha ────────────────────────────────────────────────
def agua_lirios(water_bg):
    im = water_bg.copy()
    d = ImageDraw.Draw(im)
    for x, y in [(8, 10), (20, 8), (14, 20), (24, 22)]:
        d.ellipse([x - 5, y - 3, x + 5, y + 3], fill=(46, 110, 40), outline=(24, 70, 24))
        d.ellipse([x - 1, y - 4, x + 1, y - 2], fill=(230, 240, 250))
    return im


def gelo(bg):
    im = Image.new("RGB", (TILE, TILE), (176, 223, 236))
    d = ImageDraw.Draw(im)
    d.line([(2, 28), (14, 12)], fill=(210, 240, 248), width=1)
    d.line([(18, 30), (28, 6)], fill=(210, 240, 248), width=1)
    d.line([(0, 10), (10, 4)], fill=(140, 195, 214), width=1)
    d.rectangle([0, 0, 31, 31], outline=(140, 195, 214))
    return im


def gelo_trincado(bg):
    im = gelo(bg)
    d = ImageDraw.Draw(im)
    d.line([(4, 4), (16, 16), (12, 28)], fill=(90, 150, 172), width=1)
    d.line([(16, 16), (28, 10)], fill=(90, 150, 172), width=1)
    d.line([(16, 16), (26, 26)], fill=(90, 150, 172), width=1)
    return im


def parede_rocha(bg):
    im = Image.new("RGB", (TILE, TILE), (94, 92, 96))
    d = ImageDraw.Draw(im)
    rng = random.Random(3)
    for _ in range(10):
        x, y = rng.randint(2, 26), rng.randint(2, 26)
        w, h = rng.randint(6, 11), rng.randint(4, 8)
        shade = rng.choice([(74, 72, 76), (112, 110, 114), (60, 58, 62)])
        d.rectangle([x, y, x + w, y + h], fill=shade, outline=(40, 38, 42))
    return im


def entrada_caverna(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, 8, 31], fill=(94, 92, 96), outline=(40, 38, 42))
    d.rectangle([23, 0, 29, 31], fill=(94, 92, 96), outline=(40, 38, 42))
    d.ellipse([2, -14, 29, 14], fill=(94, 92, 96), outline=(40, 38, 42))
    d.ellipse([9, 6, 22, 31], fill=(18, 16, 20))
    return im


def agua_praia(sand_bg, water_swatch):
    im = sand_bg.copy()
    d = ImageDraw.Draw(im)
    d.polygon([(0, 22), (10, 16), (22, 22), (32, 18), (32, 32), (0, 32)],
              fill=(60, 130, 200))
    d.line([(0, 22), (10, 16), (22, 22), (32, 18)], fill=(150, 210, 235), width=1)
    return im


# ── linha 4: Terrenos especiais ────────────────────────────────────────────
def solo_envenenado(bg):
    im = Image.new("RGB", (TILE, TILE), (94, 60, 110))
    d = ImageDraw.Draw(im)
    rng = random.Random(5)
    for _ in range(14):
        x, y = rng.randint(0, 30), rng.randint(0, 30)
        d.point((x, y), fill=(150, 90, 170))
    d.ellipse([12, 12, 20, 20], outline=(180, 120, 200), width=1)
    return im


def lama(bg):
    im = Image.new("RGB", (TILE, TILE), (92, 68, 42))
    d = ImageDraw.Draw(im)
    rng = random.Random(6)
    for _ in range(8):
        x, y = rng.randint(2, 26), rng.randint(2, 26)
        d.ellipse([x, y, x + 5, y + 3], fill=(72, 52, 30))
    return im


def lama_funda(bg):
    im = Image.new("RGB", (TILE, TILE), (58, 42, 26))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 27, 27], fill=(40, 28, 16))
    d.ellipse([9, 20, 15, 24], fill=(70, 52, 32))
    return im


def poca_dagua(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    d.ellipse([6, 10, 25, 24], fill=(72, 140, 205), outline=(40, 90, 150))
    d.ellipse([10, 12, 16, 16], fill=(140, 195, 230))
    return im


def rocha_vulcanica(bg):
    im = Image.new("RGB", (TILE, TILE), (54, 46, 46))
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    for _ in range(9):
        x, y = rng.randint(2, 26), rng.randint(2, 26)
        w = rng.randint(5, 9)
        d.rectangle([x, y, x + w, y + w], fill=(38, 32, 32), outline=(20, 16, 16))
    d.line([(6, 26), (14, 16), (10, 6)], fill=(214, 92, 32), width=1)
    d.line([(20, 28), (24, 18)], fill=(214, 92, 32), width=1)
    return im


def trilhos(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([6, 0, 11, 31], fill=(120, 90, 60))
    d.rectangle([21, 0, 26, 31], fill=(120, 90, 60))
    for y in range(2, 31, 6):
        d.rectangle([0, y, 31, y + 2], fill=(80, 60, 40))
    return im


def piso_pedra(bg):
    im = Image.new("RGB", (TILE, TILE), (150, 148, 140))
    d = ImageDraw.Draw(im)
    for x in range(0, TILE, 16):
        for y in range(0, TILE, 8):
            off = 8 if (y // 8) % 2 else 0
            d.rectangle([(x + off) % 32, y, (x + off) % 32 + 14, y + 7],
                        outline=(110, 108, 100))
    return im


# ── linha 5: Interior/decoração ────────────────────────────────────────────
def piso_pedra_clara(bg):
    im = Image.new("RGB", (TILE, TILE), (198, 196, 186))
    d = ImageDraw.Draw(im)
    for x in range(0, TILE, 16):
        for y in range(0, TILE, 8):
            off = 8 if (y // 8) % 2 else 0
            d.rectangle([(x + off) % 32, y, (x + off) % 32 + 14, y + 7],
                        outline=(160, 158, 148))
    return im


def pedra_musgo(bg):
    im = piso_pedra(bg)
    d = ImageDraw.Draw(im)
    rng = random.Random(11)
    for _ in range(10):
        x, y = rng.randint(0, 28), rng.randint(0, 28)
        d.ellipse([x, y, x + 4, y + 3], fill=(70, 120, 50))
    return im


def cogumelos(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    for x, y, col in [(10, 20, (196, 60, 60)), (20, 14, (220, 220, 210))]:
        d.ellipse([x - 3, y + 2, x + 3, y + 7], fill=(230, 220, 200))
        d.ellipse([x - 5, y - 3, x + 5, y + 3], fill=col, outline=(40, 20, 20))
        if col == (196, 60, 60):
            d.point((x - 2, y - 1), fill=(255, 255, 255))
            d.point((x + 2, y), fill=(255, 255, 255))
    return im


def folhas_caidas(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    rng = random.Random(13)
    cores = [(196, 110, 40), (214, 160, 40), (160, 70, 30)]
    for _ in range(9):
        x, y = rng.randint(2, 28), rng.randint(2, 28)
        d.ellipse([x, y, x + 4, y + 3], fill=rng.choice(cores))
    return im


def junco(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    rng = random.Random(15)
    for _ in range(6):
        x = rng.randint(4, 27)
        y0 = rng.randint(18, 26)
        h = rng.randint(8, 14)
        d.line([(x, y0), (x - 1, y0 - h)], fill=(96, 140, 56), width=1)
        d.line([(x, y0), (x + 1, y0 - h + 2)], fill=(70, 110, 40), width=1)
    return im


# ── linha 6: Estrutura ─────────────────────────────────────────────────────
def janela(wall_bg):
    im = wall_bg.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([7, 9, 24, 22], fill=(150, 190, 214), outline=(60, 40, 20), width=2)
    d.line([(15, 9), (15, 22)], fill=(60, 40, 20), width=1)
    d.line([(7, 15), (24, 15)], fill=(60, 40, 20), width=1)
    d.line([(9, 12), (13, 12)], fill=(220, 240, 250), width=1)
    return im


def canto_casa(wall_bg):
    im = wall_bg.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 31], fill=(150, 108, 70))
    d.polygon([(0, 31), (0, 12), (16, 0), (31, 0), (31, 31)], fill=(178, 132, 88))
    d.line([(0, 12), (16, 0)], fill=(90, 60, 30), width=2)
    return im


def caixa(bg):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([5, 6, 27, 27], fill=(172, 128, 76), outline=(96, 64, 30), width=2)
    d.line([(5, 6), (27, 27)], fill=(96, 64, 30), width=1)
    d.line([(27, 6), (5, 27)], fill=(96, 64, 30), width=1)
    d.rectangle([13, 14, 19, 20], outline=(96, 64, 30))
    return im


def main() -> None:
    sheet = Image.open(TILESET).convert("RGB")
    w, h = sheet.size
    grass = crop(sheet, 0, 0)
    water = crop(sheet, 1, 1)
    sand = crop(sheet, 3, 0)
    wall = crop(sheet, 0, 1)

    expanded = Image.new("RGB", (w, h + TILE * 4), (0, 0, 0))
    expanded.paste(sheet, (0, 0))

    row3 = [agua_lirios(water), gelo(grass), gelo_trincado(grass),
            parede_rocha(grass), entrada_caverna(grass), agua_praia(sand, water)]
    row4 = [solo_envenenado(grass), lama(grass), lama_funda(grass),
            poca_dagua(grass), rocha_vulcanica(grass), trilhos(grass), piso_pedra(grass)]
    row5 = [piso_pedra_clara(grass), pedra_musgo(grass), cogumelos(grass),
            folhas_caidas(grass), junco(grass)]
    row6 = [janela(wall), canto_casa(wall), caixa(grass)]

    for row_idx, tiles in zip([3, 4, 5, 6], [row3, row4, row5, row6]):
        y = row_idx * TILE
        for col, tile_im in enumerate(tiles):
            expanded.paste(tile_im, (col * TILE, y))

    expanded.save(TILESET)
    print(f"Tileset expandido: {w}x{h} -> {expanded.width}x{expanded.height} (linhas 3-6 adicionadas)")
    print(f"Linha 3 ({len(row3)} tiles), Linha 4 ({len(row4)} tiles), "
          f"Linha 5 ({len(row5)} tiles), Linha 6 ({len(row6)} tiles)")


if __name__ == "__main__":
    main()
