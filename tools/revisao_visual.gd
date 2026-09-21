## Galeria de QA, não é cena de gameplay. Usa tiles reais e o mesmo componente
## dos mapas. Tecla B alterna antes/depois; Enter abre o jogo normal.
extends Node2D

var mapa: TileMap
var acabamento: Node2D
var novo: Texture2D
var antigo: Texture2D
var material_novo: Material
var legenda: Label
var depois := true

func _ready() -> void:
	mapa = TileMap.new()
	mapa.tile_set = load("res://assets/tilesets/overworld.tres").duplicate(true)
	mapa.scale = Vector2(0.5, 0.5)
	mapa.position = Vector2(0, 64)
	add_child(mapa)
	# Faixa de mata, clareira/trilha e lago: composição controlada para
	# comparar exatamente a mesma arte antes/depois, sem diferença de RNG.
	for y in 10:
		for x in 20:
			var ch := "."
			if y >= 7 and x >= 12:
				ch = "~"
			elif x >= 8 and x <= 10:
				ch = "P"
			elif x >= 11 and y >= 6:
				ch = "S"
			mapa.set_cell(0, Vector2i(x, y), 0, MapLayouts.CHAR_MAP[ch])
	for especie in 4:
		for y in 3:
			for x in 2:
				mapa.set_cell(0, Vector2i(especie * 5 + 1 + x, 1 + y), 0,
					MapLayouts.ARVORES_GRANDES[especie][y * 2 + x])
	for c in [Vector2i(1, 6), Vector2i(3, 7), Vector2i(6, 6)]:
		mapa.set_cell(0, c, 0, MapLayouts.CHAR_MAP["T"])
	for c in [Vector2i(4, 4), Vector2i(6, 8), Vector2i(12, 4)]:
		mapa.set_cell(0, c, 0, MapLayouts.CHAR_MAP["F"])
	# Margem de rio em grama: exercita a borda adicional sem tiles de praia.
	for y in range(5, 10):
		for x in range(16, 20):
			mapa.set_cell(0, Vector2i(x, y), 0, MapLayouts.CHAR_MAP["~"])
	acabamento = preload("res://scripts/world/systems/AcabamentoNatural.gd").new()
	mapa.add_child(acabamento)
	acabamento.configurar(mapa)
	material_novo = mapa.material
	var fonte := mapa.tile_set.get_source(0) as TileSetAtlasSource
	novo = fonte.texture
	antigo = load("res://assets/old/overworld_20260911.png")
	var camada := CanvasLayer.new()
	add_child(camada)
	var painel := ColorRect.new()
	painel.color = Color("22201c")
	painel.size = Vector2(1280, 64)
	camada.add_child(painel)
	legenda = Label.new()
	legenda.position = Vector2(20, 16)
	legenda.add_theme_font_size_override("font_size", 22)
	camada.add_child(legenda)
	_atualizar()
	print("GALERIA_VISUAL_PRONTA")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			depois = not depois
			_atualizar()
		elif event.keycode == KEY_ENTER:
			get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _atualizar() -> void:
	var fonte := mapa.tile_set.get_source(0) as TileSetAtlasSource
	fonte.texture = novo if depois else antigo
	mapa.material = material_novo if depois else null
	acabamento.visible = depois
	legenda.text = ("DEPOIS" if depois else "ANTES") + "   •   Galeria de arte / QA   •   B: comparar   •   Enter: jogar"
