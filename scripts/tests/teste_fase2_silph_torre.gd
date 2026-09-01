## teste_fase2_silph_torre.gd — Teste headless de Silph Co. e Torre Pokémon
## ganhando interior de verdade (02/09, "Pokémon e estruturas" — Gabriel
## autorizou a exceção de warp pra esses dois, já que uma loja/prédio
## corporativo/torre não é caverna/subterrâneo, mas ele topou abrir mesmo
## assim, igual já fez pra Zona Safari). Torre Pokémon: 5 andares, MAIN-05
## (reach_floor + derrotar Agente Sombra 2). Silph Co.: 3 andares, ROCKET-05
## (defeat_count de 4 Agentes Silph — trocado de "help_npc"/expel_agents,
## tipo sem handler no QuestManager, mesmo padrão já usado em ROCKET-07).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase2_silph_torre.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 2 (Silph Co. + Torre Pokémon) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	_teste_geral()
	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % label)
	else:
		_fail += 1
		print("  FALHA - %s" % label)

func _teste_geral() -> void:
	# ---- 1. Warps de entrada existem no WorldMap ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_torre := false
		var achou_silph := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("PokemonTower_F1"):
					achou_torre = true
				if w.target_map.contains("SilphCo_F1"):
					achou_silph = true
		_assert(achou_torre, "warp de entrada pra Torre Pokémon (F1) existe")
		_assert(achou_silph, "warp de entrada pra Silph Co. (F1) existe")

		var fuji := inst.get_node_or_null("Entities/Fuji")
		_assert(fuji != null and fuji.starts_quest_id == "MAIN-05", "Sr. Fuji inicia a MAIN-05")
		inst.free()

	# ---- 2. Torre Pokémon: 5 andares carregam, com structure_id/floor_number
	# certos, encadeados corretamente (cada um sobe pro próximo) ----
	for i in range(1, 6):
		var path := "res://scenes/world/maps/PokemonTower_F%d.tscn" % i
		var scene := load(path) as PackedScene
		_assert(scene != null, "PokemonTower_F%d.tscn carrega sem erro" % i)
		if scene:
			var floor_inst := scene.instantiate()
			_assert(floor_inst.structure_id == "pokemon_tower" and floor_inst.floor_number == i,
				"F%d: structure_id/floor_number corretos" % i)
			var warps := floor_inst.get_node_or_null("WarpZones")
			var tem_down := false
			var tem_up := false
			if warps:
				for w in warps.get_children():
					if w.name == "WarpDown": tem_down = true
					if w.name == "WarpUp": tem_up = true
			_assert(tem_down, "F%d tem warp pra baixo" % i)
			if i < 5:
				_assert(tem_up, "F%d tem warp pra cima (não é o topo)" % i)
			else:
				_assert(not tem_up, "F5 (topo) NÃO tem warp pra cima")
			floor_inst.free()

	# ---- 3. Agente Sombra 2 existe no topo, com time real ----
	var f5_scene := load("res://scenes/world/maps/PokemonTower_F5.tscn") as PackedScene
	if f5_scene:
		var f5_inst := f5_scene.instantiate()
		var agente := f5_inst.get_node_or_null("Entities/AgenteSombra2")
		_assert(agente != null, "Agente Sombra 2 existe no 5º andar")
		if agente:
			_assert(agente.is_trainer and agente.trainer_team.size() == 3,
				"Agente Sombra 2 é treinador com time de 3 Pokémon")
			_assert(agente.npc_name == "Agente Sombra 2",
				"npc_name vira 'agente_sombra_2' na batalha (bate com o target da MAIN-05)")
		f5_inst.free()

	# ---- 4. Silph Co.: 3 andares carregam, encadeados, com 4 Agentes Silph
	# no total (1+2+1) ----
	var total_agentes := 0
	for i in range(1, 4):
		var path := "res://scenes/world/maps/SilphCo_F%d.tscn" % i
		var scene := load(path) as PackedScene
		_assert(scene != null, "SilphCo_F%d.tscn carrega sem erro" % i)
		if scene:
			var floor_inst := scene.instantiate()
			var warps := floor_inst.get_node_or_null("WarpZones")
			var tem_down := false
			var tem_up := false
			if warps:
				for w in warps.get_children():
					if w.name == "WarpDown": tem_down = true
					if w.name == "WarpUp": tem_up = true
			_assert(tem_down, "SilphCo F%d tem warp pra baixo" % i)
			if i < 3:
				_assert(tem_up, "SilphCo F%d tem warp pra cima" % i)
			else:
				_assert(not tem_up, "SilphCo F3 (topo) NÃO tem warp pra cima")
			var entities := floor_inst.get_node_or_null("Entities")
			if entities:
				for child in entities.get_children():
					if child.get("npc_name") == "Agente Silph":
						total_agentes += 1
			floor_inst.free()
	_assert(total_agentes == 4, "Silph Co. tem 4 Agentes Silph no total (%d encontrados)" % total_agentes)

	# ---- 5. zones.json: 5 andares da Torre com map_id certo + Cubone no topo ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	for i in range(1, 6):
		var zid := "pokemon_tower_f%d" % i
		_assert(by_id.has(zid) and by_id[zid].get("map_id", "") == zid,
			"zona %s existe com map_id certo" % zid)
	var achou_cubone := false
	for w in by_id.get("pokemon_tower_f5", {}).get("wild_pokemon", []):
		if int(w.get("id", 0)) == 104:
			achou_cubone = true
	_assert(achou_cubone, "5º andar da Torre tem Cubone (referência clássica do Gen 1)")

	# ---- 6. quests.json: MAIN-05 alcançável, ROCKET-05 com objetivo real ----
	var qf := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(qf.get_as_text())
	qf.close()
	_assert(quests["MAIN-05"]["requires"] == [], "MAIN-05 não exige mais MAIN-04 (nunca alcançável) — ajuste editorial")
	var main5_objs : Array = quests["MAIN-05"]["objectives"]
	var tem_reach_floor := false
	var tem_defeat_agente := false
	for o in main5_objs:
		if o.get("type","") == "reach_floor" and o.get("target","") == "pokemon_tower" and int(o.get("floor",0)) == 5:
			tem_reach_floor = true
		if o.get("type","") == "defeat" and o.get("target","") == "agente_sombra_2":
			tem_defeat_agente = true
	_assert(tem_reach_floor, "MAIN-05 pede chegar no 5º andar da Torre")
	_assert(tem_defeat_agente, "MAIN-05 pede derrotar o Agente Sombra 2")

	var rocket5_objs : Array = quests["ROCKET-05"]["objectives"]
	var tem_defeat_count := false
	for o in rocket5_objs:
		if o.get("type","") == "defeat_count" and o.get("target","") == "agente_silph" and int(o.get("count",0)) == 4:
			tem_defeat_count = true
	_assert(tem_defeat_count, "ROCKET-05 pede derrotar 4 Agentes Silph (defeat_count, tipo com handler real)")
