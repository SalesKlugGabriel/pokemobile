#!/usr/bin/env python3
"""
gerar_ui_pixelart.py — Gera as texturas 9-slice da interface em pixel art.

Mesma filosofia do gerador de personagem: cada pixel é colocado por código, então
este arquivo é o "fonte editável" da UI. Trocar a paleta aqui restila o jogo inteiro.

Por que 9-slice: uma textura pequena (12x12 lógicos) com as bordas marcadas vira
painel/botão de QUALQUER tamanho sem esticar a borda — é assim que UI de pixel art
escala sem borrar. As margens da StyleBoxTexture no tema apontam pra essa borda.

Paleta: seção UI da Art Bible.
  painel  #22201C   borda clara #3A362F   borda escura #151412   contorno #0A0908
  acento  #D4A868 (mesmo dourado do GROUND, pra UI não introduzir cor nova)

Regra de luz (Art Bible): luz de CIMA-ESQUERDA — topo/esquerda recebem o tom claro,
baixo/direita o escuro. Botão pressionado inverte o bisel (é o que dá a sensação de
afundar sem precisar de animação).

⚠️ Barras de progresso: OverworldHUD.gd colore as barras por `modulate`
(verde/amarelo/vermelho no HP, azul/laranja no cooldown). `modulate` MULTIPLICA a
cor da textura, então o preenchimento tem que ser quase branco — se fosse verde,
verde × verde daria uma cor errada. Por isso ui_bar_fill é neutro de propósito.
"""

from PIL import Image
import os

SCALE = 4

CONTORNO = (10, 9, 8, 255)
PAINEL = (34, 32, 28, 255)
BORDA_CLARA = (74, 70, 61, 255)
BORDA_ESCURA = (21, 20, 18, 255)
ACENTO = (212, 168, 104, 255)

BTN_NORMAL = (42, 40, 35, 255)
BTN_HOVER = (58, 54, 47, 255)
BTN_PRESSED = (26, 24, 21, 255)
BTN_DISABLED = (30, 28, 25, 255)
BORDA_MUDA = (42, 40, 35, 255)

BAR_FUNDO = (21, 20, 18, 255)
BAR_FILL = (232, 232, 232, 255)      # neutro: quem dá a cor é o modulate do jogo
BAR_FILL_HI = (255, 255, 255, 255)


def caixa(n, fill, claro, escuro, contorno=CONTORNO, inverter=False, acento=None):
    """Desenha uma caixa n x n com contorno + bisel de 1px + preenchimento.

    inverter=True troca claro/escuro de lado (botão afundado).
    acento: se dado, pinta o anel externo com essa cor (usado no hover).
    """
    img = Image.new("RGBA", (n, n), fill)
    px = img.load()
    c_top, c_bot = (escuro, claro) if inverter else (claro, escuro)
    for y in range(n):
        for x in range(n):
            borda_ext = x == 0 or y == 0 or x == n - 1 or y == n - 1
            borda_int = x == 1 or y == 1 or x == n - 2 or y == n - 2
            if borda_ext:
                px[x, y] = acento if acento else contorno
            elif borda_int:
                # canto superior-esquerdo recebe o tom de luz, inferior-direito a sombra
                px[x, y] = c_top if (x <= y and x <= n - 1 - y) or (y <= x and y <= n - 1 - x) and y < n // 2 else c_bot
                if x == 1 or y == 1:
                    px[x, y] = c_top
                if x == n - 2 or y == n - 2:
                    px[x, y] = c_bot
                # canto: prioridade pro lado iluminado no topo-esquerda
                if x == 1 and y == 1:
                    px[x, y] = c_top
                if x == n - 2 and y == n - 2:
                    px[x, y] = c_bot
    return img


def barra_fundo(n):
    """Sulco afundado: bisel invertido (escuro em cima) + fundo bem escuro."""
    return caixa(n, BAR_FUNDO, BORDA_CLARA, BORDA_ESCURA, inverter=True)


def barra_fill(n):
    """Preenchimento neutro com brilho no topo — a cor vem do modulate do jogo."""
    img = Image.new("RGBA", (n, n), BAR_FILL)
    px = img.load()
    for x in range(n):
        px[x, 0] = BAR_FILL_HI
        px[x, n - 1] = (188, 188, 188, 255)
    for y in range(n):
        px[0, y] = BAR_FILL_HI if y < n // 2 else (188, 188, 188, 255)
        px[n - 1, y] = (188, 188, 188, 255)
    return img


def salvar(img, destino):
    n = img.size[0]
    img.resize((n * SCALE, n * SCALE), Image.NEAREST).save(destino)
    return destino


if __name__ == "__main__":
    out = "assets/ui/theme"
    os.makedirs(out, exist_ok=True)
    N = 12   # caixa lógica; borda de 2px => margem 9-slice de 8px depois do 4x
    B = 8    # barras são menores (bisel de 1px basta)

    salvar(caixa(N, PAINEL, BORDA_CLARA, BORDA_ESCURA), f"{out}/ui_panel.png")
    salvar(caixa(N, BTN_NORMAL, BORDA_CLARA, BORDA_ESCURA), f"{out}/ui_button_normal.png")
    salvar(caixa(N, BTN_HOVER, BORDA_CLARA, BORDA_ESCURA, acento=ACENTO), f"{out}/ui_button_hover.png")
    salvar(caixa(N, BTN_PRESSED, BORDA_CLARA, BORDA_ESCURA, inverter=True), f"{out}/ui_button_pressed.png")
    salvar(caixa(N, BTN_DISABLED, BORDA_MUDA, BORDA_ESCURA), f"{out}/ui_button_disabled.png")
    salvar(barra_fundo(B), f"{out}/ui_bar_bg.png")
    salvar(barra_fill(B), f"{out}/ui_bar_fill.png")
    print("texturas de UI geradas em", out)
