## teste_pilha_de_telas.gd — Os 4 "trava o jogo" do teste de gameplay de 04/09.
##
## Contexto: joguei o jogo do começo, duas vezes, como uma criança de 10 anos.
## Fiquei preso duas vezes sem conseguir voltar ao jogo. Este arquivo trava os
## consertos, um assert por sintoma observado, para nenhum deles voltar quando
## uma tela nova for construída.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_pilha_de_telas.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

## Autoload não é identificador em script de teste headless (convenção já usada
## por teste_costa_e_surf.gd e outros): pega pelo nó da raiz.
var UIStack  : Node
var GameData : Node

func _initialize() -> void:
	print("=== Teste: pilha de telas e telas que prendiam o jogador (04/09) ===")
	UIStack  = root.get_node("UIStack")
	GameData = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_testar_pilha()
	_testar_icone_pokemon()
	_testar_tecla_unica()
	_testar_golpes_do_time()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# A-1 e A-3: Esc fecha o painel do topo, e os menus não empilham
# ──────────────────────────────────────────────────────────────────────────────
func _testar_pilha() -> void:
	var fechados : Array[String] = []
	var a := Node.new()
	var b := Node.new()
	root.add_child(a)
	root.add_child(b)

	_assert(not UIStack.tem_aberto(), "pilha começa vazia")
	_assert(not UIStack.fechar_topo(), "sem nada aberto, Esc não 'consome' a tecla — o menu de Pausa abre")

	UIStack.empilhar(a, func(): fechados.append("a"))
	UIStack.empilhar(b, func(): fechados.append("b"))
	_assert(UIStack.quantidade() == 2, "dois painéis abertos são dois itens na pilha")
	_assert(UIStack.topo() == b, "o topo é o último aberto")

	_assert(UIStack.fechar_topo(), "Esc com painel aberto devolve true (não abre a Pausa por cima)")
	_assert(fechados == ["b"], "fechou o de CIMA, não o de baixo — era o bug do Time + Pausa empilhados")
	_assert(UIStack.topo() == a, "o de baixo continua aberto e vira o novo topo")

	UIStack.fechar_topo()
	_assert(fechados == ["b", "a"], "segundo Esc fecha o de baixo")
	_assert(not UIStack.tem_aberto(), "pilha esvazia — o terceiro Esc abre o menu de Pausa")

	# abrir o mesmo painel duas vezes não pode criar duas entradas
	UIStack.empilhar(a, func(): pass)
	UIStack.empilhar(a, func(): pass)
	_assert(UIStack.quantidade() == 1, "abrir o mesmo painel 2x não duplica na pilha")

	# nó liberado não pode deixar Callable morto na pilha
	UIStack.empilhar(b, func(): pass)
	b.free()
	_assert(UIStack.quantidade() == 1, "painel liberado (troca de mapa) sai da pilha sozinho")

	UIStack.fechar_tudo()
	_assert(not UIStack.tem_aberto(), "fechar_tudo esvazia (usado na troca de cena)")
	a.free()

# ──────────────────────────────────────────────────────────────────────────────
# A-2: a Pokédex mostrava 12 Bulbasaurs porque usava a folha de animação inteira
# ──────────────────────────────────────────────────────────────────────────────
func _testar_icone_pokemon() -> void:
	var folha : Texture2D = load("res://assets/sprites/pokemon/mon_001.png")
	_assert(folha != null, "a folha de sprites de Bulbasaur existe")
	_assert(folha.get_width() > 200,
		"a folha é grande mesmo (%dx%d) — usá-la crua como ícone é o bug" % [
			folha.get_width(), folha.get_height()])

	var icone : Texture2D = PokemonIcon.textura(1)
	_assert(icone is AtlasTexture, "o ícone é um recorte (AtlasTexture), não a folha")
	_assert(icone.get_width() < folha.get_width(),
		"o ícone é MENOR que a folha (%d < %d) — cabe numa linha de lista" % [
			icone.get_width(), folha.get_width()])
	_assert(int(icone.get_width()) == int(folha.get_width() / 3.0),
		"o recorte tem exatamente a largura de 1 quadro (folha ÷ 3 colunas)")
	_assert(icone.get_height() <= icone.get_width() + 1,
		"o recorte é o quadro parado, não a coluna inteira de direções")

	var tr := PokemonIcon.criar(1, 24)
	_assert(tr.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
		"o TextureRect ignora o tamanho natural — sem isso ele volta a esticar a folha")
	_assert(tr.custom_minimum_size == Vector2(24, 24), "o ícone respeita o tamanho pedido")
	_assert(PokemonIcon.textura(9999) == null, "espécie sem sprite devolve null em vez de quebrar")
	tr.free()

