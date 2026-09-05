#!/usr/bin/env python3
"""
gerar_biomas.py — O terreno dos 6 biomas novos (Fase 2, 05/09).

Os biomas saíram da Fase 1 com moradores mas sem chão: 19 espécies estavam
etiquetadas para deserto, ruínas, casa assombrada, floresta fechada e glacial e
não tinham onde nascer. Este script desenha o chão delas.

O que gera, por linha do atlas:
  14  pântano      chão + 3 variantes, poça tóxica, água parada, junco, tronco morto
  15  montanha     rocha + 3 variantes, falésia, cume, pedregulho, trilha
  16  deserto      areia seca + 3 variantes, duna, cacto, osso, gretas
  17  ruínas       mosaico + 3 variantes, pilar caído, pilar de pé, parede de
                   hieróglifos, degrau
  18  assombrado   assoalho podre + 3 variantes, parede rachada, janela quebrada,
                   tábua solta, teia
  19  mata fechada chão de sombra + 3 variantes, cogumelo brilhante, raiz, samambaia
  20  ponte        madeira: meio/ponta esquerda/direita, meio/topo/base vertical,
                   poste, encosto na areia
  21-23  estruturas 2x3: pirâmide grande, obelisco de hieróglifos, pirâmide pequena

Regras seguidas, as mesmas de todo tile do projeto:
  - luz vindo de CIMA-ESQUERDA, sempre;
  - contorno derivado do tom escuro do PRÓPRIO material, nunca preto puro;
  - o chão base ladrilha sem emenda (a textura é gerada por hash da posição
    DENTRO do tile, com dobra nas bordas — ver `_ruido_ladrilhavel`);
  - objeto solto fica inteiro e centrado no quadro (regra obrigatória 1);
  - estrutura é desenhada INTEIRA e só depois fatiada (regra que nasceu das
    árvores cortadas ao meio).

Roda com:  python3 tools/gerar_biomas.py
"""

import math

from PIL import Image, ImageDraw, ImageFilter

ATLAS = "assets/tilesets/overworld.png"
T = 128
COLS = 8
LINHAS_TOTAIS = 24          # o atlas cresce até aqui

LINHA_PANTANO = 14
LINHA_MONTANHA = 15
LINHA_DESERTO = 16
LINHA_RUINAS = 17
LINHA_ASSOMBRADO = 18
LINHA_MATA_FECHADA = 19
LINHA_PONTE = 20
LINHA_ESTRUTURAS = 21       # ocupa 21, 22 e 23


# ── ruído ───────────────────────────────────────────────────────────────────
def _hash(x, y, sal=0):
    h = ((x * 0x9E3779B1) ^ (y * 0x85EBCA77) ^ (sal * 0xC2B2AE35)) & 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
    return (h ^ (h >> 13)) & 0xFFFFFFFF


def _suave(t):
    """Curva de Perlin (6t^5-15t^4+10t^3): entra e sai com derivada zero, então
    a interpolação não deixa aresta visível na fronteira entre células."""
    return t * t * t * (t * (t * 6 - 15) + 10)


def _ruido_ladrilhavel(x, y, celulas, sal):
    """Ruído de valor INTERPOLADO que casa nas quatro bordas do tile.

    Duas propriedades, e as duas são necessárias:

    1. Ladrilhável — as coordenadas de célula entram no hash já dobradas pelo
       número de células do tile, então o pixel x=127 e o x=0 do tile vizinho
       leem a MESMA célula. Sem isso a textura fica boa sozinha e mostra costura
       assim que dois tiles ficam lado a lado (defeito que a areia antiga tinha).

    2. Interpolado — a primeira versão devolvia o valor da célula direto, o que
       desenha QUADRADOS duros: o pântano e a montanha saíram parecendo
       camuflagem militar. Agora mistura os quatro cantos da célula com a curva
       de Perlin, e o resultado é mancha orgânica.
    """
    # 🔴 A versão anterior recebia uma ESCALA em pixels e derivava o número de
    # células por divisão. Com escala=21 dava 6,09 células por tile — não
    # inteiro —, então a dobra da borda caía no lugar errado e a textura
    # voltava a mostrar quadrados. Agora quem manda é o número de células, que
    # é inteiro por construção e faz o tile fechar exato.
    n = max(1, celulas)
    escala = T / float(n)
    fx = x / escala
    fy = y / escala
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = _suave(fx - x0), _suave(fy - y0)

    def canto(ix, iy):
        return (_hash(ix % n, iy % n, sal) % 1000) / 1000.0

    a = canto(x0, y0) + (canto(x0 + 1, y0) - canto(x0, y0)) * tx
    b = canto(x0, y0 + 1) + (canto(x0 + 1, y0 + 1) - canto(x0, y0 + 1)) * tx
    return a + (b - a) * ty


