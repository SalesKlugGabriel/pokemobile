## teste_covis_lendarios.gd — Os três covis dos pássaros lendários (05/09).
##
## Pedido do Gabriel: cada lendário atrás de um minigame próprio, "incrivelmente
## difíceis de alcançar".
##
## Este arquivo existe porque "difícil" e "quebrado" são indistinguíveis de
## fora. Um andar de gelo mal sorteado simplesmente não tem saída — e o jogador
## só descobre isso depois de subir catorze andares. As conferências abaixo são,
## em ordem de importância:
##
##   1. TEM SOLUÇÃO. Todos os 31 andares. Sem exceção.
##   2. É DIFÍCIL. O caminho mais curto exige um mínimo de jogadas certas —
##      senão o covil é comprido, não difícil.
##   3. O JOGO DESLIZA IGUAL AO GERADOR. Se `EfeitosDeTerreno` escorregar
##      diferente de `CovisLendarios`, o andar provado deixa de ter solução na
##      prática. É o risco mais sério desta peça, e por isso as duas funções são
##      comparadas diretamente.
##   4. A CORRENTE DE WARPS FECHA. Dá pra ir da entrada até o ninho e voltar.
##   5. O LENDÁRIO CABE NO NINHO.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_covis_lendarios.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

const DIRECOES : Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

