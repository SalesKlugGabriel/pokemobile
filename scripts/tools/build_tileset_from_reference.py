#!/usr/bin/env python3
"""Monta o tileset do jogo (overworld.png) a partir da imagem de referência
que o Gabriel mandou pronta (03/09) — decisão dele: "Adicione esses
componentes e apenas utilize nos ambientes conforme combinado" — em vez de
tentar GERAR uma arte nova "no estilo" da referência (o que a IA nunca
acerta 100%), a referência JÁ É o asset final: só precisa recortar cada um
dos 40 tiles da grade (8 colunas × 5 linhas) e colocar no atlas do jogo,
na posição de cada letra do CHAR_MAP (scripts/world/MapLayouts.gd).

Pipeline de recorte — 2 tentativas anteriores (margem fixa única, depois
uma margem fixa mais apertada) DEIXARAM RISCO PRETO no jogo mesmo assim:
o "respiro" de fundo escuro do catálogo de referência não tem o MESMO
tamanho em toda célula (Grama sangra quase até a borda, Chão Batido tem
uma faixa de ~20px, e por aí vai) — qualquer margem única sempre vai
cortar curto demais pra algum tile. Resolvido de vez com detecção
AUTOMÁTICA por tile: pra cada célula, acha o retângulo real de conteúdo
(sem fundo) por flood fill a partir das bordas, encolhe mais alguns
pixels de segurança (`SAFETY`, evita pixel de anti-serrilhado bem na
borda do conteúdo) e SÓ ENTÃO recorta — cada tile usa a MAIOR área segura
que ele realmente tem, em vez de uma margem chutada pra todos.

2 tiles do jogo não têm equivalente na referência (Caminho Escuro, Grama
Clara — variações de tom que o Gabriel não mandou) — derivados por
recolor simples (escurecer/clarear) da arte de referência mais próxima,
pra não ficarem destoando do resto com a arte antiga de 32px.
"""
from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT.parent / "pokemobile-editor" / "public" / "refs" / "tileset-ref.png"
OUT = ROOT / "assets" / "tilesets" / "overworld.png"

TILE = 128
CW, CH = 1536 / 8, 1024 / 5
LABEL_Y = 163  # exclui a faixa do rótulo de texto embaixo de cada célula
SAFETY = 4     # encolhe mais um pouco além do conteúdo detectado, por segurança


def _bg_flood_mask(cell: Image.Image, thresh: int = 32) -> bytearray:
    """bytearray w*h, 1 = pixel de fundo (conectado à borda da célula)."""
    w, h = cell.size
    px = cell.load()

    def is_bg(p) -> bool:
        r, g, b = p[:3]
        return r < thresh and g < thresh and b < thresh

    visited = bytearray(w * h)
    dq = deque()

    def seed(x: int, y: int) -> None:
        idx = y * w + x
        if not visited[idx] and is_bg(px[x, y]):
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
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                idx = ny * w + nx
                if not visited[idx] and is_bg(px[nx, ny]):
                    visited[idx] = 1
                    dq.append((nx, ny))
    return visited


