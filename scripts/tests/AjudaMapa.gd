## AjudaMapa.gd — Perguntas semânticas sobre o mapa, para os testes (Fase 0, 05/09).
##
## Por que existe: 51 asserções espalhadas por 13 arquivos comparavam COORDENADA
## LITERAL — `tiles[10][26] == "I"`, com o comentário "Pewter: interior do
## Ginásio (col 26, row 10) é piso". A intenção era "Pewter tem um ginásio com
## interior andável"; a coordenada era acidente. Enquanto ela ficar escrita no
## teste, mover uma cidade um tile pra esquerda reprova o mapa inteiro, e a
## suíte deixa de proteger pra passar a atrapalhar.
##
## Isto é a Fase 0 do plano de mundo: trocar as 51 coordenadas por perguntas que
## sobrevivem a qualquer mudança de terreno. A posição passa a ter UMA fonte —
## o retângulo da zona em `zones.json` — em vez de 51 cópias.
##
## Não é frouxidão de teste: `conta_char(rect, ["I"]) > 20` reprova exatamente
## os mesmos defeitos que `tiles[10][26] == "I"` reprovava (ginásio sumiu,
## interior virou parede, cidade não foi pintada), e mais alguns que a
## comparação literal deixava passar — como o prédio existir no lugar certo mas
## sem porta nenhuma.
class_name AjudaMapa
extends RefCounted

const CAMINHO_ZONAS := "res://data/world/zones.json"

static var _zonas : Dictionary = {}

## Retângulo de uma zona, lido do zones.json. É a ÚNICA fonte de posição que os
## testes usam agora — mover a cidade é editar aqui, e todo teste segue junto.
static func retangulo_da_zona(zone_id: String) -> Rect2i:
	if _zonas.is_empty():
		var texto := FileAccess.get_file_as_string(CAMINHO_ZONAS)
		var dados = JSON.parse_string(texto)
		if dados is Dictionary:
			for z in dados.get("zones", []):
				_zonas[str(z.get("id", ""))] = z
	var zona : Dictionary = _zonas.get(zone_id, {})
	var ret : Dictionary = zona.get("tile_rect", {})
	if ret.is_empty():
		return Rect2i(0, 0, 0, 0)
	return Rect2i(int(ret["x"]), int(ret["y"]), int(ret["w"]), int(ret["h"]))

## Quantos tiles de `chars` existem dentro do retângulo.
static func conta_char(tiles: Array, rect: Rect2i, chars: Array) -> int:
	var total := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, tiles.size())):
		var linha : String = tiles[y]
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, linha.length())):
			if linha[x] in chars:
				total += 1
	return total

## A zona tem um prédio completo? Um prédio de verdade tem as três partes:
## telhado, interior andável e porta. Testar só o interior deixava passar um
## prédio sem entrada — defeito que já aconteceu neste projeto.
static func tem_predio_completo(tiles: Array, rect: Rect2i) -> bool:
	return (conta_char(tiles, rect, ["H"]) > 0
		and conta_char(tiles, rect, ["I"]) > 0
		and tem_porta(tiles, rect))

## Quantos prédios distintos (regiões conectadas de piso interno) há na zona.
static func conta_predios(tiles: Array, rect: Rect2i) -> int:
	var interiores := {}
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, tiles.size())):
		var linha : String = tiles[y]
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, linha.length())):
			if linha[x] == "I":
				interiores[Vector2i(x, y)] = true
	var vistos := {}
	var grupos := 0
	for celula in interiores:
		if vistos.has(celula):
			continue
		grupos += 1
		var fila : Array[Vector2i] = [celula]
		vistos[celula] = true
		while not fila.is_empty():
			var atual : Vector2i = fila.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v : Vector2i = atual + d
				if interiores.has(v) and not vistos.has(v):
					vistos[v] = true
					fila.append(v)
	return grupos

## O mapa tem DUAS formas de entrada, e as duas são válidas — achado ao
## converter este teste: as casas de Pallet e os prédios de Cinnabar usam o char
## de CAMINHO no meio da fileira de parede ("wwwPPPwww"), enquanto os ginásios
## de Pewter e Cerulean usam o char de porta. Um ajudante que só conhecesse uma
## delas reprovaria metade dos prédios do jogo.
static func tem_porta(tiles: Array, rect: Rect2i) -> bool:
	var y0 : int = maxi(rect.position.y, 0)
	var y1 : int = mini(rect.position.y + rect.size.y, tiles.size())
	for y in range(y0, y1):
		var linha : String = tiles[y]
		var x0 : int = maxi(rect.position.x, 0)
		var x1 : int = mini(rect.position.x + rect.size.x, linha.length())
		for x in range(x0, x1):
			if MapLayouts.e_porta(linha[x]):
				return true
			# vão de entrada: tile de caminho com PAREDE dos dois lados
			if linha[x] == "P" and x > 0 and x + 1 < linha.length():
				var esq := linha[x - 1]
				var dir := linha[x + 1]
				if MapLayouts.e_parede(esq) or MapLayouts.e_parede(dir):
					# confere que é mesmo uma fileira de parede, não uma estrada
					if _linha_e_parede(linha, x0, x1):
						return true
	return false