func _initialize() -> void:
	print("=== Teste: covis dos lendários (05/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_testar_gelo()
	_testar_cratera()
	_testar_usina()
	_testar_deslize_concorda()
	_testar_corrente_de_cenas()
	_testar_ninhos()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
func _grade(map_id: String) -> Array:
	var layout := MapLayouts.get_layout(map_id)
	var grade : Array = []
	for linha in layout.get("tiles", []):
		var l : Array = []
		for ch in str(linha):
			l.append(ch)
		grade.append(l)
	return grade

func _testar_gelo() -> void:
	var sem_solucao : Array[String] = []
	var faceis : Array[String] = []
	var entrada := Vector2i(CovisLendarios.GELO_L / 2, CovisLendarios.GELO_A - 2)
	var saida := Vector2i(CovisLendarios.GELO_L / 2, 1)
	for n in range(1, 11):
		var grade := _grade("ilha_gelida_f%d" % n)
		var custo : int = CovisLendarios._gelo_custo(grade, entrada, saida)
		if custo < 0:
			sem_solucao.append("F%d" % n)
		elif custo < 4 + n:
			faceis.append("F%d (%d deslizes, mínimo %d)" % [n, custo, 4 + n])
	_assert(sem_solucao.is_empty(),
		"os 10 andares de gelo TÊM saída — %s" % ("ok" if sem_solucao.is_empty() else str(sem_solucao)))
	_assert(faceis.is_empty(),
		"e nenhum é fácil demais (mínimo de deslizes por andar) — %s" % (
			"ok" if faceis.is_empty() else str(faceis)))

	# a caverna de descida: aqui não há deslize, é caminhada — mas tem que
	# existir caminho, senão o ninho fica inalcançável
	var presos : Array[String] = []
	for n in range(1, 6):
		var grade := _grade("ilha_gelida_b%d" % n)
		if not _tem_caminho_a_pe(grade, entrada, saida, ['"']):
			presos.append("B%d" % n)
	_assert(presos.is_empty(),
		"os 5 andares de caverna gélida são atravessáveis a pé — %s" % (
			"ok" if presos.is_empty() else str(presos)))

func _testar_cratera() -> void:
	var presos : Array[String] = []
	var curtos : Array[String] = []
	var entrada := Vector2i(CovisLendarios.LAVA_L / 2, 1)
	var saida := Vector2i(CovisLendarios.LAVA_L / 2, CovisLendarios.LAVA_A - 2)
	for n in range(1, 11):
		var grade := _grade("cratera_b%d" % n)
		if not _tem_caminho_a_pe(grade, entrada, saida, ["c"]):
			presos.append("B%d" % n)
		else:
			var passos := _passos_a_pe(grade, entrada, saida, ["c"])
			if passos < 16:
				curtos.append("B%d (%d passos)" % [n, passos])
	_assert(presos.is_empty(),
		"os 10 andares da cratera têm caminho até a escada — %s" % (
			"ok" if presos.is_empty() else str(presos)))
	_assert(curtos.is_empty(),
		"e nenhum é um corredor curto (o piso desmorona: o caminho tem que valer a pena) — %s" % (
			"ok" if curtos.is_empty() else str(curtos)))

func _testar_usina() -> void:
	var presos : Array[String] = []
	var sem_portao : Array[String] = []
	var entrada := Vector2i(CovisLendarios.USINA_L / 2, CovisLendarios.USINA_A - 2)
	var saida := Vector2i(CovisLendarios.USINA_L / 2, 1)
	for n in range(1, 7):
		var grade := _grade("usina_s%d" % n)
		# com os portões ABERTOS (a alavanca puxada) tem que dar pra passar
		if not _tem_caminho_a_pe(grade, entrada, saida, ["w"]):
			presos.append("S%d" % n)
		var portoes := 0
		for linha in grade:
			for ch in linha:
				if str(ch) == "[":
					portoes += 1
		if portoes == 0:
			sem_portao.append("S%d" % n)
	_assert(presos.is_empty(),
		"os 6 setores da usina são atravessáveis com os portões abertos — %s" % (
			"ok" if presos.is_empty() else str(presos)))
	_assert(sem_portao.is_empty(),
		"e todo setor tem portão de verdade (senão não é labirinto de portões) — %s" % (
			"ok" if sem_portao.is_empty() else str(sem_portao)))

## O RISCO MAIS SÉRIO desta peça.
##
## O gerador prova a solução usando a SUA ideia de deslize; o jogo escorrega
## usando a de `EfeitosDeTerreno`. Se as duas discordarem num único caso, o
## andar provado como solucionável deixa de ser — e o jogador fica trancado
## dentro de um quebra-cabeça sem saída, quinze andares dentro do covil.
func _testar_deslize_concorda() -> void:
	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = ts
	var grade := _grade("ilha_gelida_f5")
	for y in grade.size():
		for x in (grade[y] as Array).size():
			var ch : String = str(grade[y][x])
			if MapLayouts.CHAR_MAP.has(ch):
				tm.set_cell(0, Vector2i(x, y), 0, MapLayouts.CHAR_MAP[ch])

	var divergencias : Array[String] = []
	var testados := 0
	for y in range(1, grade.size() - 1):
		for x in range(1, (grade[y] as Array).size() - 1):
			if str(grade[y][x]) != ",":
				continue
			for d in DIRECOES:
				testados += 1
				var do_gerador : Vector2i = CovisLendarios._deslizar(grade, Vector2i(x, y), d)
				var do_jogo : Vector2i = EfeitosDeTerreno.destino_do_deslize(tm, Vector2i(x, y), d)
				if do_gerador != do_jogo:
					divergencias.append("de %s indo %s: gerador %s, jogo %s" % [
						Vector2i(x, y), d, do_gerador, do_jogo])
			if divergencias.size() > 3:
				break
	_assert(testados > 500, "o deslize foi comparado em muitos pontos (%d)" % testados)
	_assert(divergencias.is_empty(),
		"o jogo desliza EXATAMENTE como o gerador provou — %s" % (
			"ok" if divergencias.is_empty() else str(divergencias.slice(0, 3))))
	tm.free()

func _testar_corrente_de_cenas() -> void:
	var faltando : Array[String] = []
	var todas : Array[String] = []
	for i in range(1, 11):
		todas.append("IlhaGelida_F%d" % i)
	for i in range(1, 6):
		todas.append("IlhaGelida_B%d" % i)
	for i in range(1, 11):
		todas.append("Cratera_B%d" % i)
	for i in range(1, 7):
		todas.append("Usina_S%d" % i)
	for nome in todas:
		var caminho := "res://scenes/world/dungeons/%s.tscn" % nome
		if not ResourceLoader.exists(caminho):
			faltando.append(nome)
	var resumo_faltando : String = "ok" if faltando.is_empty() else str(faltando)
	_assert(faltando.is_empty(),
		"as %d cenas de andar existem — %s" % [todas.size(), resumo_faltando])

	# a corrente fecha: cada andar aponta pro seguinte, e o texto do warp bate
	var quebradas : Array[String] = []
	for i in range(1, 15):
		var atual : String = ("IlhaGelida_F%d" % i) if i <= 10 else ("IlhaGelida_B%d" % (i - 10))
		var seguinte : String = ("IlhaGelida_F%d" % (i + 1)) if (i + 1) <= 10 else ("IlhaGelida_B%d" % (i + 1 - 10))
		var texto := FileAccess.get_file_as_string("res://scenes/world/dungeons/%s.tscn" % atual)
		if not texto.contains(seguinte + ".tscn"):
			quebradas.append("%s não leva a %s" % [atual, seguinte])
	_assert(quebradas.is_empty(),
		"a corrente da Ilha Gélida vai do 1º andar até o ninho — %s" % (
			"ok" if quebradas.is_empty() else str(quebradas)))

	# e o mundo tem a entrada
	var mundo := FileAccess.get_file_as_string("res://scenes/world/maps/WorldMap.tscn")
	_assert(mundo.contains("IlhaGelida_F1.tscn"),
		"o mapa do mundo tem a boca da montanha que leva ao covil")

	# ── E QUEM SAI DO COVIL CAI EM CHÃO FIRME ──────────────────────────────
	# 🔴 Achado ao conferir: a coordenada de volta era um chute, e caiu dentro
	# de um bloco de gelo — quem saísse do covil apareceria entalado numa
	# parede. Nenhum teste de layout pegaria isso: o mapa está certo, quem
	# estava errada era a coordenada de destino do warp. Esta conferência vale
	# pra TODA saída de covil que apontar pro mapa do mundo.
	var tm_mundo := TileMap.new()
	tm_mundo.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
	MapLayouts.paint(tm_mundo, "world_map")
	var ruins : Array[String] = []
	for nome in ["IlhaGelida_F1", "Usina_S1"]:
		var texto := FileAccess.get_file_as_string("res://scenes/world/dungeons/%s.tscn" % nome)
		var i := texto.find("WorldMap.tscn")
		if i < 0:
			continue
		var trecho := texto.substr(i, 120)
		var j := trecho.find("Vector2i(")
		if j < 0:
			continue
		var dentro := trecho.substr(j + 9, trecho.find(")", j) - j - 9)
		var partes := dentro.split(",")
		var alvo := Vector2i(int(partes[0].strip_edges()), int(partes[1].strip_edges()))
		var td : TileData = tm_mundo.get_cell_tile_data(0, alvo)
		if td == null or td.get_custom_data("blocked"):
			ruins.append("%s volta pra %s, que é parede" % [nome, alvo])
	_assert(ruins.is_empty(), "sair de um covil devolve o jogador em chão andável — %s" % (
		"ok" if ruins.is_empty() else str(ruins)))
	tm_mundo.free()

func _testar_ninhos() -> void:
	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	for map_id in CovisLendarios.NINHOS:
		var dados : Dictionary = CovisLendarios.NINHOS[map_id]
		var tm := TileMap.new()
		tm.tile_set = ts
		MapLayouts.paint(tm, str(map_id))
		var onde := CovisLendarios.centro_andavel(tm)
		_assert(onde.x != -9999,
			"%s tem chão livre pro %s nascer (%s)" % [map_id, dados["nome"], onde])
		tm.free()
		# e o ninho não tem selvagem comum, pra ninguém roubar a cena
		var zona := _zona(str(map_id))
		_assert((zona.get("wild_pokemon", []) as Array).is_empty(),
			"o ninho de %s não tem Pokémon comum (o encontro é só dele)" % dados["nome"])

func _zona(id: String) -> Dictionary:
	var dados = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/world/zones.json"))
	for z in dados.get("zones", []):
		if str(z.get("id", "")) == id:
			return z
	return {}

# ──────────────────────────────────────────────────────────────────────────────
func _tem_caminho_a_pe(grade: Array, de: Vector2i, para: Vector2i, bloqueiam: Array) -> bool:
	return _passos_a_pe(grade, de, para, bloqueiam) >= 0

func _passos_a_pe(grade: Array, de: Vector2i, para: Vector2i, bloqueiam: Array) -> int:
	var fila : Array = [[de, 0]]
	var vistos := {de: true}
	while not fila.is_empty():
		var item : Array = fila.pop_front()
		var atual : Vector2i = item[0]
		if atual == para:
			return int(item[1])
		for d in DIRECOES:
			var n : Vector2i = atual + d
			if n.y < 0 or n.y >= grade.size():
				continue
			var linha : Array = grade[n.y]
			if n.x < 0 or n.x >= linha.size():
				continue
			if str(linha[n.x]) in bloqueiam or vistos.has(n):
				continue
			vistos[n] = true
			fila.append([n, int(item[1]) + 1])
	return -1

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
