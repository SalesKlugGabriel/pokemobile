#!/usr/bin/env python3
"""
gerar_cenarios.py — Os dois cenários de tela cheia do jogo (05/09).

Pedido do Gabriel:
  1. "a tela inicial poderia ser uma tela colorida, com temática de Pokémon,
     mundo, felicidade, alegria, diversão"
  2. a escolha do inicial vira o ENCONTRO com o Prof. Carvalho, dentro do
     laboratório, com as três pokébolas na mesa

Os dois são montados com os TILES DO PRÓPRIO JOGO. É a mesma regra que já vale
pro resto: a capa e a primeira cena têm que parecer o jogo que vem depois, e
nunca "envelhecer" em relação ao mundo.

A versão anterior do fundo de título era escura e desfocada — bonita como pano
de fundo, mas o oposto do pedido. Esta é de dia, saturada, sem escurecimento
geral: só um degradê suave no alto e embaixo, o bastante pro texto ficar
legível sem apagar a cor.

Roda com:  python3 tools/gerar_cenarios.py
"""

from PIL import Image, ImageDraw, ImageFilter

ATLAS = "assets/tilesets/overworld.png"
T = 128
LARG, ALT = 1280, 720

# coordenadas conferidas tile a tile no atlas antes de usar
GRAMA = (0, 0)
GRAMA_V = [(0, 0), (0, 7), (1, 7), (2, 7)]
TERRA = (1, 0)
AREIA = (3, 0)
AGUA = (1, 1)
MATO = (0, 2)
FLOR = (2, 0)
ARVORES = [(2, 1), (1, 2), (2, 2)]
PISO = (6, 0)      # piso de madeira (interior)
TAPETE = (7, 0)    # tapete vermelho
PAREDE = (0, 1)    # parede com janela
PAREDE_LISA = (4, 8)


def espalhar(c, r):
    h = ((c * 0x9E3779B1) ^ (r * 0x85EBCA77)) & 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) & 0xFFFFFFFF
    return h % 20


def montar(atlas, celulas, lado, cols, linhas):
    """Desenha uma grade de tiles a `lado` px cada."""
    def tile(cr):
        c, r = cr
        return atlas.crop((c * T, r * T, (c + 1) * T, (r + 1) * T)).resize(
            (lado, lado), Image.LANCZOS)

    img = Image.new("RGBA", (cols * lado, linhas * lado))
    for r in range(linhas):
        for c in range(cols):
            img.paste(tile(celulas(c, r)), (c * lado, r * lado))
    return img


def degrade_topo_e_base(img, altura=190, forca=150):
    """Escurece SÓ as faixas de cima e de baixo, onde ficam texto e botões.
    O miolo da imagem fica com a cor cheia — é isso que separa 'colorido' de
    'escuro com um pouco de cor'."""
    mascara = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mascara)
    for y in range(altura):
        a = int(forca * (1.0 - y / altura))
        d.line([(0, y), (img.size[0], y)], fill=a)
    for y in range(altura):
        a = int(forca * 0.85 * (1.0 - y / altura))
        d.line([(0, img.size[1] - 1 - y), (img.size[0], img.size[1] - 1 - y)], fill=a)
    escuro = Image.new("RGBA", img.size, (8, 14, 20, 255))
    return Image.composite(escuro, img, mascara)


def viva(img, ganho=1.18):
    """Puxa a saturação: os tiles foram desenhados pra somar com sombra de
    entidade e luz do mapa; sozinhos numa tela cheia ficam apagados."""
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            m = (r + g + b) / 3.0
            px[x, y] = (
                max(0, min(255, int(m + (r - m) * ganho))),
                max(0, min(255, int(m + (g - m) * ganho))),
                max(0, min(255, int(m + (b - m) * ganho))),
                a)
    return img


