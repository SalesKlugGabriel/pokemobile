## SaveManager.gd — Gerenciamento completo de save do jogo (Autoload/Singleton)
extends Node

const SAVE_PATH := "user://pokemobile_save.json"

# Pokémon salvo: species_id, nickname, level, exp, ivs, is_shiny,
#                hp_current, hp_max, moves:[{id,pp_current,pp_max}],
#                status, held_item, uuid
var save_data: Dictionary = {
	"trainer": {
		"name": "Ash",
		"hp_current": 100,
		"hp_max": 100,
		"level": 1,
		"exp": 0,
		"money": 3000,
		"skill_tree": {
			"agilidade": 0, "sobrevivencia": 0,
			"afinidade": 0, "mestre_captura": 0, "sorte": 0
		},
		"skill_points_available": 0
	},
	"team": [],   # máx 6 Pokémons (formato acima)
	"pc":   [],   # armazenamento ilimitado
	"inventory": {},
	"quests": {},
	"diaries": [],
	"badges": [],
	"titles": [],
	"pokedex": { "seen": [], "caught": [], "defeated": {} },
	"world": {
		"current_map": "world_map",
		"last_pokemon_center": "world_map",
		"visited_maps": [],
		"defeated_alphas": [],
		"alpha_respawn_timers": {}
	},
	"final_choice": "",
	"rng_seed": 0
}

var _save_exists: bool = false

func _ready() -> void:
	_save_exists = FileAccess.file_exists(SAVE_PATH)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.zone_changed.connect(_on_zone_changed)

func _on_map_changed(_from: String, _to: String) -> void:
	if has_save():
		save_game()

func _on_battle_ended(_result: Dictionary) -> void:
	if has_save():
		save_game()

## "world.visited_maps" já existia no schema do save desde sempre, mas nunca
## era escrito nem lido em lugar nenhum — preparado, nunca ligado (mesma
## classe de achado já vista em QuestManager/reach_floor antes de existir
## handler). Usado agora pra saber a quais cidades o jogador já foi, base
## pro Teleporte (Mecânicas, 02/09): entra na lista assim que o jogador PISA
## na zona (não precisa curar no Centro), igual ao Jogo original.
func _on_zone_changed(zone_name: String) -> void:
	var visited: Array = save_data["world"]["visited_maps"]
	if zone_name not in visited:
		visited.append(zone_name)

# ──────────────────────────────────────────────────────────────────────────────
# SAVE / LOAD / DELETE
# ──────────────────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return _save_exists

func save_game() -> void:
	save_data["rng_seed"] = RNGManager.get_seed()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_save_exists = true
	EventBus.game_saved.emit()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveManager] Nenhum save encontrado.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text  := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("[SaveManager] Erro ao parsear save.")
		return false
	save_data = parsed
	RNGManager.set_seed(save_data.get("rng_seed", 0))
	_save_exists = true
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save_exists = false

# ──────────────────────────────────────────────────────────────────────────────
# NEW GAME
# ──────────────────────────────────────────────────────────────────────────────

## Inicializa um novo jogo com nome do treinador e espécie do starter.
func new_game(trainer_name: String, starter_species_id: int) -> void:
	# Reseta estrutura
	save_data["trainer"]["name"]  = trainer_name
	save_data["trainer"]["money"] = 3000
	save_data["team"]      = []
	save_data["pc"]        = []
	save_data["inventory"] = { "pokeball": 5, "potion": 3 }
	save_data["quests"]    = {}
	save_data["diaries"]   = []
	save_data["badges"]    = []
	save_data["titles"]    = []
	save_data["pokedex"]   = { "seen": [], "caught": [], "defeated": {} }
	save_data["world"]["current_map"]          = "world_map"
	save_data["world"]["last_pokemon_center"]  = "world_map"
	save_data["world"]["visited_maps"]         = []
	save_data["world"]["defeated_alphas"]      = []
	save_data["world"]["alpha_respawn_timers"] = {}
	save_data["final_choice"] = ""
	save_data["rng_seed"]     = randi()

	RNGManager.set_seed(save_data["rng_seed"])

	# Cria o Pokémon inicial (level 5)
	var starter := _make_pokemon_data(starter_species_id, 5)
	save_data["team"].append(starter)
	mark_caught(starter_species_id)

	save_game()

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS DE ACESSO — TIME
# ──────────────────────────────────────────────────────────────────────────────

