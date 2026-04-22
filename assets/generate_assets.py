#!/usr/bin/env python3
"""
Gerador de assets placeholder para PokéMobile.
Gera PNGs de tileset, sprites de personagens e Pokémon.
Executar: python3 assets/generate_assets.py
"""

from PIL import Image, ImageDraw
import os

TILE = 16  # tamanho base do tile em pixels

# ──────────────────────────────────────────────────────────────────────────────
# Paleta de cores
# ──────────────────────────────────────────────────────────────────────────────
C = {
    # walkable tiles
    "grass":        (88,  154, 50),
    "grass_dark":   (72,  130, 40),
    "path":         (200, 160, 100),
    "path_dark":    (170, 130, 80),
    "flower_bg":    (88,  154, 50),
    "flower":       (255, 160, 200),
    "sand":         (224, 196, 120),
    "light_grass":  (120, 190, 72),
    "dark_path":    (160, 120, 72),
    "floor_indoor": (208, 184, 120),
    "mat":          (160, 100, 60),
    # blocked tiles
    "wall":         (136, 136, 136),
    "wall_shadow":  (104, 104, 104),
    "water":        (68,  128, 200),
    "water_shine":  (100, 168, 240),
    "tree":         (42,  110, 16),
    "tree_dark":    (30,   80, 10),
    "rock":         (112, 112, 112),
    "rock_dark":    (80,   80, 80),
    "fence":        (144,  80, 48),
    "fence_dark":   (100,  56, 32),
    "door":         (120,  64, 32),
    "door_light":   (160,  96, 56),
    "roof":         (192,  64, 64),
    "roof_dark":    (150,  40, 40),
    "hedge":        (26,   78, 12),
    "hedge_dark":   (18,   56,  8),
    # entity colors
    "skin":         (255, 220, 180),
    "skin_dark":    (230, 195, 155),
    "player_shirt": (60,  100, 200),
    "player_pants": (80,   60, 180),
    "player_hair":  (60,   40,  20),
    "player_hat":   (200,  80,  60),
    "npc_shirt":    (60,  160,  80),
    "npc_pants":    (80,   80,  80),
    "npc_hair":     (80,   40,  20),
    "white":        (255, 255, 255),
    "black":        (0,     0,   0),
    "transparent":  (0,     0,   0, 0),
}

def px(draw, x, y, color):
    """Pinta pixel único (2x2 para pixel art look)."""
    draw.point((x, y), fill=color)

def rect(draw, x1, y1, x2, y2, color):
    draw.rectangle([x1, y1, x2, y2], fill=color)

# ──────────────────────────────────────────────────────────────────────────────
# Tileset — 8×2 tiles de 16×16 = 128×32 pixels
# ──────────────────────────────────────────────────────────────────────────────

def draw_grass(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["grass"])
    # pequenas variações
    for pos in [(1,3),(5,1),(9,5),(13,2),(3,9),(7,12),(11,8),(2,13),(14,11),(6,7)]:
        draw.point((ox+pos[0], oy+pos[1]), C["grass_dark"])

def draw_path(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["path"])
    for pos in [(2,4),(7,2),(12,6),(4,10),(10,13),(1,8),(14,3),(8,14)]:
        draw.point((ox+pos[0], oy+pos[1]), C["path_dark"])

def draw_flower(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["flower_bg"])
    # florzinhas
    for pos in [(3,4),(10,3),(6,11),(13,8),(1,12)]:
        draw.point((ox+pos[0], oy+pos[1]), C["flower"])
        draw.point((ox+pos[0]+1, oy+pos[1]), C["flower"])
        draw.point((ox+pos[0], oy+pos[1]+1), C["flower"])

def draw_sand(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["sand"])
    for pos in [(3,2),(8,5),(12,9),(5,13),(1,7),(14,4),(10,12)]:
        draw.point((ox+pos[0], oy+pos[1]), C["path_dark"])

def draw_light_grass(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["light_grass"])
    for pos in [(2,5),(6,2),(11,7),(4,12),(13,4),(8,13)]:
        draw.point((ox+pos[0], oy+pos[1]), C["grass"])

def draw_dark_path(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["dark_path"])
    for pos in [(4,3),(9,7),(2,11),(13,5),(7,14)]:
        draw.point((ox+pos[0], oy+pos[1]), C["path"])

def draw_floor_indoor(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["floor_indoor"])
    # padrão de tábua
    for y in range(oy, oy+16, 4):
        draw.line([(ox, y), (ox+15, y)], fill=C["path_dark"], width=1)

