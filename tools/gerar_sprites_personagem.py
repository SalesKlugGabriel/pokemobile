#!/usr/bin/env python3
"""
gerar_sprites_personagem.py — Gerador de sprites de personagem em pixel art de verdade.

Este arquivo é o "arquivo-fonte" da arte (o equivalente ao .aseprite que a Art Bible pede):
cada pixel é colocado deliberadamente por código, então dá pra reeditar/regerar qualquer
frame sem redesenhar tudo, e a consistência entre direções/frames/personagens é garantida
por construção — não depende de a mão (ou a IA) acertar duas vezes igual.

Regras da Art Bible aplicadas aqui, sem exceção:
  - Grade lógica de 32x64 px, escalada 4x (NEAREST) => 128x256 por frame, que é exatamente
    o que SpriteBuilder.build_entity_frames() já espera. Zero mudança de código no jogo.
  - Luz vindo de CIMA-ESQUERDA: highlight nas faces superiores/esquerdas, sombra nas
    inferiores/direitas, em todos os materiais.
  - Contorno escuro derivado da própria cor do material (nunca preto puro chapado).
  - Paleta travada por material, 3 tons (base/sombra/highlight) + contorno.
  - Mesma origem/pivô em todos os 12 frames (personagem centrado em x, pés na mesma linha).

Layout do spritesheet (idêntico ao formato atual do jogo):
  col 0 = idle, col 1 = walk_a, col 2 = walk_b
  row 0 = down, row 1 = up, row 2 = left, row 3 = right
"""

from PIL import Image

# ─────────────────────────────────────────────────────────────────────────────
# Grade e escala
# ─────────────────────────────────────────────────────────────────────────────
LW, LH = 32, 64          # grade lógica (pixel art de verdade)
SCALE = 4                # 32x64 * 4 = 128x256, o frame que o jogo já usa
COLS, ROWS = 3, 4

TRANSP = (0, 0, 0, 0)


def rgba(hexstr, a=255):
    hexstr = hexstr.lstrip("#")
    return (int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16), a)


# ─────────────────────────────────────────────────────────────────────────────
# Paletas (identidade preservada — cores extraídas do player.png atual)
# ─────────────────────────────────────────────────────────────────────────────
def paleta(cap, shirt, pants, skin="fadeb4", hair="6b4a2a", shoe="3c2a1e"):
    """Monta base/sombra/highlight/contorno de cada material a partir da cor base."""
    def tons(hexstr, esc_f=0.62, prof_f=0.42, hi_f=1.22):
        r, g, b = rgba(hexstr)[:3]
        cl = lambda v: max(0, min(255, int(v)))
        return {
            "base": (r, g, b, 255),
            "sombra": (cl(r * esc_f), cl(g * esc_f), cl(b * esc_f), 255),
            "linha": (cl(r * prof_f), cl(g * prof_f), cl(b * prof_f), 255),
            "hi": (cl(r * hi_f), cl(g * hi_f), cl(b * hi_f), 255),
        }
    return {
        "cap": tons(cap),
        "shirt": tons(shirt),
        "pants": tons(pants),
        "skin": tons(skin, esc_f=0.78, prof_f=0.55, hi_f=1.10),
        "hair": tons(hair),
        "shoe": tons(shoe, esc_f=0.70, prof_f=0.45, hi_f=1.35),
    }


# Treinador: identidade EXATA do player.png atual (boné vermelho, macacão azul,
# calça roxa, sapato marrom escuro) — só a qualidade muda, não o personagem.
PAL_PLAYER = paleta(cap="c43e32", shirt="4274ce", pants="6040b4")
PAL_NPC = paleta(cap="7a6a58", shirt="c8a24a", pants="4a5a68", hair="4a3524")
PAL_NURSE = paleta(cap="f2f2f2", shirt="f2f2f2", pants="e0567a", hair="e0567a")
PAL_OAK = paleta(cap="e8e8e8", shirt="e8e8e8", pants="7a6a58", hair="d8d8d8")

SOMBRA_CHAO = (0, 0, 0, 105)   # sombra de contato, forma rasterizada, sem blur