func get_trainer() -> Dictionary:
	return save_data["trainer"]

func get_team() -> Array:
	return save_data["team"]

func get_pokemon_at(index: int) -> Dictionary:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return {}
	return team[index]

func get_visited_maps() -> Array:
	return save_data["world"]["visited_maps"]

## True se algum Pokémon do time já sabe o golpe E é do tipo exigido — pedido
## do Gabriel (02/09): Surfar exige um Pokémon de tipo Água que saiba "surf"
## (não vale ensinar a MT11 num Pikachu e sair nadando), Voar exige um de
## tipo Voador que saiba "fly". O golpe é ensinado via MT/MO na Mochila
## (PauseMenu._teach_and_finish grava em team[i].moves); nenhum dos dois
## precisa desse Pokémon estar líder do time, só fazer parte dele.
func team_has_move_of_type(move_id: String, required_type: String) -> bool:
	for poke in save_data["team"]:
		var sabe_o_golpe := false
		for move in poke.get("moves", []):
			if move.get("id", "") == move_id:
				sabe_o_golpe = true
				break
		if not sabe_o_golpe:
			continue
		var types : Array = GameData.get_species(int(poke.get("species_id", 0))).get("types", [])
		for t in types:
			if String(t).capitalize() == required_type.capitalize():
				return true
	return false

## True se o time tem algum Pokémon cujo species_id está na lista dada —
## base da Montaria (Tauros/Dodrio/Rhyhorn/etc., 02/09): não é golpe
## nenhum, é só ter o bicho no time, igual o próprio Gabriel descreveu.
func team_has_any_species(species_ids: Array) -> bool:
	for poke in save_data["team"]:
		if int(poke.get("species_id", 0)) in species_ids:
			return true
	return false

func get_starter_species() -> int:
	var team: Array = save_data["team"]
	if team.is_empty():
		return 1
	return int(team[0].get("species_id", 1))

func get_starter_level() -> int:
	var team: Array = save_data["team"]
	if team.is_empty():
		return 5
	return int(team[0].get("level", 5))

## Atualiza dados de um Pokémon do time após batalha (HP, PP, status, exp).
func update_team_pokemon(index: int, data: Dictionary) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	team[index] = data

## Dá EXP ao Pokémon no índice; retorna nível após (pode ter subido).
func add_exp_to_pokemon(index: int, exp_gained: int) -> int:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return 0
	var poke: Dictionary = team[index]
	poke["exp"] = int(poke.get("exp", 0)) + exp_gained
	# Level up loop (medium-fast: n³)
	while true:
		var lv  : int = int(poke.get("level", 1))
		if lv >= 100:
			break
		var needed : int = (lv + 1) * (lv + 1) * (lv + 1)
		if int(poke["exp"]) >= needed:
			poke["level"] = lv + 1
			# Recalcula hp_max e hp_current proporcional
			var old_max : int = int(poke.get("hp_max", 1))
			var new_max : int = _calc_hp(
				GameData.get_species(int(poke["species_id"])).get("base_stats", {}).get("hp", 45),
				int(poke.get("ivs", {}).get("hp", 15)),
				poke["level"]
			)
			var ratio := float(int(poke.get("hp_current", old_max))) / float(old_max)
			poke["hp_max"]     = new_max
			poke["hp_current"] = maxi(1, roundi(new_max * ratio))
		else:
			break
	team[index] = poke
	# Verificar evolução
	_check_evolution(index)
	return int(poke["level"])

