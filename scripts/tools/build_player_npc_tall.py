#!/usr/bin/env python3
"""Redesenha Treinador/NPC num quadro de 128×256 (2 tiles de altura por 1
de largura) — pedido do Gabriel (03/09): "O personagem e npcs podem ter 2
tiles de altura por 1 de largura... para que eles sejam proporcionalmente
[corretos]". A arte de 128×128 (quadrada, upscale da anterior) fazia o
personagem parecer "achatado" — corpo humano de verdade precisa de mais
altura que largura.

Mesma paleta de cor da arte anterior (boné vermelho, pele clara, macacão
azul, calça roxa) — só a PROPORÇÃO do corpo muda (cabeça+tronco+pernas
ocupando o quadro mais alto), não o estilo (ainda blocos de cor lisa,
sem textura nova).

Formato de saída: 384×1024 (3 colunas × 128px, 4 linhas × 256px) — mesmo
layout de sempre (idle/walk_a/walk_b × down/up/left/right), só a ALTURA
de cada quadro que dobra.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"

TILE_W = 128
TILE_H = 256
SHEET_W = TILE_W * 3
SHEET_H = TILE_H * 4

# Paleta (extraída da arte anterior, mesma identidade visual)
CAP = (196, 62, 50)
CAP_DARK = (156, 44, 36)
SKIN = (250, 222, 180)
EYE = (30, 24, 20)
OVERALLS = (66, 116, 206)
OVERALLS_DARK = (48, 88, 168)
PANTS = (96, 64, 180)
PANTS_DARK = (72, 46, 140)
SHOE = (60, 42, 30)
HAIR = (90, 56, 30)


def new_frame():
    return Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))


def draw_body(d: ImageDraw.ImageDraw, cx: int, leg_offset: int = 0):
    """Corpo comum a idle/walk — cabeça, tronco, pernas. `leg_offset`
    desloca uma perna pra frente/trás (passo de caminhada)."""
    # Pernas (desenhadas primeiro, ficam atrás do tronco)
    leg_w = 20
    leg_top = 150
    leg_bot = 214
    d.rectangle([cx - 26, leg_top + leg_offset, cx - 26 + leg_w, leg_bot + leg_offset], fill=PANTS)
    d.rectangle([cx - 26, leg_bot - 14 + leg_offset, cx - 26 + leg_w, leg_bot + leg_offset], fill=PANTS_DARK)
    d.rectangle([cx + 6, leg_top - leg_offset, cx + 6 + leg_w, leg_bot - leg_offset], fill=PANTS)
    d.rectangle([cx + 6, leg_bot - 14 - leg_offset, cx + 6 + leg_w, leg_bot - leg_offset], fill=PANTS_DARK)
    # Sapatos
    d.ellipse([cx - 28, leg_bot + leg_offset - 6, cx - 4, leg_bot + leg_offset + 10], fill=SHOE)
    d.ellipse([cx + 4, leg_bot - leg_offset - 6, cx + 28, leg_bot - leg_offset + 10], fill=SHOE)

    # Tronco (macacão)
    d.rectangle([cx - 34, 96, cx + 34, 158], fill=OVERALLS, outline=OVERALLS_DARK, width=3)
    d.rectangle([cx - 34, 140, cx + 34, 158], fill=OVERALLS_DARK)
    # Alças do macacão
    d.rectangle([cx - 24, 78, cx - 10, 104], fill=OVERALLS)
    d.rectangle([cx + 10, 78, cx + 24, 104], fill=OVERALLS)
    # Braços (mangas de pele saindo do tronco)
    d.rectangle([cx - 44, 100, cx - 32, 138], fill=SKIN, outline=(210, 180, 140), width=2)
    d.rectangle([cx + 32, 100, cx + 44, 138], fill=SKIN, outline=(210, 180, 140), width=2)

    # Pescoço + cabeça
    d.rectangle([cx - 10, 66, cx + 10, 82], fill=SKIN)
    d.ellipse([cx - 32, 8, cx + 32, 76], fill=SKIN)
    # Boné
    d.pieslice([cx - 34, -4, cx + 34, 56], 180, 360, fill=CAP)
    d.rectangle([cx - 34, 26, cx + 34, 36], fill=CAP)
    d.ellipse([cx + 18, 22, cx + 42, 38], fill=CAP)  # aba do boné
    d.rectangle([cx - 34, 30, cx + 34, 36], fill=CAP_DARK)


def front_frame(leg_offset: int) -> Image.Image:
    im = new_frame()
    d = ImageDraw.Draw(im)
    cx = TILE_W // 2
    draw_body(d, cx, leg_offset)
    # Rosto (olhos)
    d.ellipse([cx - 14, 44, cx - 6, 52], fill=EYE)
    d.ellipse([cx + 6, 44, cx + 14, 52], fill=EYE)
    return im


def back_frame(leg_offset: int) -> Image.Image:
    im = new_frame()
    d = ImageDraw.Draw(im)
    cx = TILE_W // 2
    draw_body(d, cx, leg_offset)
    # Nuca (cabelo curto aparecendo só na base do boné, sem rosto nenhum)
    d.rectangle([cx - 22, 44, cx + 22, 54], fill=HAIR)
    return im


def side_frame(leg_offset: int, facing_right: bool) -> Image.Image:
    im = new_frame()
    d = ImageDraw.Draw(im)
    cx = TILE_W // 2
    sign = 1 if facing_right else -1
    # Pernas (perfil: uma na frente, uma atrás)
    d.rectangle([cx - 10, 150 - leg_offset, cx + 10, 214 - leg_offset], fill=PANTS_DARK)
    d.rectangle([cx - 10 + sign * 6, 150 + leg_offset, cx + 10 + sign * 6, 214 + leg_offset], fill=PANTS)
    d.ellipse([cx - 12 + sign * 6, 208 + leg_offset, cx + 14 + sign * 6, 222 + leg_offset], fill=SHOE)
    # Tronco
    d.rectangle([cx - 24, 96, cx + 24, 158], fill=OVERALLS, outline=OVERALLS_DARK, width=3)
    d.rectangle([cx - 24, 140, cx + 24, 158], fill=OVERALLS_DARK)
    d.rectangle([cx - 8 + sign * 2, 78, cx + 8 + sign * 2, 104], fill=OVERALLS)
    # Braço
    d.rectangle([cx - 10 + sign * 20, 100, cx + 10 + sign * 20, 136], fill=SKIN, outline=(210, 180, 140), width=2)
    # Pescoço + cabeça de perfil
    d.rectangle([cx - 8, 66, cx + 8, 82], fill=SKIN)
    d.ellipse([cx - 24 + sign * 4, 8, cx + 24 + sign * 4, 76], fill=SKIN)
    d.ellipse([cx - 4 + sign * 26, 40, cx + 4 + sign * 26, 48], fill=SKIN)  # nariz
    d.ellipse([cx - 4 + sign * 12, 44, cx + 4 + sign * 12, 52], fill=EYE)
    # Boné de perfil
    d.pieslice([cx - 26 + sign * 4, -4, cx + 26 + sign * 4, 56], 180, 360, fill=CAP)
    d.rectangle([cx - 26 + sign * 4, 26, cx + 26 + sign * 4, 36], fill=CAP_DARK)
    d.ellipse([cx + sign * 22, 20, cx + 20 + sign * 22, 40], fill=CAP)
    return im


def build_sheet(recolor=None) -> Image.Image:
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    rows = [
        [front_frame(0), front_frame(-6), front_frame(6)],
        [back_frame(0), back_frame(-6), back_frame(6)],
        [side_frame(0, False), side_frame(-6, False), side_frame(6, False)],
        [side_frame(0, True), side_frame(-6, True), side_frame(6, True)],
    ]
    for row_idx, frames in enumerate(rows):
        for col_idx, frame in enumerate(frames):
            if recolor:
                frame = recolor(frame)
            sheet.paste(frame, (col_idx * TILE_W, row_idx * TILE_H), frame)
    return sheet


def recolor_swap(mapping):
    def _apply(im: Image.Image) -> Image.Image:
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if p[3] == 0:
                    continue
                for old, new in mapping.items():
                    if p[:3] == old:
                        px[x, y] = (new[0], new[1], new[2], p[3])
                        break
        return im
    return _apply


def main() -> None:
    player_sheet = build_sheet()
    player_sheet.save(SPRITES / "player" / "player.png")
    print("player.png ->", player_sheet.size)

    # NPCs: mesma silhueta, cores diferentes pra distinguir (mesma ideia da
    # arte anterior — Oak tinha jaleco, enfermeira tinha uniforme rosa).
    default_recolor = recolor_swap({CAP: (90, 90, 96), CAP_DARK: (66, 66, 72),
                                     OVERALLS: (120, 118, 110), OVERALLS_DARK: (92, 90, 84)})
    nurse_recolor = recolor_swap({CAP: (240, 130, 170), CAP_DARK: (206, 96, 138),
                                   OVERALLS: (250, 250, 250), OVERALLS_DARK: (220, 220, 224),
                                   PANTS: (250, 250, 250), PANTS_DARK: (220, 220, 224)})
    oak_recolor = recolor_swap({CAP: (250, 250, 250), CAP_DARK: (220, 220, 224),
                                 OVERALLS: (250, 250, 250), OVERALLS_DARK: (220, 220, 224)})

    build_sheet(default_recolor).save(SPRITES / "npc" / "npc_default.png")
    build_sheet(nurse_recolor).save(SPRITES / "npc" / "npc_nurse.png")
    build_sheet(oak_recolor).save(SPRITES / "npc" / "npc_oak.png")
    print("npc_default.png, npc_nurse.png, npc_oak.png salvos")


if __name__ == "__main__":
    main()