def _chao(base, claro, escuro, sal, celulas=8, forca=0.5, granulado=0.22):
    """Chão de bioma: manchas grandes + granulado fino, tudo ladrilhável."""
    img = Image.new("RGBA", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            n = _ruido_ladrilhavel(x, y, celulas, sal)
            m = _ruido_ladrilhavel(x, y, 32, sal + 7)
            t = (n - 0.5) * forca + (m - 0.5) * granulado
            alvo = claro if t > 0 else escuro
            k = min(1.0, abs(t) * 2.0)
            px[x, y] = tuple(int(base[i] + (alvo[i] - base[i]) * k) for i in range(3)) + (255,)
    return img


def _variantes(fn, n=3):
    """Três variantes do mesmo chão, com sal diferente — é o que impede o
    xadrez visível quando um bioma cobre centenas de tiles."""
    return [fn(sal) for sal in range(1, n + 1)]


def _sombra(img, cx, base_y, raio, alpha=110):
    camada = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    d.ellipse((cx - raio, base_y - raio * 0.32, cx + raio, base_y + raio * 0.32),
              fill=(18, 20, 16, alpha))
    camada = camada.filter(ImageFilter.GaussianBlur(5))
    return Image.alpha_composite(camada, img)


# ── 14. PÂNTANO ─────────────────────────────────────────────────────────────
P_BASE, P_CLARO, P_ESCURO = (86, 92, 54), (118, 124, 70), (56, 62, 36)
P_AGUA, P_AGUA_ESC = (74, 96, 78), (46, 64, 52)
P_TOXICO, P_TOXICO_LUZ = (128, 190, 62), (186, 232, 96)


def pantano_chao(sal=1):
    return _chao(P_BASE, P_CLARO, P_ESCURO, 100 + sal, celulas=8, forca=0.62)


def pantano_poca_toxica():
    """A poça que envenena. Verde-limão de propósito: em jogo de tile, o dano
    tem que ser reconhecível ANTES de pisar — cor é o único aviso que funciona
    sem texto."""
    img = pantano_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse((10, 22, 118, 106), fill=P_TOXICO + (255,), outline=(70, 110, 30, 255), width=4)
    d.ellipse((22, 32, 96, 84), fill=P_TOXICO_LUZ + (255,))
    for i, (bx, by, br) in enumerate([(44, 52, 9), (76, 66, 6), (58, 80, 5), (88, 44, 4)]):
        d.ellipse((bx - br, by - br, bx + br, by + br), fill=(226, 250, 160, 235))
        d.ellipse((bx - br + 2, by - br + 2, bx, by), fill=(255, 255, 220, 255))
    return img


def pantano_agua():
    img = _chao(P_AGUA, (98, 122, 100), P_AGUA_ESC, 108, celulas=4, forca=0.6)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(5):
        y = 16 + i * 24 + (_hash(i, 3, 9) % 8)
        d.arc((6, y - 8, 122, y + 8), 200, 340, fill=(140, 168, 140, 130), width=3)
    return img


def pantano_junco():
    img = pantano_chao(5)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(11):
        x = 16 + i * 9 + (_hash(i, 11, 5) % 6)
        alt = 44 + (_hash(i, 12, 5) % 34)
        d.line([(x, 118), (x - 5 + (_hash(i, 13, 5) % 10), 118 - alt)],
               fill=(96, 118, 52, 255), width=4)
        d.ellipse((x - 6, 118 - alt - 12, x + 2, 118 - alt + 4), fill=(74, 58, 30, 255))
    return img


def pantano_tronco_morto():
    img = pantano_chao(6)
    img = _sombra(img, 64, 112, 40)
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(50, 116), (78, 116), (72, 34), (58, 34)], fill=(84, 70, 52, 255))
    d.polygon([(50, 116), (58, 116), (58, 34), (54, 34)], fill=(116, 100, 76, 255))
    d.line([(58, 62), (26, 40)], fill=(84, 70, 52, 255), width=7)
    d.line([(72, 48), (104, 30)], fill=(70, 58, 42, 255), width=6)
    d.ellipse((48, 26, 80, 42), fill=(58, 48, 34, 255))
    return img


# ── 15. MONTANHA ────────────────────────────────────────────────────────────
M_BASE, M_CLARO, M_ESCURO = (128, 118, 104), (168, 158, 142), (86, 78, 68)