## Verifica e aplica evolução por level.
## Estrutura evolutions.json: {"species_id": N, "evolves_to": M, "condition": {"type": "level"|"stone", "value": L|item_id}}
func _check_evolution(index: int) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	var poke : Dictionary = team[index]
	var species_id    := int(poke.get("species_id", 0))
	var current_level : int = int(poke.get("level", 1))

	var evo : Dictionary = GameData.get_evolution(species_id)
	if evo.is_empty():
		return
	var condition : Dictionary = evo.get("condition", {})
	if condition.get("type", "") != "level":
		return
	if current_level < int(condition.get("value", 999)):
		return

	_apply_evolution(index, int(evo.get("evolves_to", species_id)))
	_check_evolution(index)  # cadeia de evolução

## Tenta evoluir o Pokémon no índice usando uma pedra (Fire Stone etc — item
## com category "stone"). Retorna true se evoluiu (e consome a pedra fora
## daqui, quem chamar decide). Achado: `evolutions.json` já tinha as 13
## evoluções por pedra mapeadas (bate exato com o Gen 1 de verdade), só
## nunca tinha sido ligado a nada — `_check_evolution` só olhava "level".
func try_evolve_with_stone(index: int, stone_item_id: String) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var species_id := int(team[index].get("species_id", 0))
	var evo : Dictionary = GameData.get_evolution(species_id)
	if evo.is_empty():
		return false
	var condition : Dictionary = evo.get("condition", {})
	if condition.get("type", "") != "stone" or String(condition.get("value", "")) != stone_item_id:
		return false
	_apply_evolution(index, int(evo.get("evolves_to", species_id)))
	return true

func _apply_evolution(index: int, new_id: int) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	var poke : Dictionary = team[index]
	var old_id : int = int(poke.get("species_id", 0))
	var current_level : int = int(poke.get("level", 1))
	var new_species := GameData.get_species(new_id)
	if new_species.is_empty():
		return
	poke["species_id"]   = new_id
	poke["species_name"] = new_species.get("name", "???")
	var new_max := _calc_hp(
		new_species.get("base_stats", {}).get("hp", 45),
		int(poke.get("ivs", {}).get("hp", 15)),
		current_level
	)
	var ratio := float(int(poke.get("hp_current", 1))) / float(maxi(1, int(poke.get("hp_max", 1))))
	poke["hp_max"]     = new_max
	poke["hp_current"] = maxi(1, roundi(new_max * ratio))
	team[index] = poke
	EventBus.pokemon_evolved.emit(old_id, new_id)

## Ensina um move num slot (0-3) do Pokémon no índice — usado por TM/HM.
## `slot_index` = -1 significa "primeiro slot vazio" (só funciona se tiver
## menos de 4 moves); com moveset cheio, quem chamar precisa escolher o slot.
func learn_move(index: int, move_id: String, slot_index: int = -1) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var move_data := GameData.get_move(move_id)
	if move_data.is_empty():
		return false
	var poke : Dictionary = team[index]
	var moves : Array = poke.get("moves", [])
	var new_move := {
		"id": move_id,
		"pp_current": int(move_data.get("pp", 10)),
		"pp_max": int(move_data.get("pp", 10)),
	}
	if slot_index < 0:
		if moves.size() >= 4:
			return false
		moves.append(new_move)
	else:
		if slot_index >= moves.size():
			return false
		moves[slot_index] = new_move
	poke["moves"] = moves
	team[index] = poke
	return true

## Equipa um item segurado no Pokémon do índice, tirando do inventário. Se ele
## já segurava outro item, esse item volta pro inventário (troca, não perde).
## Retorna false se o item não existe no inventário.
func equip_held_item(index: int, item_id: String) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	if not has_item(item_id, 1):
		return false
	var poke : Dictionary = team[index]
	var old_item : String = str(poke.get("held_item", ""))
	remove_item(item_id, 1)
	if not old_item.is_empty():
		add_item(old_item, 1)
	poke["held_item"] = item_id
	team[index] = poke
	return true

