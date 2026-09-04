#!/usr/bin/env python3
"""
alinhar_pe_pokemon.py — Alinha o PÉ dos 151 Pokémon (+ shiny) na linha que o
motor espera. NÃO mexe no tamanho.

Correção do Gabriel (04/09): "o Pokémon está visualmente flutuando acima do
chão".

CAUSA (achada lendo o motor, não chutando): `PokemonScale.anchor_sprite_bottom()`
posiciona o sprite assumindo que o PÉ do bicho está na BASE do frame de 128px, e
`WildPokemon`/`FollowerPokemon` desenham a sombra de contato em y=+24 da origem.
Fazendo a conta: o frame ocupa y ∈ [-96, +32] na entidade, então a sombra (+24)
cai no pixel f=120 do frame. Só que os sprites da PokeAPI têm o conteúdo
centralizado, com a base variando por espécie (Charmander terminava em f≈95) —
ou seja, cada Pokémon flutuava uma altura diferente acima da própria sombra.

CORREÇÃO: encostar a base do conteúdo de TODA espécie em f=120.

SEGUNDA CORREÇÃO, da mesma investigação: os sprites também são normalizados pra
uma ALTURA NOMINAL ÚNICA (ALTURA_NOMINAL). Motivo: o jogo já tem `PokemonScale`,
que escala cada espécie pela altura oficial da Pokédex — mas os PNGs da PokeAPI
JÁ vinham com tamanhos bem diferentes entre si (Bulbasaur 44px, Charizard
106px). Os dois efeitos se multiplicavam: contagem dupla de tamanho, que deixava
os pequenos minúsculos e os grandes enormes.

Com o asset uniforme, `PokemonScale` volta a ser a ÚNICA fonte de diferença de
tamanho entre espécies — que é exatamente como ele foi projetado. Se o tamanho
relativo precisar de ajuste no futuro, o lugar é PokemonScale
(REFERENCE_HEIGHT_M / MIN_SCALE / MAX_SCALE), não este script.
"""

from PIL import Image
import glob
import os
import shutil

LINHA_PE = 120        # f=120 no frame de 128 — onde o motor desenha a sombra
# Altura nominal do conteúdo, igual pra todas as espécies. Escolhida contra a
# referência do Treinador (147 px): uma espécie de escala neutra (1.0 no
# PokemonScale, ou seja altura oficial ~1m) fica com ~51% da altura dele.
ALTURA_NOMINAL = 75
DIR = "assets/sprites/pokemon"
BACKUP = "assets/old/pokemon"


def alinhar(origem, destino):
    img = Image.open(origem).convert("RGBA")
    fw, fh = img.size[0] // 3, img.size[1] // 4
    saida = Image.new("RGBA", img.size, (0, 0, 0, 0))
    maior = 0
    for r in range(4):
        for c in range(3):
            fr = img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
            bb = fr.getbbox()
            if not bb:
                continue
            conteudo = fr.crop(bb)
            # normaliza a ALTURA (largura acompanha, proporção preservada)
            cw, ch = conteudo.size
            f = ALTURA_NOMINAL / ch
            nw, nh = max(1, round(cw * f)), max(1, round(ch * f))
            conteudo = conteudo.resize((nw, nh), Image.NEAREST)
            dx = (fw - conteudo.size[0]) // 2                 # centralizado em X
            dy = LINHA_PE - conteudo.size[1]                  # base do conteúdo na linha do pé
            dy = max(0, min(dy, fh - conteudo.size[1]))
            saida.paste(conteudo, (c * fw + dx, r * fh + dy), conteudo)
            maior = max(maior, conteudo.size[1])
    saida.save(destino)
    return maior


def main():
    arquivos = sorted(glob.glob(f"{DIR}/mon_*.png"))
    for arq in arquivos:
        bkp = os.path.join(BACKUP, os.path.basename(arq))
        if not os.path.exists(bkp):
            shutil.copy2(arq, bkp)
        # sempre parte do ORIGINAL guardado: garante que o tamanho volta ao
        # nativo da PokeAPI (desfaz a normalização de escala que eu tinha
        # aplicado antes de descobrir o PokemonScale) e só o pé é ajustado.
        alinhar(bkp, arq)
    print(f"{len(arquivos)} sprites com o pé alinhado em f={LINHA_PE}, altura nominal {ALTURA_NOMINAL}")


if __name__ == "__main__":
    main()
