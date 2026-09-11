## teste_fundo_do_mar.gd — 11/09/2026. O bioma submarino.
##
## Pedido do Gabriel, e cada peça dele tem uma seção aqui:
##
##   *"usando surf, terão áreas do oceano em que o player pode ir surfando e
##   quando chegar nessas áreas ele pode usar um comando para mergulhar, e
##   quando mergulhar terá uma barra de oxigenio e velocidade reduzida, ali
##   será um bioma 100% submarino com algas, corais, profundidades diferentes
##   e pokemons como tentacruel, gyarados, kingler, poliwhrath, etc e um NPC
##   irá entregar uma quest para conseguir roupa de mergulho que devolve a
##   velocidade do player e permite respirar no fundo do mar"*
##
## O que este arquivo defende, acima de tudo: **o fundo do mar não pode virar
## uma armadilha**. Um mapa bonito onde o jogador entra e não consegue voltar é
## pior que mapa nenhum.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node

func _initialize() -> void:
	print("=== Teste: fundo do mar (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")

	_o_mapa()
	_da_pra_voltar()
	_oxigenio()
	_velocidade()
	_profundidades_e_fauna()
	_a_quest_e_a_roupa()
	_o_contrato_com_a_hud()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# O mapa
# ──────────────────────────────────────────────────────────────────────────
func _o_mapa() -> void:
	var l : Dictionary = MapLayouts.get_layout("fundo_do_mar")
	_assert(not l.is_empty(), "o mapa do fundo do mar existe")
	var t : Array = l.get("tiles", [])
	_assert(int(l.get("width", 0)) == MapLayouts.MAR_L
		and int(l.get("height", 0)) == MapLayouts.MAR_A,
		"gera %dx%d" % [MapLayouts.MAR_L, MapLayouts.MAR_A])

	var conta := {}
	for r in t:
		var linha := String(r)
		for c in linha.length():
			conta[linha[c]] = int(conta.get(linha[c], 0)) + 1

	# "100% submarino": nada de grama, areia de praia ou árvore aqui.
	for proibido in [".", "T", "N", "O", "K", "P", "S", "F"]:
		_assert(not conta.has(proibido),
			"o fundo do mar não tem '%s' (é 100%% submarino, não praia)" % proibido)

	# As três profundidades aparecem de verdade.
	for ch in ["≡", "φ", "≈"]:
		_assert(int(conta.get(ch, 0)) > 500,
			"a profundidade '%s' cobre área de verdade (%d tiles)" % [ch, int(conta.get(ch, 0))])
	# E o que vive nelas.
	for ch in ["ψ", "α", "Ω"]:
		_assert(int(conta.get(ch, 0)) > 100, "'%s' existe no mapa (%d)" % [ch, int(conta.get(ch, 0))])
	_assert(int(conta.get("°", 0)) == MapLayouts.MAR_RESPIRADOUROS.size(),
		"os %d respiradouros estão no mapa" % MapLayouts.MAR_RESPIRADOUROS.size())

	# 🔴 O alfabeto do gerador tinha ACABADO (92 de 94 chars ASCII usados). Estes
	# são Unicode — e o teste prova que Godot os indexa por caractere.
	var linha_teste := String(t[MapLayouts.MAR_A / 2])
	_assert(linha_teste.length() == MapLayouts.MAR_L,
		"a linha tem %d CARACTERES, não bytes (Unicode indexado certo)" % MapLayouts.MAR_L)

