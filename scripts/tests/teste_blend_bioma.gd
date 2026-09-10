## teste_blend_bioma.gd — 10/09, peça técnica nova da reestruturação geográfica
## em escala real (pedido do Gabriel: nunca "floresta → linha invisível →
## deserto"). `MapLayouts._misturar_bioma_cell()` é o helper genérico que toda
## rota longa da escala nova vai usar pra misturar bioma A em bioma B aos
## poucos. Ver `docs/mundo-novo-escala.md` pro blueprint completo.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: mistura gradual de bioma (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var bioma_a := func(_c: int, _r: int) -> String: return "A_MARCA"
	var bioma_b := func(_c: int, _r: int) -> String: return "B_MARCA"

	# progresso=0.0: sempre bioma A, em qualquer (c,r).
	var todos_a := true
	for c in range(0, 40):
		if MapLayouts._misturar_bioma_cell(c, 5, 0.0, bioma_a, bioma_b) != "A_MARCA":
			todos_a = false
			break
	_assert(todos_a, "progresso 0.0 nunca sorteia o bioma B (início da transição é 100% do bioma anterior)")

	# progresso=1.0: sempre bioma B.
	var todos_b := true
	for c in range(0, 40):
		if MapLayouts._misturar_bioma_cell(c, 5, 1.0, bioma_a, bioma_b) != "B_MARCA":
			todos_b = false
			break
	_assert(todos_b, "progresso 1.0 nunca sorteia o bioma A (fim da transição é 100% do bioma seguinte)")

	# progresso=0.5: uma mistura de verdade, não 100% de nenhum dos dois — em
	# muitas amostras, a proporção de B fica perto de 50% (não exatamente,
	# ruído é ruído, mas longe de 0% ou 100%).
	var conta_b := 0
	var amostras := 400
	for i in amostras:
		if MapLayouts._misturar_bioma_cell(i, i * 3 + 1, 0.5, bioma_a, bioma_b) == "B_MARCA":
			conta_b += 1
	var proporcao : float = float(conta_b) / float(amostras)
	_assert(proporcao > 0.35 and proporcao < 0.65,
		"progresso 0.5 dá uma mistura de verdade (~50%% B, medido %.0f%%)" % (proporcao * 100.0))

	# `sal` diferente muda o padrão — duas transições vizinhas não ficam
	# sincronizadas (mesmo (c,r), mesmo progresso, sal diferente → não é
	# garantido resultado igual sempre, mas com 60 amostras tem que discordar
	# em pelo menos algumas).
	var discordancias := 0
	for c in range(0, 60):
		var r1 := MapLayouts._misturar_bioma_cell(c, 10, 0.5, bioma_a, bioma_b, 0)
		var r2 := MapLayouts._misturar_bioma_cell(c, 10, 0.5, bioma_a, bioma_b, 1)
		if r1 != r2:
			discordancias += 1
	_assert(discordancias > 5, "sal diferente muda o padrão de ruído (%d/60 células discordam)" % discordancias)

	# _progresso_transicao: folga nas pontas evita vazamento imediato.
	_assert(MapLayouts._progresso_transicao(0, 100, 10) == 0.0, "dentro da margem inicial, progresso fica travado em 0.0")
	_assert(MapLayouts._progresso_transicao(100, 100, 10) == 1.0, "dentro da margem final, progresso fica travado em 1.0")
	_assert(is_equal_approx(MapLayouts._progresso_transicao(50, 100, 10), 0.5),
		"no meio do trecho útil ([10,90], centro=50), progresso fica em 0.5")

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
