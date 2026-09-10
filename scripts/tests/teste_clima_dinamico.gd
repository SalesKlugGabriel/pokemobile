## teste_clima_dinamico.gd — 09/09, item da lista de imersão "clima
## dinâmico". ClimaDinamico.gd (autoload) guarda o estado e sorteia a
## próxima troca; ChuvaOverlay.gd (instanciado por BaseMap, só no mundo
## aberto) é quem desenha. Prova aqui: o relógio só corre com `ativar(true)`
## (nunca em dungeon/interior), sair do mundo aberto sempre desliga a chuva
## (ninguém quer voltar de um covil com o som/efeito ainda "ligado" por
## trás), e o overlay liga/desliga a partícula de verdade sem crashar sem
## viewport (`--headless` não tem janela real).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false
var ClimaDinamico : Node

func _initialize() -> void:
	print("=== Teste: clima dinâmico (09/09) ===")
	ClimaDinamico = root.get_node("ClimaDinamico")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_assert(not ClimaDinamico.chovendo, "nasce sem chuva")

	# Sem ativar(true), o relógio não deve andar (fora do mundo aberto).
	var restante_antes : float = ClimaDinamico._tempo_restante
	ClimaDinamico._process(999999.0)
	_assert(ClimaDinamico._tempo_restante == restante_antes, "sem ativar(), o relógio não corre (dungeon não tem céu)")

	# Ativado, um delta gigante força a virada de estado pelo menos uma vez.
	ClimaDinamico.ativar(true)
	var chovendo_antes : bool = ClimaDinamico.chovendo
	ClimaDinamico._process(999999.0)
	_assert(ClimaDinamico.chovendo != chovendo_antes, "com ativar(true), um tempo grande vira o estado")

	# Sair do mundo aberto sempre desliga a chuva, mesmo que estivesse chovendo.
	if not ClimaDinamico.chovendo:
		ClimaDinamico.chovendo = true  # força pra testar o desligamento de verdade
	var sinal_recebido := [false]
	var callback := func(chovendo: bool): sinal_recebido[0] = not chovendo
	ClimaDinamico.clima_mudou.connect(callback)
	ClimaDinamico.ativar(false)
	_assert(not ClimaDinamico.chovendo, "sair do mundo aberto sempre desliga a chuva")
	_assert(sinal_recebido[0], "e avisa quem estiver escutando (o overlay desliga a partícula)")
	ClimaDinamico.clima_mudou.disconnect(callback)

	# ---- ChuvaOverlay: liga/desliga sem crashar mesmo sem viewport real ----
	var overlay = preload("res://scripts/world/systems/ChuvaOverlay.gd").new()
	root.add_child(overlay)
	_assert(overlay.get_node_or_null("Gotas") != null, "cria as partículas de chuva como filho")
	overlay.set_chovendo(true)
	_assert(overlay.get_node("Gotas").emitting, "ligar a chuva liga a emissão de partículas")
	overlay.set_chovendo(false)
	_assert(not overlay.get_node("Gotas").emitting, "desligar a chuva desliga a emissão")

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
