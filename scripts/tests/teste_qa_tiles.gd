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

	# ── Regra obrigatória 1: objeto inteiro e centralizado no próprio quadro ──
	# O defeito real achado em 04/09 não era só descentralização: as três árvores
	# estavam CORTADAS ao meio por um recorte reto — a coluna x=5 era o limite
	# esquerdo em 62 a 88 das ~90 linhas do objeto, assinatura de corte e não de
	# silhueta natural. Foram reconstruídas espelhando o lado são.
	#
	# Duas conferências, porque uma sozinha deixa o defeito passar:
	#   a) desvio do centro do quadro   -> pega objeto descentralizado
	#   b) borda reta em muitas linhas  -> pega objeto cortado
	# Só vale pra tile de OBJETO SOLTO. Textura que preenche o quadro (parede,
	# sebe, toco, grama alta) tem borda reta de propósito e fica fora da lista.
	var objetos := {"arbusto": Vector2i(2, 1), "pinheiro": Vector2i(1, 2),
		"arvore_outono": Vector2i(2, 2), "caixa": Vector2i(2, 6)}
	var descentrados : Array[String] = []
	var cortados     : Array[String] = []
	for nome in objetos:
		var co : Vector2i = objetos[nome]
		var m := _medir_objeto(img, co.x, co.y)
		if m.is_empty():
			continue
		if absf(float(m["centro_x"]) - (T / 2.0)) > 12.0:
			descentrados.append("%s (centro em x=%d)" % [nome, m["centro_x"]])
		if bool(m["borda_reta"]):
			cortados.append("%s (%d linhas na mesma coluna)" % [nome, m["repeticoes"]])
	_assert(descentrados.is_empty(), "todo tile de objeto está centralizado no quadro — %s" % (
		"ok" if descentrados.is_empty() else str(descentrados)))
	_assert(cortados.is_empty(), "nenhum tile de objeto tem borda reta de corte — %s" % (
		"ok" if cortados.is_empty() else str(cortados)))

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

## Mede o objeto de um tile: onde fica o centro dele e se alguma borda lateral é
## uma linha reta (assinatura de corte). Compara com a grama limpa do tile (0,0)
## em vez de olhar transparência, porque estes tiles são opacos — o objeto vem
## desenhado JÁ sobre grama, então "fundo" aqui significa "igual à grama".
func _medir_objeto(img: Image, c: int, r: int) -> Dictionary:
	var esq : Dictionary = {}
	var dir : Dictionary = {}
	var min_x := T
	var max_x := -1
	var linhas := 0
	for y in T:
		var a := -1
		var b := -1
		for x in T:
			var p := img.get_pixel(c * T + x, r * T + y)
			var g := img.get_pixel(x, y)   # mesma posição no tile de grama limpa
			var d := absf(p.r - g.r) + absf(p.g - g.g) + absf(p.b - g.b)
			if d > 0.21:
				if a < 0:
					a = x
				b = x
		if a < 0:
			continue
		linhas += 1
		min_x = mini(min_x, a)
		max_x = maxi(max_x, b)
		esq[a] = int(esq.get(a, 0)) + 1
		dir[b] = int(dir.get(b, 0)) + 1
	if linhas < 10:
		return {}
	var pico := 0
	for k in esq:
		pico = maxi(pico, int(esq[k]))
	for k in dir:
		pico = maxi(pico, int(dir[k]))
	return {
		"centro_x": int((min_x + max_x) / 2.0),
		"repeticoes": pico,
		# metade das linhas do objeto começando/terminando na MESMA coluna é
		# corte reto; silhueta de árvore nunca faz isso
		"borda_reta": pico > int(linhas * 0.5),
	}

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
