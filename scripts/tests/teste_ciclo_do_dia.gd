## teste_ciclo_do_dia.gd — Ciclo de dia/noite (09/09), primeiro item da lista
## de imersão pedida pelo Gabriel. Confere só a MATEMÁTICA (cor por hora,
## classificação de período) — o efeito visual em si (CanvasModulate tingindo
## o mundo aberto) só se julga jogando de verdade.
##
## Padrão de acesso ao autoload igual teste_onda1_tabela_pokebolas.gd: uma
## variável de membro com o MESMO nome do autoload, preenchida via
## root.get_node() dentro de _initialize() — não em _init() (a árvore ainda
## não existe nesse ponto) e não como identificador global solto (não
## resolve em --script headless, só dentro do jogo rodando de verdade).
extends SceneTree

var _fail  := 0
var _rodou := false
var CicloDoDia : Node

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   - ", msg)
	else:
		_fail += 1
		print("  FALHA - ", msg)

func _initialize() -> void:
	print("=== Teste: ciclo do dia (09/09) ===")
	CicloDoDia = root.get_node_or_null("CicloDoDia")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_assert(CicloDoDia != null, "autoload CicloDoDia existe")
	if CicloDoDia == null:
		print("=== Resultado: 0 ok, 1 falhas (autoload não achado) ===")
		quit(1)
		return true

	# Meio-dia e meio da tarde: sem tingimento (cor branca == "luz normal").
	_assert(CicloDoDia._cor_para_hora(12.0).is_equal_approx(Color(1, 1, 1)),
		"meio-dia não tinge a tela")
	_assert(CicloDoDia._cor_para_hora(16.0).is_equal_approx(Color(1, 1, 1)),
		"meio da tarde também não tinge")

	# Meia-noite: tom escuro de verdade (mais escuro que o dia nos 3 canais).
	var noite : Color = CicloDoDia._cor_para_hora(0.0)
	_assert(noite.r < 0.5 and noite.g < 0.5 and noite.b < 0.6,
		"meia-noite tinge escuro (%s)" % str(noite))

	# A transição é suave: hora 6 (fim do amanhecer) não pode ser igual a
	# hora 12 (dia cheio) nem igual a hora 0 (noite) — tem que estar no meio.
	var meio_amanhecer : Color = CicloDoDia._cor_para_hora(6.0)
	_assert(not meio_amanhecer.is_equal_approx(Color(1, 1, 1)) and not meio_amanhecer.is_equal_approx(noite),
		"amanhecer é uma cor DE TRANSIÇÃO, não pula direto de noite pra dia")

	# Classificação de período bate com o que a cor sugere.
	_assert(CicloDoDia.periodo_de(12.0) == "dia", "meio-dia classifica como dia")
	_assert(CicloDoDia.periodo_de(0.0) == "noite", "meia-noite classifica como noite")
	_assert(CicloDoDia.periodo_de(23.9) == "noite", "quase meia-noite ainda é noite (fecha o ciclo)")
	_assert(CicloDoDia.periodo_de(6.0) == "amanhecer", "6h é amanhecer, não dia nem noite")
	_assert(CicloDoDia.periodo_de(19.0) == "entardecer", "19h é entardecer")

	# O ciclo é contínuo: hora_atual() nunca sai de [0, 24).
	CicloDoDia._tempo_acumulado_seg = CicloDoDia.SEGUNDOS_POR_DIA - 0.001
	_assert(CicloDoDia.hora_atual() < 24.0, "hora_atual nunca chega a 24 (fecha em 0 de novo)")

	# BaseMap só liga o ciclo no mundo aberto (map_id == "world_map") — nunca
	# em dungeon/interior, que tem luz própria.
	var base_map := FileAccess.get_file_as_string("res://scripts/world/BaseMap.gd")
	_assert(base_map.contains('map_id == "world_map"') and base_map.contains("_ligar_ciclo_do_dia"),
		"o ciclo só liga no mundo aberto, não em toda BaseMap")
	_assert(base_map.contains("CicloDoDia.desregistrar_modulate"),
		"e desliga ao sair do mapa (sem isso, tingiria o mapa seguinte por engano)")

	print("=== Resultado: %d ok, %d falhas ===" % [12 - _fail, _fail])
	quit(1 if _fail > 0 else 0)
	return true
