## WorldVegetationScatter — detalhe determinístico que consome a World Factory V1.
##
## Não cria geografia nem usa RNG global: cada categoria recebe a mesma seed da
## spec, deslocada por uma chave declarativa. O resultado são transformações
## puras para a cena decidir como instanciá-las (MultiMesh no WORLD_LAB).
class_name WorldVegetationScatter
extends RefCounted

var _spec: Dictionary
var _factory: WorldTerrainFactory
var _bounds: Dictionary
var _vegetation: Dictionary


func _init(spec: Dictionary, factory: WorldTerrainFactory) -> void:
	_spec = spec.duplicate(true)
	_factory = factory
	_bounds = _spec.get("bounds_m", {})
	_vegetation = (_spec.get("visual", {}) as Dictionary).get("vegetation", {})


func gerar() -> Dictionary:
	return {
		"trees": _espalhar_terrestre("trees", _vegetation.get("trees", {}), 101),
		"bushes": _espalhar_terrestre("bushes", _vegetation.get("bushes", {}), 151),
		"grass_short": _espalhar_terrestre("grass_short", (_vegetation.get("grass", {}) as Dictionary).get("short", {}), 211),
		"grass_mid": _espalhar_terrestre("grass_mid", (_vegetation.get("grass", {}) as Dictionary).get("mid", {}), 223),
		"grass_tall": _espalhar_terrestre("grass_tall", (_vegetation.get("grass", {}) as Dictionary).get("tall", {}), 227),
		"corals": _espalhar_corais(_vegetation.get("corals", {}), 307)
	}


func em_reserva_manual(x: float, z: float) -> bool:
	for value in _spec.get("manual_reservations", []):
		if not value is Dictionary:
			continue
		var reservation: Dictionary = value
		var rule := str(reservation.get("rule", ""))
		if rule != "exclude_scatter" and rule != "keep_walkable" and rule != "reserve_for_landmark":
			continue
		var center: Array = reservation.get("center_m", [])
		if center.size() == 2 and reservation.has("radius_m"):
			if Vector2(x - float(center[0]), z - float(center[1])).length() <= float(reservation["radius_m"]):
				return true
		var from: Array = reservation.get("from_m", [])
		var to: Array = reservation.get("to_m", [])
		if from.size() == 2 and to.size() == 2 and reservation.has("half_width_m"):
			var a := Vector2(float(from[0]), float(from[1]))
			var b := Vector2(float(to[0]), float(to[1]))
			if Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)) <= float(reservation["half_width_m"]):
				return true
	return false


func _espalhar_terrestre(category: String, settings_value: Variant, salt: int) -> Array[Dictionary]:
	if not settings_value is Dictionary:
		return []
	var settings: Dictionary = settings_value
	var result := _espalhar(settings, salt, func(x: float, z: float) -> bool:
		if em_reserva_manual(x, z) or _factory.tipo_de_superficie_em(x, z) != "grass":
			return false
		return 1.0 - _factory.normal_em(x, z).y <= float(settings.get("max_slope", 0.32))
	)
	for item in result:
		item["category"] = category
	if category == "trees" or category == "bushes":
		var variants: Array = settings.get("variants", [])
		for index in result.size():
			result[index]["variant"] = str(variants[index % variants.size()]) if not variants.is_empty() else ""
	return result


func _espalhar_corais(settings_value: Variant, salt: int) -> Array[Dictionary]:
	if not settings_value is Dictionary:
		return []
	var settings: Dictionary = settings_value
	var result := _espalhar(settings, salt, func(x: float, z: float) -> bool:
		return not em_reserva_manual(x, z) and _factory.tipo_de_superficie_em(x, z) == "shallow_waterbed"
	)
	var variants: Array = settings.get("variants", [])
	for index in result.size():
		result[index]["variant"] = str(variants[index % variants.size()]) if not variants.is_empty() else ""
		result[index]["category"] = "corals"
	return result


func _espalhar(settings: Dictionary, salt: int, aceitar: Callable) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_spec.get("world_seed", 0)) + int(_vegetation.get("seed_offset", 0)) + salt
	var count := int(settings.get("count", 0))
	var spacing := float(settings.get("min_spacing_m", 1.0))
	var accepted: Array[Dictionary] = []
	var attempts: int = maxi(96, count * 36)
	var min_x := float(_bounds.get("min_x", 0.0))
	var min_z := float(_bounds.get("min_z", 0.0))
	var max_x := min_x + float(_bounds.get("width", 0.0))
	var max_z := min_z + float(_bounds.get("depth", 0.0))
	var zones: Array = settings.get("zones", [])
	for _attempt in attempts:
		if accepted.size() >= count:
			break
		var candidate := _sortear_posicao(rng, zones, min_x, min_z, max_x, max_z)
		var x := float(candidate["x"])
		var z := float(candidate["z"])
		if not aceitar.call(x, z) or not _respeita_espacamento(x, z, accepted, spacing):
			continue
		accepted.append({
			"position": Vector3(x, _factory.altura_em(x, z) + 0.015, z),
			"yaw": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(float(settings.get("min_scale", 1.0)), float(settings.get("max_scale", 1.0))),
			"zone_id": str(candidate["zone_id"])
		})
	return accepted


func _sortear_posicao(rng: RandomNumberGenerator, zones: Array, min_x: float, min_z: float, max_x: float, max_z: float) -> Dictionary:
	if zones.is_empty():
		return {"x": rng.randf_range(min_x, max_x), "z": rng.randf_range(min_z, max_z), "zone_id": "world"}
	var total_weight := 0.0
	for value in zones:
		if value is Dictionary:
			total_weight += float((value as Dictionary).get("weight", 0.0))
	var roll := rng.randf_range(0.0, total_weight)
	var selected: Dictionary = zones[0] as Dictionary
	for value in zones:
		if not value is Dictionary:
			continue
		var zone: Dictionary = value
		roll -= float(zone["weight"])
		if roll <= 0.0:
			selected = zone
			break
	var center: Array = selected["center_m"]
	var angle := rng.randf_range(0.0, TAU)
	var distance := sqrt(rng.randf()) * float(selected["radius_m"])
	return {
		"x": clampf(float(center[0]) + cos(angle) * distance, min_x, max_x),
		"z": clampf(float(center[1]) + sin(angle) * distance, min_z, max_z),
		"zone_id": str(selected["id"])
	}


func _respeita_espacamento(x: float, z: float, accepted: Array[Dictionary], spacing: float) -> bool:
	var minimum_squared := spacing * spacing
	for item in accepted:
		var position: Vector3 = item["position"]
		var dx := position.x - x
		var dz := position.z - z
		if dx * dx + dz * dz < minimum_squared:
			return false
	return true