# ──────────────────────────────────────────────────────────────────────────
# Dá pra voltar? (a pergunta que mais importa)
# ──────────────────────────────────────────────────────────────────────────
func _da_pra_voltar() -> void:
	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tm, "fundo_do_mar")
	var entrada := Vector2i(60, 8)

	_assert(AjudaMapa.caminho_a_pe(tm, entrada, Vector2i(60, 200), 400000),
		"da entrada dá pra chegar ao abismo a pé")
	var isolados : Array[String] = []
	for p in MapLayouts.MAR_RESPIRADOUROS:
		if not AjudaMapa.caminho_a_pe(tm, entrada, p, 400000):
			isolados.append(str(p))
	_assert(isolados.is_empty(),
		"TODOS os respiradouros são alcançáveis (%s) — um respiradouro emparedado é uma promessa quebrada" % str(isolados))
	tm.free()

	# A cena existe e tem a saída pra superfície.
	var cena : PackedScene = load("res://scenes/world/maps/FundoDoMar.tscn")
	_assert(cena != null, "FundoDoMar.tscn carrega")
	if cena:
		var inst = cena.instantiate()
		var subir = inst.get_node_or_null("WarpZones/Subir")
		_assert(subir != null, "existe a saída 'Subir'")
		if subir:
			_assert(str(subir.target_map).ends_with("WorldMap.tscn"),
				"e ela leva de volta ao mapa-múndi")
		_assert(inst.get_node_or_null("SpawnManager") != null, "tem spawn de fauna")
		_assert(inst.get_node_or_null("ZoneManager") != null,
			"tem ZoneManager — é ele que diz a profundidade")
		inst.queue_free()

# ──────────────────────────────────────────────────────────────────────────
# O oxigênio
# ──────────────────────────────────────────────────────────────────────────
func _oxigenio() -> void:
	var cheio := Mergulho.OXIGENIO_MAXIMO
	_assert(cheio > 30.0, "o fôlego dura %ds — tempo de atravessar e voltar" % int(cheio))

	# Mais fundo gasta mais. É o que faz profundidade ser decisão, não caminho.
	var raso := Mergulho.consumo_por_segundo(Mergulho.RASO, false)
	var meio := Mergulho.consumo_por_segundo(Mergulho.MEIO, false)
	var fundo := Mergulho.consumo_por_segundo(Mergulho.ABISSO, false)
	_assert(raso < meio and meio < fundo,
		"quanto mais fundo, mais ar (%.1f < %.1f < %.1f por segundo)" % [raso, meio, fundo])

	# A roupa resolve o fôlego por completo.
	_assert(Mergulho.consumo_por_segundo(Mergulho.ABISSO, true) == 0.0,
		"com a roupa, o ar não acaba nem no abismo")
	_assert(Mergulho.segundos_restantes(cheio, Mergulho.ABISSO, true) < 0.0,
		"e o tempo restante vira 'pra sempre'")

	# Sem a roupa, o abismo é curto de propósito.
	var s := Mergulho.segundos_restantes(cheio, Mergulho.ABISSO, false)
	_assert(s > 10.0 and s < 60.0,
		"sem roupa, o abismo dá %ds — dá pra entrar e sair, não pra morar" % int(s))

	# Consumir e recuperar.
	var o := Mergulho.consumir(cheio, 10.0, Mergulho.ABISSO, false)
	_assert(o < cheio, "mergulhar gasta ar (%.0f -> %.0f)" % [cheio, o])
	_assert(Mergulho.recuperar(o, 100.0) == cheio, "na superfície o fôlego volta, e não passa do máximo")
	_assert(Mergulho.consumir(0.0, 10.0, Mergulho.ABISSO, false) == 0.0, "o ar nunca fica negativo")

	_assert(Mergulho.afogou(0.0), "zero de ar é afogamento")
	_assert(not Mergulho.afogou(1.0), "1 de ar ainda não é")
	_assert(Mergulho.em_alerta(cheio * 0.2, false), "o jogo avisa antes de acabar")
	_assert(not Mergulho.em_alerta(cheio * 0.2, true), "...mas nunca com a roupa vestida")

	# Afogar não pode custar a partida.
	_assert(Mergulho.DANO_AO_AFOGAR < 1.0,
		"ficar sem ar machuca (%.0f%%) mas não desmaia o time" % (Mergulho.DANO_AO_AFOGAR * 100.0))
	var fonte := FileAccess.get_file_as_string("res://scripts/autoloads/SaveManager.gd")
	_assert(fonte.contains("func machucar_time("), "existe a função que machuca sem matar")
	_assert(fonte.contains("maxi(1, atual - int(round(maximo * fracao)))"),
		"e ela tem piso em 1 — afogar nunca desmaia ninguém")

