## MapLayouts.gd — Layout procedural dos mapas em tiles.
##
## ARQUITETURA: Mundo aberto unificado (world_map) + interiores separados.
##   world_map: 100×120 tiles (1600×1920 px) — PalletTown + Route1 + ViridianCity contínuos
##   pokemon_center: 16×14 tiles — interior separado
##
## Zonas do world_map:
##   Rows 0-1:    Borda norte
##   Rows 2-38:   Viridian City
##   Rows 39-79:  Rota 1
##   Rows 80-118: Pallet Town
##   Row 119:     Borda sul
##
## Corredor principal norte-sul: cols 44-56
## Player spawn: tile (50, 110) → pixel (800, 1760)
## PokéCenter Pallet: entrada tile (77, 88) → pixel (1232, 1408)
##
## Atlas (source 0, overworld.tres):
##   Walkable row 0:  . grass  P path  F flower  S sand  G lt_grass  D dk_path  I floor  M mat
##   Blocked  row 1:  W wall   ~ water  T tree    R rock  E fence     d door     H roof   X hedge
class_name MapLayouts
extends RefCounted

const CHAR_MAP : Dictionary = {
	".": Vector2i(0, 0), "P": Vector2i(1, 0), "F": Vector2i(2, 0), "S": Vector2i(3, 0),
	"G": Vector2i(4, 0), "D": Vector2i(5, 0), "I": Vector2i(6, 0), "M": Vector2i(7, 0),
	"W": Vector2i(0, 1), "~": Vector2i(1, 1), "T": Vector2i(2, 1), "R": Vector2i(3, 1),
	"E": Vector2i(4, 1), "d": Vector2i(5, 1), "H": Vector2i(6, 1), "X": Vector2i(7, 1),
}

# ──────────────────────────────────────────────────────────────────────────────
# World Map unificado — 100×192, mundo aberto de verdade (sem warp entre
# cidade/rota — só warp pra caverna/subterrâneo/submarino/trocar de
# continente, decisão do Gabriel em 31/08). Pewter City e Rota 2 entraram
# como uma faixa nova ao norte de Viridian; todo o resto do mapa (Viridian/
# Rota 1/Pallet) manteve o próprio código de sempre — só passou a receber um
# número de linha deslocado (old_r = r - OFFSET_ANTIGO), pra não precisar
# reescrever nada que já estava testado.
# ──────────────────────────────────────────────────────────────────────────────

const PEWTER_ROWS  : int = 36   # linhas 1-36 (global)
const ROUTE2_ROWS  : int = 36   # linhas 37-72 (global)
const OFFSET_ANTIGO : int = PEWTER_ROWS + ROUTE2_ROWS  # 72 — a partir daqui, é o mapa de sempre

# Largura original (Pewter/Rota2/Viridian/Rota1/Pallet — tudo que já existia).
const W_ANTIGO : int = 100
# Tier 2 (Gabriel, 31/08): Rota 3 → Mt Moon (entrada) → Rota 4 → Cerulean City,
# tudo a LESTE de Pewter, na mesma faixa de linhas (1-36) — mundo aberto de
# verdade, sem warp de rota/cidade (só a caverna em si vira cena própria).
const ROUTE3_COLS    : int = 60
const ROUTE4_COLS    : int = 60
const CERULEAN_COLS  : int = 60
const W_TOTAL : int = W_ANTIGO + ROUTE3_COLS + ROUTE4_COLS + CERULEAN_COLS  # 280

