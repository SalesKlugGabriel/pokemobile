## teste_ilha_do_deserto.gd — A ilha do deserto e as pirâmides (Fase 2, 05/09).
##
## Pedido do Gabriel: "uma ilha desértica com pirâmides e hieróglifos abaixo de
## Vermilion". Resolve o único bioma que Kanto não tinha — deserto e ruínas,
## casa dos 14 Pokémon Psíquicos — sem tirar nada do lugar: é mar novo ao sul,
## e chega-se de Surf.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_ilha_do_deserto.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: Ilha do Deserto (05/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var layout := MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	var ret := AjudaMapa.retangulo_da_zona("ilha_do_deserto")
	_assert(ret.size.x > 0, "a ilha está cadastrada no zones.json")
	_assert(int(layout["height"]) > ret.position.y + ret.size.y - 1,
		"o mapa é alto o bastante pra ilha caber (altura %d)" % int(layout["height"]))

	# ---- 1. É uma ILHA: cercada de mar, com anel de praia ----------------
	var mar : int = AjudaMapa.conta_char(tiles, ret, ["~"])
	var praia : int = AjudaMapa.conta_char(tiles, ret, ["S"])
	var deserto : int = AjudaMapa.conta_char(tiles, ret, ["_", "'", "+", ";", "*"])
	_assert(mar > 400, "há mar de verdade em volta (%d tiles)" % mar)
	_assert(praia > 100, "há anel de praia entre o mar e a areia seca (%d tiles)" % praia)
	_assert(deserto > 600, "o miolo é deserto de verdade (%d tiles)" % deserto)
	# nenhum canto do retângulo pode ser terra — senão não é ilha, é continente
	var cantos_secos := 0
	for p in [Vector2i(0, 0), Vector2i(ret.size.x - 1, 0),
			Vector2i(0, ret.size.y - 1), Vector2i(ret.size.x - 1, ret.size.y - 1)]:
		var linha : String = tiles[ret.position.y + p.y]
		if linha[ret.position.x + p.x] != "~":
			cantos_secos += 1
	_assert(cantos_secos == 0, "os quatro cantos são mar — é ilha, não pedaço de continente")

	# ---- 2. O recinto de ruínas, com parede de hieróglifos e entrada -----
	# 05/09: era `mosaico > 300`, calibrado no recinto de 23x17 da primeira
	# versão. O templo encolheu de propósito (lia como estacionamento) e ganhou
	# um anel de degraus junto à parede — número cravado reprovaria a melhoria.
	# Mosaico e degrau são os dois o PISO do templo; é a área andável que importa.
	var piso : int = AjudaMapa.conta_char(tiles, ret, ["%", "="])
	var parede : int = AjudaMapa.conta_char(tiles, ret, ["["])
	_assert(piso > 120, "o templo tem piso de pedra pra andar dentro (%d tiles)" % piso)
	_assert(parede > 50, "cercado por parede de hieróglifos (%d tiles)" % parede)
	# a parede tem que ter uma abertura — recinto lacrado é conteúdo inalcançável
	var linha_sul : String = ""
	for y in range(ret.position.y, ret.position.y + ret.size.y):
		var l : String = tiles[y]
		var trecho : String = l.substr(ret.position.x, ret.size.x)
		if trecho.count("[") > 10:
			linha_sul = trecho
	_assert(linha_sul.contains("%"),
		"a parede do recinto tem abertura pra entrar (não é caixa lacrada)")

	# ---- 3. As pirâmides estão plantadas ---------------------------------
	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
	MapLayouts.paint(tm, "world_map")

	var pedaco_de := {}
	for e in MapLayouts.ESTRUTURAS_DESERTO.size():
		var lista : Array = MapLayouts.ESTRUTURAS_DESERTO[e]
		for i in lista.size():
			pedaco_de[lista[i]] = {"estrutura": e, "indice": i}

	var achados := {}
	for y in range(ret.position.y, ret.position.y + ret.size.y):
		for x in range(ret.position.x, ret.position.x + ret.size.x):
			var co := tm.get_cell_atlas_coords(0, Vector2i(x, y))
			if pedaco_de.has(co):
				achados[Vector2i(x, y)] = pedaco_de[co]
	_assert(achados.size() >= 30,
		"as estruturas 2x3 foram plantadas (%d tiles = %d estruturas)" % [
			achados.size(), achados.size() / 6])
	_assert(achados.size() % 6 == 0, "nenhuma estrutura ficou pela metade")

	# cada uma inteira, sem sobrepor: parte do pedaço 0 e confere os outros 5
	var quebradas : Array[String] = []
	var inteiras := 0
	for celula in achados:
		if int(achados[celula]["indice"]) != 0:
			continue
		inteiras += 1
		var qual : int = int(achados[celula]["estrutura"])
		for lin in 3:
			for col in 2:
				var c := Vector2i(celula.x + col, celula.y + lin)
				if not achados.has(c):
					quebradas.append("%s: falta pedaço" % celula)
				elif int(achados[c]["estrutura"]) != qual \
						or int(achados[c]["indice"]) != lin * 2 + col:
					quebradas.append("%s: pedaço trocado" % celula)
	_assert(inteiras >= 5, "há pelo menos 5 estruturas (pirâmides e obeliscos): %d" % inteiras)
	_assert(quebradas.is_empty(), "nenhuma estrutura fatiada ou sobreposta — %s" % (
		"ok" if quebradas.is_empty() else str(quebradas.slice(0, 3))))

	# ---- 4. A pirâmide bloqueia, o chão do deserto não -------------------
	var bloqueia_tudo := true
	for celula in achados:
		var td : TileData = tm.get_cell_tile_data(0, celula)
		if td == null or not td.get_custom_data("blocked"):
			bloqueia_tudo = false
	_assert(bloqueia_tudo, "toda estrutura bloqueia a passagem (é construção, não chão)")

	var andavel := AjudaMapa.tile_andavel_da_zona(tm, ret)
	_assert(andavel.x != -9999, "a ilha tem chão andável pra explorar (%s)" % andavel)

	# ---- 5. Os Psíquicos têm onde nascer aqui ----------------------------
	var mgr = load("res://scripts/world/systems/SpawnManager.gd").new()
	var no_deserto : Array = mgr.especies_do_bioma("desert")
	var nas_ruinas : Array = mgr.especies_do_bioma("ruins")
	_assert(no_deserto.size() >= 8, "o deserto tem moradores (%d espécies)" % no_deserto.size())
	_assert(nas_ruinas.size() >= 8, "as ruínas têm moradores (%d espécies)" % nas_ruinas.size())
	mgr.free()

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