# ──────────────────────────────────────────────────────────────────────────
# A velocidade
# ──────────────────────────────────────────────────────────────────────────
func _velocidade() -> void:
	_assert(Mergulho.fator_de_velocidade(false) > 1.0,
		"sem a roupa, o mergulho é %.1fx mais lento" % Mergulho.fator_de_velocidade(false))
	_assert(Mergulho.fator_de_velocidade(true) == 1.0,
		"a roupa DEVOLVE a velocidade normal — foi o pedido, literal")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(fonte.contains("Mergulho.fator_de_velocidade(tem_roupa_de_mergulho())"),
		"e o jogador usa isso de verdade na conta de velocidade")
	_assert(fonte.contains("func esta_submerso()"),
		"estar submerso é DERIVADO do mapa, não de um botão (não dessincroniza)")
	_assert(fonte.contains("func mergulhar()"), "existe o comando de mergulhar")
	_assert(InputMap.has_action("mergulhar"), "e a ação de entrada existe")
	_assert("mergulhar" in KeybindManager.REBINDABLE_ACTIONS,
		"...e é remapeável, como todo atalho do jogo")

# ──────────────────────────────────────────────────────────────────────────
# Profundidades e quem mora nelas
# ──────────────────────────────────────────────────────────────────────────
func _profundidades_e_fauna() -> void:
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var faixas := {}
	for z in zj.get("zones", []):
		if str(z.get("map_id", "")) == "fundo_do_mar":
			faixas[str(z.get("id", ""))] = z

	print("\n-- As três profundidades --")
	for id in ["mar_raso", "mar_algas", "mar_abisso"]:
		_assert(faixas.has(id), "a faixa '%s' existe em zones.json" % id)
		if not faixas.has(id):
			continue
		var especies : Array = []
		var nivel_max : int = 0
		for w in faixas[id].get("wild_pokemon", []):
			especies.append(str(w.get("name", "?")))
			nivel_max = maxi(nivel_max, int(w.get("level_max", 0)))
		print("  %-12s até Lv.%d · %s" % [id, nivel_max, ", ".join(especies)])
		_assert(especies.size() >= 4, "%s tem fauna de verdade (%d espécies)" % [id, especies.size()])

	# Quanto mais fundo, melhor o que mora lá — é o que paga o risco.
	var teto := {}
	for id in ["mar_raso", "mar_algas", "mar_abisso"]:
		var m : int = 0
		for w in faixas.get(id, {}).get("wild_pokemon", []):
			m = maxi(m, int(w.get("level_max", 0)))
		teto[id] = m
	_assert(int(teto["mar_raso"]) < int(teto["mar_algas"])
		and int(teto["mar_algas"]) < int(teto["mar_abisso"]),
		"o nível sobe com a profundidade (%d < %d < %d) — descer tem que pagar"
			% [int(teto["mar_raso"]), int(teto["mar_algas"]), int(teto["mar_abisso"])])

	# Os que o Gabriel citou por nome estão lá.
	var todos : Array[String] = []
	for id in faixas:
		for w in faixas[id].get("wild_pokemon", []):
			todos.append(str(w.get("name", "")))
	for nome in ["Tentacruel", "Gyarados", "Kingler", "Poliwrath"]:
		_assert(nome in todos, "%s mora no fundo do mar (foi citado por nome)" % nome)

	# E nada de bicho de terra aqui.
	var terrestres := ["Rattata", "Pidgey", "Geodude", "Charmander", "Caterpie"]
	for nome in terrestres:
		_assert(not (nome in todos), "%s NÃO aparece debaixo d'água" % nome)

