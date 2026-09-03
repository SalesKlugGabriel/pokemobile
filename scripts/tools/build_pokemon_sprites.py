#!/usr/bin/env python3
"""Monta as sprites dos 151 Pokémon (4 direções + shiny) a partir das sprites
REAIS de batalha, baixadas do repositório público e gratuito PokeAPI/sprites
(GitHub) — sem depender de geração por IA, sem cota.

Pedido do Gabriel (02/09): "pegar as imagens disponíveis e usar" em vez de
gerar — projeto pessoal, sem distribuição/venda, uso comum em fã-jogos.

Refinamento (02/09, mesmo dia — Gabriel jogou e pediu pra "fechar os
buracos" e fazer parecer "que está em movimentação"):
1. **Buracos**: a 1ª versão (fonte Red/Blue) removia fundo branco por
   LIMIAR NO PIXEL INTEIRO (qualquer pixel ~branco virava transparente,
   onde estivesse). Conferido pixel a pixel no Pikachu: 281 de 1600
   pixels (17,6%) eram "ilhas" transparentes DENTRO do contorno do
   Pokémon (brilho do corpo, reflexo do olho) — nada a ver com o fundo de
   verdade. Corrigido então com flood fill a partir da borda da imagem.
2. **Posição/sensação de movimento**: (a) alinhamento pelo RODAPÉ em vez
   de centralizado verticalmente — o "pé" de cada pose (alturas
   diferentes) sempre cai na mesma linha do quadro. (b) "bob" de 1px
   entre as colunas walk_a/walk_b (mesmo truque clássico dos jogos
   Pokémon originais pro sprite do companheiro seguindo no mapa), já que
   a arte de batalha não tem quadro de "andando" de verdade.

Troca de geração (02/09, mesmo dia — Gabriel mandou print de referência
querendo mais detalhe): a fonte virou **Geração 5 (Black/White)** em vez
de Red/Blue — mesmo repositório gratuito, mesma ideia, só um "conjunto"
mais detalhado (96×96 nativos, sombreado de verdade, contorno mais limpo
— ainda pixel art, não é o estilo "pintado" do print, mas uma melhora
grande e sem custo). Achado que SIMPLIFICOU o pipeline: a Geração 5 já
vem com **transparência de verdade** (paleta com índice transparente,
confirmado em 8 espécies variadas — todo canto da imagem já nasce com
alfa 0), diferente da Red/Blue que usava fundo branco sólido. Por isso a
etapa de remoção de fundo (`remove_white_bg`) não é mais necessária —
mantida no arquivo só como salvaguarda (roda sempre, mas não deve
encontrar nada pra apagar nesta fonte).

Formato de saída (mesmo layout 4-direções já usado pro Treinador/NPC,
SpriteBuilder.build_entity_frames): 384×512 (3 colunas × 128px, 4 linhas ×
128px) — migração tile128 (03/09, pedido do Gabriel: 32px "não tinha
resolução boa mesmo redesenhado"). A fonte (Geração 5, 96×96 nativos) é
MENOR que o tile novo — `fit_to_tile()` agora faz upscale de verdade com
reamostragem suave (LANCZOS, não "esticar" com nearest) quando a sprite
baixada é menor que o tile, em vez de só encolher (o `thumbnail()` do PIL
nunca aumenta uma imagem, então a versão anterior deste script, herdada
de quando o tile era 32 e a fonte 96px sempre precisava ENCOLHER, ficaria
quebrada aqui — teria deixado a sprite pequena dentro de uma moldura maior
em vez de preencher o tile).

Mapeamento de direção (sem sprite de perfil real disponível — batalha só
tem frente/costas):
  linha 0 (down) = front_default (de frente pra câmera)
  linha 1 (up)   = back_default  (de costas)
  linha 2 (left) = front_default (placeholder até ter arte de perfil)
  linha 3 (right)= front_default espelhado horizontalmente (pelo menos
                   diferente de "left", não é perfil de verdade)

Shiny: a Geração 5 TEM variante shiny oficial de verdade
(`shiny/{id}.png`) — usada em vez da aproximação por rotação de matiz da
versão Red/Blue (`shiny_variant()` fica só de salvaguarda pra id sem
shiny oficial disponível, o que não deveria acontecer nas 151 espécies).
"""
import io
import sys
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "sprites" / "pokemon"
BASE_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white"

TILE = 128  # migração tile128 (03/09): era 32
SHEET_W = TILE * 3
SHEET_H = TILE * 4
BOB_PX = 4  # migração tile128 (03/09): era 1 — mantém a mesma proporção de "passo"


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
    assim o "pé" de qualquer pose (as baixadas variam de tamanho) sempre
    cai na mesma linha do quadro, em vez de flutuar em alturas diferentes
    dependendo do tamanho de cada sprite.

    Migração tile128 (03/09): a fonte (Geração 5, ~96×96) é MENOR que o
    tile (128), então isto precisa ENCOLHER OU AUMENTAR dependendo do
    caso — `resize()` com LANCZOS faz as duas coisas com reamostragem
    suave (`thumbnail()` do PIL só encolhe, nunca aumenta; deixado de usar
    aqui de propósito)."""
    im = im.copy()
    ratio = min(tile / im.width, tile / im.height)
    new_w = max(1, round(im.width * ratio))
    new_h = max(1, round(im.height * ratio))
    im = im.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    x = (tile - new_w) // 2
    y = tile - new_h
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

    # Geração 5 tem paleta shiny oficial de verdade — só cai pra aproximação
    # por rotação de matiz se por algum motivo faltar (não deveria acontecer
    # nas 151 espécies, conferido antes de trocar a fonte).
    shiny_front_raw = fetch(f"{BASE_URL}/shiny/{species_id}.png")
    shiny_back_raw = fetch(f"{BASE_URL}/back/shiny/{species_id}.png")
    if shiny_front_raw is not None and shiny_back_raw is not None:
        shiny_front = remove_white_bg(shiny_front_raw)
        shiny_back = remove_white_bg(shiny_back_raw)
    else:
        print(f"  id {species_id}: sem shiny oficial, usando aproximação por matiz")
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
