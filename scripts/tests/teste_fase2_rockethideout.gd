## teste_fase2_rockethideout.gd — Teste headless do Rocket Hideout (Fase 2:
## "Pokémon e estruturas"). Cobre os 3 capangas da Equipe Rocket na sala de
## entrada (RocketHideout.tscn) e a quest ROCKET-07 ("Capangas no Esconderijo")
## que eles disparam/fecham.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase2_rockethideout.gd
##
## Escopo isolado (não mexe em MapLayouts.gd/WorldMap.tscn/zones.json — outra
## sessão está reescrevendo a geografia do mapa em paralelo): só valida
## RocketHideout.tscn, quests.json (entrada nova ROCKET-07) e dialogs.json
## (3 falas novas dos capangas).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

# Rodando via --script, os autoloads não ficam disponíveis como identificador
# global de compilação (só quando o jogo sobe pela cena normal) — por isso
# aqui eles são buscados por caminho (root.get_node) em vez do nome solto.
var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node


func _initialize() -> void:
	print("=== Teste Fase 2 — Rocket Hideout (capangas + ROCKET-07) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	# Os autoloads já EXISTEM na árvore aqui, mas o próprio _ready() deles só
	# roda no primeiro _process — testar direto aqui pegaria tudo vazio.


func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteQA", 1)
	QuestManager.reload_from_save()

	_teste_cena()
	_teste_dados_quest()
	_teste_dialogos()
	_teste_fluxo_quest()

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


# ---------------------------------------------------------------------------
# 1. RocketHideout.tscn: os 3 capangas existem, com time real e trigger certo
# ---------------------------------------------------------------------------
func _teste_cena() -> void:
	var scene := load("res://scenes/world/maps/RocketHideout.tscn") as PackedScene
	_assert(scene != null, "RocketHideout.tscn carrega sem erro")
	if not scene:
		return
	var inst := scene.instantiate()

	var g1 := inst.get_node_or_null("Entities/CapangaRocket1")
	var g2 := inst.get_node_or_null("Entities/CapangaRocket2")
	var g3 := inst.get_node_or_null("Entities/CapangaRocket3")
	_assert(g1 != null and g2 != null and g3 != null, "os 3 capangas existem na sala de entrada")

	if g1 and g2 and g3:
		_assert(g1.is_trainer and g2.is_trainer and g3.is_trainer,
			"os 3 capangas são treinadores (is_trainer=true)")
		_assert(not g1.trainer_team.is_empty() and not g2.trainer_team.is_empty() and not g3.trainer_team.is_empty(),
			"os 3 capangas têm time real cadastrado (trainer_team não vazio)")
		_assert(g1.npc_name == "Capanga Rocket" and g2.npc_name == g1.npc_name and g3.npc_name == g1.npc_name,
			"os 3 compartilham o mesmo npc_name ('Capanga Rocket') — é o que o defeat_count usa pra contar")
		_assert(g1.starts_quest_id == "ROCKET-07",
			"o capanga da entrada inicia a ROCKET-07 ao conversar")
		_assert(g2.starts_quest_id == "" and g3.starts_quest_id == "",
			"os outros 2 não iniciam quest de novo (evita reiniciar em série)")
		# Espécies de time temáticas de Gen 1 (Veneno/Escuridão de capanga de
		# gangue) e nível compatível com o wild_pokemon da própria zona
		# (zones.json: Zubat/Grimer/Raticate, level 22-32).
		var especies_validas := [19, 20, 23, 41, 88, 109]  # Rattata/Raticate/Ekans/Zubat/Grimer/Koffing
		var todas_ok := true
		for npc in [g1, g2, g3]:
			for mon in npc.trainer_team:
				var sid : int = int(mon.get("species_id", -1))
				var lvl : int = int(mon.get("level", -1))
				if not especies_validas.has(sid) or lvl < 20 or lvl > 32:
					todas_ok = false
		_assert(todas_ok, "todo Pokémon dos 3 times é temático (veneno/gangue) e de nível compatível com a zona (20-32)")

	# Regressão: warp de volta pro WorldMap continua intacto (não mexi nisso).
	var warps := inst.get_node_or_null("WarpZones")
	var achou_warp_sul := false
	if warps:
		for w in warps.get_children():
			if w.target_map.contains("WorldMap"):
				achou_warp_sul = true
	_assert(achou_warp_sul, "o warp de saída pro WorldMap continua existindo (não foi tocado)")

	inst.free()


# ---------------------------------------------------------------------------
# 2. quests.json: ROCKET-07 usa só tipo de objetivo com handler real
# ---------------------------------------------------------------------------
func _teste_dados_quest() -> void:
	var f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(f.get_as_text())
	f.close()

	_assert(quests.has("ROCKET-07"), "ROCKET-07 existe em quests.json")
	if not quests.has("ROCKET-07"):
		return
	var q : Dictionary = quests["ROCKET-07"]
	_assert(q.get("category", "") == "rocket", "ROCKET-07 é categoria 'rocket'")

	var objs : Array = q.get("objectives", [])
	_assert(objs.size() == 1, "ROCKET-07 tem 1 objetivo só")
	if objs.size() == 1:
		var obj : Dictionary = objs[0]
		_assert(obj.get("type", "") == "defeat_count",
			"objetivo é 'defeat_count' — tipo que o QuestManager já sabe processar")
		_assert(obj.get("target", "") == "capanga_rocket",
			"target 'capanga_rocket' bate com o npc_name normalizado dos 3 capangas")
		_assert(int(obj.get("count", 0)) == 3, "count=3 — um por capanga")

	var rewards : Dictionary = q.get("rewards", {})
	_assert(int(rewards.get("exp_trainer", 0)) == 300, "recompensa de exp_trainer=300")
	var itens : Array = rewards.get("items", [])
	var achou_escape_rope := false
	for it in itens:
		if it.get("id", "") == "escape_rope" and int(it.get("quantity", 0)) == 2:
			achou_escape_rope = true
	_assert(achou_escape_rope, "recompensa de 2x Escape Rope (item real de items.json)")

	# Não faz parte da cadeia principal ROCKET-01..06 — deve poder iniciar sozinha.
	_assert((q.get("requires", []) as Array).is_empty(),
		"ROCKET-07 não exige nenhuma outra quest — é independente, só da sala")


# ---------------------------------------------------------------------------
# 3. dialogs.json: as 3 falas novas existem e têm conteúdo
# ---------------------------------------------------------------------------
func _teste_dialogos() -> void:
	var f := FileAccess.open("res://data/dialogs/dialogs.json", FileAccess.READ)
	var dialogs = JSON.parse_string(f.get_as_text())
	f.close()

	for dialog_id in ["capanga_rocket_1", "capanga_rocket_2", "capanga_rocket_3"]:
		var linhas = dialogs.get(dialog_id, [])
		_assert(linhas is Array and not linhas.is_empty(),
			"dialogs.json tem falas para '%s'" % dialog_id)


# ---------------------------------------------------------------------------
# 4. Fluxo real da quest: iniciar, progredir, fechar e receber recompensa
# ---------------------------------------------------------------------------
func _teste_fluxo_quest() -> void:
	QuestManager.start_quest("ROCKET-07")
	_assert("ROCKET-07" in QuestManager.get_active_quests(), "ROCKET-07 inicia e fica ativa")

	var exp_antes := int(SaveManager.get_trainer().get("exp", 0))
	var escape_rope_antes := int(SaveManager.get_inventory().get("escape_rope", 0))

	# Derrota o 1º e o 2º capanga — ainda não fecha (faltam 3).
	for i in 2:
		EventBus.battle_ended.emit({
			"result": "win", "player_won": true, "is_wild": false,
			"trainer_name": "Capanga Rocket", "enemy_species_name": "Zubat", "enemy_level": 25,
		})
	_assert(QuestManager.get_objective_progress("ROCKET-07", 0) == 2,
		"2 capangas derrotados avançam o progresso pra 2/3")
	_assert(not QuestManager.is_quest_complete("ROCKET-07"),
		"ROCKET-07 ainda não fecha — falta o 3º capanga")

	# Uma vitória contra um Pokémon selvagem qualquer (não é o capanga) não conta.
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": true,
		"enemy_species_name": "Raticate", "enemy_level": 24,
	})
	_assert(QuestManager.get_objective_progress("ROCKET-07", 0) == 2,
		"vitória contra Pokémon selvagem não conta como capanga derrotado")

	# Derrota o 3º capanga — fecha a quest e dá a recompensa.
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "Capanga Rocket", "enemy_species_name": "Koffing", "enemy_level": 27,
	})
	_assert(QuestManager.is_quest_complete("ROCKET-07"), "3º capanga derrotado fecha a ROCKET-07")
	_assert(int(SaveManager.get_trainer().get("exp", 0)) == exp_antes + 300,
		"recompensa exp_trainer=300 foi creditada")
	_assert(int(SaveManager.get_inventory().get("escape_rope", 0)) == escape_rope_antes + 2,
		"recompensa de 2x Escape Rope foi creditada")