class Tela:
    """Canvas lógico 32x64 com helpers de desenho pixel a pixel."""

    def __init__(self, w=LW, h=LH):
        self.w, self.h = w, h
        self.px = [[TRANSP for _ in range(w)] for _ in range(h)]

    def set(self, x, y, cor):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = cor

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return TRANSP

    def rect(self, x0, y0, x1, y1, cor):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, cor)

    def elipse(self, cx, cy, rx, ry, cor):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                dx = (x - cx + 0.5) / (rx + 0.5)
                dy = (y - cy + 0.5) / (ry + 0.5)
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, cor)

    def contornar(self, mapa_linha):
        """Desenha contorno 1px ao redor de cada região opaca, usando a cor de
        contorno do material daquele pixel (mapa_linha: cor_do_pixel -> cor_linha)."""
        alvo = []
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y)[3] == 0:
                    # é vazio: vira contorno se tiver vizinho opaco
                    viz = None
                    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                        c = self.get(x + dx, y + dy)
                        if c[3] > 0 and c in mapa_linha:
                            viz = mapa_linha[c]
                            break
                    if viz:
                        alvo.append((x, y, viz))
        for x, y, cor in alvo:
            self.set(x, y, cor)

    def para_imagem(self, escala=SCALE):
        img = Image.new("RGBA", (self.w, self.h), TRANSP)
        for y in range(self.h):
            for x in range(self.w):
                img.putpixel((x, y), self.px[y][x])
        return img.resize((self.w * escala, self.h * escala), Image.NEAREST)


# ─────────────────────────────────────────────────────────────────────────────
# Anatomia (em coordenadas lógicas, 32x64) — mesma para todos os frames, o que
# garante pivô/altura/silhueta idênticos entre direções e entre personagens.
# ─────────────────────────────────────────────────────────────────────────────
CX = 16          # centro horizontal
Y_CAP = 8        # topo do boné
Y_ROSTO = 17     # topo do rosto (abaixo da aba)
Y_OMBRO = 26     # linha do ombro
Y_CINTURA = 40   # fim do tronco
Y_JOELHO = 47
Y_PE = 54        # linha do chão (planta do pé) — MESMA em todos os frames
Y_SOMBRA = 55


def desenhar_sombra_chao(t):
    """NÃO desenha nada de propósito.

    Achado no teste em jogo (04/09): o motor já desenha uma sombra de contato
    por código (TrainerEntity._add_visibility_shadow / FollowerPokemon), então
    assar outra no sprite dava SOMBRA DUPLA — um borrão escuro embaixo do
    personagem. A sombra fica com o motor (é ele que sabe o chão), o sprite só
    entrega o personagem recortado.
    """
    return


def desenhar_pernas(t, pal, dir_, fase):
    """fase: 0=parado, 1=perna esquerda à frente, 2=perna direita à frente."""
    p = pal["pants"]
    s = pal["shoe"]

    if dir_ in ("down", "up"):
        # duas pernas lado a lado. O passo levanta uma perna (encurta) e abaixa a
        # outra — diferença precisa ser LEGÍVEL em 32px, então 2px, não 1.
        offs = {0: (0, 0), 1: (-2, 2), 2: (2, -2)}[fase]
        for i, (x0, x1) in enumerate(((CX - 6, CX - 2), (CX + 2, CX + 6))):
            dy = offs[i]
            t.rect(x0, Y_CINTURA, x1, Y_PE - 3 + dy, p["base"])
            # sombra na metade direita da perna (luz vem da esquerda)
            t.rect(x1 - 1, Y_CINTURA, x1, Y_PE - 3 + dy, p["sombra"])
            t.rect(x0, Y_CINTURA, x0, Y_PE - 3 + dy, p["hi"])
            # sapato
            t.rect(x0 - 1, Y_PE - 3 + dy, x1, Y_PE + dy, s["base"])
            t.rect(x0 - 1, Y_PE - 3 + dy, x1, Y_PE - 3 + dy, s["hi"])
            t.rect(x1, Y_PE - 2 + dy, x1, Y_PE + dy, s["sombra"])
    else:
        # Perfil. Achado dos ciclos 2 e 3: abrir o passo no eixo X e só pôr uma
        # linha entre as pernas NÃO resolve — as duas ficam do mesmo comprimento
        # e leem como um bloco roxo único. O que resolve é o que pixel art de
        # verdade faz numa passada de perfil: a perna de trás LEVANTA O PÉ (fica
        # mais curta e em tom de sombra) enquanto a da frente fica plantada no
        # chão. Aí a silhueta conta o movimento sozinha.
        sinal = 1 if dir_ == "right" else -1
        frente, tras, lift = {0: (0, 0, 0), 1: (4, -4, 3), 2: (-4, 4, 3)}[fase]

        # perna de trás — mais curta (pé no ar), tom de sombra (mais longe)
        bx = CX + sinal * tras
        t.rect(bx - 2, Y_CINTURA, bx + 2, Y_PE - 3 - lift, p["sombra"])
        t.rect(bx - 3, Y_PE - 3 - lift, bx + 3, Y_PE - lift, s["sombra"])

        # perna da frente — plantada, tom base, com highlight na borda esquerda
        fx = CX + sinal * frente
        t.rect(fx - 2, Y_CINTURA, fx + 2, Y_PE - 3, p["base"])
        t.rect(fx - 2, Y_CINTURA, fx - 2, Y_PE - 3, p["hi"])
        t.rect(fx + 2, Y_CINTURA, fx + 2, Y_PE - 3, p["sombra"])
        t.rect(fx - 3, Y_PE - 3, fx + 3, Y_PE, s["base"])
        t.rect(fx - 3, Y_PE - 3, fx + 3, Y_PE - 3, s["hi"])
        t.rect(fx + 3, Y_PE - 2, fx + 3, Y_PE, s["sombra"])


