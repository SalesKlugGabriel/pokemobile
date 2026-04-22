class_name TMSystem
extends RefCounted

## Returns true if species_id can learn the move associated with tm_move_id.
## Compatibility is defined in species data under "tm_compatible" array.
func can_learn(species_id: int, tm_move_id: String) -> bool:
	if not Engine.has_singleton("GameData"):
		return false
	var gd = Engine.get_singleton("GameData")
	if not gd.has_method("get_species"):
		return false
	var species_data: Dictionary = gd.get_species(species_id)
	if species_data.is_empty():
		return false
	var compatible: Array = species_data.get("tm_compatible", [])
	return tm_move_id in compatible


## Teaches a TM move to a pokemon, replacing the move at slot (0-3).
## Returns updated pokemon_data. Does NOT consume the item — caller handles inventory.
func teach_tm(pokemon_data: Dictionary, tm_item_id: String, slot: int) -> Dictionary:
	var result := pokemon_data.duplicate(true)
	var tm_move := get_tm_move(tm_item_id)
	if tm_move.is_empty():
		push_warning("TMSystem.teach_tm: unknown TM item '%s'" % tm_item_id)
		return result

	slot = clampi(slot, 0, 3)
	var moves: Array = result.get("moves", ["", "", "", ""])
	while moves.size() < 4:
		moves.append("")
	moves[slot] = tm_move.get("move_id", "")
	result["moves"] = moves
	result["move_source_" + str(slot)] = "tm"
	return result


## Returns the move data for a given TM item ID by querying items.json via GameData.
## Expected return: {"move_id": String, "name": String, "type": String, ...}
func get_tm_move(tm_item_id: String) -> Dictionary:
	if not Engine.has_singleton("GameData"):
		return {}
	var gd = Engine.get_singleton("GameData")
	if not gd.has_method("get_item"):
		return {}
	var item_data: Dictionary = gd.get_item(tm_item_id)
	if item_data.is_empty():
		return {}
	# Items of category "tm_hm" store their move reference under "teaches_move"
	if item_data.get("category", "") != "tm_hm":
		return {}
	var move_id: String = item_data.get("teaches_move", "")
	if move_id.is_empty():
		return {}
	# Optionally fetch full move data
	if gd.has_method("get_move"):
		var move_data: Dictionary = gd.get_move(move_id)
		if not move_data.is_empty():
			return move_data
	return {"move_id": move_id}
