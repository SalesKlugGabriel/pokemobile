## teste_fase5_fase9_ui_skill.gd — Teste headless da Fase 9 do motor de
## combate em tempo real (skill flutuando + barra de cooldown no HUD, o
## pedido original do print que o Gabriel mandou). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_fase9_ui_skill.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var EventBus : Node

func _initialize() -> void:
	print("=== Teste Fase 5/9 (UI de skill flutuando + cooldown) ===")
	EventBus = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- FloatingText cria um Label de verdade, com o texto certo ----
	var filhos_antes : int = root.get_child_count()
	FloatingText.show_text(root, Vector2(100, 100), "Mega Drain -12", Color.GREEN)
	var achou := false
	for c in root.get_children():
		if c is Label and c.text == "Mega Drain -12":
			achou = true
			break
	_assert(achou, "FloatingText.show_text() cria um Label com o texto certo")
	_assert(root.get_child_count() == filhos_antes + 1, "só 1 nó novo criado por chamada")

	# Sem parent (defensivo) não deve quebrar
	FloatingText.show_text(null, Vector2.ZERO, "não deveria aparecer")
	_assert(true, "show_text() com parent nulo não quebra (só não faz nada)")

	# ---- Barra de cooldown no HUD ----
	var hud_scene : PackedScene = load("res://scenes/ui/OverworldHUD.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	_assert(hud._skill_bars.size() == 4, "HUD constrói 4 barras de cooldown, uma por slot")
	for bar in hud._skill_bars:
		_assert(bar.value == 1.0, "toda barra nasce cheia (skill pronta, ainda não usada)")

	_assert(hud._skill_buttons.size() == 4, "HUD constrói 4 botões de skill (tocáveis, não só indicador)")
	for btn in hud._skill_buttons:
		_assert(btn.disabled, "botão nasce desabilitado até saber o moveset do Follower")

	# ---- nome do golpe aparece no botão quando o Follower muda ----
	var dados_pokemon := {
		"species_id": 1, "level": 5,
		"moves": ["tackle", "", "vine_whip", "growl"],
	}
	EventBus.follower_changed.emit(dados_pokemon)
	_assert(not hud._skill_buttons[0].disabled, "slot com golpe fica habilitado")
	_assert(hud._skill_buttons[0].text != "—", "slot com golpe mostra o nome, não o traço")
	_assert(hud._skill_buttons[1].disabled, "slot vazio (\"\") continua desabilitado")
	# 04/09: era `text == "—"`. O traço lia como defeito no teste de gameplay
	# ("por que dois botões estão com um risquinho?"); agora o slot diz em que
	# NÍVEL abre, que é informação em vez de erro. O que importa travar é que
	# ele continua desabilitado e NÃO mostra nome de golpe.
	_assert(hud._skill_buttons[1].text != "—", "slot vazio não usa mais o traço")
	_assert(hud._skill_buttons[1].text.begins_with("Nv.") or hud._skill_buttons[1].text == "vazio",
		"slot vazio diz em que nível abre (ou 'vazio' se a espécie não aprende mais)")
	_assert(hud._skill_buttons[1].tooltip_text != "", "slot vazio explica o que é ao passar o mouse")

	# ---- tocar o botão chama use_skill() no Follower ativo, sem quebrar ----
	# (a lógica de use_skill() em si — cooldown/alvo/área — já é coberta a
	# fundo por teste_fase5_selecao_alvo.gd e teste_fase5_area_targeting.gd;
	# aqui só confere que o botão acha o Follower certo e chama sem erro.)
	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 1
	follower.pokemon_level = 5
	root.add_child(follower)
	hud._on_skill_button_pressed(0)
	_assert(true, "botão de skill não quebra ao ser pressionado com um Follower real na cena")

	EventBus.follower_skill_cooldown_updated.emit(1, 0.3)
	_assert(hud._skill_bars[1].value == 0.3, "atualizar o slot 1 muda só a barra do slot 1")
	_assert(hud._skill_bars[0].value == 1.0, "slot 0 não é afetado pela atualização do slot 1")

	EventBus.follower_skill_cooldown_updated.emit(1, 1.0)
	_assert(hud._skill_bars[1].modulate == Color(0.4, 0.8, 1.0), "barra pronta (progress=1.0) volta pra cor normal")

	# Índice fora da faixa não deve quebrar
	EventBus.follower_skill_cooldown_updated.emit(99, 0.5)
	_assert(true, "slot inválido (99) não quebra o HUD")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