def montanha_chao(sal=1):
    return _chao(M_BASE, M_CLARO, M_ESCURO, 200 + sal, celulas=8, forca=0.62, granulado=0.3)


def montanha_falesia():
    """Parede de rocha vista de cima: a faixa escura embaixo é a sombra da
    própria encosta, e é ela que faz o olho entender que ali tem desnível."""
    img = montanha_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(7):
        y = 12 + i * 18
        d.line([(0, y), (T, y + (_hash(i, 1, 3) % 9) - 4)], fill=(72, 66, 58, 200), width=3)
    d.rectangle((0, 96, T, T), fill=(58, 52, 46, 220))
    d.rectangle((0, 96, T, 104), fill=(92, 84, 74, 255))
    return img


def montanha_cume():
    img = montanha_chao(5)
    img = _sombra(img, 64, 116, 46)
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(18, 118), (64, 16), (110, 118)], fill=(140, 130, 116, 255),
              outline=(66, 60, 52, 255))
    d.polygon([(18, 118), (64, 16), (64, 118)], fill=(178, 168, 152, 255))
    d.polygon([(48, 44), (64, 16), (80, 44), (64, 36)], fill=(238, 240, 244, 255))
    return img


def montanha_pedregulho():
    img = montanha_chao(6)
    img = _sombra(img, 64, 108, 38)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse((22, 40, 106, 112), fill=(116, 106, 94, 255), outline=(60, 54, 48, 255), width=4)
    d.ellipse((34, 50, 82, 84), fill=(160, 150, 134, 255))
    d.ellipse((42, 54, 64, 70), fill=(190, 182, 166, 255))
    return img


def montanha_trilha():
    img = montanha_chao(7)
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(38, 0), (90, 0), (78, T), (50, T)], fill=(160, 138, 106, 255))
    for i in range(9):
        y = i * 15
        d.line([(44 + (_hash(i, 2, 4) % 8), y), (86 - (_hash(i, 3, 4) % 8), y + 6)],
               fill=(138, 116, 88, 200), width=3)
    return img


# ── 16. DESERTO ─────────────────────────────────────────────────────────────
D_BASE, D_CLARO, D_ESCURO = (214, 184, 122), (242, 216, 158), (176, 144, 92)


def deserto_chao(sal=1):
    return _chao(D_BASE, D_CLARO, D_ESCURO, 300 + sal, celulas=4, forca=0.4, granulado=0.14)


def deserto_duna():
    img = deserto_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(6):
        y = 14 + i * 21
        d.arc((-30, y - 26, T + 30, y + 26), 195, 345, fill=(186, 154, 100, 220), width=4)
        d.arc((-30, y - 30, T + 30, y + 22), 195, 345, fill=(246, 224, 168, 200), width=3)
    return img


def deserto_cacto():
    img = deserto_chao(5)
    img = _sombra(img, 64, 114, 30)
    d = ImageDraw.Draw(img, "RGBA")
    verde, verde_luz, verde_esc, contorno = (74, 132, 70), (108, 168, 96), (48, 96, 52), (30, 62, 34)
    d.rounded_rectangle((50, 30, 80, 116), radius=15, fill=verde, outline=contorno, width=4)
    d.rounded_rectangle((54, 34, 66, 110), radius=6, fill=verde_luz)
    d.rounded_rectangle((22, 56, 46, 76), radius=10, fill=verde, outline=contorno, width=4)
    d.rounded_rectangle((22, 56, 32, 96), radius=10, fill=verde, outline=contorno, width=4)
    d.rounded_rectangle((84, 44, 106, 64), radius=10, fill=verde, outline=contorno, width=4)
    d.rounded_rectangle((96, 44, 106, 88), radius=10, fill=verde, outline=contorno, width=4)
    for i in range(9):
        d.line([(65, 40 + i * 8), (65, 46 + i * 8)], fill=verde_esc, width=2)
    return img


def deserto_osso():
    img = deserto_chao(6)
    d = ImageDraw.Draw(img, "RGBA")
    osso, osso_esc = (238, 232, 214), (188, 180, 158)
    d.line([(34, 84), (94, 66)], fill=osso, width=9)
    d.line([(34, 84), (94, 66)], fill=osso_esc, width=3)
    for cx, cy in [(32, 78), (36, 90), (96, 60), (92, 72)]:
        d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=osso, outline=osso_esc, width=2)
    return img


