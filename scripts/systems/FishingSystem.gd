## FishingSystem.gd — Pesca (Fase 2 do Diário). Mesmo padrão do LootTable.gd:
## instanciar com .new() e chamar attempt(), sem estado entre usos.
class_name FishingSystem
extends RefCounted

# Tabela por "effect" da vara (ver items.json: old_rod=fish_common,
# good_rod=fish_good, super_rod=fish_rare). species_id são os peixes
# clássicos de Kanto — únicos Water-type que fazem sentido numa lagoa de
# Rota 1 (Gyarados só na vara boa, raro, e é a evolução do Magikarp).
const RODS : Dictionary = {
	"fish_common": {
		"bite_chance": 0.40,
		"pool": [ {"id": 129, "weight": 100, "lvl_min": 5,  "lvl_max": 15} ],  # Magikarp
	},
	"fish_good": {
		"bite_chance": 0.55,
		"pool": [
			{"id": 129, "weight": 55, "lvl_min": 10, "lvl_max": 25},  # Magikarp
			{"id": 118, "weight": 45, "lvl_min": 10, "lvl_max": 25},  # Goldeen
		],
	},
	"fish_rare": {
		"bite_chance": 0.70,
		"pool": [
			{"id": 60,  "weight": 30, "lvl_min": 15, "lvl_max": 35},  # Poliwag
			{"id": 54,  "weight": 25, "lvl_min": 15, "lvl_max": 35},  # Psyduck
			{"id": 79,  "weight": 25, "lvl_min": 15, "lvl_max": 35},  # Slowpoke
			{"id": 118, "weight": 15, "lvl_min": 15, "lvl_max": 35},  # Goldeen
			{"id": 130, "weight": 5,  "lvl_min": 20, "lvl_max": 30},  # Gyarados (raro)
		],
	},
}

## Tenta fisgar com a vara de efeito `rod_effect`. Retorna {} se nada mordeu,
## ou {"species_id":int,"level":int} se fisgou.
func attempt(rod_effect: String) -> Dictionary:
	var rod : Dictionary = RODS.get(rod_effect, RODS["fish_common"])
	if not RNGManager.chance(rod["bite_chance"]):
		return {}

	var pool : Array = rod["pool"]
	var total_weight := 0
	for entry in pool:
		total_weight += int(entry["weight"])
	var roll := RNGManager.randi_range(0, total_weight - 1)
	var acc := 0
	for entry in pool:
		acc += int(entry["weight"])
		if roll < acc:
			return {
				"species_id": int(entry["id"]),
				"level": RNGManager.randi_range(int(entry["lvl_min"]), int(entry["lvl_max"])),
			}
	return {}
