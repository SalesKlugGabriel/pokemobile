#!/usr/bin/env python3
"""
gerar_audio.py — Trilha e efeitos do PokéMobile, sintetizados (04/09).

Por que existe: no teste de gameplay o jogo estava COMPLETAMENTE MUDO. A pasta
`assets/audio/` tinha zero arquivos e o console reclamava de 5 faltando. O
AudioManager já estava pronto e chamando — só não havia nada pra tocar.

Por que sintetizar em vez de baixar: mesma razão que fez os sprites e os tiles
serem gerados por script aqui. Áudio baixado exige conferir licença de cada
arquivo, e o resultado não seria editável. Assim o arquivo-fonte é ESTE script:
mudar um tema é mudar as notas aqui e rodar de novo.

Estilo: chiptune de onda quadrada/triângulo, que é a linguagem sonora do
Pokémon de Game Boy — combina com a pixel art e não tenta parecer orquestra.

Saída: .ogg em assets/audio/bgm e assets/audio/sfx (o AudioManager procura
.ogg). Precisa de ffmpeg no PATH pra converter o WAV cru.

Roda com:  python3 tools/gerar_audio.py
"""

import math
import os
import struct
import subprocess
import tempfile
import wave

TAXA = 44100
BGM_DIR = "assets/audio/bgm"
SFX_DIR = "assets/audio/sfx"

# ── Notas (Hz). Só as que os temas usam. ────────────────────────────────────
NOTAS = {}
for _oit in range(2, 7):
    for _i, _n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G",
                             "G#", "A", "A#", "B"]):
        NOTAS[f"{_n}{_oit}"] = 440.0 * (2 ** ((_oit - 4) + (_i - 9) / 12.0))
NOTAS["-"] = 0.0   # silêncio


# ── Osciladores ─────────────────────────────────────────────────────────────
def quadrada(fase, ciclo=0.5):
    return 1.0 if (fase % 1.0) < ciclo else -1.0


def triangulo(fase):
    f = fase % 1.0
    return 4.0 * abs(f - 0.5) - 1.0


def ruido(estado):
    """Ruído de registrador deslizante — o "pshhh" de percussão do Game Boy."""
    bit = ((estado >> 0) ^ (estado >> 1)) & 1
    estado = (estado >> 1) | (bit << 14)
    return (1.0 if (estado & 1) else -1.0), estado


def envelope(i, total, ataque=0.01, decaimento=0.25, sustain=0.6):
    """Ataque curto + queda: nota de chip nunca começa nem termina com clique."""
    t = i / TAXA
    dur = total / TAXA
    if t < ataque:
        return t / ataque
    if t > dur - 0.02:                       # solta no fim, evita estalo
        return max(0.0, (dur - t) / 0.02) * sustain
    d = t - ataque
    return sustain + (1.0 - sustain) * math.exp(-d / decaimento)


def nota(freq, dur_s, onda="quadrada", vol=0.25, ciclo=0.5, decai=0.25, sus=0.6):
    n = int(dur_s * TAXA)
    saida = [0.0] * n
    if freq <= 0:
        return saida
    passo = freq / TAXA
    for i in range(n):
        f = i * passo
        v = quadrada(f, ciclo) if onda == "quadrada" else triangulo(f)
        saida[i] = v * vol * envelope(i, n, decaimento=decai, sustain=sus)
    return saida


def percussao(dur_s, vol=0.18):
    n = int(dur_s * TAXA)
    saida = [0.0] * n
    est = 0x7FFF
    for i in range(n):
        v, est = ruido(est)
        saida[i] = v * vol * math.exp(-4.0 * i / n)
    return saida


def somar(*trilhas):
    """Mixa trilhas de tamanhos diferentes, com clipe suave no fim."""
    tam = max(len(t) for t in trilhas)
    mix = [0.0] * tam
    for t in trilhas:
        for i, v in enumerate(t):
            mix[i] += v
    return [max(-1.0, min(1.0, v)) for v in mix]


def sequencia(passos, bpm, onda="quadrada", vol=0.22, ciclo=0.5):
    """passos: lista de (nome_da_nota, batidas)."""
    seg_por_batida = 60.0 / bpm
    saida = []
    for nome, batidas in passos:
        saida += nota(NOTAS[nome], batidas * seg_por_batida, onda, vol, ciclo)
    return saida


