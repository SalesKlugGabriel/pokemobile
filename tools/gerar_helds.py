#!/usr/bin/env python3
"""
gerar_helds.py — Os itens equipados (09/09/2026).

Item 03 da fila. Pesquisa feita no PokeXGames: lá são ~35 helds em 9 tiers,
divididos em dois encaixes — um **X** (combate) e um **Y** (utilidade) — e cada
Pokémon segura no máximo dois, **um de cada**. É essa regra que faz held ser
uma ESCOLHA e não uma lista de bônus empilhados.

O que eu trouxe de lá:
  · os dois encaixes (obriga a escolher entre bater mais e sobreviver mais);
  · tiers (progressão sem inventar item novo);
  · a fusão de repetidos (dá destino pro held que sobra).

O que eu deixei lá, e por quê:
  · 9 tiers — é MMO com anos de vida; aqui 3 bastam pra a progressão ser legível;
  · pagar pra desequipar — num jogo solo isso é só pedágio;
  · a economia de tokens — existe porque lá tem torneio semanal e milhares de
    jogadores; aqui o dinheiro do loot já faz esse papel.

Os SETE efeitos foram escolhidos por um critério só: o motor já sabe medir cada
um deles hoje. Held que promete o que o jogo não mede é número decorativo.

Roda com:  python3 tools/gerar_helds.py
"""

import collections
import io
import json

# efeito -> (encaixe, nome, valores por tier, texto)
EFEITOS = collections.OrderedDict([
    ("dano_tipo", ("combate", "Presa", [0.12, 0.20, 0.35],
                   "Aumenta o dano dos golpes de %s em %d%%.")),
    ("recarga", ("combate", "Cronômetro", [0.08, 0.14, 0.22],
                 "Reduz em %d%% a espera entre os golpes.")),
    ("retorno", ("combate", "Espinho", [0.10, 0.18, 0.28],
                 "Devolve %d%% do dano que você recebe a quem bateu.")),
    ("sorte", ("utilidade", "Trevo", [0.20, 0.45, 0.80],
               "Aumenta em %d%% a chance dos drops raros.")),
    ("experiencia", ("utilidade", "Pergaminho", [0.10, 0.20, 0.35],
                     "Aumenta em %d%% a experiência ganha.")),
    ("regeneracao", ("utilidade", "Musgo", [0.01, 0.02, 0.035],
                     "Recupera %d%% da vida por segundo fora de combate.")),
    ("cura_status", ("utilidade", "Folha Limpa", [0.25, 0.5, 1.0],
                     "%d%% de chance de curar sozinho um status a cada poucos segundos.")),
])

TIERS = collections.OrderedDict([
    (1, ("Bronze", 3000)),
    (2, ("Prata", 12000)),
    (3, ("Ouro", 45000)),
])

# O held de dano é por tipo — os quatro que já existiam no jogo viram tier 1 do
# efeito `dano_tipo`, em vez de eu criar itens paralelos que fariam a mesma
# coisa com outro nome.
TIPOS_DANO = collections.OrderedDict([
    ("Fire", ("brasa", "Fogo")),
    ("Water", ("gota", "Água")),
    ("Grass", ("semente", "Planta")),
    ("Electric", ("faisca", "Elétrico")),
])

## Fusão: 3 iguais viram 1 do tier acima. O custo é em dinheiro, e é o que dá
## destino pro dinheiro do loot depois que a mochila já está cheia de poção.
CUSTO_FUSAO = {1: 8000, 2: 30000}


def main():
    p = "data/items/items.json"
    itens = json.load(io.open(p, encoding="utf-8"),
                      object_pairs_hook=collections.OrderedDict)

    criados = 0
    for efeito, (encaixe, nome_base, valores, texto) in EFEITOS.items():
        for tier, (nome_tier, preco) in TIERS.items():
            valor = valores[tier - 1]
            if efeito == "dano_tipo":
                for tipo, (sufixo, tipo_pt) in TIPOS_DANO.items():
                    item_id = "held_%s_%s_t%d" % (efeito, sufixo, tier)
                    itens[item_id] = collections.OrderedDict([
                        ("id", item_id),
                        ("name", "%s de %s %s" % (nome_base, tipo_pt, nome_tier)),
                        ("category", "held"),
                        ("held_slot", encaixe),
                        ("held_effect", efeito),
                        ("held_value", valor),
                        ("held_type", tipo),
                        ("tier", tier),
                        ("price", preco),
                        ("description", texto % (tipo_pt, round(valor * 100))),
                    ])
                    criados += 1
            else:
                item_id = "held_%s_t%d" % (efeito, tier)
                itens[item_id] = collections.OrderedDict([
                    ("id", item_id),
                    ("name", "%s %s" % (nome_base, nome_tier)),
                    ("category", "held"),
                    ("held_slot", encaixe),
                    ("held_effect", efeito),
                    ("held_value", valor),
                    ("tier", tier),
                    ("price", preco),
                    ("description", texto % round(valor * 100)),
                ])
                criados += 1

    # Os quatro helds antigos ("+20% de um tipo") viram apelido do tier 2 do
    # efeito de dano — mesma função, e assim nenhum save antigo perde o item.
    antigos = {"charcoal": "Fire", "mystic_water": "Water",
               "miracle_seed": "Grass", "magnet": "Electric"}
    for antigo, tipo in antigos.items():
        if antigo in itens:
            sufixo = TIPOS_DANO[tipo][0]
            itens[antigo]["held_slot"] = "combate"
            itens[antigo]["held_effect"] = "dano_tipo"
            itens[antigo]["held_value"] = EFEITOS["dano_tipo"][2][1]
            itens[antigo]["held_type"] = tipo
            itens[antigo]["tier"] = 2
            itens[antigo]["fuses_into"] = "held_dano_tipo_%s_t3" % sufixo

    # Cadeia de fusão: cada tier aponta pro seguinte.
    for item_id, dados in list(itens.items()):
        if dados.get("category") != "held":
            continue
        tier = int(dados.get("tier", 0))
        if tier in (1, 2) and item_id.endswith("_t%d" % tier):
            seguinte = item_id[:-2] + "t%d" % (tier + 1)
            if seguinte in itens:
                dados["fuses_into"] = seguinte
                dados["fusion_cost"] = CUSTO_FUSAO[tier]

    io.open(p, "w", encoding="utf-8").write(
        json.dumps(itens, ensure_ascii=False, indent=2))

    total = len([1 for v in itens.values() if v.get("category") == "held"])
    combate = len([1 for v in itens.values()
                   if v.get("category") == "held" and v.get("held_slot") == "combate"])
    print("helds criados: %d (total no jogo: %d)" % (criados, total))
    print("  encaixe combate: %d · utilidade: %d" % (combate, total - combate))
    print("efeitos: %s" % ", ".join(EFEITOS.keys()))


if __name__ == "__main__":
    main()