def _content_bbox(cell: Image.Image) -> tuple[int, int, int, int]:
    """Retângulo (x0,y0,x1,y1) do conteúdo real da célula (sem fundo),
    encolhido por SAFETY em cada lado."""
    w, h = cell.size
    bg = _bg_flood_mask(cell)
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        row_off = y * w
        for x in range(w):
            if not bg[row_off + x]:
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
    minx = min(minx + SAFETY, w // 2 - 5)
    miny = min(miny + SAFETY, h // 2 - 5)
    maxx = max(maxx - SAFETY, w // 2 + 5)
    maxy = max(maxy - SAFETY, h // 2 + 5)
    return (minx, miny, maxx, maxy)


CENTER_BOX = 96  # lado do quadrado central seguro (ver docstring de crop_ref)


def crop_ref(im: Image.Image, row: int, col: int) -> Image.Image:
    """Tiles de TEXTURA (grama/água/parede/etc.). Achado (03/09, depois de
    3 tentativas de margem/bbox falharem): o fundo escuro do catálogo tem
    uma VINHETA — mais forte nos CANTOS da célula do que nas bordas retas
    — então nenhum retângulo alinhado aos eixos consegue evitar o canto
    escuro sem também cortar conteúdo de verdade em outro lugar (provado
    testando pixel a pixel: um recorte "seguro" na borda ainda pegava
    fundo bem no canto). Resolvido pegando só um QUADRADO PEQUENO bem no
    CENTRO da célula (longe de qualquer canto) e ampliando — como são
    texturas repetitivas (grama, água, pedra...), usar uma amostra central
    ampliada não muda a aparência de forma perceptível, e nunca mais tem
    canto de vinheta."""
    cx = round(col * CW) + CW / 2
    cy = round(row * CH) + LABEL_Y / 2
    half = CENTER_BOX / 2
    tile = im.crop((round(cx - half), round(cy - half), round(cx + half), round(cy + half))).convert("RGBA")
    return tile.resize((TILE, TILE), Image.LANCZOS)


def extract_object(im: Image.Image, row: int, col: int, thresh: int = 32) -> Image.Image:
    """Recorta um objeto "solto" (árvore, cerca, caixa...) já cortado bem
    rente ao seu retângulo de conteúdo real (via `Image.getbbox()` sobre a
    transparência) — necessário pra centralizar de verdade depois (achado
    do Gabriel, 03/09: "as árvores estão descentralizadas" — colar a
    célula inteira, com o objeto desalinhado dentro dela, carrega esse
    desalinhamento pro tile final)."""
    x0 = round(col * CW)
    y0 = round(row * CH)
    x1 = round((col + 1) * CW)
    y1 = round(row * CH + LABEL_Y)
    cell = im.crop((x0, y0, x1, y1)).convert("RGBA")
    w, h = cell.size
    px = cell.load()
    bg = _bg_flood_mask(cell, thresh)
    for i in range(w * h):
        if bg[i]:
            x, y = i % w, i // w
            r, g, b, _a = px[x, y]
            px[x, y] = (r, g, b, 0)
    bbox = cell.getbbox()
    return cell.crop(bbox) if bbox else cell


def compose_object_on_base(im: Image.Image, row: int, col: int, base: Image.Image) -> Image.Image:
    """Recorta o objeto (extract_object, já rente ao conteúdo real) e cola
    CENTRALIZADO horizontalmente e alinhado pelo RODAPÉ em cima de um tile
    base já limpo (grama/água) — garante que a moldura do tile final é
    sempre a base sem costura, com o objeto na posição certa (nem
    descentralizado, nem flutuando)."""
    obj = extract_object(im, row, col)
    # object não pode passar de ~92% da largura do tile, senão encosta na
    # borda e quebra a separação visual entre tiles vizinhos (mesma regra
    # do redesenho da árvore da sessão anterior).
    max_w = round(TILE * 0.92)
    scale = min(max_w / obj.width, TILE * 0.92 / obj.height)
    new_w = round(obj.width * scale)
    new_h = round(obj.height * scale)
    obj = obj.resize((new_w, new_h), Image.LANCZOS)
    out = base.copy().convert("RGBA")
    x = (TILE - new_w) // 2
    y = TILE - new_h
    out.paste(obj, (x, y), obj)
    return out


# (col, row) no atlas do jogo -> (row, col) na referência do Gabriel.
# TEXTURE = recorte direto (piso/parede/água — sangra até a borda, sem
# "objeto solto" no meio). OBJECT = tem um objeto solto sobre uma base
# (árvore/cerca/caixa/etc.) — precisa da extração por transparência
# (extract_object/compose_object_on_base) pra não sobrar fundo escuro nas
# bordas do tile (achado ao ver o resultado em jogo, 03/09).
TEXTURE_PLACEMENT = {
    # linha 0 — walkable
    (0, 0): (0, 1),  # grama <- Grama Baixa
    (1, 0): (0, 0),  # caminho <- Chão Batido
    (3, 0): (3, 5),  # areia <- Areia
    (6, 0): (4, 2),  # piso de casa <- Piso de Madeira
    (7, 0): (4, 3),  # tapete <- Tapete
    # linha 1 — bloqueado
    (0, 1): (1, 0),  # parede <- Parede
    (1, 1): (2, 0),  # água <- Água
    (3, 1): (2, 5),  # rocha <- Rocha
    (5, 1): (1, 2),  # porta <- Porta
    (6, 1): (1, 5),  # telhado <- Telhado
    # linha 2 — terreno base extra
    (0, 2): (0, 2),  # grama alta <- Grama Alta
    # linha 3 — água/gelo/rocha
    (1, 3): (2, 3),  # gelo <- Gelo
    (2, 3): (2, 4),  # gelo trincado <- Gelo Trincado
    (3, 3): (2, 6),  # parede de rocha <- Parede de Rocha
    (4, 3): (2, 7),  # entrada caverna <- Entrada Caverna
    (5, 3): (2, 1),  # água+praia <- Água com Praia
    # linha 4 — terrenos especiais
    (0, 4): (3, 0),  # solo envenenado <- Solo Envenenado
    (1, 4): (3, 1),  # lama <- Lama
    (2, 4): (3, 2),  # lama funda <- Lama Funda
    (3, 4): (3, 3),  # poça d'água <- Poça d'Água
    (4, 4): (3, 4),  # rocha vulcânica <- Rocha Vulcânica
    (5, 4): (3, 6),  # trilhos <- Trilhos
    (6, 4): (3, 7),  # piso de pedra <- Piso de Pedra
    # linha 5 — interior/decoração
    (0, 5): (4, 0),  # piso de pedra clara <- Piso de Pedra Clara
    (1, 5): (4, 1),  # pedra c/ musgo <- Pedra com Musgo
    (3, 5): (4, 6),  # folhas caídas <- Folhas Caídas
    # linha 6 — estrutura
    (0, 6): (1, 1),  # janela <- Janela
    (1, 6): (1, 4),  # canto de casa <- Canto Casa
    (3, 6): (1, 3),  # entrada de casa (nova) <- Entrada Casa
}

# (col, row) -> (ref_row, ref_col, base) — base é "grass", "water" ou "wall"
OBJECT_PLACEMENT = {
    (2, 0): (4, 4, "grass"),   # grama+flor <- Flores
    (2, 1): (0, 4, "grass"),   # árvore <- Árvore
    (4, 1): (1, 6, "grass"),   # cerca <- Cerca
    (7, 1): (0, 3, "grass"),   # arbusto <- Arbusto
    (1, 2): (0, 5, "grass"),   # pinheiro <- Árvore Pinho
    (2, 2): (0, 6, "grass"),   # outono <- Árvore Outono
    (3, 2): (0, 7, "grass"),   # toco <- Toco/Tronco
    (0, 3): (2, 2, "water"),   # água+lírios <- Água com Lírios
    (2, 5): (4, 5, "grass"),   # cogumelos <- Cogumelos
    (4, 5): (4, 7, "water"),   # junco <- Junco
    (2, 6): (1, 7, "grass"),   # caixa <- Caixa
}


def main() -> None:
    ref = Image.open(REF).convert("RGB")
    COLS, ROWS = 8, 7  # grade fixa do atlas do jogo (CHAR_MAP)
    sheet = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))

    for (col, row), (ref_row, ref_col) in TEXTURE_PLACEMENT.items():
        tile = crop_ref(ref, ref_row, ref_col)
        sheet.paste(tile, (col * TILE, row * TILE), tile)
        print(f"col{col} row{row} <- referência linha{ref_row} col{ref_col} (textura)")

    grass_base = crop_ref(ref, 0, 1)   # Grama Baixa, já extraída acima
    water_base = crop_ref(ref, 2, 0)   # Água, já extraída acima
    bases = {"grass": grass_base, "water": water_base}

    for (col, row), (ref_row, ref_col, base_name) in OBJECT_PLACEMENT.items():
        tile = compose_object_on_base(ref, ref_row, ref_col, bases[base_name])
        sheet.paste(tile, (col * TILE, row * TILE), tile)
        print(f"col{col} row{row} <- referência linha{ref_row} col{ref_col} (objeto sobre {base_name})")

    # Grama Clara (G) — versão clara da Grama Baixa (col0 linha0)
    grass = sheet.crop((0, 0, TILE, TILE))
    lt_grass = ImageEnhance.Brightness(grass).enhance(1.35)
    lt_grass = ImageEnhance.Color(lt_grass).enhance(0.85)
    sheet.paste(lt_grass, (4 * TILE, 0))
    print("col4 row0 <- Grama Baixa clareada (derivado)")

    # Caminho Escuro (D) — versão escura do Chão Batido (col1 linha0)
    path = sheet.crop((TILE, 0, TILE * 2, TILE))
    dk_path = ImageEnhance.Brightness(path).enhance(0.72)
    sheet.paste(dk_path, (5 * TILE, 0))
    print("col5 row0 <- Chão Batido escurecido (derivado)")

    sheet.convert("RGB").save(OUT)
    print(f"\nTileset salvo: {sheet.size} em {OUT}")


if __name__ == "__main__":
    main()
