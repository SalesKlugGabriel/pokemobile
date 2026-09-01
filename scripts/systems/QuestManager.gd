extends Node
## QuestManager — Autoload
## Manages quest state: active, completed, objective progress.
## Listens to EventBus signals and auto-advances objectives.
##
## Achado ao ligar (31/08/2026): este arquivo já existia pronto, mas nunca era
## carregado (faltava no autoload) e usava Engine.has_singleton()/get_singleton()
## pra falar com EventBus/SaveManager/GameData — API errada pra autoload do
## Godot (é só pra singleton nativo/C++). Corrigido pra chamar os autoloads
## direto pelo nome, como todo resto do projeto já faz. Também não existia
## nenhum "carregar progresso salvo" — só salvava, nunca lia de volta.

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_index: int, progress: int)
signal quest_completed(quest_id: String)

const QUESTS_PATH := "res://data/quests/quests.json"

var _all_quests: Dictionary = {}        # quest_id -> quest definition
var _active_quests: Dictionary = {}     # quest_id -> { "progress": [int, ...] }
var _completed_quests: Array[String] = []

## Diálogo aberto por último (EventBus.dialog_started manda o NPC, mas
## dialog_ended não manda nada — precisa lembrar aqui pra saber quem era).
var _last_npc_dialog_id: String = ""


func _ready() -> void:
	_load_quests()
	reload_from_save()
	_connect_event_bus()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start a quest if pre-requisites are satisfied and it is not already active/done.
func start_quest(quest_id: String) -> void:
	if not _all_quests.has(quest_id):
		push_warning("QuestManager.start_quest: unknown quest '%s'" % quest_id)
		return
	if quest_id in _completed_quests or _active_quests.has(quest_id):
		return
	var quest_data: Dictionary = _all_quests[quest_id]
	for req in quest_data.get("requires", []):
		if not is_quest_complete(req):
			return  # Pre-requisite not met
	var obj_count: int = quest_data.get("objectives", []).size()
	var progress: Array = Array([], TYPE_INT, "", null)
	for i in obj_count:
		progress.append(0)
	_active_quests[quest_id] = {"progress": progress}
	emit_signal("quest_started", quest_id)
	SaveManager.save_quest_progress(quest_id, progress, false)


## Update objective progress. Completes the quest automatically when all objectives done.
func update_objective(quest_id: String, objective_index: int, progress: int) -> void:
	if not _active_quests.has(quest_id):
		return
	var state: Dictionary = _active_quests[quest_id]
	var prg: Array = state["progress"]
	if objective_index < 0 or objective_index >= prg.size():
		return
	prg[objective_index] = progress
	emit_signal("quest_updated", quest_id, objective_index, progress)
	# Check if all objectives are complete
	var quest_data: Dictionary = _all_quests[quest_id]
	var objectives: Array = quest_data.get("objectives", [])
	var all_done := true
	for i in objectives.size():
		var required: int = _get_objective_required(objectives[i])
		if prg[i] < required:
			all_done = false
			break
	if all_done:
		complete_quest(quest_id)
	else:
		SaveManager.save_quest_progress(quest_id, prg, false)


## Manually complete a quest (also called internally when objectives done).
func complete_quest(quest_id: String) -> void:
	if not _active_quests.has(quest_id):
		return
	var final_progress: Array = _active_quests[quest_id].get("progress", [])
	_active_quests.erase(quest_id)
	_completed_quests.append(quest_id)
	SaveManager.save_quest_progress(quest_id, final_progress, true)
	var quest_data: Dictionary = _all_quests[quest_id]
	_give_rewards(quest_data)
	emit_signal("quest_completed", quest_id)
	# Auto-start unlocked quests
	for unlocked_id in quest_data.get("unlocks", []):
		start_quest(unlocked_id)


func get_active_quests() -> Array:
	return _active_quests.keys()


func is_quest_complete(quest_id: String) -> bool:
	return quest_id in _completed_quests


func get_quest_data(quest_id: String) -> Dictionary:
	return _all_quests.get(quest_id, {})


func get_objective_progress(quest_id: String, objective_index: int) -> int:
	if not _active_quests.has(quest_id):
		return 0
	var prg: Array = _active_quests[quest_id].get("progress", [])
	if objective_index < prg.size():
		return prg[objective_index]
	return 0


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_quests() -> void:
	var file := FileAccess.open(QUESTS_PATH, FileAccess.READ)
	if file == null:
		push_error("QuestManager: could not open '%s'" % QUESTS_PATH)
		return
	var json_text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("QuestManager: invalid JSON in quests.json")
		return
	_all_quests = parsed


## Reconstrói _active_quests/_completed_quests a partir do save atual —
## sem isso, todo progresso de quest sumia ao reabrir o jogo (o antigo
## _save_state() só escrevia, nunca tinha um par que lesse de volta).
## Público (sem "_") porque também precisa ser chamado de fora: o autoload
## roda no boot do jogo, ANTES da TitleScreen decidir se carrega um save
## existente — sem essa segunda chamada, "Continuar" mostraria o progresso
## de quest sempre zerado. Idempotente: limpa o estado antes de reconstruir.
func reload_from_save() -> void:
	_active_quests.clear()
	_completed_quests.clear()
	var saved: Dictionary = SaveManager.get_all_quest_progress()
	for quest_id in saved.keys():
		if not _all_quests.has(quest_id):
			continue  # quest_id salvo não existe mais nos dados atuais
		var entry: Dictionary = saved[quest_id]
		if entry.get("completed", false):
			_completed_quests.append(quest_id)
		else:
			var prg: Array = Array(entry.get("progress", []), TYPE_INT, "", null)
			_active_quests[quest_id] = {"progress": prg}