def deserto_gretas():
    img = deserto_chao(7)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(5):
        x0 = (_hash(i, 20, 6) % T)
        pontos = [(x0, 0)]
        for k in range(1, 9):
            x0 = max(2, min(T - 2, x0 + (_hash(i, k, 6) % 21) - 10))
            pontos.append((x0, k * 16))
        d.line(pontos, fill=(158, 128, 82, 220), width=3)
    return img


# ── 17. RUÍNAS ──────────────────────────────────────────────────────────────
R_BASE, R_CLARO, R_ESCURO = (186, 168, 138), (216, 200, 168), (140, 124, 100)
R_PEDRA, R_PEDRA_LUZ, R_PEDRA_ESC, R_CONT = (172, 158, 132), (206, 194, 168), (122, 110, 90), (74, 66, 52)
HIERO = (128, 104, 66)


def ruinas_chao(sal=1):
    """Mosaico gasto: as juntas são desenhadas na MESMA grade em todo tile, o
    que faz o piso continuar de um quadro pro outro sem quebra."""
    img = _chao(R_BASE, R_CLARO, R_ESCURO, 400 + sal, celulas=8, forca=0.3)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(1, 4):
        d.line([(i * 32, 0), (i * 32, T)], fill=(150, 134, 108, 190), width=3)
        d.line([(0, i * 32), (T, i * 32)], fill=(150, 134, 108, 190), width=3)
    for i in range(4):
        for k in range(4):
            if _hash(i, k, 400 + sal) % 5 == 0:
                d.rectangle((i * 32 + 5, k * 32 + 5, i * 32 + 27, k * 32 + 27),
                            fill=(160, 146, 118, 150))
    return img


def _hieroglifos(d, x0, y0, x1, y1, sal):
    """Hieróglifos: nunca letras de verdade. São formas simples (olho, ave,
    onda, sol, mão) sorteadas por hash — legíveis como escrita antiga sem
    virar texto, que é justamente o que a regra 3 proíbe dentro de tile."""
    passo = 22
    linhas = max(1, (y1 - y0) // passo)
    colunas = max(1, (x1 - x0) // passo)
    for c in range(colunas):
        for l in range(linhas):
            cx = x0 + 10 + c * passo
            cy = y0 + 10 + l * passo
            forma = _hash(c, l, sal) % 6
            if forma == 0:      # olho
                d.ellipse((cx - 7, cy - 4, cx + 7, cy + 4), outline=HIERO, width=2)
                d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=HIERO)
            elif forma == 1:    # ave
                d.line([(cx - 7, cy + 3), (cx, cy - 4), (cx + 7, cy + 3)], fill=HIERO, width=2)
            elif forma == 2:    # onda
                d.arc((cx - 7, cy - 5, cx, cy + 5), 180, 360, fill=HIERO, width=2)
                d.arc((cx, cy - 5, cx + 7, cy + 5), 0, 180, fill=HIERO, width=2)
            elif forma == 3:    # sol
                d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline=HIERO, width=2)
                d.line([(cx, cy - 8), (cx, cy - 6)], fill=HIERO, width=2)
                d.line([(cx, cy + 6), (cx, cy + 8)], fill=HIERO, width=2)
            elif forma == 4:    # mão
                d.rectangle((cx - 5, cy - 2, cx + 5, cy + 5), outline=HIERO, width=2)
                for k in range(3):
                    d.line([(cx - 4 + k * 4, cy - 2), (cx - 4 + k * 4, cy - 7)], fill=HIERO, width=2)
            else:               # bastão
                d.line([(cx, cy - 7), (cx, cy + 7)], fill=HIERO, width=2)
                d.line([(cx - 4, cy - 7), (cx + 4, cy - 7)], fill=HIERO, width=2)


def ruinas_parede_hieroglifos():
    img = ruinas_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, T, T), fill=R_PEDRA + (255,))
    d.rectangle((0, 0, T, 10), fill=R_PEDRA_LUZ + (255,))
    d.rectangle((0, T - 12, T, T), fill=R_PEDRA_ESC + (255,))
    for i in range(1, 4):
        d.line([(0, i * 32), (T, i * 32)], fill=R_CONT + (160,), width=2)
    _hieroglifos(d, 6, 14, T - 6, T - 14, 41)
    return img


def ruinas_pilar_de_pe():
    img = ruinas_chao(5)
    img = _sombra(img, 64, 116, 34)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((44, 18, 84, 116), fill=R_PEDRA, outline=R_CONT, width=4)
    d.rectangle((44, 18, 58, 116), fill=R_PEDRA_LUZ)
    for i in range(5):
        d.line([(46, 30 + i * 18), (82, 30 + i * 18)], fill=R_PEDRA_ESC, width=2)
    d.rectangle((36, 10, 92, 26), fill=R_PEDRA, outline=R_CONT, width=4)
    d.rectangle((34, 110, 94, 122), fill=R_PEDRA, outline=R_CONT, width=4)
    return img


