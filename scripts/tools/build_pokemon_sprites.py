#!/usr/bin/env python3
"""Monta as sprites dos 151 Pokémon (4 direções + shiny) a partir das sprites
REAIS da Geração 1 (Red/Blue), baixadas do repositório público e gratuito
PokeAPI/sprites (GitHub) — sem depender de geração por IA, sem cota.

Pedido do Gabriel (02/09): "pegar as imagens disponíveis e usar" em vez de
gerar — projeto pessoal, sem distribuição/venda, uso comum em fã-jogos.

Refinamento (02/09, mesmo dia — Gabriel jogou e pediu pra "fechar os
buracos" e fazer parecer "que está em movimentação"):
1. **Buracos**: a 1ª versão removia fundo branco por LIMIAR NO PIXEL
   INTEIRO (qualquer pixel ~branco virava transparente, onde estivesse).
   Conferido pixel a pixel no Pikachu: 281 de 1600 pixels (17,6%) eram
   "ilhas" transparentes DENTRO do contorno do Pokémon (brilho do corpo,
   reflexo do olho) — nada a ver com o fundo de verdade. Ao reduzir de
   ~40px pra 32px (tile do jogo), essas ilhas viravam buracos visíveis
   ("suíço"). Corrigido com **flood fill a partir da borda da imagem**:
   só vira transparente o branco que está CONECTADO ao fundo de verdade
   (alcançável a partir da moldura externa); brilho/reflexo branco preso
   dentro do contorno preto do desenho fica intacto, porque não toca a
   borda.
2. **Posição/sensação de movimento**: (a) a sprite entrava centralizada
   verticalmente no quadro de 32×32 — como cada pose baixada tem altura
   diferente, o "chão" (pé) de cada Pokémon caía numa altura diferente
   dentro do quadro, fazendo parecer flutuar de forma inconsistente entre
   direções. Corrigido alinhando pelo **rodapé** (só sobra espaço em
   cima), igual o resto do jogo já assume pro chão da entidade. (b) as
   sprites de batalha da Red/Blue são só 1 pose parada (sem quadro de
   "andando" de verdade) — sem diferença nenhuma entre as 3 colunas do
   sheet, o Pokémon nunca parecia se mexer. Criado um "bob" de 1px pra
   cima/baixo entre as colunas 2 e 3 (mesmo truque clássico dos jogos
   Pokémon originais pro sprite do Pokémon seguindo o treinador no mapa),
   dando a sensação de passo mesmo sem arte de perna nova.

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

Shiny: gerado por rotação de matiz (HSV +100°) em cima do sprite normal —
não existe "shiny" oficial pra Red/Blue (o conceito é da Geração 2), então
esta é uma aproximação nossa, não uma paleta oficial.
"""
import io
import sys
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "sprites" / "pokemon"
BASE_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-i/red-blue"

TILE = 32
SHEET_W = TILE * 3
SHEET_H = TILE * 4
BOB_PX = 1  # deslocamento vertical do "passo" entre as colunas walk_a/walk_b


def fetch(url: str) -> Image.Image | None:
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            data = resp.read()
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception as e:
        print(f"  aviso: falhou baixar {url}: {e}")
        return None


def remove_white_bg(im: Image.Image, threshold: int = 245) -> Image.Image:
    """Fundo das sprites do PokeAPI é branco sólido, sem alpha. Em vez de
    apagar TODO pixel ~branco (que também zera brilho/reflexo branco
    dentro do próprio desenho, virando "buraco" — achado real no Pikachu,
    17,6% dos pixels), faz flood fill a partir da BORDA da imagem: só
    limpa o branco que está conectado ao fundo verdadeiro. Branco preso
    dentro do contorno (não toca nenhuma borda) fica intacto."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_bg_white(p) -> bool:
        r, g, b, _a = p
        return r >= threshold and g >= threshold and b >= threshold

    visited = bytearray(w * h)
    dq = deque()

    def seed(x: int, y: int) -> None:
        idx = y * w + x
        if not visited[idx] and is_bg_white(px[x, y]):
            visited[idx] = 1
            dq.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while dq:
        x, y = dq.popleft()
        r, g, b, _a = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                idx = ny * w + nx
                if not visited[idx] and is_bg_white(px[nx, ny]):
                    visited[idx] = 1
                    dq.append((nx, ny))
    return im


def fit_to_tile(im: Image.Image, tile: int = TILE) -> Image.Image:
    """Encaixa a sprite (proporção preservada) num canvas tile×tile
    transparente, alinhada pelo RODAPÉ (não centralizada verticalmente) —
    assim o "pé" de qualquer pose (as baixadas variam de 32 a 40px de
    altura) sempre cai na mesma linha do quadro, em vez de flutuar em
    alturas diferentes dependendo do tamanho de cada sprite."""
    im = im.copy()
    im.thumbnail((tile, tile), Image.NEAREST)
    canvas = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    x = (tile - im.width) // 2
    y = tile - im.height
    canvas.paste(im, (x, y), im)
    return canvas


def bob(im: Image.Image, offset: int) -> Image.Image:
    """Desloca o conteúdo já encaixado no tile verticalmente por `offset`
    px (positivo = desce, negativo = sobe), mantendo o canvas do mesmo
    tamanho — simula o "passo" clássico de sprite de Pokémon seguindo no
    mapa, já que a arte de batalha da Red/Blue não tem quadro de andar."""
    if offset == 0:
        return im
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    canvas.paste(im, (0, offset), im)
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
    # idle (col 0) = pose parada; walk_a/walk_b (col 1/2) = bob de 1px pra
    # cima e pra baixo — dá a sensação de passo mesmo sem quadro de perna.
    cols = [lambda p: p, lambda p: bob(p, -BOB_PX), lambda p: bob(p, BOB_PX)]
    for row_idx, pose in enumerate(rows):
        for col_idx, make_col in enumerate(cols):
            frame = make_col(pose)
            sheet.paste(frame, (col_idx * TILE, row_idx * TILE), frame)
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