static func _gen_world_map() -> Array:
	var W := W_TOTAL
	var H := 120 + OFFSET_ANTIGO
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _world_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _world_cell(c: int, r: int, W: int, H: int) -> String:
	# Bordas absolutas
	if r == 0 or r >= H - 1 or c == 0 or c >= W - 1:
		return "T"

	# ── Pewter City (linhas 1-36) — e, a leste dela, Rota 3/Mt Moon/Rota 4/
	# Cerulean, na MESMA faixa de linhas (a "largura antiga" W_ANTIGO é onde
	# Pewter termina; dali pra leste é território novo) ────────────────────
	if r <= PEWTER_ROWS:
		if c < W_ANTIGO:
			# Achado (mesma classe do seam de Viridian/Rota2): _pewter_cell
			# trata c>=W-3 como borda leste — fazia sentido quando Pewter
			# era o fim do mapa. Agora que a Rota 3 continua pra leste, isso
			# virava parede bem no meio do caminho principal (row 16-20).
			if c >= W_ANTIGO - 3 and r >= 16 and r <= 20:
				return "P"
			return _pewter_cell(c, r, W_ANTIGO)
		return _leste_de_pewter_cell(c - W_ANTIGO, r)

	# ── Rota 2 (linhas 37-72) — só existe na largura antiga; o resto é borda
	if r <= OFFSET_ANTIGO:
		if c >= W_ANTIGO:
			return "T"
		return _route2_cell(c, r - PEWTER_ROWS, W_ANTIGO)

	# ── Daqui pra baixo: exatamente o mapa antigo (Viridian/Rota 1/Pallet),
	# só com o número de linha traduzido de volta pro valor original — e,
	# de novo, só existe até W_ANTIGO; o resto é borda ──────────────────────
	if c >= W_ANTIGO:
		return "T"
	var old_r := r - OFFSET_ANTIGO

	# ── Viridian City (rows 2-38 no mapa antigo) ────────────────────────────
	if old_r <= 38:
		# Achado: _viridian_cell trata old_r<=3 como borda norte — fazia
		# sentido quando Viridian era o topo do mapa de verdade. Agora que a
		# Rota 2 continua pra cima, isso virava uma parede de 3 tiles bem no
		# meio do corredor. Corrigido só nas colunas do corredor, sem tocar
		# em nada mais de Viridian (loja/NPC/decoração continuam iguais).
		if old_r <= 3 and c >= 44 and c <= 56:
			return "P"
		return _viridian_cell(c, old_r, W_ANTIGO)

	# ── Rota 1 (rows 39-79 no mapa antigo) ──────────────────────────────────
	if old_r <= 79:
		return _route1_cell(c, old_r, W_ANTIGO)

	# ── Pallet Town (rows 80-119 no mapa antigo) ────────────────────────────
	return _pallet_cell(c, old_r, W_ANTIGO)

# ──────────────────────────────────────────────────────────────────────────────
# Rota 3 → Mt Moon (entrada) → Rota 4 → Cerulean City — leste de Pewter,
# linhas 1-36 (mesma faixa). `c` já vem local (0 = logo a leste da borda de
# Pewter). Caminho principal é horizontal, rows 16-20; resto é grama/árvore
# esparsa (Rota 3/4) ou a cidade em si (Cerulean).
# ──────────────────────────────────────────────────────────────────────────────
static func _leste_de_pewter_cell(c: int, r: int) -> String:
	if r <= 2 or r >= PEWTER_ROWS - 1:
		return "T"

	# ── Caminho principal leste-oeste ── rows 16-20
	var no_caminho := r >= 16 and r <= 20

	# ── Rota 3 ── local cols 0-59
	if c < ROUTE3_COLS:
		if no_caminho:
			return "P"
		if (c + r * 2) % 9 == 0:
			return "T"
		if (c * 2 + r) % 13 == 4:
			return "F"
		return "."

	# ── Mt Moon: boca da caverna ── local cols ROUTE3_COLS-3 .. ROUTE3_COLS+3
	# (a entrada em si — a caverna de verdade é uma cena própria, warp aqui)
	if c >= ROUTE3_COLS - 4 and c < ROUTE3_COLS + 4 and r >= 12 and r <= 24:
		if no_caminho and c >= ROUTE3_COLS - 2 and c < ROUTE3_COLS + 2:
			return "P"  # entrada caminhável (warp fica aqui)
		return "R"  # rochedo da montanha ao redor da boca da caverna

	# ── Rota 4 ── local cols ROUTE3_COLS .. ROUTE3_COLS+ROUTE4_COLS-1
	if c < ROUTE3_COLS + ROUTE4_COLS:
		if no_caminho:
			return "P"
		if (c + r * 3) % 9 == 1:
			return "T"
		if (c + r * 2) % 13 == 5:
			return "S"  # Rota 4 é mais arenosa (perto de Cerulean/Celadon)
		return "."

	# ── Cerulean City ── local cols ROUTE3_COLS+ROUTE4_COLS em diante
	var cc := c - ROUTE3_COLS - ROUTE4_COLS  # local dentro da própria cidade

	# ── Ginásio de Cerulean (Misty) ── cols 10-22, rows 6-14
	if cc >= 10 and cc <= 22 and r >= 6 and r <= 14:
		if cc == 10 or cc == 22: return "W"
		if r == 6: return "H"
		if r == 14:
			if cc >= 15 and cc <= 17: return "P"  # porta
			return "W"
		return "I"
	if r >= 14 and r <= 16 and cc >= 15 and cc <= 17:
		return "P"

	# ── Centro Pokémon de Cerulean ── cols 35-47, rows 6-14
	if cc >= 35 and cc <= 47 and r >= 6 and r <= 14:
		if cc == 35 or cc == 47: return "W"
		if r == 6: return "H"
		if r == 14:
			if cc >= 40 and cc <= 42: return "P"  # porta
			return "W"
		return "I"
	if r >= 14 and r <= 16 and cc >= 40 and cc <= 42:
		return "P"

	# ── Rio/lago decorativo (Cerulean é a "Cidade Azulada") ──
	if (cc + r * 3) % 19 == 6 and r >= 22 and r <= 34 and cc >= 2 and cc <= 55:
		return "~"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Pewter City — linhas 1-36 (globais), full 100 largo.
