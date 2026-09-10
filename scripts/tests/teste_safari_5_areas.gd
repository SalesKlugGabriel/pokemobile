## teste_safari_5_areas.gd — 10/09, Fase 6 (parte 2). A Zona Safari virou
## 5 ÁREAS ENCADEADAS de 300×300 (era uma sala única de 44×44 desde o Tier
## 12). O blueprint da reestruturação sempre pediu isso; nunca tinha sido
## construído.
##
## O que este teste garante, e que nenhum outro garantiria: a CORRENTE
## inteira — Fuchsia → Área 1 → 2 → 3 → 4 → 5 — sem elo faltando, com
## estrada andável de portão a portão dentro de cada área (a lição que a
## Cinnabar cobrou nesta mesma fase: terreno aleatório decorativo não
## garante travessia; precisa de caminho explícito).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const AREAS := [
	{"map_id": "safari_zone", "cena": "SafariZone",    "tema": "Centro"},
	{"map_id": "safari_a2",   "cena": "SafariZone_A2", "tema": "Mata Fechada"},
	{"map_id": "safari_a3",   "cena": "SafariZone_A3", "tema": "Pedregal"},
	{"map_id": "safari_a4",   "cena": "SafariZone_A4", "tema": "Brejo"},
	{"map_id": "safari_a5",   "cena": "SafariZone_A5", "tema": "Casa Secreta"},
]

func _initialize() -> void:
	print("=== Teste: Zona Safari, 5 áreas encadeadas (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var zonas := {}
	for z in zj.get("zones", []):
		zonas[String(z.get("id", ""))] = z

	for i in AREAS.size():
		var a : Dictionary = AREAS[i]
		var mid : String = a["map_id"]
		var ultima : bool = i == AREAS.size() - 1
		print("\n-- Área %d (%s) --" % [i + 1, a["tema"]])

		# ---- Layout: 300x300, cercado, portões nos lugares certos ----
		var layout : Dictionary = MapLayouts.get_layout(mid)
		_assert(not layout.is_empty(), "%s: get_layout existe" % mid)
		if layout.is_empty():
			continue
		var tiles : Array = layout["tiles"]
		_assert(int(layout["width"]) == 300 and int(layout["height"]) == 300, "%s: 300x300" % mid)
		_assert(String(tiles[150])[0] == "E", "%s: cerca na borda oeste" % mid)
		_assert(String(tiles[299])[149] == "P", "%s: portão sul (volta) existe" % mid)
		if ultima:
			_assert(String(tiles[0])[149] == "E",
				"%s: a última área NÃO tem portão norte (é o fim da reserva)" % mid)
		else:
			_assert(String(tiles[0])[149] == "P", "%s: portão norte (avança) existe" % mid)

		# ---- Estrada garantida: dá pra atravessar de portão a portão ----
		var tm := TileMap.new()
		tm.tile_set = load("res://assets/tilesets/overworld.tres")
		MapLayouts.paint(tm, mid)
		_assert(AjudaMapa.caminho_a_pe(tm, Vector2i(149, 298), Vector2i(149, 1), 400000),
			"%s: dá pra atravessar a área inteira a pé, portão a portão" % mid)
		tm.free()

		# ---- Cena: existe, aponta pra trás e pra frente ----
		var caminho : String = "res://scenes/world/maps/%s.tscn" % a["cena"]
		var cena : PackedScene = load(caminho)
		_assert(cena != null, "%s: cena existe e carrega" % a["cena"])
		if cena == null:
			continue
		var inst = cena.instantiate()
		root.add_child(inst)
		_assert(String(inst.map_id) == mid, "%s: map_id é '%s'" % [a["cena"], mid])

		var alvos : Array[String] = []
		var wz = inst.get_node_or_null("WarpZones")
		if wz:
			for w in wz.get_children():
				alvos.append(String(w.target_map))

		var anterior : String = "res://scenes/world/maps/WorldMap.tscn" if i == 0 \
			else "res://scenes/world/maps/%s.tscn" % AREAS[i - 1]["cena"]
		_assert(anterior in alvos, "%s: tem volta pro passo anterior" % a["cena"])

		if not ultima:
			var proximo : String = "res://scenes/world/maps/%s.tscn" % AREAS[i + 1]["cena"]
			_assert(proximo in alvos, "%s: avança pra %s" % [a["cena"], AREAS[i + 1]["cena"]])
		else:
			# "não avança" = não aponta pra NENHUMA área além dela mesma. A
			# volta pra Área 4 é legítima e não conta (o teste ingênuo de
			# "contém SafariZone_A" reprovava justamente a volta certa).
			var tem_frente := false
			for alvo in alvos:
				if alvo.contains("SafariZone_A") and alvo != anterior:
					tem_frente = true
			_assert(not tem_frente, "%s: a última área não avança pra lugar nenhum" % a["cena"])
		inst.queue_free()

		# ---- zones.json: zona própria, com bicho próprio ----
		_assert(zonas.has(mid), "zones.json tem a zona '%s'" % mid)
		if zonas.has(mid):
			var z : Dictionary = zonas[mid]
			_assert(String(z.get("map_id", "")) == mid, "%s: map_id próprio no zones.json" % mid)
			_assert(int(z.get("tile_rect", {}).get("w", 0)) == 300, "%s: tile_rect bate com 300" % mid)
			_assert(z.get("wild_pokemon", []).size() >= 4, "%s: tem spawn selvagem próprio" % mid)

	# ---- A porta de Fuchsia continua abrindo a Área 1 ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var achou := false
	for w in wm.get_node("WarpZones").get_children():
		if String(w.target_map) == "res://scenes/world/maps/SafariZone.tscn":
			achou = true
	_assert(achou, "o portão de Fuchsia continua abrindo a Área 1 da Zona Safari")
	wm.queue_free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