# ──────────────────────────────────────────────────────────────────────────────
# A-1 (segunda metade): a tecla M tinha DOIS donos
# ──────────────────────────────────────────────────────────────────────────────
func _testar_tecla_unica() -> void:
	# 🔴 04/09, achado ao vivo: uma edição minha no project.godot deixou um "}"
	# solto e a ação "pause" virou "}pause". O jogo abriu normal, a suíte inteira
	# passou, e só o navegador denunciou (Esc parou de funcionar em TUDO). Por
	# isso a existência de cada ação virou conferência: a suíte tinha um ponto
	# cego do tamanho do mapa de controles.
	var esperadas : Array[String] = ["move_up", "move_down", "move_left", "move_right",
		"skill_1", "skill_2", "skill_3", "skill_4", "pokeball", "interact",
		"menu_team", "menu_bag", "pause", "run", "open_pokedex"]
	var faltando : Array[String] = []
	for acao in esperadas:
		if not InputMap.has_action(acao):
			faltando.append(acao)
	_assert(faltando.is_empty(), "toda ação de controle existe no InputMap — %s" % (
		"ok" if faltando.is_empty() else str(faltando)))
	var estranhas : Array[String] = []
	for acao in InputMap.get_actions():
		var nome := str(acao)
		if nome.begins_with("ui_"):
			continue
		if not nome.is_valid_identifier():
			estranhas.append(nome)
	_assert(estranhas.is_empty(), "nenhuma ação com nome corrompido — %s" % (
		"ok" if estranhas.is_empty() else str(estranhas)))

	var por_tecla := {}
	var repetidas : Array[String] = []
	for acao in InputMap.get_actions():
		var nome := str(acao)
		if nome.begins_with("ui_"):
			continue   # as ações internas do Godot compartilham teclas de propósito
		for ev in InputMap.action_get_events(acao):
			if not (ev is InputEventKey):
				continue
			var codigo : int = (ev as InputEventKey).physical_keycode
			if codigo == 0:
				continue
			if por_tecla.has(codigo):
				repetidas.append("%s tem o mesmo botão de %s" % [nome, por_tecla[codigo]])
			else:
				por_tecla[codigo] = nome
	_assert(repetidas.is_empty(), "nenhuma tecla do jogo tem dois donos — %s" % (
		"ok" if repetidas.is_empty() else str(repetidas)))

# ──────────────────────────────────────────────────────────────────────────────
# C-3: os golpes saíam como "?" na tela do Time (lia a chave errada do save)
# ──────────────────────────────────────────────────────────────────────────────
func _testar_golpes_do_time() -> void:
	# Formato real gravado pelo SaveManager: {id, pp_current, pp_max}
	var golpe := {"id": "tackle", "pp_current": 35, "pp_max": 35}
	var dados : Dictionary = GameData.get_move(str(golpe.get("id", "")))
	_assert(not dados.is_empty(), "a chave do save é 'id' e o golpe é encontrado por ela")
	_assert(str(dados.get("name", "")) != "", "o golpe tem nome de verdade (era '?' na tela)")

	var errado : Dictionary = GameData.get_move(str(golpe.get("move_id", "")))
	_assert(errado.is_empty(),
		"a chave antiga 'move_id' não existe no save — era daí que vinha o '? | ?'")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