def gravar(amostras, caminho_ogg, qualidade=4):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in amostras))
    os.makedirs(os.path.dirname(caminho_ogg), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-c:a", "libvorbis", "-q:a", str(qualidade), caminho_ogg],
                   check=True)
    os.unlink(wav)
    print(f"  {caminho_ogg}  ({os.path.getsize(caminho_ogg) // 1024} KB)")


# ── Temas ───────────────────────────────────────────────────────────────────
def tema_overworld():
    """Cidade/mapa: alegre, andamento médio, feito pra repetir sem cansar."""
    bpm = 132
    melodia = [("G4", 1), ("A4", .5), ("B4", .5), ("D5", 1), ("B4", 1),
               ("A4", 1), ("G4", .5), ("A4", .5), ("B4", 1), ("-", 1),
               ("E5", 1), ("D5", .5), ("B4", .5), ("A4", 1), ("G4", 1),
               ("D5", 1), ("B4", .5), ("A4", .5), ("G4", 2)]
    baixo = [("G2", 1), ("G2", 1), ("D3", 1), ("D3", 1),
             ("E3", 1), ("E3", 1), ("C3", 1), ("C3", 1)] * 2
    ritmo = []
    for _ in range(16):
        ritmo += percussao(60.0 / bpm * 0.5) + [0.0] * int(60.0 / bpm * 0.5 * TAXA)
    return somar(sequencia(melodia, bpm, "quadrada", .20, .5),
                 sequencia(baixo, bpm, "triangulo", .22),
                 ritmo)


def tema_titulo():
    """Abertura: fanfarra curta e solene, mais lenta."""
    bpm = 96
    melodia = [("C4", 1), ("E4", 1), ("G4", 1), ("C5", 2), ("B4", .5), ("G4", .5),
               ("A4", 2), ("F4", 1), ("G4", 1), ("C5", 3), ("-", 1)]
    baixo = [("C3", 2), ("C3", 2), ("G2", 2), ("A2", 2), ("F2", 2), ("C3", 2)]
    return somar(sequencia(melodia, bpm, "quadrada", .22, .25),
                 sequencia(baixo, bpm, "triangulo", .20))


def tema_batalha():
    """Batalha selvagem: rápido, tenso, notas curtas."""
    bpm = 168
    melodia = [("E4", .5), ("E4", .5), ("G4", .5), ("E4", .5), ("A4", 1), ("G4", 1),
               ("E4", .5), ("D4", .5), ("E4", .5), ("G4", .5), ("B4", 1), ("A4", 1),
               ("C5", .5), ("B4", .5), ("A4", .5), ("G4", .5), ("E4", 2)]
    baixo = [("E2", .5)] * 8 + [("A2", .5)] * 4 + [("G2", .5)] * 4 + [("E2", .5)] * 8
    ritmo = []
    for _ in range(24):
        ritmo += percussao(60.0 / bpm * 0.5, .14)
    return somar(sequencia(melodia, bpm, "quadrada", .20, .25),
                 sequencia(baixo, bpm, "triangulo", .24),
                 ritmo)


def tema_batalha_treinador():
    """Treinador: mesma pegada da batalha, um tom acima e mais marcada."""
    bpm = 176
    melodia = [("A4", .5), ("A4", .5), ("C5", .5), ("A4", .5), ("D5", 1), ("C5", 1),
               ("A4", .5), ("G4", .5), ("A4", .5), ("C5", .5), ("E5", 1), ("D5", 1),
               ("F5", .5), ("E5", .5), ("D5", .5), ("C5", .5), ("A4", 2)]
    baixo = [("A2", .5)] * 8 + [("D3", .5)] * 4 + [("C3", .5)] * 4 + [("A2", .5)] * 8
    ritmo = []
    for _ in range(24):
        ritmo += percussao(60.0 / bpm * 0.5, .16)
    return somar(sequencia(melodia, bpm, "quadrada", .21, .25),
                 sequencia(baixo, bpm, "triangulo", .24),
                 ritmo)


def tema_gameover():
    bpm = 76
    melodia = [("G4", 1), ("F4", 1), ("E4", 1), ("D4", 2), ("C4", 3)]
    baixo = [("C3", 2), ("A2", 2), ("F2", 2), ("C2", 2)]
    return somar(sequencia(melodia, bpm, "triangulo", .22),
                 sequencia(baixo, bpm, "triangulo", .18))


