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
	"pokedex": { "seen": [], "caught": [] },
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

func _on_map_changed(_from: String, _to: String) -> void:
	if has_save():
		save_game()

func _on_battle_ended(_result: Dictionary) -> void:
	if has_save():
		save_game()

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
	save_data["pokedex"]   = { "seen": [], "caught": [] }
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
## Estrutura evolutions.json: {"species_id": N, "evolves_to": M, "condition": {"type": "level", "value": L}}
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

	# Evolui!
	var new_id := int(evo.get("evolves_to", species_id))
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
	EventBus.pokemon_evolved.emit(species_id, new_id)
	_check_evolution(index)  # cadeia de evolução

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
		"is_shiny":   bp.is_shiny,
		"hp_current": bp.hp,
		"hp_max":     bp.max_hp,
		"moves":      moves,
		"status":     "none",
		"held_item":  ""
	}
