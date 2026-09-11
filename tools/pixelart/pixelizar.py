#!/usr/bin/env python3
"""
pixelizar.py — Converte um render do Blender em pixel art utilizável.

É a segunda metade do pipeline da RFC-005. O render sai bonito e ERRADO pra
este jogo: medido, um render de 64x64 da casa de exemplo saiu com **138 cores
distintas**. Pixel art de RPG vive com 8 a 24. Sem esta etapa, o asset gerado
em 3D grita "eu vim de outro lugar" ao lado dos 638 PNGs que já existem.

O que faz, em ordem:

  1. RECORTA o transparente sobrando (o render deixa margem morta);
  2. REDUZ pro tamanho final com vizinho mais próximo (nunca suavizar — é o que
     transforma pixel art em borrão);
  3. QUANTIZA a paleta pra um número pequeno de cores;
  4. opcionalmente CONTORNA com uma linha escura, que é o que dá leitura ao
     sprite em cima de qualquer fundo.

USO
    python3 tools/pixelart/pixelizar.py entrada.png saida.png \\
        --tamanho 32 --cores 12 --contorno

Precisa só de Pillow, que já está instalado.
"""
import argparse
import os
from PIL import Image


def recortar(im):
    """Tira a margem transparente. Render quase sempre deixa sobra."""
    caixa = im.getbbox()
    return im.crop(caixa) if caixa else im


## Densidade dos tiles do jogo, medida no atlas. É o alvo.
DENSIDADE_DO_JOGO = 0.51
DENSIDADE_MINIMA = 0.15


def densidade(im):
    """Cores distintas por pixel opaco — a medida de 'quão texturizado'."""
    px = [p for p in im.getdata() if p[3] > 200]
    return len(set(p[:3] for p in px)) / len(px) if px else 0.0


def reduzir(im, lado):
    """Reduz cabendo no quadrado, com LANCZOS.

    Mantém a proporção e centraliza — esticar um sprite pra caber num quadrado
    deforma a construção, e num tile de 32px isso é visível de imediato.

    LANCZOS, e não NEAREST: ver a nota do cabeçalho. Medido, NEAREST entrega
    0,09 de densidade contra 0,44 do LANCZOS, num jogo cuja arte mede 0,51.
    """
    w, h = im.size
    escala = min(lado / w, lado / h)
    novo = (max(1, int(w * escala)), max(1, int(h * escala)))
    reduzida = im.resize(novo, Image.LANCZOS)
    tela = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    tela.paste(reduzida, ((lado - novo[0]) // 2, (lado - novo[1]) // 2))
    return tela


def quantizar(im, cores):
    """Corta a paleta pra `cores` tons, preservando a transparência.

    O alfa é separado antes e reaplicado depois: quantizar junto com o alfa
    cria pixels meio-transparentes coloridos na borda, que é o artefato que faz
    o sprite parecer sujo.
    """
    alfa = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=cores, method=Image.MEDIANCUT)
    saida = rgb.convert("RGBA")
    # Alfa vira binário: ou é sprite, ou é fundo. Meio-termo não existe em
    # pixel art de tile.
    saida.putalpha(alfa.point(lambda v: 255 if v > 128 else 0))
    return saida


def contornar(im, cor=(24, 20, 32, 255)):
    """Linha escura ao redor do que é opaco. É o que faz o sprite ler em cima
    de grama, areia ou pedra sem sumir."""
    px = im.load()
    w, h = im.size
    borda = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    borda.append((x, y))
                    break
    for x, y in borda:
        px[x, y] = cor
    return im


def main():
    p = argparse.ArgumentParser()
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--tamanho", type=int, default=32)
    p.add_argument("--cores", type=int, default=0,
                   help="0 = não quantizar (padrão). Quantizar SEMPRE reduz a "
                        "densidade e afasta do estilo do jogo — só use se souber por quê")
    p.add_argument("--contorno", action="store_true")
    a = p.parse_args()

    im = Image.open(a.entrada).convert("RGBA")
    antes = len(set(p[:3] for p in im.getdata() if p[3] > 10))

    im = recortar(im)
    im = reduzir(im, a.tamanho)
    if a.cores > 0:
        im = quantizar(im, a.cores)
    if a.contorno:
        im = contornar(im)

    os.makedirs(os.path.dirname(a.saida) or ".", exist_ok=True)
    im.save(a.saida)

    d = densidade(im)
    depois = len(set(p[:3] for p in im.getdata() if p[3] > 200))
    print(f"[pixelart] {os.path.basename(a.entrada)}: {antes} -> {depois} cores "
          f"em {a.tamanho}x{a.tamanho} · densidade {d:.2f} -> {a.saida}")
    if d < DENSIDADE_MINIMA:
        print(f"           ⚠ CHAPADO: {d:.2f} contra {DENSIDADE_DO_JOGO:.2f} do jogo. "
              f"Renderize maior (4 a 8x o alvo) e não quantize.")


if __name__ == "__main__":
    main()
