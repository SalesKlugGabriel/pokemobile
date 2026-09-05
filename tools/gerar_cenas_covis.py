#!/usr/bin/env python3
"""
gerar_cenas_covis.py — As 31 cenas dos covis lendários (05/09).

Pedido do Gabriel: cada pássaro lendário atrás de um minigame próprio,
"incrivelmente difíceis de alcançar".

  Ilha Gélida (Articuno) — 10 andares de montanha subindo + 5 de caverna
                           descendo por dentro da ilha, até o ninho.
  Cratera     (Moltres)  — 10 andares descendo dentro do vulcão.
  Usina       (Zapdos)   — 6 setores de labirinto de portões.

Por que gerado por script e não escrito à mão: são 31 arquivos com a mesma
estrutura e só a ligação de warp mudando. Escrever à mão significa 31 chances de
digitar o andar errado num warp — e um warp errado num covil de 15 andares só
aparece pra quem já está lá dentro. Aqui a ligação é calculada, e
`teste_covis_lendarios.gd` confere que a corrente inteira fecha.

Roda com:  python3 tools/gerar_cenas_covis.py
"""

import os

DESTINO = "scenes/world/dungeons"

MODELO = '''[gd_scene load_steps=12 format=3]

[ext_resource type="Script" path="res://scripts/world/BaseMap.gd" id="1_basemap"]
[ext_resource type="PackedScene" path="res://scenes/entities/TrainerEntity.tscn" id="2_trainer"]
[ext_resource type="Script" path="res://scripts/world/systems/ZoneManager.gd" id="3_zm"]
[ext_resource type="Script" path="res://scripts/world/systems/SpawnManager.gd" id="4_sm"]
[ext_resource type="TileSet" path="res://assets/tilesets/overworld.tres" id="5_tileset"]
[ext_resource type="PackedScene" path="res://scenes/ui/DialogBox.tscn" id="6_dialog"]
[ext_resource type="PackedScene" path="res://scenes/ui/OverworldHUD.tscn" id="7_hud"]
[ext_resource type="PackedScene" path="res://scenes/ui/PauseMenu.tscn" id="8_pause"]
[ext_resource type="PackedScene" path="res://scenes/ui/PartyScene.tscn" id="9_party"]
[ext_resource type="PackedScene" path="res://scenes/world/WarpZone.tscn" id="10_warpzone"]

[sub_resource type="RectangleShape2D" id="Shape_warp"]
size = Vector2(128, 128)

[node name="{nome}" type="Node2D"]
script = ExtResource("1_basemap")
map_id = "{map_id}"
structure_id = "{structure_id}"
floor_number = {floor_number}

[node name="TileMap" type="TileMap" parent="."]
tile_set = ExtResource("5_tileset")
format = 2

[node name="Entities" type="Node2D" parent="."]

[node name="WildPokemons" type="Node2D" parent="Entities"]

[node name="NPCs" type="Node2D" parent="Entities"]

[node name="Player" parent="Entities" instance=ExtResource("2_trainer")]
position = Vector2({px}, {py})

[node name="Camera2D" type="Camera2D" parent="Entities/Player"]
position_smoothing_enabled = true
position_smoothing_speed = 8.0
limit_left = 0
limit_top = 0
limit_right = {limite_x}
limit_bottom = {limite_y}
zoom = Vector2(0.5, 0.5)

[node name="ZoneManager" type="Node" parent="."]
script = ExtResource("3_zm")

[node name="SpawnManager" type="Node" parent="."]
script = ExtResource("4_sm")

[node name="WarpZones" type="Node2D" parent="."]
{warps}
[node name="DialogBox" parent="." instance=ExtResource("6_dialog")]

[node name="OverworldHUD" parent="." instance=ExtResource("7_hud")]

[node name="PauseMenu" parent="." instance=ExtResource("8_pause")]

[node name="PartyScene" parent="." instance=ExtResource("9_party")]
'''

WARP = '''
[node name="{nome}" parent="WarpZones" instance=ExtResource("10_warpzone")]
position = Vector2({px}, {py})
target_map = "{destino}"
spawn_tile = Vector2i({sx}, {sy})

[node name="CollisionShape2D" parent="WarpZones/{nome}"]
shape = SubResource("Shape_warp")
'''

T = 128


def px(tile):
    return tile * T + T // 2


def cena(nome, map_id, structure_id, floor_number, larg, alt, entrada, warps):
    corpo = "".join(
        WARP.format(nome=w["nome"], px=px(w["tile"][0]), py=px(w["tile"][1]),
                    destino=w["destino"], sx=w["spawn"][0], sy=w["spawn"][1])
        for w in warps)
    return MODELO.format(
        nome=nome, map_id=map_id, structure_id=structure_id,
        floor_number=floor_number, px=px(entrada[0]), py=px(entrada[1]),
        limite_x=larg * T, limite_y=alt * T, warps=corpo)