# Ginásio do Brock a oeste (cols 18-34), Centro Pokémon a leste (cols 70-82,
# mesma posição usada em toda cidade — Pallet e Viridian já seguem isso).
# Corredor N-S cols 44-56, contínuo com a Rota 2 logo abaixo.
# ──────────────────────────────────────────────────────────────────────────────
static func _pewter_cell(c: int, r: int, W: int) -> String:
	if c <= 2 or c >= W - 3:
		return "T"
	if r <= 2:
		return "T"

	# ── Corredor N-S ── cols 44-56
	if c >= 44 and c <= 56:
		return "P"
	# ── Passeio leste-oeste da cidade ── row 24
	if r == 24 and c >= 5 and c <= 93:
		return "P"

	# ── Ginásio de Pewter (Brock) ── cols 18-34, rows 6-18
	if c >= 18 and c <= 34 and r >= 6 and r <= 18:
		if c == 18 or c == 34: return "W"
		if r == 6: return "H"
		if r == 18:
			if c >= 25 and c <= 27: return "P"  # porta
			return "W"
		return "I"
	# ── Caminho Ginásio → corredor ── row 18-19, cols 34-44
	if r >= 18 and r <= 19 and c >= 34 and c <= 44:
		return "P"

	# ── Centro Pokémon de Pewter ── cols 70-82, rows 6-14
	if c >= 70 and c <= 82 and r >= 6 and r <= 14:
		if c == 70 or c == 82: return "W"
		if r == 6: return "H"
		if r == 14:
			if c >= 75 and c <= 77: return "P"  # porta (warp aqui)
			return "W"
		return "I"
	# ── Caminho PokéCenter → corredor ── row 14-15, cols 56-77
	if r >= 14 and r <= 15 and c >= 56 and c <= 77:
		return "P"

	# ── Pedras decorativas (Cidade das Pedras) ──
	if (c + r * 3) % 17 == 5 and r >= 20 and r <= 34 and c >= 4 and c <= 93:
		return "R"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rota 2 — linhas locais 1-36 (globais 37-72), corredor cols 44-56 igual a
