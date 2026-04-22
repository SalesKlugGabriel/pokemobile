class_name EvolutionSystem
extends RefCounted

## Returns the evolved species ID (>0) if conditions are met, else 0.
## triggered_item: pass item ID string if player used an evolution stone/item; "" otherwise.
func check_evolution(species_id: int, level: int, triggered_item: String) -> int:
	var condition := get_evolution_condition(species_id)
	if condition.is_empty():
		return 0

	var cond_type: String = condition.get("type", "")
	match cond_type:
		"level":
			if level >= int(condition.get("min_level", 999)):
				return int(condition.get("into", 0))
		"item":
			if triggered_item != "" and triggered_item == condition.get("item", ""):
				return int(condition.get("into", 0))
		"level_and_item":
			if level >= int(condition.get("min_level", 999)) and triggered_item == condition.get("item", ""):
				return int(condition.get("into", 0))
	return 0


## Executes prestige evolution: resets to level 1, applies new-form base stats,
## rerolls 4 skill slots, clears TMs. Returns updated pokemon_data Dictionary.
func execute_prestige(pokemon_data: Dictionary) -> Dictionary:
	var result := pokemon_data.duplicate(true)
	var new_id: int = result.get("prestige_into", result.get("species_id", 0))

	result["species_id"] = new_id
	result["level"]      = 1
	result["exp"]        = 0

	# Reset TM moves (slots that were TM-taught become "")
	var moves: Array = result.get("moves", ["", "", "", ""])
	for i in moves.size():
		if result.get("move_source_" + str(i), "") == "tm":
			moves[i] = ""
			result["move_source_" + str(i)] = ""
	result["moves"] = moves

	# Signal skill reroll — caller is responsible for assigning new skills
	result["needs_skill_reroll"] = true

	# Apply new form base stats from GameData if available
	if Engine.has_singleton("GameData"):
		var gd = Engine.get_singleton("GameData")
		if gd.has_method("get_species"):
			var species_data: Dictionary = gd.get_species(new_id)
			if not species_data.is_empty():
				result["base_stats"] = species_data.get("base_stats", result.get("base_stats", {}))

	return result


## Queries evolutions.json via GameData to get the evolution condition for a species.
## Returns Dictionary like: {"type": "level", "min_level": 16, "into": 2}
## or {} if no evolution exists.
func get_evolution_condition(species_id: int) -> Dictionary:
	if not Engine.has_singleton("GameData"):
		return {}
	var gd = Engine.get_singleton("GameData")
	if not gd.has_method("get_evolution"):
		return {}
	var evo = gd.get_evolution(species_id)
	if evo == null:
		return {}
	return evo
