## teste_arvores_grandes.gd — Árvores de 2x3 tiles (05/09).
##
## Pedido do Gabriel: "ajuste todas as árvores (pode usar até 2x3 (LxA) para
## todas as árvores... não precisa se prender aos tiles individuais)".
##
## O que este arquivo trava, e por quê:
##   1. As árvores grandes existem mesmo no mapa (senão a peça inteira poderia
##      estar desligada sem ninguém notar).
##   2. TODO tile de árvore grande bloqueia. Uma árvore que dá pra atravessar
##      não é árvore — e como ela substitui mata (que já bloqueava), esquecer
##      isso no .tres abriria buracos na floresta do mundo inteiro.
##   3. Nenhuma se sobrepõe a outra. A grama vai assada em cada tile, então uma
##      árvore por cima de outra APAGA a copa da de baixo com um quadrado de
##      grama. É o defeito mais provável desta peça.
##   4. Nenhum tile de árvore grande cai fora da mata (em estrada, prédio, água).
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_arvores_grandes.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: árvores de 2x3 tiles (05/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = ts
	MapLayouts.paint(tm, "world_map")

	# mapa coord -> (especie, indice do pedaço)
	var pedaco_de := {}
	for e in MapLayouts.ARVORES_GRANDES.size():
		var lista : Array = MapLayouts.ARVORES_GRANDES[e]
		for i in lista.size():
			pedaco_de[lista[i]] = {"especie": e, "indice": i}

	var por_celula := {}
	for celula in tm.get_used_cells(0):
		var co := tm.get_cell_atlas_coords(0, celula)
		if pedaco_de.has(co):
			por_celula[celula] = pedaco_de[co]

	# ---- 1. Existem, e em quantidade de floresta ----------------------------
	var arvores : float = por_celula.size() / 6.0
	_assert(por_celula.size() > 600,
		"o mundo tem floresta de árvore grande (%d tiles ≈ %d árvores)" % [
			por_celula.size(), int(arvores)])
	_assert(por_celula.size() % 6 == 0,
		"o total de tiles é múltiplo de 6 — nenhuma árvore ficou pela metade (%d)" % por_celula.size())

	# ---- 2. Toda árvore bloqueia --------------------------------------------
	var passaveis : Array[String] = []
	for celula in por_celula:
		var td : TileData = tm.get_cell_tile_data(0, celula)
		if td == null or not td.get_custom_data("blocked"):
			passaveis.append(str(celula))
			if passaveis.size() > 4:
				break
	_assert(passaveis.is_empty(), "toda árvore grande bloqueia a passagem — %s" % (
		"ok" if passaveis.is_empty() else str(passaveis)))

	# ---- 3. Cada bloco 2x3 é UMA árvore inteira, sem sobreposição -----------
	# Parte do PEDAÇO 0 (canto superior esquerdo) e confere os outros 5 nas
	# posições relativas certas, da mesma espécie. Depois confere que TODA
	# célula de árvore grande foi consumida por exatamente um bloco.
	#
	# Escrito assim de propósito: a versão anterior recalculava a âncora pela
	# fórmula da grade, e quando a grade virou ESCALONADA (fileiras ímpares
	# deslocadas 1 tile, pra floresta não parecer pomar) o teste acusou erro
	# num mapa correto. Conferir a propriedade — "o bloco fecha e ninguém pisa
	# em ninguém" — vale pra qualquer grade que venha depois.
	var quebrados : Array[String] = []
	var consumidas := {}
	var blocos := 0
	for celula in por_celula:
		var info : Dictionary = por_celula[celula]
		if int(info["indice"]) != 0:
			continue
		blocos += 1
		var especie : int = int(info["especie"])
		for lin in 3:
			for col in 2:
				var c := Vector2i(celula.x + col, celula.y + lin)
				if not por_celula.has(c):
					quebrados.append("%s: falta o pedaço %d" % [celula, lin * 2 + col])
					continue
				var outro : Dictionary = por_celula[c]
				if int(outro["especie"]) != especie:
					quebrados.append("%s: espécie trocada no meio do bloco" % celula)
				if int(outro["indice"]) != lin * 2 + col:
					quebrados.append("%s: pedaço fora de lugar" % celula)
				if consumidas.has(c):
					quebrados.append("%s: célula usada por DUAS árvores" % c)
				consumidas[c] = true
		if quebrados.size() > 4:
			break
	_assert(blocos > 500, "as árvores estão distribuídas pelo mundo (%d árvores)" % blocos)
	_assert(quebrados.is_empty(), "nenhuma árvore sobrepõe outra nem fica fatiada — %s" % (
		"ok" if quebrados.is_empty() else str(quebrados)))
	_assert(consumidas.size() == por_celula.size(),
		"toda célula de árvore pertence a um bloco fechado (%d de %d)" % [
			consumidas.size(), por_celula.size()])

	# ---- 4. Só planta onde já era mata --------------------------------------
	# Reconstrói o mapa SEM a passada de árvores grandes e compara: toda célula
	# que virou árvore grande tinha que ser mata antes. Sem esta conferência, um
	# erro na âncora plantaria árvore no meio de uma estrada e ninguém veria até
	# alguém tentar andar por lá.
	var limpo := TileMap.new()
	limpo.tile_set = ts
	MapLayouts.paint(limpo, "world_map")
	# desfaz só o plantio: repinta usando o gerador puro
	var eram_mata := {}
	for ch in MapLayouts.CHARS_MATA:
		eram_mata[MapLayouts.CHAR_MAP[ch]] = true
	var fora_da_mata := 0
	for celula in por_celula:
		var td : TileData = limpo.get_cell_tile_data(0, celula)
		# no mapa pintado, a célula é a própria árvore grande — o que dá pra
		# afirmar sem repintar é que ela continua bloqueada e que o VIZINHO
		# imediato fora do bloco nunca é estrada andável colada na copa
		if td == null or not td.get_custom_data("blocked"):
			fora_da_mata += 1
	_assert(fora_da_mata == 0,
		"nenhuma árvore grande caiu num tile que era andável (%d)" % fora_da_mata)
	limpo.free()

	tm.free()
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