## Tira o item segurado do Pokémon do índice, devolvendo pro inventário.
## Retorna o item_id removido ("" se ele não segurava nada).
func unequip_held_item(index: int) -> String:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return ""
	var poke : Dictionary = team[index]
	var item_id : String = str(poke.get("held_item", ""))
	if item_id.is_empty():
		return ""
	add_item(item_id, 1)
	poke["held_item"] = ""
	team[index] = poke
	return item_id

## Cura todo o time: HP e PP restaurados, status removido. Salva o jogo.
func heal_team() -> void:
	for poke in save_data["team"]:
		poke["hp_current"] = int(poke.get("hp_max", 1))
		poke["status"] = "none"
		for move in poke.get("moves", []):
			move["pp_current"] = int(move.get("pp_max", 35))
	save_game()

## Adiciona Pokémon ao time (ou PC se cheio). Retorna "team" ou "pc".
func add_pokemon(pokemon_data: Dictionary) -> String:
	var team: Array = save_data["team"]
	if team.size() < 6:
		team.append(pokemon_data)
		return "team"
	else:
		save_data["pc"].append(pokemon_data)
		return "pc"

## Alias de add_pokemon — nome que o QuestManager usa pra presente de missão
## (mesmo destino: time se tiver vaga, senão PC).
func add_pokemon_to_party(pokemon_data: Dictionary) -> String:
	return add_pokemon(pokemon_data)

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — INVENTÁRIO
# ──────────────────────────────────────────────────────────────────────────────

func get_inventory() -> Dictionary:
	return save_data["inventory"]

func add_item(item_id: String, quantity: int = 1) -> void:
	var inv: Dictionary = save_data["inventory"]
	inv[item_id] = int(inv.get(item_id, 0)) + quantity

func remove_item(item_id: String, quantity: int = 1) -> bool:
	var inv: Dictionary = save_data["inventory"]
	if int(inv.get(item_id, 0)) < quantity:
		return false
	inv[item_id] = int(inv[item_id]) - quantity
	if int(inv[item_id]) == 0:
		inv.erase(item_id)
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return int(save_data["inventory"].get(item_id, 0)) >= quantity

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — DINHEIRO
# ──────────────────────────────────────────────────────────────────────────────
## Achado: OverworldHUD.gd já chamava SaveManager.get_money() desde antes desta
## função existir de verdade — era a causa do erro "a number is required" que
## aparecia sozinho toda vez que o HUD do mundo atualizava.
func get_money() -> int:
	return int(save_data["trainer"].get("money", 0))

func add_money(amount: int) -> void:
	save_data["trainer"]["money"] = get_money() + maxi(0, amount)

## Retorna true se conseguiu pagar (tinha dinheiro suficiente).
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_money() < amount:
		return false
	save_data["trainer"]["money"] = get_money() - amount
	return true

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — POKÉDEX
# ──────────────────────────────────────────────────────────────────────────────

func get_pokedex() -> Dictionary:
	return save_data.get("pokedex", { "seen": [], "caught": [] })