def caminho(nome):
    return f"res://{DESTINO}/{nome}.tscn"


def main():
    os.makedirs(DESTINO, exist_ok=True)
    escritas = []

    # ── ILHA GÉLIDA (Articuno) — 21x21, entra embaixo, escada em cima ────────
    L = A = 21
    baixo = (L // 2, A - 2)
    cima = (L // 2, 1)
    andares = [f"IlhaGelida_F{i}" for i in range(1, 11)] + \
              [f"IlhaGelida_B{i}" for i in range(1, 6)]
    for i, nome in enumerate(andares):
        map_id = nome.replace("IlhaGelida_F", "ilha_gelida_f").replace(
            "IlhaGelida_B", "ilha_gelida_b")
        warps = []
        # descida (volta): o primeiro andar sai pro mundo, os outros pro anterior
        if i == 0:
            # Volta pra Ilha Gélida no mapa do mundo. O tile (248,-62) foi
            # ESCOLHIDO por varredura, não chutado: é o mais próximo da boca da
            # montanha (250,-60) que é andável e fica a 2 tiles dela — longe o
            # bastante pra não reentrar no covil no mesmo passo em que sai.
            #
            # 🔴 O chute anterior era (250,-57), e caiu dentro de um bloco de
            # gelo: quem saísse do covil apareceria entalado numa parede. É o
            # tipo de defeito que nenhum teste de layout pega, porque o mapa
            # está certo — quem está errado é a coordenada de destino.
            warps.append({"nome": "SaidaParaOMundo", "tile": (baixo[0], A - 1),
                          "destino": "res://scenes/world/maps/WorldMap.tscn",
                          "spawn": (248, -62)})
        else:
            warps.append({"nome": "Descer", "tile": (baixo[0], A - 1),
                          "destino": caminho(andares[i - 1]), "spawn": cima})
        # subida: o último (B5) é o ninho, não leva a lugar nenhum
        if i < len(andares) - 1:
            warps.append({"nome": "Subir", "tile": cima,
                          "destino": caminho(andares[i + 1]), "spawn": baixo})
        estrutura = "ilha_gelida"
        numero = i + 1
        escritas.append((nome, cena(nome, map_id, estrutura, numero, L, A, baixo, warps)))

    # ── CRATERA (Moltres) — 19x19, entra em cima, escada embaixo ─────────────
    L = A = 19
    topo = (L // 2, 1)
    fundo = (L // 2, A - 2)
    craterasas = [f"Cratera_B{i}" for i in range(1, 11)]
    for i, nome in enumerate(craterasas):
        map_id = f"cratera_b{i + 1}"
        warps = []
        if i == 0:
            warps.append({"nome": "SaidaParaCinnabar", "tile": (topo[0], 0),
                          "destino": "res://scenes/world/maps/CinnabarIsland.tscn",
                          "spawn": (20, 24)})
        else:
            warps.append({"nome": "Subir", "tile": (topo[0], 0),
                          "destino": caminho(craterasas[i - 1]), "spawn": fundo})
        if i < len(craterasas) - 1:
            warps.append({"nome": "Descer", "tile": fundo,
                          "destino": caminho(craterasas[i + 1]), "spawn": topo})
        escritas.append((nome, cena(nome, map_id, "cratera", i + 1, L, A, topo, warps)))

    # ── USINA (Zapdos) — 25x25, entra embaixo, saída em cima ─────────────────
    L = A = 25
    baixo = (L // 2, A - 2)
    cima = (L // 2, 1)
    setores = [f"Usina_S{i}" for i in range(1, 7)]
    for i, nome in enumerate(setores):
        map_id = f"usina_s{i + 1}"
        warps = []
        if i == 0:
            warps.append({"nome": "SaidaParaOMundo", "tile": (baixo[0], A - 1),
                          "destino": "res://scenes/world/maps/WorldMap.tscn",
                          "spawn": (247, 310)})
        else:
            warps.append({"nome": "Voltar", "tile": (baixo[0], A - 1),
                          "destino": caminho(setores[i - 1]), "spawn": cima})
        if i < len(setores) - 1:
            warps.append({"nome": "Avancar", "tile": cima,
                          "destino": caminho(setores[i + 1]), "spawn": baixo})
        escritas.append((nome, cena(nome, map_id, "usina_zapdos", i + 1, L, A, baixo, warps)))

    for nome, texto in escritas:
        with open(f"{DESTINO}/{nome}.tscn", "w", encoding="utf-8") as f:
            f.write(texto)
    print(f"{len(escritas)} cenas gravadas em {DESTINO}/")
    for grupo, n in [("Ilha Gélida", 15), ("Cratera", 10), ("Usina", 6)]:
        print(f"  {grupo}: {n} andares")


if __name__ == "__main__":
    main()