def tema_creditos():
    bpm = 104
    melodia = [("C5", 1), ("B4", .5), ("A4", .5), ("G4", 1), ("E4", 1),
               ("F4", 1), ("G4", 1), ("A4", 2),
               ("G4", 1), ("F4", .5), ("E4", .5), ("D4", 1), ("C4", 3)]
    baixo = [("C3", 2), ("G2", 2), ("A2", 2), ("F2", 2), ("C3", 2), ("G2", 2)]
    return somar(sequencia(melodia, bpm, "quadrada", .19, .5),
                 sequencia(baixo, bpm, "triangulo", .20))


# ── Efeitos ─────────────────────────────────────────────────────────────────
def sfx_confirmar():
    return nota(NOTAS["E5"], .06, vol=.3) + nota(NOTAS["A5"], .10, vol=.3)


def sfx_cancelar():
    return nota(NOTAS["A4"], .06, vol=.28) + nota(NOTAS["E4"], .10, vol=.28)


def sfx_menu():
    return nota(NOTAS["C5"], .05, vol=.24, ciclo=.25)


def sfx_selecao():
    return nota(NOTAS["G5"], .04, vol=.22, ciclo=.25)


def sfx_dano():
    s = percussao(.09, .30)
    return somar(s, nota(NOTAS["C3"], .09, "quadrada", .22, ciclo=.25))


def sfx_encontro():
    """Três subidas rápidas — o "achou alguém!" do original."""
    return (nota(NOTAS["C5"], .07, vol=.26) + nota(NOTAS["E5"], .07, vol=.26)
            + nota(NOTAS["G5"], .07, vol=.26) + nota(NOTAS["C6"], .16, vol=.28))


def sfx_arremesso():
    """Pokébola voando: glissando pra cima."""
    n = int(.28 * TAXA)
    s = [0.0] * n
    f = 0.0
    for i in range(n):
        freq = 300 + 900 * (i / n)
        f += freq / TAXA
        s[i] = quadrada(f, .25) * .22 * (1 - i / n)
    return s


def sfx_capturou():
    return (nota(NOTAS["C5"], .10, vol=.28) + nota(NOTAS["E5"], .10, vol=.28)
            + nota(NOTAS["G5"], .10, vol=.28) + nota(NOTAS["C6"], .30, vol=.30))


def sfx_subiu_nivel():
    return (nota(NOTAS["G4"], .08, vol=.28) + nota(NOTAS["C5"], .08, vol=.28)
            + nota(NOTAS["E5"], .08, vol=.28) + nota(NOTAS["G5"], .08, vol=.28)
            + nota(NOTAS["C6"], .35, vol=.30))


def sfx_curar():
    return (nota(NOTAS["C5"], .12, "triangulo", .26)
            + nota(NOTAS["G5"], .12, "triangulo", .26)
            + nota(NOTAS["C6"], .24, "triangulo", .26))


def sfx_item():
    return (nota(NOTAS["A4"], .07, vol=.26) + nota(NOTAS["D5"], .07, vol=.26)
            + nota(NOTAS["A5"], .20, vol=.28))


def sfx_pescar():
    n = int(.22 * TAXA)
    s = [0.0] * n
    f = 0.0
    for i in range(n):
        freq = 900 - 600 * (i / n)
        f += freq / TAXA
        s[i] = triangulo(f) * .20 * (1 - i / n)
    return s


BGM = {
    "overworld": tema_overworld, "title": tema_titulo, "battle": tema_batalha,
    "battle_trainer": tema_batalha_treinador, "gameover": tema_gameover,
    "credits": tema_creditos,
}
SFX = {
    "confirm": sfx_confirmar, "cancel": sfx_cancelar, "menu_open": sfx_menu,
    "menu_close": sfx_cancelar, "menu_select": sfx_selecao, "select": sfx_selecao,
    "hit": sfx_dano, "encounter": sfx_encontro, "catch_throw": sfx_arremesso,
    "catch_success": sfx_capturou, "level_up": sfx_subiu_nivel, "heal": sfx_curar,
    "item_get": sfx_item, "fishing_cast": sfx_pescar,
}


def main():
    print("BGM:")
    for nome, fn in BGM.items():
        gravar(fn(), f"{BGM_DIR}/{nome}.ogg", qualidade=3)
    print("SFX:")
    for nome, fn in SFX.items():
        gravar(fn(), f"{SFX_DIR}/{nome}.ogg", qualidade=5)


if __name__ == "__main__":
    main()
