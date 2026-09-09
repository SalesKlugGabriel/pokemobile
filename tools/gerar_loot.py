#!/usr/bin/env python3
"""
gerar_loot.py — A economia do jogo: o que cada Pokémon deixa cair, e quanto
vale (09/09/2026).

🔴 Por que existe: o Gabriel perguntou se o loot existia. Não existia. O que
havia era uma tabela por "tier" que dropava poção, revive e Doce Raro — ou
seja, o jogo dava de graça exatamente o que ele quer que seja SÓ de compra, e
não dava nada do que devia dar.

O DESENHO, copiado da estrutura do otPokemon (três camadas), porque é ela que
faz a economia funcionar:

  1. FRAGMENTO do tipo   — todo Pokémon daquele tipo dropa. É o troco do dia a
                           dia: sozinho não vale nada, junto paga a poção.
  2. AMULETO do tipo     — mais raro. É o drop que anima quando cai.
  3. PEÇA DE ESPÉCIE     — só AQUELE Pokémon dropa (Barbatana de Magikarp,
                           Garra de Krabby). É o que dá motivo pra caçar UM
                           bicho específico em vez de qualquer um.
  4. PEDRA DE EVOLUÇÃO   — raríssima, e a única fonte no mundo aberto.
  5. MT DO TIPO          — regra do Gabriel: **só de evolução final**, taxa de
                           0,5%. Super rara de propósito: é a única fonte
                           dessas MTs no jogo inteiro.

E a contrapartida, também pedido dele: **cura, revive e XP saem dos drops** e
passam a ser só de compra — com preço que pesa. Sem isso, o dinheiro do loot
não teria pra que servir.

Roda com:  python3 tools/gerar_loot.py
"""

import json
import collections
import io

TIPOS_PT = {
    "Normal": "Normal", "Fire": "Fogo", "Water": "Água", "Electric": "Elétrico",
    "Grass": "Planta", "Ice": "Gelo", "Fighting": "Luta", "Poison": "Veneno",
    "Ground": "Terra", "Flying": "Voador", "Psychic": "Psíquico", "Bug": "Inseto",
    "Rock": "Pedra", "Ghost": "Fantasma", "Dragon": "Dragão", "Dark": "Sombrio",
    "Steel": "Aço", "Fairy": "Fada",
}

# ── Preços (o dossiê pedido pelo Gabriel) ────────────────────────────────────
# A régua: um fragmento paga ~1/8 de poção. Um amuleto paga uma poção inteira.
# Uma peça de espécie paga duas. A venda devolve 50% (SELL_RATIO da loja), então
# o preço aqui é o "de tabela" e o jogador recebe metade.
PRECO_FRAGMENTO = 80
PRECO_AMULETO = 900
PRECO_PECA = 1400
PRECO_PEDRA_LOOT = 12000

# Consumível ficou CARO de propósito: é o que faz o loot valer a pena e a
# preparação pesar antes de entrar numa dungeon.
PRECOS_CONSUMIVEIS = {
    "potion": 800, "super_potion": 1800, "hyper_potion": 3500,
    "max_potion": 6500, "full_restore": 9000,
    "revive": 5000, "max_revive": 12000,
    "antidote": 400, "burn_heal": 400, "ice_heal": 400, "awakening": 400,
    "parlyz_heal": 400, "full_heal": 1600,
    "ether": 2500, "max_ether": 5000, "elixir": 4000, "max_elixir": 8000,
    # XP e nível: caros porque são atalho. Antes o Doce Raro CAÍA de graça.
    "rare_candy": 15000,
    "hp_up": 6000, "protein": 6000, "iron": 6000,
    "calcium": 6000, "carbos": 6000, "zinc": 6000,
    "pp_up": 9000,
}

