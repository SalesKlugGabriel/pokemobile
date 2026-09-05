#!/usr/bin/env python3
"""
etiquetar_biomas.py — Onde cada Pokémon vive (Fase 1, 05/09).

Aplica as 10 regras de bioma que o Gabriel definiu, escrevendo o campo `biomes`
das 151 espécies em `data/pokemon/species.json`.

Por que existe como ferramenta e não como edição à mão: são 151 espécies e as
regras vão mudar de novo (a Fase 4 do plano acrescenta terreno). Editar o JSON
na mão uma vez é rápido; editar três vezes sem uma regra escrita vira 151
decisões soltas que ninguém consegue conferir depois. Aqui a regra é o
arquivo-fonte, e o JSON é a saída.

As regras, como o Gabriel escreveu:
  Veneno    -> pântano (com áreas envenenadas)
  Água      -> debaixo d'água, ilhas e regiões costeiras
  Planta    -> florestas
  Inseto    -> florestas
  Pedra     -> montanhas e colinas
  Terra     -> montanhas e colinas
  Voador    -> florestas altas e montanhas
  Psíquico  -> desertos e estruturas antigas com ruínas
  Fantasma  -> prédios abandonados / ambientes escuros
  Fogo      -> vulcões e áreas incendiadas
  Elétrico  -> usinas
  Fada      -> meio da floresta fechada, escondidos

Tipos que ele não citou ficam com a leitura clássica da franquia, marcada
abaixo — nenhum é chute silencioso.

Roda com:  python3 tools/etiquetar_biomas.py [--conferir]
"""

import json
import sys
from collections import Counter

CAMINHO = "data/pokemon/species.json"

# ── Os 14 biomas ────────────────────────────────────────────────────────────
# 8 já existiam no arquivo; 6 são novos (marcados).
BIOMAS = [
    "plains", "forest", "deep_forest", "swamp", "mountain", "cave",
    "desert", "ruins", "haunted", "volcanic", "power_plant",
    "beach", "underwater", "glacial",
]
NOVOS = {"deep_forest", "swamp", "mountain", "desert", "ruins", "haunted"}

# ── Regra por tipo ──────────────────────────────────────────────────────────
POR_TIPO = {
    # as 10 regras do Gabriel
    "Poison":   ["swamp"],
    "Water":    ["beach", "underwater"],
    "Grass":    ["forest"],
    "Bug":      ["forest"],
    "Rock":     ["mountain"],
    "Ground":   ["mountain"],
    "Flying":   ["forest", "mountain"],
    "Psychic":  ["desert", "ruins"],
    "Ghost":    ["haunted"],
    "Fire":     ["volcanic"],
    "Electric": ["power_plant"],
    "Fairy":    ["deep_forest"],
    # tipos que ele não citou — leitura clássica da franquia, declarada
    "Normal":   ["plains"],          # campo aberto, perto das cidades
    "Ice":      ["glacial"],
    "Fighting": ["mountain", "cave"],  # dojos de montanha e cavernas
    "Dragon":   ["mountain", "underwater"],  # Dratini é d'água, Dragonite voa alto
    "Steel":    ["power_plant"],     # Magnemite/Magneton, os únicos da 1ª geração
}

# ── Ajustes por espécie ─────────────────────────────────────────────────────
# A regra por tipo acerta a esmagadora maioria, mas erra em casos que qualquer
# fã aponta na hora. Cada exceção aqui tem o motivo escrito — sem motivo, não
# entra na lista.
EXCECOES = {
    25:  ["forest", "power_plant"],   # Pikachu: a Floresta de Viridian é o lugar dele
    26:  ["power_plant"],             # Raichu
    10:  ["forest"], 11: ["forest"], 12: ["forest"],   # Caterpie: só floresta, apesar do Voador do Butterfree
    13:  ["forest"], 14: ["forest"], 15: ["forest"],   # Weedle: Inseto/Veneno, mas mora na mata
    16:  ["plains", "forest"], 17: ["plains", "forest"], 18: ["plains", "forest"],  # Pidgey vive perto das cidades
    35:  ["deep_forest"], 36: ["deep_forest"],         # Clefairy: Monte Lua no original, mata fechada aqui
    39:  ["deep_forest"], 40: ["deep_forest"],         # Jigglypuff
    172: ["deep_forest"],
    54:  ["beach"], 55: ["beach"],    # Psyduck é Água antes de ser Psíquico
    79:  ["beach"], 80: ["beach"],    # Slowpoke, idem
    92:  ["haunted"], 93: ["haunted"], 94: ["haunted"],  # a linha do Gastly é a razão do bioma existir
    201: ["ruins"],                   # Unown, se algum dia entrar
    132: ["plains"],                  # Ditto imita: aparece onde há gente
    143: ["mountain"],                # Snorlax dorme na estrada da montanha
    41:  ["cave"], 42: ["cave"],       # Zubat é Veneno/Voador, mas morcego mora em caverna
    50:  ["cave"], 51: ["cave"],       # Diglett cava; a Caverna do Diglett é o nome do lugar
    27:  ["desert"], 28: ["desert"],   # Sandshrew é o Terra do deserto, não da montanha
    95:  ["mountain", "cave"],         # Onix atravessa a rocha por dentro e por fora
    131: ["glacial", "underwater"],   # Lapras
    144: ["glacial"], 145: ["power_plant"], 146: ["volcanic"],  # as três aves lendárias
    150: ["ruins"], 151: ["deep_forest"],  # Mewtwo nas ruínas; Mew escondido na mata
}


def biomas_de(especie):
    ident = int(especie["id"])
    if ident in EXCECOES:
        return list(EXCECOES[ident])
    saida = []
    for t in especie.get("types", []):
        for b in POR_TIPO.get(t, []):
            if b not in saida:
                saida.append(b)
    if not saida:
        saida = ["plains"]
    return saida


def main():
    conferir = "--conferir" in sys.argv
    dados = json.load(open(CAMINHO, encoding="utf-8"))

    mudou = 0
    contagem = Counter()
    sem_bioma = []
    for chave, esp in dados.items():
        antes = list(esp.get("biomes", []))
        depois = biomas_de(esp)
        if antes != depois:
            mudou += 1
        esp["biomes"] = depois
        for b in depois:
            contagem[b] += 1
        if not depois:
            sem_bioma.append(esp["name"])

    desconhecidos = [b for b in contagem if b not in BIOMAS]
    assert not desconhecidos, f"bioma fora da lista: {desconhecidos}"
    assert not sem_bioma, f"espécie sem bioma: {sem_bioma}"

    print(f"{len(dados)} espécies · {mudou} mudaram de bioma")
    print()
    for b in BIOMAS:
        marca = " (novo)" if b in NOVOS else ""
        print(f"  {b:13s} {contagem.get(b, 0):3d} espécies{marca}")

    if conferir:
        print("\n--conferir: nada gravado.")
        return
    with open(CAMINHO, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"\ngravado em {CAMINHO}")


if __name__ == "__main__":
    main()