def draw_mat(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["mat"])
    rect(draw, ox+2, oy+2, ox+13, oy+13, C["fence"])

# Tiles bloqueados
def draw_wall(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["wall"])
    # bordas mais escuras
    rect(draw, ox, oy, ox+15, oy, C["wall_shadow"])
    rect(draw, ox, oy, ox, oy+15, C["wall_shadow"])
    # janela
    rect(draw, ox+4, oy+3, ox+11, oy+9, C["water_shine"])
    rect(draw, ox+7, oy+3, ox+7, oy+9, C["wall_shadow"])

def draw_water(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["water"])
    # ondas
    for x in range(ox, ox+16, 4):
        draw.point((x, oy+4), C["water_shine"])
        draw.point((x+1, oy+4), C["water_shine"])
        draw.point((x+2, oy+10), C["water_shine"])
        draw.point((x+3, oy+10), C["water_shine"])

def draw_tree(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["tree"])
    # tronco na base
    rect(draw, ox+5, oy+10, ox+10, oy+15, C["fence_dark"])
    # copa redonda
    for dy in range(8):
        for dx in range(16):
            cx, cy = dx - 7, dy - 4
            if cx*cx + cy*cy < 30:
                draw.point((ox+dx, oy+dy+1), C["tree"] if (dx+dy) % 3 != 0 else C["tree_dark"])

def draw_rock(draw, ox, oy):
    rect(draw, ox+1, oy+3, ox+14, oy+14, C["rock"])
    rect(draw, ox+3, oy+1, ox+12, oy+14, C["rock"])
    rect(draw, ox+2, oy+1, ox+13, oy+12, C["rock_dark"])
    # brilho
    draw.point((ox+5, oy+3), C["wall"])
    draw.point((ox+6, oy+3), C["wall"])

def draw_fence(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["grass"])
    # postes
    rect(draw, ox, oy+2, ox+2, oy+13, C["fence"])
    rect(draw, ox+13, oy+2, ox+15, oy+13, C["fence"])
    # barras horizontais
    rect(draw, ox, oy+4, ox+15, oy+6, C["fence"])
    rect(draw, ox, oy+10, ox+15, oy+12, C["fence"])

def draw_door(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["wall"])
    rect(draw, ox+3, oy+2, ox+12, oy+15, C["door"])
    rect(draw, ox+4, oy+3, ox+11, oy+14, C["door_light"])
    # maçaneta
    draw.point((ox+10, oy+9), C["sand"])

def draw_roof(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["roof"])
    # telhas
    for y in range(oy, oy+16, 3):
        for x in range(ox, ox+16, 4):
            draw.point((x, y), C["roof_dark"])

def draw_hedge(draw, ox, oy):
    rect(draw, ox, oy, ox+15, oy+15, C["hedge"])
    for pos in [(1,2),(4,1),(8,3),(12,2),(2,6),(5,7),(10,5),(14,8),(3,11),(7,13),(11,10),(14,12)]:
        draw.point((ox+pos[0], oy+pos[1]), C["hedge_dark"])
    for pos in [(2,4),(6,3),(13,6),(9,11),(4,14)]:
        draw.point((ox+pos[0], oy+pos[1]), C["tree_dark"])

WALKABLE_DRAWERS = [
    draw_grass, draw_path, draw_flower, draw_sand,
    draw_light_grass, draw_dark_path, draw_floor_indoor, draw_mat
]
BLOCKED_DRAWERS = [
    draw_wall, draw_water, draw_tree, draw_rock,
    draw_fence, draw_door, draw_roof, draw_hedge
]

def gen_tileset():
    img = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i, fn in enumerate(WALKABLE_DRAWERS):
        fn(draw, i * TILE, 0)
    for i, fn in enumerate(BLOCKED_DRAWERS):
        fn(draw, i * TILE, TILE)
    img.save("tilesets/overworld.png")
    print("  overworld.png (128x32)")

# ──────────────────────────────────────────────────────────────────────────────
# Player sprite — 48×64 (3 frames × 4 direções)
# ──────────────────────────────────────────────────────────────────────────────