# Rota 1, mesma faixa de grama/árvore/flor esparsa. Geodude entra no spawn
# selvagem via zones.json (não muda nada aqui, só o dado de spawn).
# ──────────────────────────────────────────────────────────────────────────────
static func _route2_cell(c: int, r: int, W: int) -> String:
	if c <= 4 or c >= W - 5:
		return "T"
	if c >= 44 and c <= 56:
		return "P"
	if c <= 43:
		if c <= 8 or c >= 40:
			return "T"
		if (c + r * 2) % 8 == 0:
			return "T"
		if (c * 2 + r) % 11 == 3:
			return "F"
		return "."
	if c >= 57:
		if c <= 60 or c >= 91:
			return "T"
		if (c + r * 3) % 8 == 2:
			return "T"
		if (c + r * 2) % 11 == 3:
			return "F"
		return "."
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Pallet Town — rows 80-119, full 100 wide
# Corredor N-S: cols 44-56
# Prof. Oak lab: cols 18-34, rows 82-90
# PokéCenter: cols 70-82, rows 82-90 (entrada col 76, row 90)
# Casas: várias posições
# Player spawn: (50, 110)
# ──────────────────────────────────────────────────────────────────────────────
static func _pallet_cell(c: int, r: int, W: int) -> String:
	# Bordas laterais: árvores
	if c <= 2 or c >= W - 3:
		return "T"
	# Borda sul
	if r >= 116:
		return "T"

	# ── Corredor norte-sul principal ── cols 44-56
	if c >= 44 and c <= 56 and r >= 80 and r <= 115:
		return "P"

	# ── Laboratório do Prof. Carvalho ── cols 18-34, rows 82-90
	if c >= 18 and c <= 34 and r >= 82 and r <= 90:
		if c == 18 or c == 34: return "W"
		if r == 82: return "H"
		if r == 90:
			if c >= 25 and c <= 27: return "P"  # porta
			return "W"
		return "I"

	# ── Caminho do lab até corredor ── row 90, cols 27-44
	if r == 90 and c >= 27 and c <= 44:
		return "P"
	if r == 91 and c >= 27 and c <= 44:
		return "P"

	# ── PokéCenter de Pallet ── cols 70-82, rows 82-90
	if c >= 70 and c <= 82 and r >= 82 and r <= 90:
		if c == 70 or c == 82: return "W"
		if r == 82: return "H"
		if r == 90:
			if c >= 75 and c <= 77: return "P"  # porta (warp aqui)
			return "W"
		return "I"

	# ── Caminho do pokécenter até corredor ── row 90-91, cols 56-77
	if r >= 90 and r <= 91 and c >= 56 and c <= 77:
		return "P"

	# ── Casa 1 ── cols 8-16, rows 97-105
	if c >= 8 and c <= 16 and r >= 97 and r <= 105:
		if c == 8 or c == 16: return "W"
		if r == 97: return "H"
		if r == 105:
			if c == 12: return "P"
			return "W"
		return "I"

	# ── Caminho casa 1 ── col 12, rows 105-110
	if c == 12 and r >= 105 and r <= 112:
		return "P"
	if r == 110 and c >= 12 and c <= 44:
		return "P"

	# ── Casa 2 ── cols 58-66, rows 97-105
	if c >= 58 and c <= 66 and r >= 97 and r <= 105:
		if c == 58 or c == 66: return "W"
		if r == 97: return "H"
		if r == 105:
			if c == 62: return "P"
			return "W"
		return "I"

	# ── Caminho casa 2 ── col 62, rows 105-110
	if c == 62 and r >= 105 and r <= 110:
		return "P"
	if r == 110 and c >= 56 and c <= 62:
		return "P"

	# ── Casa 3 ── cols 84-92, rows 97-105
	if c >= 84 and c <= 92 and r >= 97 and r <= 105:
		if c == 84 or c == 92: return "W"
		if r == 97: return "H"
		if r == 105:
			if c == 88: return "P"
			return "W"
		return "I"

	# ── Flores esparsas ──
	if (c * 3 + r * 7) % 13 == 5 and r >= 92 and r <= 115 and c >= 5 and c <= 94:
		return "F"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rota 1 — rows 39-79, corredor cols 44-56, árvores nas bordas
# ──────────────────────────────────────────────────────────────────────────────
static func _route1_cell(c: int, r: int, W: int) -> String:
	# Bordas laterais densas
	if c <= 4 or c >= W - 5:
		return "T"
	# Corredor central N-S: cols 44-56
	if c >= 44 and c <= 56:
		return "P"
	# Faixa de grama caminhável entre árvores e corredor
	# Lado oeste: cols 5-43 — grama com árvores esparsas
	if c <= 43:
		if c <= 8 or c >= 40:
			return "T"  # bordas internas também são árvore
		if (c + r * 2) % 7 == 0:
			return "T"
		if (c * 2 + r) % 9 == 3:
			return "F"
		return "."
	# Lado leste: cols 57-94 — grama com árvores esparsas
	if c >= 57:
		if c <= 60 or c >= 91:
			return "T"
		# Lago pequeno (Fase 2 do Diário — pesca precisa de água de verdade
		# em algum lugar do mapa; não existia nenhum tile "~" no jogo antes).
		if c >= 63 and c <= 70 and r >= 55 and r <= 60:
			return "~"
		if (c + r * 3) % 7 == 1:
			return "T"
		if (c + r * 2) % 11 == 4:
			return "F"
		return "."
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Viridian City — rows 2-38, corredor cols 44-56 vindo do sul
# PokéCenter Viridian: cols 70-82, rows 4-12
# Ginásio (fechado): cols 18-34, rows 4-14
# ──────────────────────────────────────────────────────────────────────────────
static func _viridian_cell(c: int, r: int, W: int) -> String:
	# Bordas laterais
	if c <= 2 or c >= W - 3:
		return "T"
	# Borda norte
	if r <= 3:
		return "T"

	# ── Corredor N-S ── cols 44-56
	if c >= 44 and c <= 56:
		return "P"

	# ── Corredor leste-oeste ── row 28, cols 5-93 (passeio da cidade)
	if r == 28 and c >= 5 and c <= 93:
		return "P"
	if r == 29 and c >= 5 and c <= 93:
		return "P"

	# ── Ginásio (fechado) ── cols 18-34, rows 6-18
	if c >= 18 and c <= 34 and r >= 6 and r <= 18:
		if c == 18 or c == 34: return "W"
		if r == 6: return "H"
		if r == 18:
			# Porta bloqueada (ginásio fechado)
			return "W"
		return "W"  # interior inacessível

	# ── PokéCenter Viridian ── cols 70-82, rows 6-14
	if c >= 70 and c <= 82 and r >= 6 and r <= 14:
		if c == 70 or c == 82: return "W"
		if r == 6: return "H"
		if r == 14:
			if c >= 75 and c <= 77: return "P"
			return "W"
		return "I"

	# ── Caminho PokéCenter Viridian → corredor ── row 14-15, cols 56-77
	if r >= 14 and r <= 15 and c >= 56 and c <= 77:
		return "P"

	# ── Caminho Ginásio → corredor ── row 18-19, cols 34-44
	if r >= 18 and r <= 19 and c >= 34 and c <= 44:
		return "P"

	# ── Loja de itens ── cols 50-60, rows 8-16
	if c >= 50 and c <= 60 and r >= 8 and r <= 16:
		if c == 50 or c == 60: return "W"
		if r == 8: return "H"
		if r == 16:
			if c == 55: return "P"
			return "W"
		return "I"

	# ── Caminho loja → corredor ── col 55, rows 16-28
	if c == 55 and r >= 16 and r <= 28:
		return "P"

	# ── Árvores e flores decorativas ──
	if (c + r * 5) % 11 == 2 and r >= 20 and r <= 36 and c >= 6 and c <= 92:
		return "T"
	if (c * 2 + r * 3) % 13 == 4 and r >= 20 and r <= 36 and c >= 6 and c <= 92:
		return "F"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# PokéCenter interior — 16×14 (inalterado)
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_pokemon_center() -> Array:
	return [
		"HHHHHHHHHHHHHHHH",
		"WWWWWWWWWWWWWWWW",
		"WIIIIIIIIIIIIIIW",
		"WIIIIIIIIIIIIIIW",
		"WIIWWWWWWWWWWIIW",
		"WII..........IIW",
		"WII..........IIW",
		"WIIIIIIIIIIIIIIW",
		"WIIIIIIIIIIIIIIW",
		"WIIM........MIIW",
		"WIIIIIIIIIIIIIIW",
		"WII....PP....IIW",
		"WWWWWWWPPWWWWWWW",
		"TTTTTTTTTTTTTTTT",
	]

