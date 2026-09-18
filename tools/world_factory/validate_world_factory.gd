## Validação isolada das Fases 2–3 da World Factory.
extends SceneTree

const Spec = preload("res://scripts/world_factory/WorldSpec.gd")
const Factory = preload("res://scripts/world_factory/WorldTerrainFactory.gd")

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
	_finalizar()

func _finalizar() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
