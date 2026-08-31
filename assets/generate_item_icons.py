#!/usr/bin/env python3
"""
Gerador de ícones por categoria de item (Loja/Mochila) — mesmo estilo simples
e geométrico já usado em generate_assets.py (placeholder, não pixel art fina).
Executar: python3 assets/generate_item_icons.py
"""
from PIL import Image, ImageDraw
import os

SIZE = 32
OUT = os.path.join(os.path.dirname(__file__), "ui", "icons")
os.makedirs(OUT, exist_ok=True)


def _new():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def icon_medicine():
    im = _new()
    d = ImageDraw.Draw(im)
    d.rectangle([11, 6, 20, 10], fill=(200, 60, 90, 255))
    d.rectangle([10, 10, 21, 27], fill=(240, 245, 250, 255), outline=(60, 60, 70, 255))
    d.rectangle([13, 17, 18, 19], fill=(200, 60, 90, 255))
    d.rectangle([15, 15, 16, 21], fill=(200, 60, 90, 255))
    return im


def icon_ball():
    im = _new()
    d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 27, 27], fill=(230, 60, 60, 255), outline=(20, 20, 20, 255), width=2)
    d.pieslice([4, 4, 27, 27], 180, 360, fill=(245, 245, 245, 255), outline=(20, 20, 20, 255))
    d.rectangle([4, 14, 27, 17], fill=(20, 20, 20, 255))
    d.ellipse([12, 12, 19, 19], fill=(245, 245, 245, 255), outline=(20, 20, 20, 255), width=2)
    return im


def icon_stone():
    im = _new()
    d = ImageDraw.Draw(im)
    d.polygon([(16, 4), (26, 12), (22, 27), (10, 27), (6, 12)],
               fill=(120, 190, 235, 255), outline=(30, 30, 40, 255))
    d.polygon([(16, 4), (20, 12), (12, 12)], fill=(180, 225, 250, 255))
    return im


def icon_tm():
    im = _new()
    d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 27, 27], fill=(150, 90, 210, 255), outline=(30, 30, 40, 255), width=2)
    d.ellipse([12, 12, 19, 19], fill=(240, 235, 250, 255))
    return im


def icon_battle():
    im = _new()
    d = ImageDraw.Draw(im)
    d.rectangle([14, 5, 17, 21], fill=(230, 160, 40, 255), outline=(30, 30, 40, 255))
    d.polygon([(10, 21), (21, 21), (16, 28)], fill=(230, 160, 40, 255), outline=(30, 30, 40, 255))
    return im


def icon_vitamin():
    im = _new()
    d = ImageDraw.Draw(im)
    d.rectangle([9, 9, 22, 22], fill=(90, 200, 140, 255), outline=(30, 30, 40, 255), width=2)
    d.line([9, 15, 22, 15], fill=(30, 30, 40, 255), width=2)
    return im


def icon_key():
    im = _new()
    d = ImageDraw.Draw(im)
    d.ellipse([6, 6, 16, 16], outline=(230, 200, 90, 255), width=3)
    d.line([14, 14, 26, 26], fill=(230, 200, 90, 255), width=3)
    d.line([21, 21, 25, 17], fill=(230, 200, 90, 255), width=3)
    return im


def icon_field():
    im = _new()
    d = ImageDraw.Draw(im)
    d.polygon([(16, 5), (27, 16), (16, 27), (5, 16)], fill=(70, 140, 200, 255), outline=(30, 30, 40, 255))
    return im


ICONS = {
    "medicine": icon_medicine,
    "ball": icon_ball,
    "stone": icon_stone,
    "tm_hm": icon_tm,
    "battle": icon_battle,
    "vitamin": icon_vitamin,
    "key": icon_key,
    "field": icon_field,
}

if __name__ == "__main__":
    for name, fn in ICONS.items():
        im = fn()
        path = os.path.join(OUT, f"{name}.png")
        im.save(path)
        print("wrote", path)