## A linha é predominantemente parede? Distingue o vão de entrada (parede com
## um furo) de uma estrada que por acaso passa ao lado de um prédio.
static func _linha_e_parede(linha: String, x0: int, x1: int) -> bool:
	var paredes := 0
	var total := 0
	for x in range(x0, x1):
		total += 1
		if MapLayouts.e_parede(linha[x]):
			paredes += 1
	return total > 0 and float(paredes) / float(total) > 0.25

## Existe uma faixa contínua do char em toda a largura pedida, nesta linha?
## Serve pras estradas: o que importa é que a estrada ATRAVESSA, não em que
## coluna exata ela começa.
static func faixa_continua(tiles: Array, linha_idx: int, x0: int, x1: int, chars: Array) -> bool:
	if linha_idx < 0 or linha_idx >= tiles.size():
		return false
	var linha : String = tiles[linha_idx]
	for x in range(maxi(x0, 0), mini(x1, linha.length())):
		if not (linha[x] in chars):
			return false
	return true

## A estrada atravessa a zona de um lado a outro, em ALGUMA linha? Não importa
## qual — importa que dá pra passar.
static func atravessa_na_horizontal(tiles: Array, rect: Rect2i, chars: Array) -> bool:
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, tiles.size())):
		if faixa_continua(tiles, y, rect.position.x, rect.position.x + rect.size.x, chars):
			return true
	return false

## Maior trecho contínuo de `chars` numa coluna da zona. Melhor que exigir
## borda a borda: a estrada de Pallet termina na praia, e uma travessia
## "completa" seria falsa — mas uma corrida de 30 linhas prova que a estrada
## atravessa a cidade.
static func maior_corrida_vertical(tiles: Array, rect: Rect2i, chars: Array) -> int:
	var melhor := 0
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		var atual := 0
		for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, tiles.size())):
			var linha : String = tiles[y]
			if x < linha.length() and linha[x] in chars:
				atual += 1
				melhor = maxi(melhor, atual)
			else:
				atual = 0
	return melhor

static func atravessa_na_vertical(tiles: Array, rect: Rect2i, chars: Array) -> bool:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		var inteira := true
		for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, tiles.size())):
			var linha : String = tiles[y]
			if x >= linha.length() or not (linha[x] in chars):
				inteira = false
				break
		if inteira:
			return true
	return false

## ── A rede de segurança das Fases 3 a 5 ────────────────────────────────────
## Dá pra ir a pé de um tile até o outro? Busca em largura pelo mapa pintado,
## respeitando exatamente a mesma regra de colisão do jogo (`blocked` no
## TileSet), com um teto de células visitadas pra não varrer o mundo inteiro
## quando o destino é inalcançável.
##
## É esta função que impede o pior acidente possível ao reorganizar o mapa: uma
## cidade ficar ilhada e ninguém notar até um jogador tentar chegar nela.
static func caminho_a_pe(tm: TileMap, de: Vector2i, para: Vector2i, teto: int = 400000) -> bool:
	if de == para:
		return true
	var fila : Array[Vector2i] = [de]
	var vistos := {de: true}
	var contados := 0
	while not fila.is_empty() and contados < teto:
		var atual : Vector2i = fila.pop_front()
		contados += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v : Vector2i = atual + d
			if vistos.has(v):
				continue
			if v == para:
				return true
			if tm.get_cell_source_id(0, v) == -1:
				continue
			var td : TileData = tm.get_cell_tile_data(0, v)
			if td == null or td.get_custom_data("blocked"):
				continue
			vistos[v] = true
			fila.append(v)
	return false

## Um tile andável dentro da zona, ou (-9999,-9999) se a zona não tiver nenhum.
## Usado como ponto de partida/chegada do teste de conectividade — não adianta
## perguntar "dá pra chegar em Pewter" apontando pra dentro de uma parede.
static func tile_andavel_da_zona(tm: TileMap, rect: Rect2i) -> Vector2i:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var c := Vector2i(x, y)
			if tm.get_cell_source_id(0, c) == -1:
				continue
			var td : TileData = tm.get_cell_tile_data(0, c)
			if td != null and not td.get_custom_data("blocked"):
				return c
	return Vector2i(-9999, -9999)
