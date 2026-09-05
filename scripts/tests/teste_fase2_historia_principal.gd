## teste_fase2_historia_principal.gd — Teste headless de "destravar a
## história principal" (02/09): MAIN-01 até MAIN-09 encadeadas de verdade
## (cada quest completa AUTO-INICIA a próxima via "unlocks", mecanismo que
## já existia no QuestManager desde a Fase 0 — só nunca tinha sido
## exercitado ponta a ponta), terminando no Ginásio de Viridian (Giovanni)
## abrindo de verdade. Content novo: Agente Sombra 1 (Mt Moon), Game Corner
## + Bruno (Celadon), Quartel General + resgate do Carvalho (embaixo do
## Game Corner), Mansão Pokémon com 3 andares (Cinnabar), Giovanni no
## Ginásio de Viridian. Handler novo: defeat_count por TIPO (ex:
## "water_pokemon"), reaproveitável por qualquer quest futura do gênero.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase2_historia_principal.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node

func _initialize() -> void:
	print("=== Teste Fase 2 (História Principal MAIN-01..MAIN-09) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	SaveManager.new_game("TesteHistoria", 1)
	QuestManager.reload_from_save()
	_teste_conteudo_novo()
	_teste_giovanni_tile_bloqueado()
	_teste_cascata_main()
	_teste_giovanni_tile_liberado()
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

# ── 1. Conteúdo novo: cenas/NPCs/zonas ──────────────────────────────────
func _teste_conteudo_novo() -> void:
	var mt_moon := (load("res://scenes/world/maps/MtMoon.tscn") as PackedScene).instantiate()
	var sombra1 := mt_moon.get_node_or_null("Entities/AgenteSombra1")
	_assert(sombra1 != null and sombra1.is_trainer, "Agente Sombra 1 existe em Mt Moon")
	mt_moon.free()

	for path in ["PokemonMansion_F1", "PokemonMansion_F2", "PokemonMansion_F3"]:
		var scene := load("res://scenes/world/maps/%s.tscn" % path) as PackedScene
		_assert(scene != null, "%s.tscn carrega sem erro" % path)

	var gc := (load("res://scenes/world/maps/CeladonGameCorner.tscn") as PackedScene).instantiate()
	var bruno := gc.get_node_or_null("Entities/Bruno")
	_assert(bruno != null and bruno.dialog_id == "bruno_game_corner", "Bruno existe no Game Corner")
	var gc_warps := gc.get_node_or_null("WarpZones")
	var achou_hq := false
	if gc_warps:
		for w in gc_warps.get_children():
			if w.target_map.contains("RocketHQ_F1"):
				achou_hq = true
	_assert(achou_hq, "Game Corner tem warp escondido pro Quartel General")
	gc.free()

	var hq2 := (load("res://scenes/world/maps/RocketHQ_F2.tscn") as PackedScene).instantiate()
	var carvalho := hq2.get_node_or_null("Entities/CarvalhoResgate")
	var boss := hq2.get_node_or_null("Entities/AgenteSombraFinal")
	_assert(carvalho != null and carvalho.dialog_id == "carvalho_resgate", "Carvalho preso existe no Quartel General")
	_assert(boss != null and boss.is_trainer and boss.npc_name == "Agente Sombra Final",
		"Agente Sombra Final existe e é treinador")
	hq2.free()

	var world := (load("res://scenes/world/maps/WorldMap.tscn") as PackedScene).instantiate()
	var giovanni := world.get_node_or_null("Entities/Giovanni")
	var oak := world.get_node_or_null("Entities/ProfCarvalho")
	_assert(giovanni != null and giovanni.trainer_team.size() == 6, "Giovanni existe com time completo de 6 Pokémon tipo Terra (Fase 5, 02/09)")
	_assert(oak != null and oak.starts_quest_id == "MAIN-01", "Prof. Carvalho inicia a MAIN-01")
	world.free()

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(by_id.has("rocket_hq") and by_id["rocket_hq"]["map_id"] == "rocket_hq_f1",
		"zona rocket_hq existe, ligada ao 1º andar do Quartel General")
	for i in range(1, 4):
		_assert(by_id.has("pokemon_mansion_f%d" % i), "zona pokemon_mansion_f%d existe" % i)

# ── 2. Ginásio de Viridian começa FECHADO (MAIN-08 ainda não completa) ──
func _teste_giovanni_tile_bloqueado() -> void:
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	# 05/09 (Fase 0): era `tiles[90][26]`. O Ginásio de Viridian é o ÚNICO tile
	# do mapa que muda com o estado do save, então o teste tem que achar a porta
	# em vez de decorar onde ela fica.
	var r_vir := AjudaMapa.retangulo_da_zona("viridian_city")
	_assert(not AjudaMapa.tem_porta(tiles, Rect2i(r_vir.position.x + 20, r_vir.position.y + 12, 14, 8)),
		"porta do Ginásio de Viridian começa FECHADA (MAIN-08 não completa)")

# ── 3. Cascata MAIN-01 → MAIN-09: cada conclusão auto-inicia a próxima ──
func _teste_cascata_main() -> void:
	QuestManager.start_quest("MAIN-01")
	_assert(QuestManager.get_active_quests().has("MAIN-01"), "MAIN-01 iniciada (Prof. Carvalho)")
	QuestManager.update_objective("MAIN-01", 0, 1)
	_assert(QuestManager.is_quest_complete("MAIN-01"), "MAIN-01 completa (talk oak_intro)")
	_assert(QuestManager.get_active_quests().has("MAIN-02"), "MAIN-02 auto-iniciada (cascata de unlocks)")

	QuestManager.update_objective("MAIN-02", 0, 3)
	_assert(QuestManager.is_quest_complete("MAIN-02"), "MAIN-02 completa (3 selvagens)")
	_assert(QuestManager.get_active_quests().has("MAIN-03"), "MAIN-03 auto-iniciada")

	# defeat agente_sombra_1 — simula o resultado real de uma batalha de treinador
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "agente_sombra_1", "enemy_species": 0,
	})
	_assert(QuestManager.is_quest_complete("MAIN-03"), "MAIN-03 completa (derrotar Agente Sombra 1)")
	_assert(QuestManager.get_active_quests().has("MAIN-04"), "MAIN-04 auto-iniciada")

	# defeat_count water_pokemon — handler novo por TIPO, não por nome/espécie
	for i in 5:
		EventBus.battle_ended.emit({
			"result": "win", "player_won": true, "is_wild": true,
			"trainer_name": "", "enemy_species": 7,  # Squirtle — tipo Water
		})
	_assert(QuestManager.is_quest_complete("MAIN-04"), "MAIN-04 completa (5 Pokémon de água — handler por tipo)")
	_assert(QuestManager.get_active_quests().has("MAIN-05"), "MAIN-05 auto-iniciada")

	EventBus.floor_reached.emit("pokemon_tower", 5)
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "agente_sombra_2", "enemy_species": 0,
	})
	_assert(QuestManager.is_quest_complete("MAIN-05"), "MAIN-05 completa (andar 5 + Agente Sombra 2)")
	_assert(QuestManager.get_active_quests().has("MAIN-06"), "MAIN-06 auto-iniciada")

	QuestManager.update_objective("MAIN-06", 0, 1)
	_assert(QuestManager.is_quest_complete("MAIN-06"), "MAIN-06 completa (talk Bruno)")
	_assert(QuestManager.get_active_quests().has("MAIN-07"), "MAIN-07 auto-iniciada")

	EventBus.floor_reached.emit("pokemon_mansion", 3)
	_assert(QuestManager.is_quest_complete("MAIN-07"), "MAIN-07 completa (3º andar da Mansão)")
	_assert(QuestManager.get_active_quests().has("MAIN-08"), "MAIN-08 auto-iniciada")

	EventBus.zone_changed.emit("rocket_hq")
	QuestManager.update_objective("MAIN-08", 1, 1)  # talk carvalho_resgate
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "agente_sombra_final", "enemy_species": 0,
	})
	_assert(QuestManager.is_quest_complete("MAIN-08"),
		"MAIN-08 completa (infiltrar + resgatar Carvalho + derrotar Agente Sombra Final)")
	_assert(QuestManager.get_active_quests().has("MAIN-09"), "MAIN-09 auto-iniciada")
	_assert(QuestManager.get_active_quests().has("GYM-08"), "GYM-08 auto-iniciada (Ginásio de Viridian libera)")

	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "giovanni", "enemy_species": 0,
	})
	_assert(QuestManager.is_quest_complete("MAIN-09"), "MAIN-09 completa (derrotar Giovanni)")
	_assert(QuestManager.is_quest_complete("GYM-08"),
		"GYM-08 completa também (mesma batalha conta pras 2 quests ativas)")

# ── 4. Depois de MAIN-08 completa, a porta do Ginásio abre de verdade ───
func _teste_giovanni_tile_liberado() -> void:
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	var r_vir2 := AjudaMapa.retangulo_da_zona("viridian_city")
	var recorte_ginasio := Rect2i(r_vir2.position.x + 20, r_vir2.position.y + 12, 14, 8)
	_assert(AjudaMapa.conta_char(tiles, recorte_ginasio, ["P"]) > 0,
		"porta do Ginásio de Viridian agora está ABERTA (MAIN-08 completa)")
	_assert(AjudaMapa.conta_char(tiles, Rect2i(r_vir2.position.x + 20, r_vir2.position.y + 2, 14, 12), ["I"]) > 0,
		"interior do Ginásio agora é andável (Giovanni pode ser desafiado)")
