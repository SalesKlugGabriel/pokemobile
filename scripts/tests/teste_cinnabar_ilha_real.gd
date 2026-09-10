## teste_cinnabar_ilha_real.gd — 10/09, Fase 6 da reestruturação
## geográfica em escala real (docs/mundo-novo-escala.md). Cinnabar Island
## vira uma ilha de verdade pra explorar (1.200×1.200, pedido explícito do
## Gabriel: "quero uma ilha pra explorar, achar os pokémons de fogo,
## moltres, arcanine, charizard... quase uma DLC do jogo"). Prédios
## (Ginásio/Centro/Mansão) mantêm o tamanho original — só a distância
## entre eles cresceu, mesma filosofia das Fases 1-5.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S", "^", ":", "D", "_", "I"]

func _initialize() -> void:
	print("=== Teste: Cinnabar Island em escala real (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var layout : Dictionary = MapLayouts.get_layout("cinnabar_island")
	_assert(not layout.is_empty(), "get_layout('cinnabar_island') existe")
	_assert(int(layout.get("width", 0)) == 1200 and int(layout.get("height", 0)) == 1200,
		"Cinnabar gera 1.200x1.200 (era 40x40)")
	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 1200, "a grade tem 1.200 linhas de verdade")

	# ---- Prédios mantêm o TAMANHO original (12x8 Ginásio, 8x8 Centro,
	# 12x6 Mansão) — só mudou de posição ----
	_assert(tiles[754][486] == "I", "Ginásio: interior é piso")
	_assert(tiles[750][486] == "H", "Ginásio: telhado existe")
	_assert(tiles[754][624] == "I", "Centro Pokémon: interior é piso")
	_assert(tiles[903][576] == "I", "Mansão: interior (fachada) é piso")

	# ---- Conectividade: doca alcança Ginásio, Centro, Mansão E o planalto
	# vulcânico ao norte (onde a Cratera do Vulcão vai entrar um dia) ----
	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tm, "cinnabar_island")
	var doca := Vector2i(599, 1000)
	_assert(tiles[1000][599] == "D", "doca existe na costa sul de verdade (não flutuando em mar aberto)")
	_assert(AjudaMapa.caminho_a_pe(tm, doca, Vector2i(486, 754)), "doca alcança o Ginásio a pé")
	_assert(AjudaMapa.caminho_a_pe(tm, doca, Vector2i(624, 754)), "doca alcança o Centro Pokémon a pé")
	_assert(AjudaMapa.caminho_a_pe(tm, doca, Vector2i(576, 903)), "doca alcança a Mansão a pé")
	_assert(AjudaMapa.caminho_a_pe(tm, doca, Vector2i(600, 200), 3000000),
		"doca alcança o planalto vulcânico ao norte a pé (teto maior — a ilha é grande, o padrão de 400 mil não é suficiente)")

	# Amostragem ampla: pontos aleatórios andáveis pela ilha toda batem no
	# mesmo componente conectado da doca (acha bolsões isolados por trás
	# de uma reentrância da costa orgânica, que já aconteceu uma vez ao
	# construir esta fase).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var isolados := 0
	var testados := 0
	for i in 25:
		var r : int = rng.randi_range(50, 1150)
		var c : int = rng.randi_range(50, 1150)
		if tiles[r][c] in ANDAVEL:
			testados += 1
			if not AjudaMapa.caminho_a_pe(tm, doca, Vector2i(c, r), 3000000):
				isolados += 1
	_assert(testados > 10, "amostragem achou pontos andáveis suficientes pra testar (%d)" % testados)
	_assert(isolados == 0, "nenhum ponto amostrado ficou isolado da doca (%d de %d)" % [isolados, testados])
	tm.free()

	# ---- Cena de verdade ----
	var cena : PackedScene = load("res://scenes/world/maps/CinnabarIsland.tscn")
	_assert(cena != null, "CinnabarIsland.tscn existe e carrega")
	var inst = cena.instantiate()
	root.add_child(inst)
	var blaine := inst.get_node_or_null("Entities/Blaine")
	_assert(blaine != null and not blaine.trainer_team.is_empty(), "Blaine continua existindo, com time real")
	var wpc := inst.get_node_or_null("WarpZones/WarpPokeCenter")
	var wbv := inst.get_node_or_null("WarpZones/WarpBarcoVolta")
	var wpm := inst.get_node_or_null("WarpZones/WarpPokemonMansion")
	_assert(wpc != null and wbv != null and wpm != null, "os 3 warps de sempre continuam existindo")
	if wbv:
		_assert(wbv.target_map == "res://scenes/world/maps/WorldMap.tscn", "o barco de volta continua voltando pro world_map")
	inst.queue_free()

	# ---- WorldMap: o Capitão continua levando pro tile certo da doca nova ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var capitao := wm.get_node_or_null("Entities/Capitao")
	if capitao == null:
		# nome do nó pode variar — procura por dialog_id em vez de nome fixo
		for filho in wm.get_node("Entities").get_children():
			if filho.get("dialog_id") == "capitao_vermilion":
				capitao = filho
				break
	_assert(capitao != null, "o Capitão do barco existe em WorldMap")
	if capitao:
		_assert(capitao.travel_target_map == "res://scenes/world/maps/CinnabarIsland.tscn",
			"o Capitão continua levando pra CinnabarIsland.tscn")
		var destino : Vector2i = capitao.travel_spawn_tile
		_assert(tiles[destino.y][destino.x] == "D",
			"o tile de chegada do barco (%s) é doca de verdade" % destino)
	wm.queue_free()

	# ---- zones.json ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	for z in zj.get("zones", []):
		if z.get("id", "") == "cinnabar_island":
			_assert(int(z.get("tile_rect", {}).get("w", 0)) == 1200, "zone cinnabar_island: tile_rect bate com 1.200")
			var especies := []
			for w in z.get("wild_pokemon", []):
				especies.append(int(w.get("id", 0)))
			_assert(58 in especies and 37 in especies and 77 in especies and 126 in especies,
				"Growlithe/Vulpix/Ponyta/Magmar continuam no spawn selvagem")
		if z.get("id", "") == "pokemon_mansion":
			_assert(int(z.get("tile_rect", {}).get("x", -1)) == 570, "zone pokemon_mansion: posição atualizada pra dentro da ilha nova")

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
