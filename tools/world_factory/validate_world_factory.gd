## Validação isolada das Fases 2–3 da World Factory.
extends SceneTree

const Spec = preload("res://scripts/world_factory/WorldSpec.gd")
const Factory = preload("res://scripts/world_factory/WorldTerrainFactory.gd")
const VegetationScatter = preload("res://scripts/world_factory/WorldVegetationScatter.gd")

var ok := 0
var fail := 0

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s %s" % [nome, detalhe])

func _initialize() -> void:
	print("== World Factory · Fases 2–3 ==")
	var spec: Dictionary = Spec.carregar_world_lab()
	_conf(not spec.is_empty(), "spec JSON carrega")
	_conf(Spec.validar(spec).is_empty(), "spec JSON é válida", str(Spec.validar(spec)))
	if spec.is_empty() or not Spec.validar(spec).is_empty():
		_finalizar()
		return
	var a = Factory.new(spec)
	var b = Factory.new(spec)
	var outra: Dictionary = spec.duplicate(true)
	outra["world_seed"] = int(spec["world_seed"]) + 1
	var c = Factory.new(outra)

	var maior_delta := 0.0
	for ix in 32:
		for iz in 32:
			var x := -126.7 + ix * 7.85
			var z := -125.3 + iz * 7.73
			maior_delta = maxf(maior_delta, absf(a.altura_em(x, z) - b.altura_em(x, z)))
	_conf(maior_delta < 0.000001, "mesma seed reproduz altura", "delta %.8f" % maior_delta)
	_conf(absf(a.altura_em(31.4, -21.7) - c.altura_em(31.4, -21.7)) > 0.0001,
		"seed distinta altera o terreno")
	_conf(a.largura_praia_m() == float(spec["terrain"]["beach_width_m"])
		and a.largura_linha_dagua_m() == float(spec["terrain"]["shoreline_width_m"])
		and a.profundidade_rasa_m() == float(spec["terrain"]["shallow_depth_m"]),
		"parâmetros de costa vêm explicitamente da spec")

	var delta_borda := 0.0
	for i in 33:
		delta_borda = maxf(delta_borda,
			absf(a.altura_do_vertice_chunk(0, 0, 32, i) - a.altura_do_vertice_chunk(1, 0, 0, i)))
	_conf(delta_borda < 0.000001, "vértices da borda entre chunks coincidem")
	_conf(a.coordenada_do_chunk(-128.1, -128.1) == Vector2i(-1, -1),
		"chunks negativos usam floor, não truncamento")
	var malha := a.gerar_malha_chunk(0, 0)
	_conf(malha != null and malha.get_surface_count() == 1, "chunk gera uma malha")
	_conf(malha.create_trimesh_shape() != null, "chunk gera colisão triangulada")

	var classes := {}
	var classes_reproduzidas := true
	for ix in 128:
		for iz in 128:
			var x := float(spec["bounds_m"]["min_x"]) + ix * 2.0 + 0.31
			var z := float(spec["bounds_m"]["min_z"]) + iz * 2.0 + 0.67
			var classe := a.tipo_de_superficie_em(x, z)
			classes[classe] = int(classes.get(classe, 0)) + 1
			classes_reproduzidas = classes_reproduzidas and classe == b.tipo_de_superficie_em(x, z)
	for classe_esperada in ["deep_waterbed", "shallow_waterbed", "shoreline", "sand", "grass", "rock"]:
		_conf(int(classes.get(classe_esperada, 0)) > 0,
			"WORLD_LAB contém faixa %s" % classe_esperada, str(classes))
	_conf(classes_reproduzidas, "classificação de superfície é determinística")

	var scatter_a := VegetationScatter.new(spec, a)
	var scatter_b := VegetationScatter.new(spec, b)
	var vegetation_a: Dictionary = scatter_a.gerar()
	var vegetation_b: Dictionary = scatter_b.gerar()
	var vegetation_config: Dictionary = (spec["visual"] as Dictionary)["vegetation"]
	var grass_config: Dictionary = vegetation_config["grass"]
	_conf((vegetation_a["trees"] as Array).size() == int((vegetation_config["trees"] as Dictionary)["count"])
		and (vegetation_a["grass_short"] as Array).size() == int((grass_config["short"] as Dictionary)["count"])
		and (vegetation_a["grass_mid"] as Array).size() == int((grass_config["mid"] as Dictionary)["count"])
		and (vegetation_a["grass_tall"] as Array).size() == int((grass_config["tall"] as Dictionary)["count"])
		and (vegetation_a["corals"] as Array).size() == int((vegetation_config["corals"] as Dictionary)["count"]),
		"spec entrega a quantidade declarada de vegetação")
	var deterministic_scatter := true
	for group_name in vegetation_a:
		var first: Array = vegetation_a[group_name]
		var second: Array = vegetation_b[group_name]
		if first.size() != second.size():
			deterministic_scatter = false
			break
		for index in first.size():
			var one: Dictionary = first[index]
			var two: Dictionary = second[index]
			deterministic_scatter = deterministic_scatter and (one["position"] as Vector3).is_equal_approx(two["position"] as Vector3)
			deterministic_scatter = deterministic_scatter and is_equal_approx(float(one["yaw"]), float(two["yaw"]))
	_conf(deterministic_scatter, "mesma seed reproduz scatter de vegetação")
	var terrestrial_valid := true
	for group_name in ["trees", "grass_short", "grass_mid", "grass_tall"]:
		for item_value in vegetation_a[group_name]:
			var item: Dictionary = item_value
			var position: Vector3 = item["position"]
			terrestrial_valid = terrestrial_valid and a.tipo_de_superficie_em(position.x, position.z) == "grass"
			terrestrial_valid = terrestrial_valid and not scatter_a.em_reserva_manual(position.x, position.z)
	_conf(terrestrial_valid, "árvores e grama ficam em solo gramado fora das reservas")
	var corals_valid := true
	for item_value in vegetation_a["corals"]:
		var item: Dictionary = item_value
		var position: Vector3 = item["position"]
		corals_valid = corals_valid and a.tipo_de_superficie_em(position.x, position.z) == "shallow_waterbed"
		corals_valid = corals_valid and position.y < a.nivel_do_mar()
	_conf(corals_valid, "corais ficam somente sob água rasa")
	_finalizar()

func _finalizar() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