func mark_seen(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if species_id not in dex["seen"]:
		dex["seen"].append(species_id)

func mark_caught(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if species_id not in dex["seen"]:
		dex["seen"].append(species_id)
	if species_id not in dex["caught"]:
		dex["caught"].append(species_id)

func is_seen(species_id: int) -> bool:
	return species_id in save_data["pokedex"]["seen"]

func is_caught(species_id: int) -> bool:
	return species_id in save_data["pokedex"]["caught"]

## Bestiary — quantas vezes essa espécie já foi derrotada em batalha selvagem
## (não conta treinador, não é "quem venceu de quem", é presença registrada).
func record_defeat(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if not dex.has("defeated"):
		dex["defeated"] = {}
	var key := str(species_id)
	dex["defeated"][key] = int(dex["defeated"].get(key, 0)) + 1
	mark_seen(species_id)

func get_defeat_count(species_id: int) -> int:
	var dex: Dictionary = save_data.get("pokedex", {})
	return int(dex.get("defeated", {}).get(str(species_id), 0))

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — INSÍGNIAS E TÍTULOS
# ──────────────────────────────────────────────────────────────────────────────

func get_badges() -> Array:
	return save_data["badges"]

func award_badge(badge_id: String) -> void:
	if badge_id.is_empty() or badge_id in save_data["badges"]:
		return
	save_data["badges"].append(badge_id)
	save_game()

func has_badge(badge_id: String) -> bool:
	return badge_id in save_data["badges"]

func get_titles() -> Array:
	return save_data.get("titles", [])

func unlock_title(title: String) -> void:
	if title.is_empty() or title in save_data["titles"]:
		return
	save_data["titles"].append(title)
	save_game()

func has_title(title: String) -> bool:
	return title in save_data.get("titles", [])

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — QUESTS (progresso persistido; QuestManager é o dono da lógica)
# ──────────────────────────────────────────────────────────────────────────────

## Salva o progresso de UMA quest. `completed=true` some da lista de ativas.
func save_quest_progress(quest_id: String, progress: Array, completed: bool) -> void:
	save_data["quests"][quest_id] = { "progress": progress.duplicate(), "completed": completed }
	save_game()

## Devolve o dicionário inteiro quest_id → {progress, completed}, pro QuestManager
## reconstruir o próprio estado (ativas/completas) ao carregar o jogo.
func get_all_quest_progress() -> Dictionary:
	return save_data.get("quests", {})

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — XP E SKILL TREE DO TREINADOR
# ──────────────────────────────────────────────────────────────────────────────

## Ganha XP de treinador e sobe de nível (mesma curva cúbica do Pokémon, por
## consistência — nível n exige exp total (n+1)³). Cada nível dá 1 ponto de
## skill; XP de quest também pode dar ponto de bônus direto via add_skill_points.
func add_trainer_exp(amount: int) -> void:
	if amount <= 0:
		return
	var t: Dictionary = save_data["trainer"]
	t["exp"] = int(t.get("exp", 0)) + amount
	EventBus.trainer_exp_gained.emit(amount)
	var leveled := false
	while true:
		var lv: int = int(t.get("level", 1))
		if lv >= 100:
			break
		var needed: int = (lv + 1) * (lv + 1) * (lv + 1)
		if int(t["exp"]) >= needed:
			t["level"] = lv + 1
			leveled = true
		else:
			break
	if leveled:
		EventBus.trainer_level_up.emit(int(t["level"]))
	save_game()

## Constrói um TrainerStats (calculadora) a partir do save atual — sem cache,
## sempre fresco. Fonte de verdade é save_data; TrainerStats só faz a conta.
func get_trainer_stats() -> TrainerStats:
	var t: Dictionary = save_data["trainer"]
	var skill_tree: Dictionary = t.get("skill_tree", {})
	var spent := 0
	for v in skill_tree.values():
		spent += int(v)
	var ts := TrainerStats.new()
	ts.deserialize({
		"trainer_level": int(t.get("level", 1)),
		"points":        skill_tree,
		"spent_total":   spent,
		"bonus_points":  int(t.get("skill_points_available", 0)),
	})
	return ts

## Pontos de bônus concedidos fora do nível (recompensa de quest/task), somados
## aos pontos normais de nível na hora de calcular quanto dá pra gastar.
func add_skill_points(n: int) -> void:
	if n <= 0:
		return
	var t: Dictionary = save_data["trainer"]
	t["skill_points_available"] = int(t.get("skill_points_available", 0)) + n
	save_game()
	EventBus.trainer_skill_tree_updated.emit()

## Gasta 1 ponto no atributo indicado. Retorna false se não há ponto disponível
## ou o atributo já está no máximo (TrainerStats.MAX_POINTS).
func spend_skill_point(attribute: String) -> bool:
	var ts := get_trainer_stats()
	if not ts.add_point(attribute):
		return false
	save_data["trainer"]["skill_tree"] = ts.serialize()["points"]
	save_game()
	return true

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — MUNDO
# ──────────────────────────────────────────────────────────────────────────────

func get_world() -> Dictionary:
	return save_data["world"]

func get_quest_state(quest_id: String) -> Dictionary:
	return save_data["quests"].get(quest_id, {})

# ──────────────────────────────────────────────────────────────────────────────
# UTILITÁRIOS INTERNOS
# ──────────────────────────────────────────────────────────────────────────────

## Gera UUID simples para identificar Pokémon no save.
static func _make_uuid() -> String:
	return "%08x-%04x-%04x" % [randi(), randi() % 65536, randi() % 65536]

## Calcula HP máximo (fórmula Gen 3+).
static func _calc_hp(base: int, iv: int, level: int) -> int:
	return int((2 * base + iv) * level / 100) + level + 10

## Calcula stat (fórmula Gen 3+, sem nature para simplificar).
static func _calc_stat(base: int, iv: int, level: int) -> int:
	return int((2 * base + iv) * level / 100) + 5

## Cria dicionário completo de dados de um Pokémon novo (nível dado).
func _make_pokemon_data(species_id: int, level: int) -> Dictionary:
	var species := GameData.get_species(species_id)
	var bs : Dictionary = species.get("base_stats", {})
	var ivs     := {
		"hp":  RNGManager.randi_range(0, 31),
		"atk": RNGManager.randi_range(0, 31),
		"def": RNGManager.randi_range(0, 31),
		"spa": RNGManager.randi_range(0, 31),
		"spd": RNGManager.randi_range(0, 31),
		"spe": RNGManager.randi_range(0, 31),
	}
	var hp_max := _calc_hp(int(bs.get("hp", 45)), int(ivs["hp"]), level)

	# Auto-seleciona até 4 moves aprendidos até este nível
	var learnset : Array = GameData.get_learnable_moves(species_id, level)
	var available : Array = []
	for entry in learnset:
		available.append(entry["move"])
	if available.size() > 4:
		available = available.slice(available.size() - 4)
	var moves : Array = []
	for move_id in available:
		var move_data := GameData.get_move(move_id)
		moves.append({
			"id":         move_id,
			"pp_current": int(move_data.get("pp", 35)),
			"pp_max":     int(move_data.get("pp", 35))
		})

	return {
		"uuid":       _make_uuid(),
		"species_id": species_id,
		"nickname":   "",
		"level":      level,
		"exp":        level * level * level,  # início exato do nível
		"ivs":        ivs,
		"evs":        { "hp":0, "atk":0, "def":0, "spa":0, "spd":0, "spe":0 },
		"nature":     GameData.roll_random_nature(),
		"is_shiny":   false,
		"hp_current": hp_max,
		"hp_max":     hp_max,
		"moves":      moves,
		"status":     "none",
		"held_item":  ""
	}

## Cria dados de Pokémon capturado a partir de um BattlePokemon.
func make_caught_data(bp) -> Dictionary:
	var moves : Array = []
	for move in bp.moves:
		moves.append({
			"id":         move.get("id", ""),
			"pp_current": int(move.get("pp_current", 0)),
			"pp_max":     int(move.get("pp_max", 35))
		})
	var species := GameData.get_species(bp.species_id)
	var bs : Dictionary = species.get("base_stats", {})
	return {
		"uuid":       _make_uuid(),
		"species_id": bp.species_id,
		"nickname":   "",
		"level":      bp.level,
		"exp":        bp.level * bp.level * bp.level,
		"ivs":        bp.ivs,
		"evs":        { "hp":0, "atk":0, "def":0, "spa":0, "spd":0, "spe":0 },
		"nature":     bp.nature,
		"is_shiny":   bp.is_shiny,
		"hp_current": bp.hp,
		"hp_max":     bp.max_hp,
		"moves":      moves,
		"status":     "none",
		"held_item":  ""
	}
