#!/usr/bin/env python3
"""
normalizar_escala_pokemon.py — Corrige a escala dos 151 Pokémon (+ shiny).

PROBLEMA (medido, não achismo): os sprites vindos da PokeAPI ocupam frações
muito diferentes do frame de 128px. Bulbasaur usa 47x44 px; Charizard usa
128x111. Como o jogo desenha tudo em escala 1.0 (PokemonEntity.gd:51), no mundo
de tiles de 128px o Bulbasaur fica do tamanho de um inseto ao lado do Treinador
(que usa 80x196). Não é um problema de arte, é de escala.

SOLUÇÃO: normalizar, não uniformizar. Uma escala única não serve — o maior já
preenche o frame, então multiplicar tudo estouraria. Em vez disso, mapeia a
faixa de alturas atual (~40..111) para uma faixa alvo mais alta e mais estreita
(ALVO_MIN..ALVO_MAX), o que:
  - levanta muito os pequenos (Bulbasaur ~44 -> ~75),
  - quase não mexe nos grandes (Charizard ~111 -> ~120),
  - PRESERVA a ordem relativa (Snorlax continua maior que Caterpie).

Regras de segurança:
  - Escala NEAREST: pixel art continua pixel art, sem blur/suavização. Isto NÃO
    é "upscale + sharpen" (proibido pela Art Bible) — é reamostragem por vizinho
    mais próximo de arte que já é pixel.
  - Âncora no PÉ (base do conteúdo): o bicho cresce pra cima, então continua
    plantado no mesmo ponto onde a sombra do motor é desenhada.
  - A escala é calculada uma vez POR ESPÉCIE, olhando todos os 12 frames, e a
    variante shiny herda exatamente a mesma — senão normal e shiny ficariam de
    tamanhos diferentes.
  - Clamp: se a escala fizer o conteúdo passar do frame, reduz até caber.
"""

from PIL import Image
import glob
import os
import shutil

ALVO_MIN = 72.0     # altura alvo do menor Pokémon (Treinador tem 196)
ALVO_MAX = 120.0    # altura alvo do maior (frame é 128, deixa folga)
MARGEM = 4          # folga mínima até a borda do frame

DIR = "assets/sprites/pokemon"
BACKUP = "assets/old/pokemon"


def frames_de(img):
    fw, fh = img.size[0] // 3, img.size[1] // 4
    for r in range(4):
        for c in range(3):
            yield c, r, fw, fh, img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))


def altura_conteudo(path):
    img = Image.open(path).convert("RGBA")
    maior = 0
    for _, _, _, _, fr in frames_de(img):
        bb = fr.getbbox()
        if bb:
            maior = max(maior, bb[3] - bb[1])
    return maior


def reescalar(path, escala):
    img = Image.open(path).convert("RGBA")
    fw, fh = img.size[0] // 3, img.size[1] // 4
    saida = Image.new("RGBA", img.size, (0, 0, 0, 0))

    for c, r, _, _, fr in frames_de(img):
        bb = fr.getbbox()
        if not bb:
            continue
        conteudo = fr.crop(bb)
        cw, ch = conteudo.size
        nw, nh = max(1, round(cw * escala)), max(1, round(ch * escala))
        # clamp: nunca passar do frame
        if nw > fw - MARGEM:
            f = (fw - MARGEM) / nw
            nw, nh = round(nw * f), round(nh * f)
        if nh > fh - MARGEM:
            f = (fh - MARGEM) / nh
            nw, nh = round(nw * f), round(nh * f)

        grande = conteudo.resize((nw, nh), Image.NEAREST)

        # âncora: mesma base (pé) e mesmo centro horizontal do original
        base_y = bb[3]
        centro_x = (bb[0] + bb[2]) // 2
        dx = centro_x - nw // 2
        dy = base_y - nh
        # não deixar sair do frame
        dx = max(0, min(dx, fw - nw))
        dy = max(0, min(dy, fh - nh))
        saida.paste(grande, (c * fw + dx, r * fh + dy), grande)

    saida.save(path)


def main():
    os.makedirs(BACKUP, exist_ok=True)
    normais = sorted(p for p in glob.glob(f"{DIR}/mon_*.png") if "_shiny" not in p)

    alturas = {p: altura_conteudo(p) for p in normais}
    h_min = min(alturas.values())
    h_max = max(alturas.values())
    print(f"alturas atuais: min={h_min} max={h_max} ({len(normais)} especies)")

    mudou = 0
    for p in normais:
        h = alturas[p]
        alvo = ALVO_MIN + (h - h_min) * (ALVO_MAX - ALVO_MIN) / (h_max - h_min)
        escala = alvo / h
        if escala <= 1.001:
            continue
        for arq in (p, p.replace(".png", "_shiny.png")):
            if not os.path.exists(arq):
                continue
            bkp = os.path.join(BACKUP, os.path.basename(arq))
            if not os.path.exists(bkp):
                shutil.copy2(arq, bkp)
            reescalar(arq, escala)
        mudou += 1

    print(f"{mudou} espécies reescaladas (normal + shiny), backup em {BACKUP}")


if __name__ == "__main__":
    main()
