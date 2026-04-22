class_name LootTable
extends RefCounted

# Tier weights (sum = 100)
const TIER_WEIGHTS := {
	"common":   70,
	"uncommon": 22,
	"rare":      6,
	"epic":      2
}

# Item pools per tier. Keys map to species_id ranges for context-sensitive drops.
# Format: { "tier": [ { "id": String, "quantity": int, "weight": int } ] }
const ITEM_POOLS := {
	"common": [
		{"id": "potion",       "quantity": 1, "weight": 40},
		{"id": "pokeball",     "quantity": 1, "weight": 35},
		{"id": "antidote",     "quantity": 1, "weight": 15},
		{"id": "repel",        "quantity": 1, "weight": 10}
	],
	"uncommon": [
		{"id": "super_potion", "quantity": 1, "weight": 40},
		{"id": "great_ball",   "quantity": 1, "weight": 35},
		{"id": "awakening",    "quantity": 1, "weight": 15},
		{"id": "berry_common", "quantity": 2, "weight": 10}
	],
	"rare": [
		{"id": "hyper_potion", "quantity": 1, "weight": 40},
		{"id": "ultra_ball",   "quantity": 1, "weight": 30},
		{"id": "revive",       "quantity": 1, "weight": 20},
		{"id": "rare_candy",   "quantity": 1, "weight": 10}
	],
	"epic": [
		{"id": "max_potion",   "quantity": 1, "weight": 35},
		{"id": "master_ball",  "quantity": 1, "weight": 5},
		{"id": "pp_up",        "quantity": 1, "weight": 30},
		{"id": "full_restore", "quantity": 1, "weight": 30}
	]
}


## Returns a drop Dictionary {"id": String, "quantity": int} or null if no drop occurs.
func roll_drop(pokemon_level: int, luck_points: int) -> Dictionary:
	var chance_drop: float = minf(0.15 + (pokemon_level / 200.0) + (luck_points * 0.02), 0.85)
	if randf() > chance_drop:
		return {}
	var tier := get_tier(luck_points)
	return get_item_for_tier(tier, 0)


## Determines drop tier based on luck_points.
## luck_points shifts weight toward better tiers.
func get_tier(luck_points: int) -> String:
	var bonus := clampi(luck_points, 0, 20)
	# Redistribute weight: each luck point shifts 0.5% from common to rarer tiers
	var w_common   := maxi(TIER_WEIGHTS["common"]   - bonus,     40)
	var w_uncommon := TIER_WEIGHTS["uncommon"] + (bonus / 2)
	var w_rare     := TIER_WEIGHTS["rare"]     + (bonus / 4)
	var w_epic     := TIER_WEIGHTS["epic"]     + (bonus / 5)
	var total      := w_common + w_uncommon + w_rare + w_epic
	var roll       := randi() % total

	if roll < w_common:
		return "common"
	elif roll < w_common + w_uncommon:
		return "uncommon"
	elif roll < w_common + w_uncommon + w_rare:
		return "rare"
	return "epic"


## Returns a random item from the given tier's pool.
## species_id is reserved for future context-sensitive drops.
func get_item_for_tier(tier: String, _species_id: int) -> Dictionary:
	if not ITEM_POOLS.has(tier):
		return {}
	var pool: Array = ITEM_POOLS[tier]
	var total_weight := 0
	for entry in pool:
		total_weight += entry["weight"]
	var roll := randi() % total_weight
	var accumulated := 0
	for entry in pool:
		accumulated += entry["weight"]
		if roll < accumulated:
			return {"id": entry["id"], "quantity": entry["quantity"]}
	return {}
