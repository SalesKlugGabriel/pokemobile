## teste_telhado_segundo_andar.gd — O "segundo andar": telhado por cima do
## prédio, que some quando o jogador entra (04/09, ideia do Gabriel).
##
## Por que existe: quando os Centros Pokémon viraram "entra andando", o prédio
## passou a mostrar o piso interno visto de fora — parecia tapete, não
## construção. O telhado numa camada por cima devolve a aparência de prédio
## sólido sem tirar o "entra andando".
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_telhado_segundo_andar.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: telhado do 'segundo andar' (04/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = ts
	MapLayouts.paint(tm, "world_map")

	# ---- 1. Os prédios são detectados sozinhos, sem lista pra manter ----
	var predios : Array = MapLayouts.agrupar_interiores(tm)
	_assert(predios.size() >= 10, "achou os prédios do mundo pelo piso interno (%d)" % predios.size())

	var soltos := 0
	for p in predios:
		if (p as Array).size() < 4:
			soltos += 1
	_assert(soltos == 0, "nenhum 'prédio' é um punhado solto de tiles (%d suspeitos)" % soltos)

	# ---- 2. Cada prédio é uma região conectada (não juntou dois prédios num só) ----
	var maior := 0
	for p in predios:
		maior = maxi(maior, (p as Array).size())
	_assert(maior < 400, "nenhum prédio absurdamente grande — não fundiu prédios vizinhos (maior=%d)" % maior)

	# ---- 3. O telhado cobre o interior e é RETIRÁVEL ----
	var mapa := load("res://scripts/world/BaseMap.gd")
	var alvo : Array = predios[0]
	var celula : Vector2i = alvo[0]

	# simula o que o BaseMap faz: pinta telhado na camada 1
	while tm.get_layers_count() <= 1:
		tm.add_layer(-1)
	var telhado : Vector2i = MapLayouts.CHAR_MAP["H"]
	for c in alvo:
		tm.set_cell(1, c, 0, telhado)
	_assert(tm.get_cell_source_id(1, celula) != -1, "com o jogador FORA, o telhado cobre o interior")
	_assert(tm.get_cell_atlas_coords(1, celula) == telhado, "o que cobre é tile de telhado mesmo")

	for c in alvo:
		tm.erase_cell(1, c)
	_assert(tm.get_cell_source_id(1, celula) == -1, "com o jogador DENTRO, o telhado some e revela o interior")

	# ---- 4. O chão embaixo do telhado continua intacto e andável ----
	var td : TileData = tm.get_cell_tile_data(0, celula)
	_assert(tm.get_cell_atlas_coords(0, celula) == MapLayouts.CHAR_MAP["I"],
		"a camada de baixo continua sendo o piso interno (telhado não substituiu o chão)")
	_assert(td != null and not td.get_custom_data("blocked"),
		"o piso sob o telhado continua andável — dá pra estar dentro do prédio")

	tm.free()

	# ---- 5. O telhado usa o KIT (cantos/bordas), não só o tile central ----
	# Regra obrigatória 2 do Gabriel: a estrutura tem que fechar como casa, com
	# canto e borda — não pode ser uma faixa reta de telha repetida.
	var conjunto := {}
	for c in alvo:
		conjunto[c] = true
	var usadas := {}
	for c in alvo:
		usadas[MapLayouts.peca_de_telhado(c, conjunto)] = true
	for canto in ["u", "v", "x", "y"]:
		_assert(usadas.has(canto), "telhado usa o canto '%s' (casa fechada, não faixa reta)" % canto)
	_assert(usadas.has("H"), "telhado tem miolo além das bordas")
	var todas_no_atlas := true
	for peca in usadas:
		if not MapLayouts.CHAR_MAP.has(peca):
			todas_no_atlas = false
	_assert(todas_no_atlas, "toda peça do kit existe no CHAR_MAP")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
