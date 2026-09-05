## teste_mapa_de_kanto.gd — O mapa da região (05/09).
##
## Pedido do Gabriel: "faça um mini mapa real do que já existe, pois o atual não
## serve pra muita coisa". O antigo era um raio de tiles em volta do jogador —
## serve pra desviar da árvore ao lado, não pra saber onde você está no mundo.
##
## O que este arquivo trava:
##   1. O mapa lê as cidades de `zones.json`, a MESMA fonte do resto do jogo —
##      não pode existir uma segunda lista de cidades pra manter em sincronia.
##   2. Existe um caminho de TECLA e a tecla não briga com nenhuma outra (a
##      Pokédex e o mapa já dividiram a tecla M uma vez, em 04/09).
##   3. O mapa entra na pilha de telas: Esc fecha ele, como toda tela do jogo.
##   4. Toda coordenada de atlas que o mapa sabe colorir cobre o que o mundo de
##      fato usa — senão regiões inteiras sairiam com a cor de "grama" genérica.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_mapa_de_kanto.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: mapa de Kanto (05/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- 1. As cidades vêm do zones.json ------------------------------------
	var caminho := "res://data/world/zones.json"
	_assert(FileAccess.file_exists(caminho), "zones.json existe (é a fonte das cidades do mapa)")
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	var cidades : Array[String] = []
	for z in dados["zones"]:
		var nome := str(z.get("name", ""))
		if nome.ends_with("City") or nome.ends_with("Town") or nome.ends_with("Island") \
				or nome.ends_with("Plateau"):
			_assert(z.has("tile_rect"), "%s tem retângulo no mapa" % nome)
			cidades.append(nome)
	_assert(cidades.size() >= 8,
		"o mapa tem cidades de verdade pra marcar (%d: %s)" % [cidades.size(), ", ".join(cidades)])

	# ---- 2. A tecla do mapa existe e é só dela ------------------------------
	_assert(InputMap.has_action("menu_map"), "existe a ação 'menu_map'")
	var teclas_do_mapa : Array[int] = []
	for ev in InputMap.action_get_events("menu_map"):
		if ev is InputEventKey:
			teclas_do_mapa.append((ev as InputEventKey).physical_keycode)
	_assert(not teclas_do_mapa.is_empty(), "o mapa tem atalho de teclado (não só o botão do menu)")
	var conflito : Array[String] = []
	for acao in InputMap.get_actions():
		var nome := str(acao)
		if nome == "menu_map" or nome.begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(acao):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode in teclas_do_mapa:
				conflito.append(nome)
	_assert(conflito.is_empty(), "a tecla do mapa não é de mais ninguém — %s" % (
		"ok" if conflito.is_empty() else str(conflito)))

	# ---- 3. Entra na pilha de telas -----------------------------------------
	var fonte := FileAccess.get_file_as_string("res://scripts/ui/MapaMundi.gd")
	_assert(fonte.contains("UIStack.empilhar"), "o mapa se registra na pilha (Esc fecha ele)")
	_assert(fonte.contains("UIStack.desempilhar"), "e sai da pilha ao fechar")

	# ---- 4. A tabela de cores cobre o mundo de verdade ----------------------
	# Sem esta conferência, um tipo de tile novo (foi o caso das árvores de 2x3)
	# sairia no mapa com a cor de grama — regiões inteiras de floresta pintadas
	# como campo aberto, e ninguém notaria até olhar.
	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
	MapLayouts.paint(tm, "world_map")

	var conhecidas := {}
	for ch in MapLayouts.CHAR_MAP:
		conhecidas[MapLayouts.CHAR_MAP[ch]] = true
	for ch in MapLayouts.VARIANTES_TERRENO:
		for co in MapLayouts.VARIANTES_TERRENO[ch]:
			conhecidas[co] = true
	for co in MapLayouts.COSTA_ATLAS:
		conhecidas[co] = true
	for lista in MapLayouts.ARVORES_GRANDES:
		for co in lista:
			conhecidas[co] = true
	for lista in MapLayouts.ESTRUTURAS_DESERTO:
		for co in lista:
			conhecidas[co] = true

	var desconhecidas := {}
	for celula in tm.get_used_cells(0):
		var co := tm.get_cell_atlas_coords(0, celula)
		if not conhecidas.has(co):
			desconhecidas[co] = true
	_assert(desconhecidas.is_empty(),
		"todo tile do mundo tem cor no mapa — %s" % (
			"ok" if desconhecidas.is_empty() else str(desconhecidas.keys())))

	# ---- 5. E a cor é EXPLÍCITA, não o verde genérico -----------------------
	# 🔴 Furo real, achado em tela: os 6 biomas novos entraram no CHAR_MAP, então
	# a conferência acima passou — mas nenhum deles estava na tabela de cores do
	# mapa, e todos caíam no fallback de grama. A Ilha do Deserto inteira
	# aparecia VERDE no mapa de Kanto. Conferir "o char existe" não é o mesmo que
	# conferir "o mapa sabe desenhá-lo".
	var fonte_mapa := FileAccess.get_file_as_string("res://scripts/ui/MapaMundi.gd")
	var sem_cor : Array[String] = []
	for ch in MapLayouts.CHAR_MAP:
		# peças de kit (telhado/parede laterais) herdam a cor de parede/telhado
		if ch in ["q", "r", "s", "t", "u", "v", "x", "y", "a", "p",
				"1", "2", "3", "4", "5", "6", "7", "8"]:
			continue
		if not fonte_mapa.contains('"%s": Color(' % ch):
			sem_cor.append(str(ch))
	_assert(sem_cor.is_empty(),
		"todo terreno tem cor PRÓPRIA no mapa (não cai no verde genérico) — %s" % (
			"ok" if sem_cor.is_empty() else str(sem_cor)))
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