# ── Peça de espécie: só estes dropam, e é o que os torna alvo ────────────────
# Escolhidos por serem reconhecíveis — a peça tem que dizer de quem é.
PECAS = {
    129: ("magikarp_fin", "Barbatana de Magikarp"),
    98:  ("krabby_claw", "Garra de Krabby"),
    79:  ("slowpoke_tail", "Cauda de Slowpoke"),
    27:  ("sandshrew_claw", "Garra de Sandshrew"),
    23:  ("ekans_fang", "Presa de Ekans"),
    50:  ("diglett_dirt", "Terra de Diglett"),
    56:  ("mankey_fur", "Pelo de Mankey"),
    77:  ("ponyta_ember", "Brasa de Ponyta"),
    83:  ("farfetchd_leek", "Alho-poró de Farfetch'd"),
    90:  ("shellder_pearl", "Pérola de Shellder"),
    100: ("voltorb_coil", "Bobina de Voltorb"),
    102: ("exeggcute_shell", "Casca de Exeggcute"),
    104: ("cubone_bone", "Osso de Cubone"),
    108: ("lickitung_lick", "Saliva de Lickitung"),
    109: ("koffing_gas", "Gás de Koffing"),
    111: ("rhyhorn_horn", "Chifre de Rhyhorn"),
    114: ("tangela_vine", "Cipó de Tangela"),
    116: ("horsea_ink", "Tinta de Horsea"),
    120: ("staryu_core", "Núcleo de Staryu"),
    128: ("tauros_hide", "Couro de Tauros"),
    138: ("omanyte_shell", "Concha de Omanyte"),
    140: ("kabuto_shell", "Carapaça de Kabuto"),
    147: ("dratini_scale", "Escama de Dratini"),
    25:  ("pikachu_static", "Estática de Pikachu"),
}

# ── Pedra por tipo (as 5 que existem no jogo) ────────────────────────────────
PEDRA_POR_TIPO = {
    "Fire": "fire_stone", "Water": "water_stone", "Electric": "thunder_stone",
    "Grass": "leaf_stone", "Fairy": "moon_stone", "Psychic": "moon_stone",
}

# ── MT por tipo: a assinatura do tipo, só de evolução final ─────────────────
# Alguns golpes não existiam no moves.json e são criados abaixo — o Gabriel
# citou "leaf > giga drain" e "fire > inferno" nominalmente.
MT_POR_TIPO = {
    "Ground": ("earthquake", "Terremoto", 100, "physical"),
    "Grass": ("giga_drain", "Giga Drenar", 75, "special"),
    "Fire": ("inferno", "Inferno", 100, "special"),
    "Water": ("hydro_pump", "Hidro Bomba", 110, "special"),
    "Electric": ("thunder", "Trovão", 110, "special"),
    "Ice": ("blizzard", "Nevasca", 110, "special"),
    "Psychic": ("psychic", "Psíquico", 90, "special"),
    "Rock": ("rock_slide", "Rocha Explosiva", 75, "physical"),
    "Poison": ("sludge_bomb", "Bomba de Lodo", 90, "special"),
    "Ghost": ("shadow_ball", "Bola Sombria", 80, "special"),
    "Dragon": ("dragon_claw", "Garra de Dragão", 80, "physical"),
    "Fighting": ("close_combat", "Combate Fechado", 120, "physical"),
    "Flying": ("air_slash", "Corte de Ar", 75, "special"),
    "Bug": ("megahorn", "Mega Chifre", 120, "physical"),
    "Normal": ("hyper_beam", "Hiper Raio", 150, "special"),
    "Steel": ("iron_head", "Cabeça de Ferro", 80, "physical"),
    "Fairy": ("dazzling_gleam", "Brilho Deslumbrante", 80, "special"),
    "Dark": ("crunch", "Mordida Forte", 80, "physical"),
}

CHANCE_MT = 0.005          # 0,5% — regra do Gabriel: super raro
CHANCE_PEDRA = 0.004
CHANCE_PECA = 0.06
CHANCE_AMULETO = 0.14
CHANCE_FRAGMENTO = 0.55


def carregar(caminho):
    return json.load(io.open(caminho, encoding="utf-8"),
                     object_pairs_hook=collections.OrderedDict)


def gravar(caminho, dados):
    io.open(caminho, "w", encoding="utf-8").write(
        json.dumps(dados, ensure_ascii=False, indent=2))


