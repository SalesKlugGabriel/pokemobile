## teste_qa_tiles.gd — QA do atlas de tiles (04/09).
##
## Vem da "regra obrigatória 3" do documento de direção de arte do Gabriel:
## apareceu texto de legenda preso dentro da arte de alguns tiles (um "1" solto
## e palavras), visível várias vezes no mapa. A origem foi achada: o atlas tinha
## sido recortado da imagem de referência, que traz a LEGENDA escrita embaixo de
## cada tile — o recorte desalinhado trouxe junto pedaços de texto e faixas
## pretas do fundo da referência.
##
## O próprio Gabriel pediu pra tratar isso como ERRO RECORRENTE DE PROCESSO, não
## acidente isolado: por isso a checagem virou teste, e roda junto com a suíte
## em todo lote daqui pra frente.
##
## O que dá pra automatizar com confiança é a FAIXA PRETA (borda quase toda
## preta = recorte errado, nunca arte intencional). A checagem de texto continua
## precisando de olho humano no zoom — o detector automático confunde pedra
## clara e gelo com letra —, então ela está documentada no tool
## `tools/reparar_tiles.py --conferir`, que lista os suspeitos pra revisão.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_qa_tiles.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

const T : int = 128

func _initialize() -> void:
	print("=== Teste: QA do atlas de tiles (04/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var tex : Texture2D = load("res://assets/tilesets/overworld.png")
	var img : Image = tex.get_image()
	var cols := img.get_width() / T
	var rows := img.get_height() / T

	var com_faixa : Array[String] = []
	var usados := 0
	for r in rows:
		for c in cols:
			if _slot_vazio(img, c, r):
				continue
			usados += 1
			var pretas := _colunas_pretas(img, c, r)
			if pretas > 0:
				com_faixa.append("(%d,%d): %d colunas" % [c, r, pretas])

	_assert(usados >= 40, "atlas tem os tiles esperados (%d em uso)" % usados)
	_assert(com_faixa.is_empty(),
		"nenhum tile com faixa preta de recorte — %s" % ("ok" if com_faixa.is_empty() else str(com_faixa)))

	# Os tiles que o jogo referencia em CHAR_MAP têm que existir de verdade no
	# atlas (pega char apontando pra slot vazio, que renderiza buraco no mapa).
	var fora : Array[String] = []
	for ch in MapLayouts.CHAR_MAP:
		var coord : Vector2i = MapLayouts.CHAR_MAP[ch]
		if coord.x >= cols or coord.y >= rows or _slot_vazio(img, coord.x, coord.y):
			fora.append("%s -> %s" % [ch, coord])
	_assert(fora.is_empty(), "todo char do CHAR_MAP aponta pra um tile que existe — %s" % (
		"ok" if fora.is_empty() else str(fora)))

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _slot_vazio(img: Image, c: int, r: int) -> bool:
	for y in range(0, T, 8):
		for x in range(0, T, 8):
			var p := img.get_pixel(c * T + x, r * T + y)
			if p.a > 0.1 and (p.r + p.g + p.b) > 0.12:
				return false
	return true

## Coluna "preta" = quase toda escura de cima a baixo. É assinatura de recorte
## errado (fundo da folha de referência entrando no quadro), não de arte.
func _colunas_pretas(img: Image, c: int, r: int) -> int:
	var total := 0
	for x in T:
		var escuros := 0
		for y in T:
			var p := img.get_pixel(c * T + x, r * T + y)
			if p.a > 0.5 and (p.r + p.g + p.b) < 0.24:
				escuros += 1
		if escuros > int(T * 0.85):
			total += 1
	return total

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
