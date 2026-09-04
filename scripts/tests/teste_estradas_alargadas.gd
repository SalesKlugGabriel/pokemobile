## teste_estradas_alargadas.gd — Teste headless das estradas alargadas
## (03/09, pedido do Gabriel: "estradas que tenham 6 a 10 pisos de largura,
## mais perto do formato original do jogo"). Cobre só os 3 trechos já
## alargados nesta leva (Rota 7, Rota 3/4, Rota 8) — os demais (rotas
## verticais, cidades) ficam pra uma leva futura, documentado em
## progresso.md com o motivo (prédios/molduras de caverna ancorados na
## largura antiga em cada um deles).
## Roda com: godot4 --headless --script res://scripts/tests/teste_estradas_alargadas.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: estradas alargadas (03/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Rota 7 (Saffron -> Celadon): 5 -> 8 tiles, r14-21 ----
	for r in range(14, 22):
		_assert(MapLayouts._route7_cell(5, r) == "P", "Rota 7: linha %d é caminho (dentro dos 8 tiles novos)" % r)
	_assert(MapLayouts._route7_cell(5, 13) != "P" or MapLayouts._route7_cell(5, 13) == ".",
		"Rota 7: linha 13 (fora da faixa) não é forçada a virar caminho só por acidente")

	# ---- Rota 3/4 (Pewter -> Cerulean): 5 -> 10 tiles, r13-22 ----
	for r in range(13, 23):
		_assert(MapLayouts._leste_de_pewter_cell(5, r) == "P", "Rota 3: linha %d é caminho (dentro dos 10 tiles novos)" % r)
	# A moldura de Mt Moon (r12-24, cols ROUTE3_COLS-4..+4) continua de pé —
	# alargar o caminho não apagou a rocha ao redor da boca da caverna.
	var route3_cols : int = MapLayouts.ROUTE3_COLS
	_assert(MapLayouts._leste_de_pewter_cell(route3_cols, 12) == "R",
		"Mt Moon: moldura de rocha continua existindo, mesmo com o caminho mais largo")

	# ---- Rota 8 (Saffron -> Lavender): 5 -> 10 tiles, r13-22 ----
	for r in range(13, 23):
		_assert(MapLayouts._route8_cell(5, r) == "P", "Rota 8 (trecho aberto): linha %d é caminho" % r)
	# Boca do Rock Tunnel continua vencendo nas próprias colunas (r10 20-27, r12-15).
	var route9_cols : int = MapLayouts.ROUTE9_COLS
	_assert(MapLayouts._route8_cell(route9_cols + 20, 13) == "R",
		"Rock Tunnel: a moldura de rocha continua vencendo mesmo com a estrada mais larga")

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
