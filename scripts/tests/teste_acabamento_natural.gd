extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	var mapa := TileMap.new()
	mapa.tile_set = load("res://assets/tilesets/overworld.tres")
	root.add_child(mapa)
	for y in range(-4, 5):
		for x in range(-4, 5):
			var ch := "." if x < 0 else "P"
			mapa.set_cell(0, Vector2i(x, y), 0, MapLayouts.CHAR_MAP[ch])
	var antes := mapa.get_used_cells(0)
	var conteudo := {}
	for c in antes:
		conteudo[c] = mapa.get_cell_atlas_coords(0, c)
	var acabamento = load("res://scripts/world/systems/AcabamentoNatural.gd").new()
	mapa.add_child(acabamento)
	acabamento.configurar(mapa)
	_assert(mapa.material is ShaderMaterial, "liga shader ao terreno")
	# Frames reais: o sistema visual deve ser apenas leitor do mapa.
	for i in 3:
		await process_frame
	var intacto := mapa.get_used_cells(0) == antes
	for c in antes:
		intacto = intacto and mapa.get_cell_atlas_coords(0, c) == conteudo[c]
	_assert(intacto, "renderizar não escreve células nem altera atlas/colisões")
	var dados := mapa.get_cell_tile_data(0, Vector2i.ZERO)
	_assert(not bool(dados.get_custom_data("blocked")), "caminho continua andável")
	# Repaint de editor/chunk é lido na próxima renderização; sem cache obsoleto.
	mapa.set_cell(0, Vector2i.ZERO, 0, MapLayouts.CHAR_MAP["~"])
	acabamento.queue_redraw()
	await process_frame
	_assert(mapa.get_cell_atlas_coords(0, Vector2i.ZERO) == MapLayouts.CHAR_MAP["~"], "preserva override recebido depois de configurar")
	var n: int = acabamento.irregular(Vector2i(-5000, 12000), 3, 1)
	_assert(n == acabamento.irregular(Vector2i(-5000, 12000), 3, 1), "bordas determinísticas também em coordenada negativa")
	_assert(n != acabamento.irregular(Vector2i(-4999, 12000), 3, 1), "tiles vizinhos não usam a mesma sequência de borda")
	acabamento.free()
	_assert(mapa.material == null, "remover componente restaura material anterior")
	var proprio := CanvasItemMaterial.new()
	mapa.material = proprio
	acabamento = load("res://scripts/world/systems/AcabamentoNatural.gd").new()
	mapa.add_child(acabamento)
	acabamento.configurar(mapa)
	_assert(mapa.material == proprio, "não sobrescreve material já definido por outro sistema")
	acabamento.free()
	mapa.free()
	print("=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail else 0)

func _assert(cond: bool, texto: String) -> void:
	if cond:
		_ok += 1
		print("OK: " + texto)
	else:
		_fail += 1
		print("FALHOU: " + texto)
