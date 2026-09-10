## teste_estradas_alargadas.gd — Teste headless das estradas alargadas
## (03/09, pedido do Gabriel: "estradas que tenham 6 a 10 pisos de largura,
## mais perto do formato original do jogo"). Cobre o trecho alargado desta
## leva ainda vivo dentro do world_map (Rota 8) — os demais (rotas
## verticais, cidades) ficam pra uma leva futura.
##
## 🔴 10/09: a Rota 3/4 (Pewter→Cerulean, Fase 2) e a Rota 7
## (Saffron→Celadon, Fase 3) SAÍRAM deste teste — não porque deixaram de
## ser largas, mas porque deixaram de existir dentro do world_map: viraram
## RotaPewterCerulean.tscn e RotaSaffronCeladon.tscn (cenas próprias, com
## largura de caminho variável própria — ver `_rpc_*_cell`/`_rota_campo_
## leste_oeste_cell` em MapLayouts.gd). Cobertura equivalente está em
## teste_rota_pewter_cerulean.gd e teste_no_central_saffron.gd.
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