def main():
    itens = carregar("data/items/items.json")
    golpes = carregar("data/moves/moves.json")
    especies_arq = carregar("data/pokemon/species.json")
    especies = especies_arq["species"] if isinstance(especies_arq, dict) and "species" in especies_arq else especies_arq
    lista = especies if isinstance(especies, list) else list(especies.values())

    tipos = sorted({t for e in lista for t in e.get("types", [])})

    # 1) Fragmentos e amuletos por tipo
    for tipo in tipos:
        pt = TIPOS_PT.get(tipo, tipo)
        for sufixo, nome, preco, desc in [
            ("fragmento", "Fragmento de %s" % pt, PRECO_FRAGMENTO,
             "Caco de energia de %s. Sozinho não vale muito; aos montes, paga as contas." % pt),
            ("amuleto", "Amuleto de %s" % pt, PRECO_AMULETO,
             "Amuleto carregado de energia de %s. Colecionadores pagam bem." % pt),
        ]:
            item_id = "%s_%s" % (tipo.lower(), sufixo)
            itens[item_id] = collections.OrderedDict([
                ("id", item_id), ("name", nome), ("category", "loot"),
                ("price", preco), ("description", desc),
            ])

    # 2) Peças de espécie
    for _id, (item_id, nome) in PECAS.items():
        itens[item_id] = collections.OrderedDict([
            ("id", item_id), ("name", nome), ("category", "loot"),
            ("price", PRECO_PECA),
            ("description", "Só se consegue derrotando esse Pokémon. Vale bem na loja."),
        ])

    # 3) MTs de tipo (criando o golpe se ele não existir)
    mt_por_tipo_id = {}
    numero = 20
    for tipo, (golpe_id, golpe_nome, poder, categoria) in MT_POR_TIPO.items():
        if golpe_id not in golpes:
            golpes[golpe_id] = collections.OrderedDict([
                ("id", golpe_id), ("name", golpe_nome), ("type", tipo),
                ("category", categoria), ("power", poder), ("accuracy", 90),
                ("pp", 5), ("priority", 0), ("contact", categoria == "physical"),
                ("effect", "none"), ("cooldown", 3.4), ("target_type", "single"),
            ])
        item_id = "tm%d" % numero
        numero += 1
        mt_por_tipo_id[tipo] = item_id
        itens[item_id] = collections.OrderedDict([
            ("id", item_id), ("name", "MT%d %s" % (numero - 1, golpe_nome)),
            ("category", "tm_hm"), ("teaches", golpe_id), ("price", 0),
            ("single_use", False),
            ("description", "Ensina %s. Só cai de Pokémon de evolução final, e é raríssima." % golpe_nome),
        ])

    # 4) Preços dos consumíveis — caros de propósito
    for item_id, preco in PRECOS_CONSUMIVEIS.items():
        if item_id in itens:
            itens[item_id]["price"] = preco

    # 5) `drops` por espécie
    finais = 0
    for e in lista:
        tipo_principal = e.get("types", ["Normal"])[0]
        drops = []
        drops.append({"id": "%s_fragmento" % tipo_principal.lower(),
                      "chance": CHANCE_FRAGMENTO, "quantidade": [1, 3]})
        drops.append({"id": "%s_amuleto" % tipo_principal.lower(),
                      "chance": CHANCE_AMULETO, "quantidade": [1, 1]})
        if e["id"] in PECAS:
            drops.append({"id": PECAS[e["id"]][0], "chance": CHANCE_PECA,
                          "quantidade": [1, 1]})
        if tipo_principal in PEDRA_POR_TIPO:
            drops.append({"id": PEDRA_POR_TIPO[tipo_principal],
                          "chance": CHANCE_PEDRA, "quantidade": [1, 1]})
        # A MT: SÓ evolução final (quem não evolui mais), 0,5%.
        if not e.get("evolution_to") and tipo_principal in mt_por_tipo_id:
            drops.append({"id": mt_por_tipo_id[tipo_principal],
                          "chance": CHANCE_MT, "quantidade": [1, 1]})
            finais += 1
        e["drops"] = drops

    gravar("data/items/items.json", itens)
    gravar("data/moves/moves.json", golpes)
    gravar("data/pokemon/species.json", especies_arq)

    de_loot = len([k for k, v in itens.items() if v.get("category") == "loot"])
    print("itens de loot criados: %d" % de_loot)
    print("MTs de tipo criadas:   %d" % len(mt_por_tipo_id))
    print("espécies com drops:    %d" % len(lista))
    print("evolucoes finais com MT: %d (chance %.1f%%)" % (finais, CHANCE_MT * 100))
    print("consumíveis reprecificados: %d" % len(PRECOS_CONSUMIVEIS))


if __name__ == "__main__":
    main()