def draw_character(draw, ox, oy, frame, direction, shirt, pants, hair, hat_or_none):
    """
    Desenha personagem 16×16.
    frame: 0=idle, 1=walk1, 2=walk2
    direction: 0=down, 1=up, 2=left, 3=right
    """
    # leg offset para animação de caminhada
    leg_off = [0, 1, -1][frame]

    # ── Sombra ──
    rect(draw, ox+4, oy+14, ox+11, oy+15, (0, 0, 0, 60))

    # ── Pernas ──
    if direction != 1:  # não-up: pernas visíveis
        if frame == 0:
            rect(draw, ox+4, oy+10, ox+6, oy+14, pants)
            rect(draw, ox+9, oy+10, ox+11, oy+14, pants)
        elif frame == 1:
            rect(draw, ox+4, oy+9, ox+6, oy+14, pants)
            rect(draw, ox+9, oy+11, ox+11, oy+14, pants)
        else:
            rect(draw, ox+4, oy+11, ox+6, oy+14, pants)
            rect(draw, ox+9, oy+9, ox+11, oy+14, pants)

    # ── Corpo ──
    rect(draw, ox+3, oy+6, ox+12, oy+11, shirt)

    # ── Cabeça ──
    rect(draw, ox+4, oy+1, ox+11, oy+7, C["skin"])
    # cabelo / chapéu
    if hat_or_none:
        rect(draw, ox+3, oy+0, ox+12, oy+3, hat_or_none)
        rect(draw, ox+2, oy+1, ox+13, oy+2, hat_or_none)  # aba
    else:
        rect(draw, ox+4, oy+0, ox+11, oy+2, hair)

    # ── Face por direção ──
    if direction == 0:  # down — olhos na frente
        draw.point((ox+6, oy+4), C["black"])
        draw.point((ox+9, oy+4), C["black"])
        draw.point((ox+7, oy+6), C["skin_dark"])
    elif direction == 1:  # up — costas
        rect(draw, ox+4, oy+1, ox+11, oy+7, hair)
    elif direction == 2:  # left
        draw.point((ox+5, oy+4), C["black"])
        draw.point((ox+7, oy+6), C["skin_dark"])
    else:  # right
        draw.point((ox+10, oy+4), C["black"])
        draw.point((ox+8, oy+6), C["skin_dark"])

    # ── Braços ──
    if frame == 1:
        draw.point((ox+2, oy+7), shirt)
        draw.point((ox+2, oy+8), shirt)
        draw.point((ox+13, oy+9), shirt)
        draw.point((ox+13, oy+10), shirt)
    elif frame == 2:
        draw.point((ox+2, oy+9), shirt)
        draw.point((ox+2, oy+10), shirt)
        draw.point((ox+13, oy+7), shirt)
        draw.point((ox+13, oy+8), shirt)
    else:
        draw.point((ox+2, oy+8), shirt)
        draw.point((ox+13, oy+8), shirt)

def gen_player():
    img = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for row, direction in enumerate([0, 1, 2, 3]):
        for col, frame in enumerate([0, 1, 2]):
            draw_character(
                draw, col * TILE, row * TILE, frame, direction,
                shirt=C["player_shirt"], pants=C["player_pants"],
                hair=C["player_hair"], hat_or_none=C["player_hat"]
            )
    img.save("sprites/player/player.png")
    print("  sprites/player/player.png (48x64)")

def gen_npc():
    img = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for row, direction in enumerate([0, 1, 2, 3]):
        for col, frame in enumerate([0, 1, 2]):
            draw_character(
                draw, col * TILE, row * TILE, frame, direction,
                shirt=C["npc_shirt"], pants=C["npc_pants"],
                hair=C["npc_hair"], hat_or_none=None
            )
    img.save("sprites/npc/npc_default.png")
    print("  sprites/npc/npc_default.png (48x64)")

def gen_npc_oak():
    """Prof Oak: jaleco branco, cabelo grisalho."""
    img = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    gray_hair = (160, 160, 160)
    for row, direction in enumerate([0, 1, 2, 3]):
        for col, frame in enumerate([0, 1, 2]):
            draw_character(
                draw, col * TILE, row * TILE, frame, direction,
                shirt=(230, 230, 225), pants=(80, 80, 100),
                hair=gray_hair, hat_or_none=None
            )
    img.save("sprites/npc/npc_oak.png")
    print("  sprites/npc/npc_oak.png (48x64)")

def gen_npc_nurse():
    """Nurse Joy: uniforme branco/rosa."""
    img = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for row, direction in enumerate([0, 1, 2, 3]):
        for col, frame in enumerate([0, 1, 2]):
            draw_character(
                draw, col * TILE, row * TILE, frame, direction,
                shirt=(255, 220, 230), pants=(240, 240, 240),
                hair=(255, 160, 180), hat_or_none=(255, 240, 240)
            )
    img.save("sprites/npc/npc_nurse.png")
    print("  sprites/npc/npc_nurse.png (48x64)")

# ──────────────────────────────────────────────────────────────────────────────
# Pokémon sprites — 32×32 por sprite (dois frames walk)
# ──────────────────────────────────────────────────────────────────────────────