def desenhar_tronco(t, pal, dir_, fase, bob):
    sh = pal["shirt"]
    sk = pal["skin"]
    y0 = Y_OMBRO + bob
    y1 = Y_CINTURA
    # perfil é mais estreito que a vista frontal (é um corpo visto de lado),
    # mas nunca "chapado": ganha uma coluna a mais de sombra pra ter volume.
    meia = 7 if dir_ in ("down", "up") else 5

    t.rect(CX - meia, y0, CX + meia - 1, y1, sh["base"])
    # volume: highlight na faixa esquerda, sombra na faixa direita
    t.rect(CX - meia, y0, CX - meia + 1, y1, sh["hi"])
    t.rect(CX + meia - 2, y0, CX + meia - 1, y1, sh["sombra"])
    # sombra sob o queixo/gola (ambient occlusion estilizada)
    t.rect(CX - meia + 2, y0, CX + meia - 3, y0 + 1, sh["sombra"])

    if dir_ == "down":
        # peitilho do macacão + alças
        t.rect(CX - 3, y0 + 2, CX + 2, y1, sh["hi"])
        t.rect(CX - 3, y0 + 2, CX + 2, y0 + 2, sh["base"])
        t.rect(CX - 6, y0 + 2, CX - 5, y0 + 6, sh["sombra"])
        t.rect(CX + 4, y0 + 2, CX + 5, y0 + 6, sh["sombra"])
    elif dir_ == "up":
        # costas: alças cruzadas
        t.rect(CX - 5, y0 + 3, CX + 4, y0 + 4, sh["sombra"])
    else:
        # perfil: costura vertical do macacão, dá leitura de lateral
        sinal = 1 if dir_ == "right" else -1
        t.rect(CX + sinal * 2, y0 + 3, CX + sinal * 2, y1, sh["sombra"])

    # braços (pele), balançando com a caminhada
    swing = {0: 0, 1: -2, 2: 2}[fase]
    if dir_ in ("down", "up"):
        for sgn in (-1, 1):
            ax = CX - 9 if sgn < 0 else CX + 7
            ay = y0 + 1 + (swing if sgn < 0 else -swing)
            t.rect(ax, ay, ax + 1, ay + 10, sk["base"])
            t.rect(ax, ay, ax, ay + 10, sk["hi"] if sgn < 0 else sk["sombra"])
    else:
        # perfil: o braço visível fica na BORDA do corpo (o da frente), nunca
        # no meio do tronco — foi o erro do 1º ciclo, lia como listra solta.
        sinal = 1 if dir_ == "right" else -1
        ax = CX + sinal * (meia - 1)
        ay = y0 + 2 + swing
        t.rect(ax - 1, ay, ax + 1, ay + 9, sk["base"])
        t.rect(ax + sinal, ay, ax + sinal, ay + 9, sk["sombra"])
        t.rect(ax - sinal, ay, ax - sinal, ay + 9, sk["hi"])
        # mão, um tom mais escuro pra separar do braço
        t.rect(ax - 1, ay + 8, ax + 1, ay + 9, sk["sombra"])


