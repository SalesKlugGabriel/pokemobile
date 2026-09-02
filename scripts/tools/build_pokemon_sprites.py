#!/usr/bin/env python3
"""Monta as sprites dos 151 Pokémon (4 direções + shiny) a partir das sprites
REAIS da Geração 1 (Red/Blue), baixadas do repositório público e gratuito
PokeAPI/sprites (GitHub) — sem depender de geração por IA, sem cota.

Pedido do Gabriel (02/09): "pegar as imagens disponíveis e usar" em vez de
gerar — projeto pessoal, sem distribuição/venda, uso comum em fã-jogos.

Formato de saída (mesmo layout 4-direções já usado pro Treinador/NPC,
SpriteBuilder.build_entity_frames): 96×128 (3 colunas × 32px, 4 linhas ×
32px) — tile 32, não 16, porque a arte baixada (32-40px) já é grande demais
pra caber sem virar ruído em 16px (mesmo achado da sprite da Bicicleta).

Mapeamento de direção (sem sprite de perfil real disponível — batalha só
tem frente/costas):
  linha 0 (down) = front_default (de frente pra câmera)
  linha 1 (up)   = back_default  (de costas)
  linha 2 (left) = front_default (placeholder até ter arte de perfil)
  linha 3 (right)= front_default espelhado horizontalmente (pelo menos
                   diferente de "left", não é perfil de verdade)
Cada linha repete a mesma pose nas 3 colunas (idle/walk_a/walk_b) — as
sprites de batalha são paradas, sem quadro de caminhada; fica sem animação
de perna por ora, mesmo trade-off que o resto do jogo já aceitou antes.

Shiny: gerado por rotação de matiz (HSV +100°) em cima do sprite normal —
não existe "shiny" oficial pra Red/Blue (o conceito é da Geração 2), então
esta é uma aproximação nossa, não uma paleta oficial.
"""
import io
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "sprites" / "pokemon"
BASE_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-i/red-blue"

TILE = 32
SHEET_W = TILE * 3
SHEET_H = TILE * 4


def fetch(url: str) -> Image.Image | None:
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            data = resp.read()
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception as e:
        print(f"  aviso: falhou baixar {url}: {e}")
        return None


def remove_white_bg(im: Image.Image, threshold: int = 245) -> Image.Image:
    """Fundo das sprites do PokeAPI é branco sólido, sem alpha — troca por
    transparente. Tolerância alta (245) porque o fundo é 100% branco puro,
    sem anti-aliasing suave nesta fonte."""
    data = im.getdata()
    new_data = []
    for r, g, b, a in data:
        if r >= threshold and g >= threshold and b >= threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, a))
    out = im.copy()
    out.putdata(new_data)
    return out


def fit_to_tile(im: Image.Image, tile: int = TILE) -> Image.Image:
    """Centraliza a sprite (proporção preservada) num canvas tile×tile
    transparente. As sprites baixadas variam de tamanho (32-40px)."""
    im = im.copy()
    im.thumbnail((tile, tile), Image.NEAREST)
    canvas = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    x = (tile - im.width) // 2
    y = (tile - im.height) // 2
    canvas.paste(im, (x, y), im)
    return canvas


def shiny_variant(im: Image.Image) -> Image.Image:
    """Aproximação nossa de 'shiny' (Red/Blue não tinha o conceito) — gira
    o matiz mantendo saturação/brilho, preserva o alpha original."""
    r, g, b, a = im.split()
    rgb = Image.merge("RGB", (r, g, b)).convert("HSV")
    h, s, v = rgb.split()
    h = h.point(lambda x: (x + int(100 / 360 * 255)) % 255)
    shifted = Image.merge("HSV", (h, s, v)).convert("RGB")
    r2, g2, b2 = shifted.split()
    return Image.merge("RGBA", (r2, g2, b2, a))


def build_sheet(front: Image.Image, back: Image.Image) -> Image.Image:
    front_t = fit_to_tile(front)
    back_t = fit_to_tile(back)
    right_t = front_t.transpose(Image.FLIP_LEFT_RIGHT)

    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    rows = [front_t, back_t, front_t, right_t]  # down, up, left, right
    for row_idx, pose in enumerate(rows):
        for col_idx in range(3):
            sheet.paste(pose, (col_idx * TILE, row_idx * TILE), pose)
    return sheet


def process_species(species_id: int) -> bool:
    front = fetch(f"{BASE_URL}/{species_id}.png")
    back = fetch(f"{BASE_URL}/back/{species_id}.png")
    if front is None or back is None:
        print(f"  id {species_id}: SEM sprite (pulado, mantém o arquivo antigo)")
        return False

    front = remove_white_bg(front)
    back = remove_white_bg(back)

    normal_sheet = build_sheet(front, back)
    normal_sheet.save(OUT_DIR / f"mon_{species_id:03d}.png")

    shiny_front = shiny_variant(front)
    shiny_back = shiny_variant(back)
    shiny_sheet = build_sheet(shiny_front, shiny_back)
    shiny_sheet.save(OUT_DIR / f"mon_{species_id:03d}_shiny.png")
    return True


def main() -> None:
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 151
    ok, fail = 0, 0
    for species_id in range(start, end + 1):
        print(f"[{species_id}/151] baixando e montando...")
        if process_species(species_id):
            ok += 1
        else:
            fail += 1
    print(f"\nConcluído: {ok} espécie(s) processada(s), {fail} falharam.")


if __name__ == "__main__":
    main()