def ruinas_pilar_caido():
    img = ruinas_chao(6)
    img = _sombra(img, 64, 96, 46, alpha=90)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(3):
        x = 8 + i * 40
        d.rounded_rectangle((x, 56, x + 34, 92), radius=8, fill=R_PEDRA,
                            outline=R_CONT, width=4)
        d.rounded_rectangle((x + 3, 59, x + 30, 72), radius=6, fill=R_PEDRA_LUZ)
    return img


def ruinas_degrau():
    img = ruinas_chao(7)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(4):
        y = i * 32
        d.rectangle((0, y, T, y + 26), fill=R_PEDRA)
        d.rectangle((0, y, T, y + 6), fill=R_PEDRA_LUZ)
        d.rectangle((0, y + 26, T, y + 32), fill=R_PEDRA_ESC)
    return img


# ── 18. ASSOMBRADO ──────────────────────────────────────────────────────────
A_BASE, A_CLARO, A_ESCURO = (72, 62, 58), (98, 86, 78), (48, 40, 38)
A_MADEIRA, A_MADEIRA_LUZ, A_MADEIRA_ESC, A_CONT = (92, 72, 56), (118, 96, 74), (62, 48, 38), (34, 26, 22)


def assombrado_chao(sal=1):
    """Assoalho podre. As tábuas são desenhadas na mesma grade em todo tile —
    piso de casa velha continua de um quadro pro outro."""
    img = _chao(A_BASE, A_CLARO, A_ESCURO, 500 + sal, celulas=8, forca=0.4)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(4):
        y = i * 32
        d.rectangle((0, y, T, y + 30), fill=A_MADEIRA + (255,))
        d.line([(0, y), (T, y)], fill=A_CONT + (200,), width=3)
        for k in range(6):
            vx = (k * 23 + i * 11) % T
            d.line([(vx, y + 3), (vx + 14, y + 27)], fill=A_MADEIRA_ESC + (110,), width=2)
        if _hash(i, 0, 501 + sal) % 3 == 0:
            d.line([(0, y + 15), (T, y + 15)], fill=A_MADEIRA_ESC + (160,), width=2)
    return img


def assombrado_parede_rachada():
    img = Image.new("RGBA", (T, T), (86, 78, 76, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(4):
        for k in range(4):
            x, y = i * 32, k * 32
            tom = 86 + (_hash(i, k, 55) % 22)
            d.rectangle((x + 2, y + 2, x + 30, y + 30), fill=(tom, tom - 8, tom - 10, 255))
    for i in range(3):
        x0 = 20 + i * 40
        pontos = [(x0, 0)]
        for k in range(1, 8):
            x0 = max(2, min(T - 2, x0 + (_hash(i, k, 56) % 23) - 11))
            pontos.append((x0, k * 18))
        d.line(pontos, fill=(34, 28, 28, 230), width=3)
    return img


def assombrado_janela_quebrada():
    img = assombrado_parede_rachada()
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((22, 24, 106, 100), fill=(18, 20, 30, 255), outline=A_CONT + (255,), width=6)
    d.polygon([(26, 28), (56, 28), (34, 62)], fill=(120, 140, 168, 190))
    d.polygon([(70, 28), (102, 28), (102, 54)], fill=(120, 140, 168, 150))
    d.polygon([(26, 96), (52, 96), (28, 70)], fill=(120, 140, 168, 130))
    d.line([(56, 28), (44, 96)], fill=(150, 165, 190, 120), width=2)
    return img


def assombrado_tabua_solta():
    img = assombrado_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(20, 70), (108, 54), (110, 76), (22, 92)], fill=A_MADEIRA_LUZ + (255,),
              outline=A_CONT + (255,))
    d.rectangle((30, 30, 96, 46), fill=(16, 14, 16, 220))     # buraco no assoalho
    return img


def assombrado_teia():
    img = assombrado_chao(5)
    d = ImageDraw.Draw(img, "RGBA")
    branco = (222, 224, 228, 130)
    for a in range(0, 91, 15):
        r = math.radians(a)
        d.line([(0, 0), (math.cos(r) * 150, math.sin(r) * 150)], fill=branco, width=2)
    for raio in range(22, 140, 24):
        d.arc((-raio, -raio, raio, raio), 0, 90, fill=branco, width=2)
    return img


