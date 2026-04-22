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
# World Map unificado — 100×120
# ──────────────────────────────────────────────────────────────────────────────

static func _gen_world_map() -> Array:
	var W := 100
	var H := 120
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

	# ── Viridian City (rows 2-38) ──────────────────────────────────────────────
	if r <= 38:
		return _viridian_cell(c, r, W)

	# ── Rota 1 (rows 39-79) ───────────────────────────────────────────────────
	if r <= 79:
		return _route1_cell(c, r, W)

	# ── Pallet Town (rows 80-119) ─────────────────────────────────────────────
	return _pallet_cell(c, r, W)

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
# API pública
# ──────────────────────────────────────────────────────────────────────────────

static func get_layout(map_id: String) -> Dictionary:
	match map_id:
		"world_map":
			var tiles := _gen_world_map()
			return {"tiles": tiles, "width": 100, "height": 120}
		"pokemon_center":
			var tiles := _gen_pokemon_center()
			return {"tiles": tiles, "width": 16, "height": 14}
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
			var atlas := CHAR_MAP.get(ch, Vector2i(0, 0))
			tilemap.set_cell(0, Vector2i(col_idx, row_idx), 0, atlas)

static func get_pixel_bounds(map_id: String) -> Rect2i:
	var layout := get_layout(map_id)
	if layout.is_empty():
		return Rect2i(0, 0, 1280, 720)
	return Rect2i(0, 0, layout["width"] * 16, layout["height"] * 16)