# ──────────────────────────────────────────────────────────────────────────────
# Mt Moon — 20×30, cena própria (é caverna/subterrâneo — a ÚNICA situação em
# que o Gabriel pediu warp de verdade, 31/08). Entrada ao sul (vem da Rota 3),
# saída ao norte (sai na Rota 4) — sem volta pela superfície, tem que atravessar.
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_mtmoon() -> Array:
	var W := 20
	var H := 30
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _mtmoon_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _mtmoon_cell(c: int, r: int, W: int, H: int) -> String:
	if c == 0 or c == W - 1:
		return "W"
	if r == 0:
		if c >= 9 and c <= 10: return "P"  # saída (Rota 4)
		return "W"
	if r == H - 1:
		if c >= 9 and c <= 10: return "P"  # entrada (Rota 3)
		return "W"
	# Rochas espalhadas — nunca nas colunas 9-10 (mantém sempre um caminho
	# reto entrada→saída, mesmo que sinuoso pelas rochas ao redor)
	if (c + r * 2) % 7 == 0 and (c < 8 or c > 11):
		return "R"
	return "I"

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

static func get_layout(map_id: String) -> Dictionary:
	match map_id:
		"world_map":
			var tiles := _gen_world_map()
			return {"tiles": tiles, "width": W_TOTAL, "height": 120 + OFFSET_ANTIGO}
		"pokemon_center":
			var tiles := _gen_pokemon_center()
			return {"tiles": tiles, "width": 16, "height": 14}
		"mt_moon":
			var tiles := _gen_mtmoon()
			return {"tiles": tiles, "width": 20, "height": 30}
		_:
			return {}

static func paint(tilemap: TileMap, map_id: String) -> void:
	var layout := get_layout(map_id)
	if layout.is_empty():
		push_warning("MapLayouts: layout desconhecido para '%s'" % map_id)
		return
	tilemap.clear()
	var rows : Array = layout["tiles"]
	for row_idx in rows.size():
		var row : String = rows[row_idx]
		for col_idx in row.length():
			var ch := row[col_idx]
			var atlas : Vector2i = CHAR_MAP.get(ch, Vector2i(0, 0))
			tilemap.set_cell(0, Vector2i(col_idx, row_idx), 0, atlas)

static func get_pixel_bounds(map_id: String) -> Rect2i:
	var layout := get_layout(map_id)
	if layout.is_empty():
		return Rect2i(0, 0, 1280, 720)
	return Rect2i(0, 0, layout["width"] * 16, layout["height"] * 16)