# ── 19. MATA FECHADA ────────────────────────────────────────────────────────
F_BASE, F_CLARO, F_ESCURO = (36, 58, 34), (56, 82, 46), (22, 38, 24)


def mata_chao(sal=1):
    """Chão de mata fechada: escuro porque a copa tapa o sol. É a cor que conta
    a história do bioma — se fosse verde-claro, seria só mais uma floresta."""
    return _chao(F_BASE, F_CLARO, F_ESCURO, 600 + sal, celulas=8, forca=0.55, granulado=0.26)


def mata_cogumelo():
    img = mata_chao(4)
    d = ImageDraw.Draw(img, "RGBA")
    brilho = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    db = ImageDraw.Draw(brilho)
    for (cx, cy, r) in [(46, 76, 26), (84, 62, 20), (66, 96, 16)]:
        db.ellipse((cx - r * 2, cy - r * 2, cx + r * 2, cy + r * 2), fill=(120, 220, 190, 46))
    brilho = brilho.filter(ImageFilter.GaussianBlur(12))
    img = Image.alpha_composite(img, brilho)
    d = ImageDraw.Draw(img, "RGBA")
    for (cx, cy, r) in [(46, 76, 22), (84, 64, 16), (66, 98, 13)]:
        d.rectangle((cx - r // 4, cy, cx + r // 4, cy + r), fill=(214, 220, 206, 255))
        d.chord((cx - r, cy - r, cx + r, cy + r * 0.7), 180, 360, fill=(120, 226, 196, 255),
                outline=(46, 122, 104, 255))
        d.ellipse((cx - r * 0.5, cy - r * 0.7, cx - r * 0.1, cy - r * 0.3),
                  fill=(198, 250, 232, 255))
    return img


def mata_raiz():
    img = mata_chao(5)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(4):
        y = 16 + i * 30
        d.line([(0, y), (40, y + 10), (86, y - 8), (T, y + 6)],
               fill=(58, 44, 30, 255), width=9)
        d.line([(0, y - 3), (40, y + 7), (86, y - 11), (T, y + 3)],
               fill=(84, 66, 46, 255), width=3)
    return img


def mata_samambaia():
    img = mata_chao(6)
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(7):
        cx = 14 + i * 17 + (_hash(i, 1, 61) % 6)
        cy = 104 - (_hash(i, 2, 61) % 22)
        for lado in (-1, 1):
            for k in range(7):
                ang = math.radians(250 + lado * (12 + k * 9))
                comp = 34 - k * 3
                d.line([(cx, cy), (cx + math.cos(ang) * comp, cy + math.sin(ang) * comp)],
                       fill=(58, 104, 52, 255), width=3)
    return img


# ── 20. PONTE ───────────────────────────────────────────────────────────────
PT_BASE, PT_LUZ, PT_ESC, PT_CONT = (146, 106, 62), (182, 140, 88), (104, 72, 40), (58, 38, 20)


def _tabuas(vertical=False):
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    largura = 96
    off = (T - largura) // 2
    if vertical:
        d.rectangle((off, 0, off + largura, T), fill=PT_BASE + (255,))
        d.rectangle((off, 0, off + 8, T), fill=PT_LUZ + (255,))
        d.rectangle((off + largura - 8, 0, off + largura, T), fill=PT_ESC + (255,))
        for i in range(9):
            y = i * 15
            d.line([(off, y), (off + largura, y)], fill=PT_CONT + (170,), width=3)
    else:
        d.rectangle((0, off, T, off + largura), fill=PT_BASE + (255,))
        d.rectangle((0, off, T, off + 8), fill=PT_LUZ + (255,))
        d.rectangle((0, off + largura - 8, T, off + largura), fill=PT_ESC + (255,))
        for i in range(9):
            x = i * 15
            d.line([(x, off), (x, off + largura)], fill=PT_CONT + (170,), width=3)
    return img


def ponte_h_meio():
    return _tabuas(False)


def ponte_h_esq():
    img = _tabuas(False)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 8, 14, T - 8), fill=PT_ESC + (255,), outline=PT_CONT + (255,), width=3)
    return img


def ponte_h_dir():
    img = _tabuas(False)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((T - 14, 8, T, T - 8), fill=PT_ESC + (255,), outline=PT_CONT + (255,), width=3)
    return img


def ponte_v_meio():
    return _tabuas(True)


def ponte_v_topo():
    img = _tabuas(True)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((8, 0, T - 8, 14), fill=PT_ESC + (255,), outline=PT_CONT + (255,), width=3)
    return img