# ── Tela de título: paisagem de dia, alegre ─────────────────────────────────
def cena_titulo(c, r, cols, linhas):
    if r >= linhas - 2:
        return AGUA
    if r == linhas - 3:
        return AREIA
    if r <= 1:
        return ARVORES[espalhar(c, r) % len(ARVORES)]
    if r == 2 and espalhar(c, r) < 8:
        return ARVORES[espalhar(c, r) % len(ARVORES)]
    # Encruzilhada: uma estrada que atravessa e outra que sobe. Lê como
    # "mundo pra explorar". A primeira versão cruzava duas diagonais e formava
    # um X apontando pro nada no meio da tela.
    faixa_h = 6 <= r <= 7
    faixa_v = cols // 2 - 2 <= c <= cols // 2 + 1
    if faixa_h or faixa_v:
        return TERRA
    # lago no canto: quebra o verde e dá um segundo bioma na capa
    if 3 <= r <= 5 and 1 <= c <= 5:
        return AGUA
    if (r == 2 or r == 6) and 0 <= c <= 6:
        return AREIA
    if 8 <= r <= 9 and 2 <= c <= 6:
        return MATO
    if 3 <= r <= 5 and cols - 7 <= c <= cols - 3:
        return MATO
    d = espalhar(c, r)
    if d < 4:
        return FLOR          # bem mais flor que no mapa: aqui é capa, é festa
    return GRAMA_V[d % len(GRAMA_V)]


# ── Laboratório do Prof. Carvalho ───────────────────────────────────────────
def cena_lab(c, r, cols, linhas):
    if r <= 2:
        return PAREDE if (c % 3 == 1) else PAREDE_LISA
    # tapete embaixo, na frente da mesa
    if linhas - 3 <= r and 2 <= c <= cols - 3:
        return TAPETE
    return PISO


def mesa(img, y_topo, y_base, x0, x1):
    """A BANCADA onde as pokébolas ficam apoiadas.

    Sem ela as bolas pareciam flutuando na parede: um objeto pequeno no meio de
    uma tela grande precisa de algo embaixo pra o olho entender onde ele está.
    Desenhada aqui (e não com tiles) porque é um móvel visto de frente, e o
    atlas só tem tiles vistos de cima."""
    d = ImageDraw.Draw(img, "RGBA")
    tampo_alto = (176, 132, 84, 255)
    tampo = (146, 104, 62, 255)
    frente = (104, 72, 42, 255)
    borda = (58, 38, 22, 255)
    # sombra projetada no chão (luz vem de cima-esquerda)
    sombra = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(sombra)
    ds.rectangle((x0 + 26, y_base - 6, x1 + 60, y_base + 26), fill=(18, 12, 8, 120))
    sombra = sombra.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(sombra)

    d.rectangle((x0, y_topo, x1, y_base), fill=frente, outline=borda, width=3)
    d.rectangle((x0 - 14, y_topo - 22, x1 + 14, y_topo + 10), fill=tampo, outline=borda, width=3)
    d.rectangle((x0 - 14, y_topo - 22, x1 + 14, y_topo - 14), fill=tampo_alto)
    # três encaixes redondos, um por pokébola
    return img


def main():
    atlas = Image.open(ATLAS).convert("RGBA")

    lado = 64
    cols, linhas = LARG // lado, ALT // lado + 1

    titulo = montar(atlas, lambda c, r: cena_titulo(c, r, cols, linhas),
                    lado, cols, linhas).crop((0, 0, LARG, ALT))
    titulo = viva(titulo, 1.22)
    titulo = degrade_topo_e_base(titulo, altura=210, forca=140)
    titulo.save("assets/ui/fundo_titulo.png")
    print("assets/ui/fundo_titulo.png  (dia, colorido)")

    lab = montar(atlas, lambda c, r: cena_lab(c, r, cols, linhas),
                 lado, cols, linhas).crop((0, 0, LARG, ALT))
    lab = viva(lab, 1.10)
    # luz de janela caindo do alto-esquerda, que é a direção de luz da Art Bible
    luz = Image.new("RGBA", lab.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(luz)
    dl.polygon([(90, 0), (430, 0), (700, ALT), (300, ALT)], fill=(255, 246, 200, 34))
    luz = luz.filter(ImageFilter.GaussianBlur(28))
    lab = Image.alpha_composite(lab, luz)
    lab = mesa(lab, 470, 560, 300, 1000)
    lab = degrade_topo_e_base(lab, altura=150, forca=110)
    lab.save("assets/ui/fundo_laboratorio.png")
    print("assets/ui/fundo_laboratorio.png")


if __name__ == "__main__":
    main()