func _connect_event_bus() -> void:
	EventBus.capture_success.connect(_on_capture_success)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.dialog_started.connect(_on_dialog_started)
	EventBus.dialog_ended.connect(_on_dialog_ended)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.floor_reached.connect(_on_floor_reached)


func _give_rewards(quest_data: Dictionary) -> void:
	var rewards: Dictionary = quest_data.get("rewards", {})
	if rewards.is_empty():
		return
	# EXP de treinador
	var exp_trainer: int = rewards.get("exp_trainer", 0)
	if exp_trainer > 0:
		SaveManager.add_trainer_exp(exp_trainer)
	# Itens (e TM/HM — mesmo tratamento, viram item no inventário)
	for item_entry in rewards.get("items", []):
		var item_id: String = item_entry.get("id", "")
		var quantity: int   = item_entry.get("quantity", 1)
		if not item_id.is_empty():
			SaveManager.add_item(item_id, quantity)
	for tm_entry in rewards.get("tms", []) + rewards.get("hms", []):
		var tm_id: String = tm_entry.get("id", "")
		if not tm_id.is_empty():
			SaveManager.add_item(tm_id, 1)
	# Pontos de skill (bônus, fora da progressão normal por nível)
	var skill_pts: int = rewards.get("skill_points", 0)
	if skill_pts > 0:
		SaveManager.add_skill_points(skill_pts)
	# Títulos
	for title in rewards.get("titles", []):
		SaveManager.unlock_title(title)
	# Insígnias
	for badge in rewards.get("badges", []):
		SaveManager.award_badge(badge)
	# Pokémon de presente
	var gift_pokemon: Dictionary = rewards.get("pokemon", {})
	if not gift_pokemon.is_empty():
		SaveManager.add_pokemon_to_party(gift_pokemon)


func _get_objective_required(objective: Dictionary) -> int:
	var obj_type: String = objective.get("type", "")
	match obj_type:
		"defeat_count", "capture_count", "monitor_count", "collect_samples",\
		"collect_count", "find_count", "capture_unique", "capture_total",\
		"defeat_alpha", "use_tms":
			return int(objective.get("count", 1))
		"reach_floor", "traverse_floors":
			return int(objective.get("floor", objective.get("floors", 1)))
		"report_sighting":
			return int(objective.get("locations", 1))
		_:
			return 1  # talk, defeat, receive_item, choice, etc.


# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_capture_success(pokemon_data: Dictionary) -> void:
	var species_id: int = int(pokemon_data.get("species_id", 0))
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			match obj.get("type", ""):
				"capture_any", "capture_total", "find_all":
					update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"capture_unique":
					pass  # exige rastrear espécies únicas — não implementado ainda
				"capture_count":
					if GameData.get_species_id_by_name(str(obj.get("target", ""))) == species_id:
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"capture":
					if GameData.get_species_id_by_name(str(obj.get("target", ""))) == species_id:
						update_objective(quest_id, i, 1)


func _on_battle_ended(result: Dictionary) -> void:
	if not result.get("player_won", false):
		return
	var enemy_name  : String = str(result.get("enemy_species_name", "")).to_lower()
	var trainer_name: String = str(result.get("trainer_name", "")).to_lower().replace(" ", "_")
	var is_wild     : bool   = result.get("is_wild", false)
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			var target: String = str(obj.get("target", "")).to_lower()
			match obj.get("type", ""):
				"defeat":
					if not is_wild and target == trainer_name:
						update_objective(quest_id, i, 1)
					elif is_wild and target == enemy_name:
						update_objective(quest_id, i, 1)
				"defeat_count":
					if target == "any":
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
					elif target == "wild_pokemon" and is_wild:
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
					elif target == enemy_name:
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"defeat_alpha":
					if result.get("is_alpha", false):
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				_:
					pass


func _on_dialog_started(npc: Node) -> void:
	_last_npc_dialog_id = str(npc.get("dialog_id")) if npc and npc.get("dialog_id") else ""


func _on_dialog_ended() -> void:
	if _last_npc_dialog_id.is_empty():
		return
	var npc_id := _last_npc_dialog_id
	_last_npc_dialog_id = ""
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") == "talk" and str(obj.get("target", "")) == npc_id:
				update_objective(quest_id, i, 1)


func _on_item_picked_up(item_id: String, _quantity: int) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") == "receive_item" and obj.get("item", "") == item_id:
				update_objective(quest_id, i, 1)


func _on_zone_changed(zone_name: String) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") in ["reach_zone", "infiltrate"] and obj.get("target", "") == zone_name:
				update_objective(quest_id, i, 1)


## reach_floor/traverse_floors: o objetivo já tinha o "required" calculado
## (_get_objective_required lê "floor" ou "floors"), só faltava algo chamar
## update_objective quando o jogador de fato chega lá. `floor` é o andar
## alcançado agora — usa o MAIOR já visto (voltar pra um andar de cima não
## reduz o progresso; passar direto de um andar alto pro objetivo já conta).
func _on_floor_reached(structure_id: String, floor: int) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") in ["reach_floor", "traverse_floors"] \
					and str(obj.get("target", "")) == structure_id:
				var current: int = get_objective_progress(quest_id, i)
				if floor > current:
					update_objective(quest_id, i, floor)