def ponte_v_base():
    img = _tabuas(True)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((8, T - 14, T - 8, T), fill=PT_ESC + (255,), outline=PT_CONT + (255,), width=3)
    return img


def ponte_poste():
    img = _tabuas(False)
    d = ImageDraw.Draw(img, "RGBA")
    for cx in (18, T - 18):
        d.rectangle((cx - 9, 6, cx + 9, T - 6), fill=PT_ESC + (255,),
                    outline=PT_CONT + (255,), width=3)
        d.rectangle((cx - 9, 6, cx - 3, T - 6), fill=PT_BASE + (255,))
    return img


def ponte_encosto():
    """Onde a ponte encosta na areia. Sem esta peça a ponte termina no ar."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    areia = Image.open(ATLAS).convert("RGBA").crop((3 * T, 0, 4 * T, T))
    img.paste(areia, (0, 0))
    tab = _tabuas(False)
    img.alpha_composite(tab)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 12, 18, T - 12), fill=(120, 104, 78, 255), outline=PT_CONT + (255,), width=3)
    return img


# ── 21-23. ESTRUTURAS 2x3 ───────────────────────────────────────────────────
LARG_E, ALT_E = 2 * T, 3 * T
PIR_LUZ, PIR_BASE, PIR_ESC, PIR_CONT = (226, 198, 140), (196, 166, 108), (150, 122, 74), (92, 74, 44)


def piramide(escala=1.0, sal=1):
    """Pirâmide vista de frente-cima: face iluminada à esquerda, face na sombra
    à direita, e a aresta clara no meio — é essa aresta que faz o olho ler
    volume em vez de um triângulo chapado."""
    img = Image.new("RGBA", (LARG_E, ALT_E), (0, 0, 0, 0))
    base_y = ALT_E - 18
    meia = int(118 * escala)
    topo_y = int(base_y - 250 * escala)
    cx = LARG_E // 2

    img = _sombra(img, cx + 14, base_y + 4, meia, alpha=120)
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(cx - meia, base_y), (cx, topo_y), (cx, base_y)], fill=PIR_LUZ, outline=PIR_CONT)
    d.polygon([(cx, topo_y), (cx + meia, base_y), (cx, base_y)], fill=PIR_ESC, outline=PIR_CONT)
    # fiadas de blocos
    passos = 13
    for i in range(1, passos):
        t = i / passos
        y = int(topo_y + (base_y - topo_y) * t)
        largura = int(meia * t)
        d.line([(cx - largura, y), (cx + largura, y)], fill=PIR_CONT + (110,), width=2)
    d.line([(cx, topo_y), (cx, base_y)], fill=(244, 224, 176, 220), width=3)
    # entrada com hieróglifos
    porta_l = int(30 * escala)
    porta_a = int(52 * escala)
    d.rectangle((cx - porta_l, base_y - porta_a, cx + porta_l, base_y),
                fill=(58, 46, 34, 255), outline=PIR_CONT, width=4)
    d.polygon([(cx - porta_l - 10, base_y - porta_a), (cx + porta_l + 10, base_y - porta_a),
               (cx, base_y - porta_a - 22)], fill=PIR_BASE, outline=PIR_CONT)
    _hieroglifos(d, cx - porta_l - 8, base_y - porta_a - 18, cx + porta_l + 8,
                 base_y - porta_a - 2, sal)
    # capstone dourado
    d.polygon([(cx - int(22 * escala), topo_y + int(34 * escala)), (cx, topo_y),
               (cx + int(22 * escala), topo_y + int(34 * escala))],
              fill=(238, 200, 92, 255), outline=(150, 116, 40, 255))
    return img


def obelisco(sal=2):
    img = Image.new("RGBA", (LARG_E, ALT_E), (0, 0, 0, 0))
    base_y = ALT_E - 20
    cx = LARG_E // 2
    img = _sombra(img, cx + 10, base_y + 2, 54, alpha=110)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((cx - 48, base_y - 16, cx + 48, base_y), fill=R_PEDRA_ESC,
                outline=R_CONT, width=4)
    d.polygon([(cx - 34, base_y - 16), (cx + 34, base_y - 16), (cx + 26, 74), (cx - 26, 74)],
              fill=R_PEDRA, outline=R_CONT)
    d.polygon([(cx - 34, base_y - 16), (cx - 6, base_y - 16), (cx - 6, 74), (cx - 26, 74)],
              fill=R_PEDRA_LUZ)
    d.polygon([(cx - 26, 74), (cx + 26, 74), (cx, 22)], fill=(238, 200, 92, 255),
              outline=(150, 116, 40, 255))
    _hieroglifos(d, cx - 24, 96, cx + 24, base_y - 30, sal)
    return img


# ── montagem ────────────────────────────────────────────────────────────────
def main():
    im = Image.open(ATLAS).convert("RGBA")
    if im.size[1] // T < LINHAS_TOTAIS:
        maior = Image.new("RGBA", (im.size[0], LINHAS_TOTAIS * T), (0, 0, 0, 0))
        maior.paste(im, (0, 0))
        im = maior

    linhas = {
        LINHA_PANTANO: [pantano_chao(1)] + _variantes(pantano_chao) +
                       [pantano_poca_toxica(), pantano_agua(), pantano_junco(),
                        pantano_tronco_morto()],
        LINHA_MONTANHA: [montanha_chao(1)] + _variantes(montanha_chao) +
                        [montanha_falesia(), montanha_cume(), montanha_pedregulho(),
                         montanha_trilha()],
        LINHA_DESERTO: [deserto_chao(1)] + _variantes(deserto_chao) +
                       [deserto_duna(), deserto_cacto(), deserto_osso(), deserto_gretas()],
        LINHA_RUINAS: [ruinas_chao(1)] + _variantes(ruinas_chao) +
                      [ruinas_parede_hieroglifos(), ruinas_pilar_de_pe(),
                       ruinas_pilar_caido(), ruinas_degrau()],
        LINHA_ASSOMBRADO: [assombrado_chao(1)] + _variantes(assombrado_chao) +
                          [assombrado_parede_rachada(), assombrado_janela_quebrada(),
                           assombrado_tabua_solta(), assombrado_teia()],
        LINHA_MATA_FECHADA: [mata_chao(1)] + _variantes(mata_chao) +
                            [mata_cogumelo(), mata_raiz(), mata_samambaia(), mata_chao(9)],
        LINHA_PONTE: [ponte_h_meio(), ponte_h_esq(), ponte_h_dir(), ponte_v_meio(),
                      ponte_v_topo(), ponte_v_base(), ponte_poste(), ponte_encosto()],
    }
    for linha, tiles in linhas.items():
        for c, t in enumerate(tiles[:COLS]):
            im.paste(t, (c * T, linha * T))
        print(f"  linha {linha}: {len(tiles[:COLS])} tiles")

    # Estruturas 2x3, fatiadas de um desenho inteiro.
    #
    # A areia vai ASSADA atrás, pelo mesmo motivo das árvores grandes: os tiles
    # de canto de uma estrutura são quase todos transparentes, e a camada 0 do
    # TileMap não tem nada por trás — na primeira versão as pirâmides
    # apareceram como retângulos PRETOS no meio do deserto.
    def sobre(desenho, indice, linha_fundo):
        """`linha_fundo` é o chão onde a estrutura vai ficar no mapa. A pirâmide
        grande mora DENTRO do templo, sobre mosaico; se levasse areia assada
        atrás, apareceria um retalho claro no meio do piso de pedra — foi o que
        aconteceu na primeira versão."""
        fundo = Image.new("RGBA", (LARG_E, ALT_E))
        for lin in range(3):
            for col in range(2):
                v = _hash(indice * 5 + col, lin, 77) % 4
                fundo.paste(im.crop((v * T, linha_fundo * T,
                                     (v + 1) * T, (linha_fundo + 1) * T)),
                            (col * T, lin * T))
        return Image.alpha_composite(fundo, desenho)

    estruturas = [("piramide_grande", sobre(piramide(1.0, 11), 0, LINHA_RUINAS)),
                  ("obelisco", sobre(obelisco(12), 1, LINHA_DESERTO)),
                  ("piramide_pequena", sobre(piramide(0.62, 13), 2, LINHA_DESERTO))]
    for i, (nome, desenho) in enumerate(estruturas):
        col0 = i * 2
        for lin in range(3):
            for col in range(2):
                pedaco = desenho.crop((col * T, lin * T, (col + 1) * T, (lin + 1) * T))
                im.paste(pedaco, ((col0 + col) * T, (LINHA_ESTRUTURAS + lin) * T))
        print(f"  {nome}: colunas {col0}-{col0+1}, linhas "
              f"{LINHA_ESTRUTURAS}-{LINHA_ESTRUTURAS+2}")

    im.save(ATLAS)
    print(f"atlas: {im.size[0]}x{im.size[1]} ({im.size[0]//T}x{im.size[1]//T} tiles)")


if __name__ == "__main__":
    main()
