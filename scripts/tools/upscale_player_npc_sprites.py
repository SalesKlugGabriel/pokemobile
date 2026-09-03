#!/usr/bin/env python3
"""Reamostra as sprites do Treinador/NPC/Bicicleta pro tile128 (03/09).

Estas continuam sendo a arte SIMPLES original (blocos de cor lisa) — o
Gabriel não mandou referência pra personagem ainda, só pro mapa. Upscale
por LANCZOS deixa os contornos mais suaves (menos serrilhado) que um
"esticar" chapado, mas não adiciona detalhe de verdade — é só pra não
ficar do tamanho errado (pequeno demais) do lado do tileset novo. Fica
registrado como próximo passo se o Gabriel quiser arte de personagem no
mesmo nível da referência do mapa — pede uma referência própria de
personagem (igual ele mandou pro mapa) antes de eu tentar de novo.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"

JOBS = [
    (SPRITES / "player" / "player.png", 128),        # 48x64 (tile16) -> 384x512 (tile128)
    (SPRITES / "npc" / "npc_default.png", 128),
    (SPRITES / "npc" / "npc_nurse.png", 128),
    (SPRITES / "npc" / "npc_oak.png", 128),
    (SPRITES / "player" / "player_bike.png", 256),   # 96x128 (tile32) -> 768x1024 (tile256)
]


def main() -> None:
    for path, new_tile in JOBS:
        im = Image.open(path).convert("RGBA")
        old_tile_w = im.width // 3
        scale = new_tile / old_tile_w
        new_size = (round(im.width * scale), round(im.height * scale))
        up = im.resize(new_size, Image.LANCZOS)
        up.save(path)
        print(f"{path.name}: {im.size} -> {up.size} (tile {old_tile_w} -> {new_tile})")


if __name__ == "__main__":
    main()