POKEMON_COLORS = {
    1:   ((80, 160, 80),   (50, 110, 50)),    # Bulbasaur - verde
    2:   ((80, 160, 80),   (50, 110, 50)),    # Ivysaur
    3:   ((80, 160, 80),   (50, 110, 50)),    # Venusaur
    4:   ((200, 80, 50),   (150, 50, 30)),    # Charmander - vermelho
    5:   ((200, 80, 50),   (150, 50, 30)),    # Charmeleon
    6:   ((200, 80, 50),   (150, 50, 30)),    # Charizard
    7:   ((80, 150, 200),  (50, 110, 160)),   # Squirtle - azul
    8:   ((80, 150, 200),  (50, 110, 160)),   # Wartortle
    9:   ((80, 150, 200),  (50, 110, 160)),   # Blastoise
    10:  ((180, 180, 80),  (120, 120, 50)),   # Caterpie - amarelo-verde
    13:  ((220, 200, 60),  (170, 150, 40)),   # Weedle - amarelo
    16:  ((160, 100, 60),  (110, 70, 40)),    # Pidgey - marrom
    19:  ((180, 150, 100), (130, 110, 70)),   # Rattata - bege
    25:  ((230, 200, 50),  (180, 150, 30)),   # Pikachu - amarelo
    35:  ((220, 140, 180), (170, 100, 140)),  # Clefairy - rosa
    39:  ((220, 150, 180), (170, 110, 140)),  # Jigglypuff - rosa claro
    52:  ((160, 140, 180), (110, 90, 130)),   # Meowth - roxo claro
    54:  ((200, 200, 80),  (150, 150, 50)),   # Psyduck - amarelo
    63:  ((160, 90, 200),  (110, 60, 150)),   # Abra - roxo
    74:  ((120, 110, 100), (80, 70, 60)),     # Geodude - cinza
    129: ((200, 80, 100),  (150, 50, 70)),    # Magikarp - vermelho
    133: ((200, 160, 60),  (150, 120, 40)),   # Eevee - bege/marrom
}

def draw_pokemon_sprite(draw, ox, oy, frame, main_color, dark_color):
    """Desenha Pokémon simples 16×16 (blob com olhos)."""
    # corpo oval
    for dy in range(4, 14):
        for dx in range(3, 13):
            cx, cy = dx - 7, dy - 9
            if cx*cx * 1.5 + cy*cy < 25:
                color = main_color if (dx + dy) % 3 != 0 else dark_color
                draw.point((ox+dx, oy+dy), color)
    # olhos
    draw.point((ox+5, oy+7), C["white"])
    draw.point((ox+9, oy+7), C["white"])
    draw.point((ox+5, oy+7), C["black"]) if frame == 0 else None
    draw.point((ox+9, oy+7), C["black"]) if frame == 0 else None
    if frame == 1:
        draw.point((ox+5, oy+8), C["black"])
        draw.point((ox+9, oy+8), C["black"])
    # sombra base
    rect(draw, ox+5, oy+14, ox+10, oy+15, (0, 0, 0, 60))

def gen_pokemon_sprites():
    # Spritesheet com todos os pokémon: 2 frames lado a lado (32×16 por mon)
    # Layout: 1 pokémon por linha, 2 colunas (frame 0, frame 1)
    default_main = (150, 150, 200)
    default_dark = (100, 100, 150)

    for species_id in range(1, 152):
        main, dark = POKEMON_COLORS.get(species_id, (default_main, default_dark))
        img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw_pokemon_sprite(draw, 0, 0, 0, main, dark)
        draw_pokemon_sprite(draw, 16, 0, 1, main, dark)
        img.save(f"sprites/pokemon/mon_{species_id:03d}.png")
    print("  sprites/pokemon/mon_001..151.png (32x16 each)")

    # placeholder genérico para fallback
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_pokemon_sprite(draw, 0, 0, 0, default_main, default_dark)
    draw_pokemon_sprite(draw, 16, 0, 1, default_main, default_dark)
    img.save("sprites/pokemon/placeholder.png")
    print("  sprites/pokemon/placeholder.png")

# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Rodar de dentro de assets/
    os.makedirs("tilesets", exist_ok=True)
    os.makedirs("sprites/player", exist_ok=True)
    os.makedirs("sprites/npc", exist_ok=True)
    os.makedirs("sprites/pokemon", exist_ok=True)

    print("Gerando assets...")
    gen_tileset()
    gen_player()
    gen_npc()
    gen_npc_oak()
    gen_npc_nurse()
    gen_pokemon_sprites()
    print("Done.")
