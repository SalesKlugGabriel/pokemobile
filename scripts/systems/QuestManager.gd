extends Node
## QuestManager — Autoload
## Manages quest state: active, completed, objective progress.
## Listens to EventBus signals and auto-advances objectives.

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_index: int, progress: int)
signal quest_completed(quest_id: String)

const QUESTS_PATH := "res://data/quests/quests.json"

var _all_quests: Dictionary = {}        # quest_id -> quest definition
var _active_quests: Dictionary = {}     # quest_id -> { "progress": [int, ...] }
var _completed_quests: Array[String] = []


func _ready() -> void:
	_load_quests()
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
	_active_quests[quest_id] = {"progress": Array([], TYPE_INT, "", null)}
	for i in obj_count:
		_active_quests[quest_id]["progress"].append(0)
	emit_signal("quest_started", quest_id)
	_save_state()


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
		_save_state()


## Manually complete a quest (also called internally when objectives done).
func complete_quest(quest_id: String) -> void:
	if not _active_quests.has(quest_id):
		return
	_active_quests.erase(quest_id)
	_completed_quests.append(quest_id)
	var quest_data: Dictionary = _all_quests[quest_id]
	_give_rewards(quest_data)
	emit_signal("quest_completed", quest_id)
	# Auto-start unlocked quests
	for unlocked_id in quest_data.get("unlocks", []):
		start_quest(unlocked_id)
	_save_state()


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


func _connect_event_bus() -> void:
	if not Engine.has_singleton("EventBus"):
		return
	var eb = Engine.get_singleton("EventBus")
	# pokemon_caught(species_id, is_alpha)
	if eb.has_signal("pokemon_caught"):
		eb.pokemon_caught.connect(_on_pokemon_caught)
	# battle_ended(result: Dictionary)
	if eb.has_signal("battle_ended"):
		eb.battle_ended.connect(_on_battle_ended)
	# dialog_ended(npc_id: String)
	if eb.has_signal("dialog_ended"):
		eb.dialog_ended.connect(_on_dialog_ended)
	# item_received(item_id: String)
	if eb.has_signal("item_received"):
		eb.item_received.connect(_on_item_received)
	# zone_entered(zone_id: String)
	if eb.has_signal("zone_entered"):
		eb.zone_entered.connect(_on_zone_entered)


func _give_rewards(quest_data: Dictionary) -> void:
	var rewards: Dictionary = quest_data.get("rewards", {})
	if rewards.is_empty():
		return
	# EXP to trainer
	var exp_trainer: int = rewards.get("exp_trainer", 0)
	if exp_trainer > 0 and Engine.has_singleton("GameData"):
		var gd = Engine.get_singleton("GameData")
		if gd.has_method("add_trainer_exp"):
			gd.add_trainer_exp(exp_trainer)
	# Items
	for item_entry in rewards.get("items", []):
		var item_id: String = item_entry.get("id", "")
		var quantity: int   = item_entry.get("quantity", 1)
		if item_id.is_empty():
			continue
		if Engine.has_singleton("SaveManager"):
			var sm = Engine.get_singleton("SaveManager")
			if sm.has_method("add_item"):
				sm.add_item(item_id, quantity)
	# Skill points
	var skill_pts: int = rewards.get("skill_points", 0)
	if skill_pts > 0 and Engine.has_singleton("SaveManager"):
		var sm = Engine.get_singleton("SaveManager")
		if sm.has_method("add_skill_points"):
			sm.add_skill_points(skill_pts)
	# Titles
	for title in rewards.get("titles", []):
		if Engine.has_singleton("SaveManager"):
			var sm = Engine.get_singleton("SaveManager")
			if sm.has_method("unlock_title"):
				sm.unlock_title(title)
	# Badges
	for badge in rewards.get("badges", []):
		if Engine.has_singleton("SaveManager"):
			var sm = Engine.get_singleton("SaveManager")
			if sm.has_method("award_badge"):
				sm.award_badge(badge)
	# Gift pokemon
	var gift_pokemon: Dictionary = rewards.get("pokemon", {})
	if not gift_pokemon.is_empty():
		if Engine.has_singleton("SaveManager"):
			var sm = Engine.get_singleton("SaveManager")
			if sm.has_method("add_pokemon_to_party"):
				sm.add_pokemon_to_party(gift_pokemon)


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


func _save_state() -> void:
	if not Engine.has_singleton("SaveManager"):
		return
	var sm = Engine.get_singleton("SaveManager")
	if sm.has_method("set_quest_state"):
		sm.set_quest_state({
			"active":    _active_quests.duplicate(true),
			"completed": _completed_quests.duplicate()
		})


# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_pokemon_caught(species_id: int, _is_alpha: bool) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			match obj.get("type", ""):
				"capture_any", "capture_total", "find_all":
					update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"capture_unique":
					# Tracking unique species is handled by caller passing count
					pass
				"capture_count":
					if str(obj.get("target", "")) == str(species_id):
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"capture":
					if str(obj.get("target", "")) == str(species_id):
						update_objective(quest_id, i, 1)


func _on_battle_ended(result: Dictionary) -> void:
	var enemy_id: String    = str(result.get("enemy_id", ""))
	var enemy_level: int    = int(result.get("enemy_level", 0))
	var is_wild: bool       = result.get("is_wild", false)
	var player_won: bool    = result.get("player_won", false)
	if not player_won:
		return
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			match obj.get("type", ""):
				"defeat":
					if obj.get("target", "") == enemy_id:
						update_objective(quest_id, i, 1)
				"defeat_count":
					var target: String = obj.get("target", "")
					if target == "any":
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
					elif target == "wild_pokemon" and is_wild:
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
					elif target == enemy_id:
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				"defeat_alpha":
					if result.get("is_alpha", false):
						update_objective(quest_id, i, get_objective_progress(quest_id, i) + 1)
				_:
					pass
	# Suppress unused var warning
	var _lv := enemy_level


func _on_dialog_ended(npc_id: String) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") == "talk" and obj.get("target", "") == npc_id:
				update_objective(quest_id, i, 1)


func _on_item_received(item_id: String) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") == "receive_item" and obj.get("item", "") == item_id:
				update_objective(quest_id, i, 1)


func _on_zone_entered(zone_id: String) -> void:
	for quest_id in _active_quests.keys():
		var quest_data: Dictionary = _all_quests.get(quest_id, {})
		var objectives: Array = quest_data.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") in ["reach_zone", "infiltrate"] and obj.get("target", "") == zone_id:
				update_objective(quest_id, i, 1)