# ──────────────────────────────────────────────────────────────────────────
# A quest e a roupa
# ──────────────────────────────────────────────────────────────────────────
func _a_quest_e_a_roupa() -> void:
	var item : Dictionary = GameData.get_item(Mergulho.ROUPA)
	_assert(not item.is_empty(), "a roupa de mergulho existe como item")
	_assert(str(item.get("category", "")) == "key",
		"é item-chave: não se vende, não se perde")

	# quests.json é um DICIONÁRIO por id (não uma lista) — conferido no arquivo,
	# não suposto. A primeira versão deste teste supôs lista e reprovou uma
	# quest que existia.
	var qj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/quests.json"))
	var mar : Dictionary = qj.get("MAR-01", {})
	_assert(not mar.is_empty(), "a quest MAR-01 existe")
	if mar.is_empty():
		return

	var entrega := false
	for r in mar.get("rewards", {}).get("items", []):
		if str(r.get("id", "")) == Mergulho.ROUPA:
			entrega = true
	_assert(entrega, "e ela ENTREGA a roupa (era o pedido: um NPC dá a quest da roupa)")
	_assert(not str(mar.get("npc_id", "")).is_empty(), "tem um NPC dono dela")

	# 🔴 A decisão de desenho que vale registrar: os objetivos acontecem todos
	# DEBAIXO D'ÁGUA. O jogador aprende a lutar contra o cronômetro antes de
	# ganhar o direito de ignorá-lo — senão a roupa chega antes da tensão que
	# ela existe pra aliviar.
	var submersos : int = 0
	for o in mar.get("objectives", []):
		var z := str(o.get("zone", ""))
		if z.begins_with("mar_") or z == "fundo_do_mar":
			submersos += 1
	_assert(submersos >= 2,
		"os objetivos acontecem no fundo do mar (%d deles) — a quest ensina a mecânica antes de aliviá-la" % submersos)

# ──────────────────────────────────────────────────────────────────────────
# O contrato com a HUD (a barra é do Codex)
# ──────────────────────────────────────────────────────────────────────────
func _o_contrato_com_a_hud() -> void:
	var barramento := FileAccess.get_file_as_string("res://scripts/autoloads/EventBus.gd")
	_assert(barramento.contains("signal oxigenio_mudou(atual: float, maximo: float)"),
		"existe o sinal que a barra de oxigênio vai escutar")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(fonte.contains("EventBus.oxigenio_mudou.emit("),
		"e o gameplay emite o estado (a UI nunca recalcula fôlego — AGENTS.md)")
	_assert(fonte.contains("if not is_equal_approx(antes, oxigenio):"),
		"só emite quando MUDA — sinal a cada quadro é o que trava HUD")

	# Mergulhar exige estar surfando e num ponto de mergulho.
	var r1 : Dictionary = Mergulho.pode_mergulhar("world_map", Vector2i(248, 196), false)
	_assert(not bool(r1["pode"]), "não dá pra mergulhar a pé")
	_assert(str(r1["motivo"]).contains("surfando"), "e o motivo explica isso em português")

	var r2 : Dictionary = Mergulho.pode_mergulhar("world_map", Vector2i(10, 10), true)
	_assert(not bool(r2["pode"]), "nem em água rasa qualquer")

	var r3 : Dictionary = Mergulho.pode_mergulhar("world_map", Vector2i(248, 196), true)
	_assert(bool(r3["pode"]), "surfando em cima do ponto, dá")
	_assert(not (r3["ponto"] as Dictionary).is_empty(), "e o ponto vem com destino e chegada")

	# Tolerância: o jogador não pode ter que caçar um pixel.
	var perto : Dictionary = Mergulho.pode_mergulhar("world_map", Vector2i(249, 197), true)
	_assert(bool(perto["pode"]), "um tile de folga ainda conta (ninguém caça pixel no mar)")

	_assert(Mergulho.PONTOS.get("world_map", []).size() >= 3,
		"há mais de um ponto de mergulho no mapa")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