def desenhar_cabeca(t, pal, dir_, bob):
    sk = pal["skin"]
    cp = pal["cap"]
    hr = pal["hair"]
    y_cap = Y_CAP + bob
    y_rosto = Y_ROSTO + bob

    # rosto / cabeça
    t.rect(CX - 6, y_rosto, CX + 5, y_rosto + 7, sk["base"])
    t.rect(CX + 4, y_rosto, CX + 5, y_rosto + 7, sk["sombra"])   # lado direito na sombra
    t.rect(CX - 6, y_rosto, CX - 6, y_rosto + 7, sk["hi"])       # lado esquerdo iluminado
    # cantos arredondados (silhueta legível)
    t.set(CX - 6, y_rosto, TRANSP)
    t.set(CX + 5, y_rosto, TRANSP)
    t.set(CX - 6, y_rosto + 7, TRANSP)
    t.set(CX + 5, y_rosto + 7, TRANSP)

    if dir_ == "up":
        # de costas: cabelo cobre a cabeça INTEIRA (no 1º ciclo sobrava pele
        # embaixo, lia como faixa de cabelo em vez de nuca). Só o pescoço
        # aparece, e em sombra.
        t.rect(CX - 6, y_rosto, CX + 5, y_rosto + 6, hr["base"])
        t.rect(CX - 6, y_rosto, CX - 5, y_rosto + 6, hr["hi"])
        t.rect(CX + 4, y_rosto, CX + 5, y_rosto + 6, hr["sombra"])
        t.rect(CX - 3, y_rosto + 7, CX + 2, y_rosto + 7, sk["sombra"])
    else:
        # cabelo aparecendo sob o boné, nas laterais
        t.rect(CX - 6, y_rosto, CX - 4, y_rosto + 2, hr["base"])
        t.rect(CX + 3, y_rosto, CX + 5, y_rosto + 2, hr["sombra"])
        # olhos
        if dir_ == "down":
            t.rect(CX - 4, y_rosto + 3, CX - 3, y_rosto + 4, (30, 26, 22, 255))
            t.rect(CX + 2, y_rosto + 3, CX + 3, y_rosto + 4, (30, 26, 22, 255))
            t.set(CX - 4, y_rosto + 3, (70, 62, 56, 255))   # brilho no olho
            t.set(CX + 2, y_rosto + 3, (70, 62, 56, 255))
        elif dir_ == "left":
            # em perfil o olho vai perto da borda que "olha", não no meio do rosto
            t.rect(CX - 5, y_rosto + 3, CX - 4, y_rosto + 4, (30, 26, 22, 255))
            t.set(CX - 5, y_rosto + 3, (70, 62, 56, 255))
        else:
            t.rect(CX + 3, y_rosto + 3, CX + 4, y_rosto + 4, (30, 26, 22, 255))
            t.set(CX + 3, y_rosto + 3, (70, 62, 56, 255))

    # boné: copa
    t.rect(CX - 7, y_cap + 2, CX + 6, y_rosto, cp["base"])
    t.rect(CX - 5, y_cap, CX + 4, y_cap + 2, cp["base"])
    # volume da copa
    t.rect(CX - 7, y_cap + 2, CX - 5, y_rosto, cp["hi"])
    t.rect(CX + 4, y_cap + 2, CX + 6, y_rosto, cp["sombra"])
    t.rect(CX - 5, y_cap, CX - 2, y_cap + 1, cp["hi"])
    # cantos da copa arredondados
    t.set(CX - 7, y_cap + 2, TRANSP)
    t.set(CX + 6, y_cap + 2, TRANSP)

    # aba do boné, conforme a direção
    if dir_ == "down":
        t.rect(CX - 7, y_rosto, CX + 6, y_rosto + 1, cp["sombra"])
        t.rect(CX - 7, y_rosto, CX + 2, y_rosto, cp["base"])
    elif dir_ == "left":
        t.rect(CX - 10, y_rosto, CX - 6, y_rosto + 1, cp["sombra"])
        t.rect(CX - 10, y_rosto, CX - 7, y_rosto, cp["base"])
    elif dir_ == "right":
        t.rect(CX + 5, y_rosto, CX + 9, y_rosto + 1, cp["sombra"])
        t.rect(CX + 5, y_rosto, CX + 8, y_rosto, cp["base"])
    else:
        # de costas: só a tirinha de trás do boné
        t.rect(CX - 3, y_rosto, CX + 2, y_rosto + 1, cp["sombra"])


def montar_frame(pal, dir_, fase):
    t = Tela()
    bob = -1 if fase in (1, 2) else 0   # leve sobe-desce ao andar
    desenhar_sombra_chao(t)
    desenhar_pernas(t, pal, dir_, fase)
    desenhar_tronco(t, pal, dir_, fase, bob)
    desenhar_cabeca(t, pal, dir_, bob)

    # contorno: cada material contorna com o próprio tom escuro
    mapa = {}
    for mat in pal.values():
        for k in ("base", "sombra", "hi"):
            mapa[mat[k]] = mat["linha"]
    mapa[(30, 26, 22, 255)] = (30, 26, 22, 255)
    mapa[(70, 62, 56, 255)] = (30, 26, 22, 255)
    t.contornar(mapa)
    return t.para_imagem()


def gerar_spritesheet(pal, destino):
    fw, fh = LW * SCALE, LH * SCALE
    folha = Image.new("RGBA", (fw * COLS, fh * ROWS), TRANSP)
    direcoes = ["down", "up", "left", "right"]
    for row, dir_ in enumerate(direcoes):
        for col, fase in enumerate((0, 1, 2)):     # idle, walk_a, walk_b
            frame = montar_frame(pal, dir_, fase)
            folha.paste(frame, (col * fw, row * fh))
    folha.save(destino)
    return destino


if __name__ == "__main__":
    import sys
    saida = sys.argv[1] if len(sys.argv) > 1 else "/tmp/player_novo.png"
    alvo = sys.argv[2] if len(sys.argv) > 2 else "player"
    pal = {"player": PAL_PLAYER, "npc": PAL_NPC, "nurse": PAL_NURSE, "oak": PAL_OAK}[alvo]
    print(gerar_spritesheet(pal, saida))
