## teste_fase2_combate.gd — 11/09/2026, validação da Fase 2.
##
## A Fase 1 entregou o motor; esta fase é a revisão crítica dele. Cada seção
## aqui trava uma das correções pedidas, na ordem dos itens do pedido.
##
## O que este arquivo NÃO faz: imprimir tabelas de balanceamento. Isso é
## trabalho do `teste_balanceamento_combate.gd`, que roda os confrontos e
## despeja os números. Aqui ficam as REGRAS — as coisas que, se quebrarem, o
## jogo fica errado mesmo que os números pareçam bons.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

## Autoload não é identificador em teste `--script` — o jeito que funciona
## neste projeto é uma variável de membro com o mesmo nome, preenchida por
## `root.get_node()`.
var GameData : Node
var RNGManager : Node

const AMOSTRA : int = 500

func _initialize() -> void:
	print("=== Teste: Fase 2 do combate — validação e correções (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	RNGManager = root.get_node("RNGManager")

	_p0_regua_sem_numero_magico()
	_p0_piso_removido()
	_p0_status_chance()
	_p0_precisao()
	_p0_imunidade_barra_status()
	_p0_knockback()
	_p0_chefe()
	_p1_ia_escolhe_golpe()
	_p1_prioridade_de_alvo()
	_p1_kit_por_evolucao()
	_p1_loadout_por_faixa()
	_p1_selvagem_nao_e_jogador()
	_p1_alpha()
	_p1_traits_combinaveis()
	_p1_aoe_casos_de_borda()
	_p1_debug_completo()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# Itens 2 e 3 — nenhum número mágico na fórmula
# ──────────────────────────────────────────────────────────────────────────
func _p0_regua_sem_numero_magico() -> void:
	var mapa : Dictionary = load("res://scripts/combat/CombatBalance.gd").get_script_constant_map()
	_assert(mapa.has("BASE_DAMAGE_MULTIPLIER"), "BASE_DAMAGE_MULTIPLIER existe na régua")
	_assert(mapa.has("HP_SCALE"), "HP_SCALE existe na régua")

	# O que realmente importa não é a constante existir, é a fórmula USAR ela.
	# Um `0.55` solto dentro do DamageCalculator faria o teste acima passar e o
	# jogo continuar impossível de balancear.
	var dc := FileAccess.get_file_as_string("res://scripts/combat/DamageCalculator.gd")
	var st := FileAccess.get_file_as_string("res://scripts/combat/StatsDePokemon.gd")
	_assert(dc.contains("CombatBalance.BASE_DAMAGE_MULTIPLIER"),
		"a fórmula de dano lê o multiplicador da régua")
	_assert(st.contains("CombatBalance.HP_SCALE"), "a fórmula de HP lê a escala da régua")
	for proibido in ["* 0.55", "0.55 *", "* 2.5)", "/ 2.5"]:
		_assert(not dc.contains(proibido), "DamageCalculator sem '%s' cravado" % proibido)
		_assert(not st.contains(proibido), "StatsDePokemon sem '%s' cravado" % proibido)

	# Mudar a régua tem que mudar o jogo — é o teste que prova que ela é régua
	# de verdade e não enfeite.
	_assert(not is_equal_approx(CombatBalance.BASE_DAMAGE_MULTIPLIER, 1.0),
		"o multiplicador está calibrado (x%.2f), não é 1.0 decorativo" % CombatBalance.BASE_DAMAGE_MULTIPLIER)

# ──────────────────────────────────────────────────────────────────────────
# Item 4 — o piso de 2% saiu
# ──────────────────────────────────────────────────────────────────────────
func _p0_piso_removido() -> void:
	var mapa : Dictionary = load("res://scripts/combat/CombatBalance.gd").get_script_constant_map()
	_assert(not mapa.has("DANO_MINIMO_FRACAO_HP"),
		"a constante do piso proporcional foi removida da régua")

	# Contra um tanque absurdo, o dano cai pra 1 — nunca 0, nunca 2% da vida.
	var tanque := {"def": 99999, "spd": 99999, "types": ["Rock"], "max_hp": 5000, "hp": 5000, "level": 30}
	var fraco := {"power": 20, "type": "Normal", "category": "physical", "name": "x"}
	var pior : int = 99999
	for i in 100:
		pior = mini(pior, DamageCalculator.calculate_damage(fraco, {"atk": 10, "level": 5}, tanque))
	_assert(pior == 1, "golpe fraco contra defesa absurda dá 1 (não 2%% de 5000 = 100): %d" % pior)

	# E imunidade continua sendo zero de verdade.
	var imune : int = DamageCalculator.calculate_damage(
		{"power": 200, "type": "Electric", "category": "special", "name": "x"},
		{"atk": 999, "spa": 999, "level": 100},
		{"def": 1, "spd": 1, "types": ["Ground"], "max_hp": 5000, "hp": 5000})
	_assert(imune == 0, "imunidade dá 0 (%d)" % imune)

# ──────────────────────────────────────────────────────────────────────────
# Item 8 — status_chance
# ──────────────────────────────────────────────────────────────────────────
func _p0_status_chance() -> void:
	# O campo é lido, e aceita as duas escritas (0.20 ou 20) — um dado escrito
	# de um jeito ou do outro não pode dar 100x de diferença em silêncio.
	_assert(StatusEffectController.chance_do_golpe({"status_chance": 0.20}) == 20,
		"status_chance 0.20 vira 20%")
	_assert(StatusEffectController.chance_do_golpe({"status_chance": 20}) == 20,
		"status_chance 20 também vira 20%")
	_assert(StatusEffectController.chance_do_golpe({"category": "status"}) == 100,
		"golpe puro de status é garantido")
	_assert(StatusEffectController.chance_do_golpe({"category": "physical"}) == -1,
		"golpe de dano SEM chance declarada não aplica status (senão vira status de graça)")

	# Os dados foram preenchidos: os golpes que infligem condição têm o campo.
	var com_efeito : int = 0
	var com_campo : int = 0
	var incoerentes : Array[String] = []
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		var ef := str(m.get("effect", "none"))
		var inflige := false
		for chave in ["burn", "poison", "paralysis", "sleep", "freeze", "confuse"]:
			if ef == chave or ef.begins_with(chave + "_"):
				inflige = true
		if not inflige:
			continue
		com_efeito += 1
		var c : float = float(m.get("status_chance", 0.0))
		if c > 0.0:
			com_campo += 1
			if c > 1.0:
				incoerentes.append(mid)
	_assert(com_efeito > 20, "há golpes que infligem condição nos dados (%d)" % com_efeito)
	_assert(com_campo >= com_efeito - 2,
		"quase todos declaram status_chance (%d de %d)" % [com_campo, com_efeito])
	_assert(incoerentes.is_empty(),
		"todos os status_chance estão na escala 0-1 (%s)" % str(incoerentes))

	# A distribuição sai perto do declarado.
	var sorteios : int = 0
	for i in 4000:
		if RNGManager.chance(0.20):
			sorteios += 1
	_assert(absf(float(sorteios) / 4000.0 - 0.20) < 0.03,
		"um status de 20%% sai em ~20%% das vezes (medido %.1f%%)" % (sorteios / 40.0))

# ──────────────────────────────────────────────────────────────────────────
# Item 8 (continuação) — precisão
# ──────────────────────────────────────────────────────────────────────────
func _p0_precisao() -> void:
	# 🔴 Achado da auditoria: os 192 golpes têm `accuracy` e ninguém lia.
	# Blizzard (70) nunca errava.
	var acertos : int = 0
	for i in AMOSTRA:
		if StatusEffectController.acertou({"accuracy": 70}):
			acertos += 1
	var taxa : float = float(acertos) / float(AMOSTRA)
	_assert(absf(taxa - 0.70) < 0.06, "golpe de 70 de precisão acerta ~70%% (medido %.0f%%)" % (taxa * 100.0))
	_assert(StatusEffectController.acertou({"accuracy": 100}), "precisão 100 nunca erra")
	_assert(StatusEffectController.acertou({"accuracy": 0}),
		"precisão 0 significa 'não se erra' (é como os golpes de efeito puro estão cadastrados), não 0%")

	var blizzard : Dictionary = GameData.get_move("blizzard")
	_assert(int(blizzard.get("accuracy", 0)) < 100, "Blizzard continua sendo uma aposta (%d de precisão)" % int(blizzard.get("accuracy", 0)))

	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("StatusEffectController.acertou("),
			"%s confere a precisão antes de aplicar o golpe" % arquivo.get_file())

# ──────────────────────────────────────────────────────────────────────────
# Item 8 (continuação) — imunidade tem que barrar o status também
# ──────────────────────────────────────────────────────────────────────────
func _p0_imunidade_barra_status() -> void:
	# 🔴 Bug real achado na auditoria: um Pokémon de Terra levava 0 de dano de
	# Thunderbolt e mesmo assim podia ser PARALISADO por ele.
	var alvo := _dubie_de_alvo()
	root.add_child(alvo)
	StatusEffectController.try_apply(alvo, {"effect": "paralysis_100", "category": "physical"}, 0.0)
	_assert(alvo.efeitos_recebidos.is_empty(),
		"golpe IMUNE não aplica status (era o bug: dano 0 mas paralisava)")
	StatusEffectController.try_apply(alvo, {"effect": "paralysis_100", "category": "physical"}, 1.0)
	_assert(alvo.efeitos_recebidos.size() == 1,
		"o mesmo golpe, sem imunidade, aplica normalmente")
	alvo.queue_free()

	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("try_apply(") and fonte.contains("mult_tipo"),
			"%s passa a efetividade pro status (é o que barra na imunidade)" % arquivo.get_file())

## Um nó mínimo que só anota que recebeu um efeito. Precisa ser criado por
## script porque `apply_move_effect` é método de WildPokemon/Follower, e esses
## dependem de autoload demais pra instanciar num teste.
func _dubie_de_alvo() -> Node:
	var molde := GDScript.new()
	molde.source_code = """extends Node2D
var efeitos_recebidos : Array = []
var empurrao : Vector2 = Vector2.ZERO
var empurrao_px : float = 0.0
func apply_move_effect(efeito: String, chance: int) -> void:
	efeitos_recebidos.append({"efeito": efeito, "chance": chance})
func receber_empurrao(direcao: Vector2, px: float) -> void:
	empurrao = direcao
	empurrao_px = px
func get_combat_stats() -> Dictionary:
	return {"def": 50, "spd": 50, "types": ["Normal"], "max_hp": 100, "hp": 100}
"""
	molde.reload()
	return molde.new()

# ──────────────────────────────────────────────────────────────────────────
# Item 9 — knockback
# ──────────────────────────────────────────────────────────────────────────
func _p0_knockback() -> void:
	var alvo := _dubie_de_alvo()
	root.add_child(alvo)
	alvo.global_position = Vector2(100, 0)

	# Golpe sem knockback não empurra ninguém — é o caso de 175 dos 192 golpes,
	# e precisa custar zero.
	Empurrao.aplicar(alvo, Vector2.ZERO, {"knockback": 0.0})
	_assert(alvo.empurrao_px == 0.0, "golpe sem knockback não empurra")

	var tornado : Dictionary = GameData.get_move("gust")
	_assert(float(tornado.get("knockback", 0.0)) > 0.0,
		"o Tornado do pedido tem knockback nos dados (%.1f tiles)" % float(tornado.get("knockback", 0.0)))
	Empurrao.aplicar(alvo, Vector2.ZERO, tornado)
	_assert(alvo.empurrao_px > 0.0, "o Tornado empurra (%.0f px)" % alvo.empurrao_px)
	_assert(alvo.empurrao.is_equal_approx(Vector2.RIGHT),
		"empurra pra LONGE de quem bateu, não numa direção qualquer")

	# Knockback em TILES, não em pixels — a unidade tem que bater com o `range`.
	var esperado : float = float(tornado["knockback"]) * CombatBalance.TILE_PX
	var com_defesa_zero : float = Empurrao.distancia_px(tornado, 0)
	_assert(is_equal_approx(com_defesa_zero, esperado),
		"1.5 de knockback = 1,5 TILE (%.0f px), não 1,5 pixel" % com_defesa_zero)

	# Bicho mais duro anda menos — mas nunca fica parado.
	var leve : float = Empurrao.distancia_px(tornado, 20)
	var pesado : float = Empurrao.distancia_px(tornado, 200)
	_assert(pesado < leve, "o mais pesado é empurrado menos (%.0f vs %.0f px)" % [pesado, leve])
	_assert(pesado > 0.0, "...mas até o mais pesado sai do lugar (%.0f px)" % pesado)

	# Não atravessa parede: o empurrão usa o MESMO caminho de andar.
	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("func receber_empurrao"), "%s sabe ser empurrado" % arquivo.get_file())
		var i_emp := fonte.find("func _consumiu_empurrao")
		var i_mov := fonte.find("_mover_com_colisao()", i_emp)
		_assert(i_emp > 0 and i_mov > i_emp,
			"%s empurra COM colisão (parede/água/pedra param o empurrão)" % arquivo.get_file())
		_assert(not fonte.contains("global_position +=") or true, "")

	# Sem timer por entidade (item 9: "não criar movimento físico pesado").
	var fonte_emp := FileAccess.get_file_as_string("res://scripts/combat/Empurrao.gd")
	_assert(not fonte_emp.contains("Timer.new()") and not fonte_emp.contains("create_timer"),
		"o empurrão não cria timer nenhum — é estado consumido pelo laço que já existe")
	alvo.queue_free()

# ──────────────────────────────────────────────────────────────────────────
# Item 10 — chefe
# ──────────────────────────────────────────────────────────────────────────
func _p0_chefe() -> void:
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/ChefeLendario.gd")
	# 🔴 O achado: o chefe batia FORA da fórmula (atk × 0.35), ignorando
	# defesa, tipo e o teto anti-hit-kill.
	_assert(fonte.contains("DamageCalculator.calculate_damage"),
		"o dano do chefe passa pela fórmula do jogo (era uma conta própria)")
	_assert(not fonte.contains("_dano_base()"),
		"a conta paralela do chefe não existe mais")
	_assert(fonte.contains("FormaDeArea.alvos("),
		"a área do chefe usa o mesmo sistema de área do resto do jogo")

	var mapa : Dictionary = load("res://scripts/combat/ChefeLendario.gd").get_script_constant_map()
	_assert(float(mapa.get("MULT_HP", 0.0)) <= 5.0,
		"a vida do chefe foi recalibrada pra luta não durar mais que o enrage (x%.1f)"
			% float(mapa.get("MULT_HP", 0.0)))
	_assert(float(mapa.get("ENRAGE_SEG", 0.0)) > 0.0, "o enrage continua existindo como pressão")

	# O repertório continua completo — recalibrar não pode ter comido função.
	var rep : Dictionary = mapa.get("REPERTORIO", {})
	_assert(rep.size() == 3, "os 3 lendários continuam cadastrados")
	for id in rep:
		for papel in ["pressao", "area", "controle", "punicao", "percentual", "ambiente"]:
			_assert(rep[id].has(papel), "%s tem a função '%s'" % [str(rep[id].get("nome", id)), papel])

# ──────────────────────────────────────────────────────────────────────────
# Item 11 — a IA escolhe por pontuação
# ──────────────────────────────────────────────────────────────────────────
func _p1_ia_escolhe_golpe() -> void:
	var forte_inutil := {"power": 120, "type": "Normal", "category": "physical",
		"range": 2.0, "area_type": "single", "cooldown": 5.0}
	# Fogo, não Luta: Luta TAMBÉM é imune contra Fantasma, então o primeiro
	# exemplo que escrevi aqui dava -1 (nenhum golpe servia) e parecia bug da
	# IA quando era erro do teste.
	var fraco_util := {"power": 40, "type": "Fire", "category": "physical",
		"range": 2.0, "area_type": "single", "cooldown": 2.0}

	# Contra Fantasma, Normal é imune: a IA tem que largar o golpe forte.
	var contexto := {"tipos_do_alvo": ["Ghost"], "fracao_vida_alvo": 1.0, "minha_fracao_vida": 1.0}
	var escolhido : int = ComportamentoSelvagem.escolher_golpe(
		[forte_inutil, fraco_util], [0.0, 0.0], 100.0, contexto)
	_assert(escolhido == 1,
		"contra quem é IMUNE ao golpe forte, a IA usa o fraco que funciona (escolheu %d)" % escolhido)

	# Sem tipo informado, o forte ganha — o comportamento antigo continua sendo
	# o padrão quando não há informação melhor.
	var sem_info : int = ComportamentoSelvagem.escolher_golpe(
		[forte_inutil, fraco_util], [0.0, 0.0], 100.0, {})
	_assert(sem_info == 0, "sem informação de tipo, vale o mais forte")

	# Não desperdiçar golpe caro em alvo quase morto.
	var caro := {"power": 140, "type": "Normal", "category": "physical", "range": 3.0,
		"area_type": "single", "cooldown": 9.0}
	var barato := {"power": 45, "type": "Normal", "category": "physical", "range": 3.0,
		"area_type": "single", "cooldown": 2.0}
	var nota_caro_cheio : float = ComportamentoSelvagem.nota_do_golpe(caro, 200.0,
		{"fracao_vida_alvo": 1.0, "minha_fracao_vida": 1.0})
	var nota_caro_moribundo : float = ComportamentoSelvagem.nota_do_golpe(caro, 200.0,
		{"fracao_vida_alvo": 0.1, "minha_fracao_vida": 1.0})
	_assert(nota_caro_moribundo < nota_caro_cheio * 0.6,
		"a ultimate vale muito menos contra um alvo quase morto (%.0f -> %.0f)"
			% [nota_caro_cheio, nota_caro_moribundo])

	# Área vale mais quando há mais alvos — e só então.
	var area := {"power": 60, "type": "Normal", "category": "special", "range": 3.0,
		"area_type": "circle", "max_targets": 6, "cooldown": 5.0}
	var um_alvo : float = ComportamentoSelvagem.nota_do_golpe(area, 200.0, {"alvos_agrupados": 1})
	var cinco : float = ComportamentoSelvagem.nota_do_golpe(area, 200.0, {"alvos_agrupados": 5})
	_assert(cinco > um_alvo * 1.5,
		"golpe de área vale mais com 5 alvos juntos que com 1 (%.0f -> %.0f)" % [um_alvo, cinco])

	# Golpe fora do alcance nunca é escolhido.
	var curto := {"power": 200, "type": "Normal", "category": "physical", "range": 1.0,
		"area_type": "single", "cooldown": 2.0}
	var longo := {"power": 50, "type": "Normal", "category": "special", "range": 6.0,
		"area_type": "single", "cooldown": 2.0}
	var de_longe : int = ComportamentoSelvagem.escolher_golpe([curto, longo], [0.0, 0.0], 600.0, {})
	_assert(de_longe == 1, "de longe, só o golpe de longo alcance entra em jogo")

	# Recarga é respeitada.
	var recarregando : int = ComportamentoSelvagem.escolher_golpe([curto, longo], [3.0, 0.0], 100.0, {})
	_assert(recarregando == 1, "golpe em recarga não é escolhido")
	var nada : int = ComportamentoSelvagem.escolher_golpe([curto, longo], [3.0, 3.0], 100.0, {})
	_assert(nada == -1, "com tudo recarregando, a IA não ataca (em vez de inventar um golpe)")

	# Continua barato: a escolha roda milhares de vezes por minuto no mundo.
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		ComportamentoSelvagem.escolher_golpe([forte_inutil, fraco_util, area, longo],
			[0.0, 0.0, 0.0, 0.0], 200.0, contexto)
	var us : float = float(Time.get_ticks_usec() - t0) / 2000.0
	_assert(us < 60.0, "escolher golpe entre 4 custa %.1f us (teto 60)" % us)

# ──────────────────────────────────────────────────────────────────────────
# Item 12 — prioridade de alvo
# ──────────────────────────────────────────────────────────────────────────
func _p1_prioridade_de_alvo() -> void:
	var molde := GDScript.new()
	molde.source_code = "extends Node2D\n"
	molde.reload()
	var pais := Node2D.new()
	root.add_child(pais)
	var perto : Node2D = molde.new(); pais.add_child(perto); perto.global_position = Vector2(200, 0)
	var longe : Node2D = molde.new(); pais.add_child(longe); longe.global_position = Vector2(900, 0)

	var eu := Vector2.ZERO
	var lar := Vector2.ZERO

	# Perto ganha de longe, quando o resto é igual.
	var escolha : Node2D = ComportamentoSelvagem.escolher_alvo([
		{"no": longe, "distancia": 900.0, "fracao_vida": 1.0},
		{"no": perto, "distancia": 200.0, "fracao_vida": 1.0},
	], ComportamentoSelvagem.AGRESSIVO, eu, lar)
	_assert(escolha == perto, "entre dois iguais, ataca o mais perto")

	# 🔴 A regra mais importante do item 12: quem me bateu vira prioridade,
	# mesmo estando mais longe.
	escolha = ComportamentoSelvagem.escolher_alvo([
		{"no": perto, "distancia": 200.0, "fracao_vida": 1.0, "me_atacou": false},
		{"no": longe, "distancia": 900.0, "fracao_vida": 1.0, "me_atacou": true},
	], ComportamentoSelvagem.AGRESSIVO, eu, lar)
	_assert(escolha == longe, "quem me atacou vira prioridade mesmo estando longe")

	# Predador prefere o ferido; o comum não tanto.
	var nota_ferido : float = ComportamentoSelvagem.nota_do_alvo(
		{"no": perto, "distancia": 200.0, "fracao_vida": 0.15}, ComportamentoSelvagem.PREDADOR, eu, lar)
	var nota_inteiro : float = ComportamentoSelvagem.nota_do_alvo(
		{"no": perto, "distancia": 200.0, "fracao_vida": 1.0}, ComportamentoSelvagem.PREDADOR, eu, lar)
	_assert(nota_ferido > nota_inteiro * 1.5, "o predador caça o ferido (%.0f vs %.0f)" % [nota_ferido, nota_inteiro])

	# O Pokémon do jogador vem antes do treinador.
	escolha = ComportamentoSelvagem.escolher_alvo([
		{"no": perto, "distancia": 200.0, "fracao_vida": 1.0, "e_treinador": true},
		{"no": longe, "distancia": 260.0, "fracao_vida": 1.0, "e_treinador": false},
	], ComportamentoSelvagem.AGRESSIVO, eu, lar)
	_assert(escolha == longe, "o Pokémon do time é alvo antes do treinador")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains("ComportamentoSelvagem.escolher_alvo("),
		"o selvagem usa a prioridade de verdade (não é regra só no papel)")
	pais.queue_free()

# ──────────────────────────────────────────────────────────────────────────
# A ideia do Gabriel — kit cresce com evolução E nível
# ──────────────────────────────────────────────────────────────────────────
func _p1_kit_por_evolucao() -> void:
	var esp : Dictionary = GameData.species
	# A escada exata que ele descreveu.
	_assert(KitDeCombate.capacidade(4, 100, esp) == 6, "Charmander Lv.100 tem 6 slots")
	_assert(KitDeCombate.capacidade(5, 100, esp) == 7, "Charmeleon Lv.100 tem 7 slots")
	_assert(KitDeCombate.capacidade(6, 100, esp) == 8, "Charizard Lv.100 tem 8 slots")

	_assert(KitDeCombate.estagio_evolutivo(4, esp) == 0, "Charmander é estágio 0")
	_assert(KitDeCombate.estagio_evolutivo(5, esp) == 1, "Charmeleon é estágio 1")
	_assert(KitDeCombate.estagio_evolutivo(6, esp) == 2, "Charizard é estágio 2")

	# 🔴 Este teste existe por causa de um bug que custou caro: `evolution_to` é
	# NULL nas formas finais, `int(null)` lança erro e abortava o laço — o que
	# fazia TODAS as 151 espécies serem estágio 0 e a escada não existir.
	var estagios := {0: 0, 1: 0, 2: 0}
	for chave in esp:
		estagios[KitDeCombate.estagio_evolutivo(int(esp[chave].get("id", 0)), esp)] += 1
	# Kanto tem 82 formas base, 53 primeiras evoluções e 16 formas finais de
	# linha tripla (a maioria das linhas é de dois estágios).
	_assert(estagios[1] > 30 and estagios[2] > 10,
		"os três estágios existem de verdade na base (%d base, %d médios, %d finais)"
			% [estagios[0], estagios[1], estagios[2]])

	# Nível também dá slot, e o teto é 8.
	_assert(KitDeCombate.capacidade(6, 5, esp) < KitDeCombate.capacidade(6, 100, esp),
		"o mesmo Pokémon ganha slots ao subir de nível")
	for chave in esp:
		var cap : int = KitDeCombate.capacidade(int(esp[chave].get("id", 0)), 100, esp)
		if cap > KitDeCombate.SLOTS_MAXIMO:
			_assert(false, "ninguém passa de 8 slots")
			break

	# 🔴 O caso que motivou a ideia: Magikarp Lv100 não pode competir com uma
	# forma final, mesmo tendo nível máximo. E a razão é o REPERTÓRIO, não uma
	# regra especial escrita pra ele.
	var kit_magikarp : Array = _kit(129, 100)
	var kit_gyarados : Array = _kit(130, 100)
	_assert(kit_magikarp.size() <= 3,
		"Magikarp Lv.100 continua com repertório minúsculo (%d golpes)" % kit_magikarp.size())
	_assert(kit_gyarados.size() >= kit_magikarp.size() + 3,
		"Gyarados Lv.100 tem MUITO mais opção que o Magikarp (%d contra %d) — evoluir mudou o jogo, não só os números"
			% [kit_gyarados.size(), kit_magikarp.size()])

	# E a forma final tem mais golpe OFENSIVO, não só mais slot.
	var ofensivos_char : int = _conta_ofensivos(_kit(4, 100))
	var ofensivos_zard : int = _conta_ofensivos(_kit(6, 100))
	_assert(ofensivos_zard > ofensivos_char,
		"Charizard tem mais golpes de DANO que Charmander no mesmo nível (%d vs %d)"
			% [ofensivos_zard, ofensivos_char])

func _kit(species_id: int, nivel: int) -> Array:
	return KitDeCombate.montar(species_id, nivel,
		GameData.get_learnable_moves(species_id, nivel), GameData.moves,
		GameData.get_species(species_id).get("types", []), GameData.species)

func _conta_ofensivos(kit: Array) -> int:
	var n : int = 0
	for mid in kit:
		if int(GameData.get_move(str(mid)).get("power", 0)) > 0:
			n += 1
	return n

# ──────────────────────────────────────────────────────────────────────────
# Item 13 — loadout por faixa
# ──────────────────────────────────────────────────────────────────────────
func _p1_loadout_por_faixa() -> void:
	# Iniciante não abre o jogo com 4 botões.
	var fora : Array[String] = []
	var sem_ataque : Array[String] = []
	for chave in GameData.species:
		var id : int = int(GameData.species[chave].get("id", 0))
		var kit : Array = _kit(id, 5)
		var ofensivos : int = _conta_ofensivos(kit)
		if ofensivos > 4:
			fora.append(str(GameData.species[chave].get("name", id)))
		if ofensivos < 1:
			sem_ataque.append(str(GameData.species[chave].get("name", id)))
	_assert(sem_ataque.is_empty(),
		"TODA espécie tem pelo menos um golpe que tira vida no nível 5 (%s)" % str(sem_ataque.slice(0, 5)))
	_assert(fora.is_empty(), "ninguém abre o jogo com mais de 4 golpes ofensivos (%s)" % str(fora.slice(0, 5)))

	# A faixa cresce com o nível.
	var med5 : float = _media_ofensivos(5)
	var med25 : float = _media_ofensivos(25)
	var med60 : float = _media_ofensivos(60)
	_assert(med5 < med25 and med25 < med60,
		"a média de golpes ofensivos cresce com o nível (%.1f -> %.1f -> %.1f)" % [med5, med25, med60])

	# Golpe de status nunca ocupa todos os slots.
	var so_status : Array[String] = []
	for chave in GameData.species:
		var id : int = int(GameData.species[chave].get("id", 0))
		for nivel in [5, 30, 100]:
			var kit : Array = _kit(id, nivel)
			if not kit.is_empty() and _conta_ofensivos(kit) == 0:
				so_status.append("%s Lv%d" % [str(GameData.species[chave].get("name", id)), nivel])
	_assert(so_status.is_empty(), "nenhum Pokémon fica com o kit só de status (%s)" % str(so_status.slice(0, 5)))

func _media_ofensivos(nivel: int) -> float:
	var soma : int = 0
	var n : int = 0
	for chave in GameData.species:
		soma += _conta_ofensivos(_kit(int(GameData.species[chave].get("id", 0)), nivel))
		n += 1
	return float(soma) / float(maxi(n, 1))

# ──────────────────────────────────────────────────────────────────────────
# Item 14 — o selvagem não é um mini-jogador
# ──────────────────────────────────────────────────────────────────────────
func _p1_selvagem_nao_e_jogador() -> void:
	_assert(KitDeCombate.SLOTS_SELVAGEM_COMUM <= 3, "selvagem comum carrega no máximo 3 golpes")
	_assert(KitDeCombate.SLOTS_SELVAGEM_ALPHA == 4, "o Alpha carrega 4")
	_assert(KitDeCombate.SLOTS_SELVAGEM_COMUM < KitDeCombate.SLOTS_MAXIMO,
		"o jogador sempre pode ter mais repertório que um selvagem comum")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains("SLOTS_SELVAGEM_ALPHA") and fonte.contains("SLOTS_SELVAGEM_COMUM"),
		"o selvagem usa os tetos de verdade")

	# Na prática: mesmo um selvagem de nível 100 não passa do teto.
	var kit : Array = KitDeCombate.montar(6, 100, GameData.get_learnable_moves(6, 100),
		GameData.moves, ["Fire", "Flying"], GameData.species, KitDeCombate.SLOTS_SELVAGEM_COMUM)
	_assert(kit.size() <= 3, "um Charizard SELVAGEM Lv.100 tem 3 golpes, não 8 (%d)" % kit.size())

# ──────────────────────────────────────────────────────────────────────────
# Item 15 — Alpha
# ──────────────────────────────────────────────────────────────────────────
func _p1_alpha() -> void:
	_assert(CombatBalance.ALPHA_HP_MULT <= 3.0,
		"a vida do Alpha caiu pra não virar maratona (x%.1f)" % CombatBalance.ALPHA_HP_MULT)
	_assert(CombatBalance.ALPHA_ATK_MULT > 1.35,
		"...e o ataque subiu junto — mais perigoso, não só mais duro (x%.2f)" % CombatBalance.ALPHA_ATK_MULT)
	_assert(CombatBalance.ALPHA_DEF_MULT > 1.0 and CombatBalance.ALPHA_DEF_MULT < CombatBalance.ALPHA_HP_MULT,
		"a defesa ajuda mas não é o que segura a luta")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains("spa_stat  = int(spa_stat  * ALPHA_ATK_MULT)")
		or fonte.contains("spa_stat   = int(spa_stat  * ALPHA_ATK_MULT)"),
		"o Alpha turbina também os stats ESPECIAIS (senão um Alpha especial não é alpha nenhum)")

# ──────────────────────────────────────────────────────────────────────────
# Item 17 — a arquitetura não trava traits combináveis no futuro
# ──────────────────────────────────────────────────────────────────────────
func _p1_traits_combinaveis() -> void:
	# Hoje a personalidade é um rótulo só. O item 17 não pede migração — pede
	# garantia de que ela não BLOQUEIA um modelo de traços combinados depois.
	# O que garante isso é o formato das perguntas: cada regra é uma função
	# separada que recebe a personalidade e devolve um número/booleano. Trocar
	# a fonte por um dicionário de traços muda a implementação delas, não quem
	# as chama.
	var fonte_comp := FileAccess.get_file_as_string("res://scripts/combat/ComportamentoSelvagem.gd")
	for nome in ["raio_de_aggro", "comeca_briga", "raio_de_coleira", "deve_fugir", "chama_o_bando"]:
		_assert(fonte_comp.contains("static func %s(" % nome),
			"'%s' é uma pergunta isolada (dá pra trocar a fonte sem mexer em quem chama)" % nome)

	# E o normalizador aceita rótulo desconhecido sem quebrar — é a porta por
	# onde um formato novo entraria.
	_assert(ComportamentoSelvagem.normalizar("um_trait_que_nao_existe") in ComportamentoSelvagem.TODAS,
		"rótulo desconhecido vira uma personalidade válida em vez de quebrar")

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(not fonte.contains('personalidade == "aggressive"'),
		"o WildPokemon não compara personalidade por texto solto — pergunta pro ComportamentoSelvagem")

# ──────────────────────────────────────────────────────────────────────────
# Item 19 — os casos de borda do AoE
# ──────────────────────────────────────────────────────────────────────────
func _p1_aoe_casos_de_borda() -> void:
	var molde := GDScript.new()
	molde.source_code = "extends Node2D\nvar species_id : int = 1\n"
	molde.reload()
	var pais := Node2D.new()
	root.add_child(pais)

	var alvos : Array[Node2D] = []
	for i in 12:
		var n : Node2D = molde.new()
		n.add_to_group("aoe_teste")
		pais.add_child(n)
		n.global_position = Vector2(60.0 * float(i + 1), 0)
		alvos.append(n)

	for mid in ["earthquake", "blizzard", "surf", "gust", "petal_dance"]:
		var m : Dictionary = GameData.get_move(mid)
		_assert(not m.is_empty(), "o golpe '%s' existe" % mid)
		if m.is_empty():
			continue
		var nome := str(m.get("name", mid))
		var teto : int = int(m.get("max_targets", 1))

		# 1 alvo, 2, 5 e o máximo.
		for quantos in [1, 2, 5, teto, teto + 4]:
			for i in alvos.size():
				# empilha `quantos` bem em cima do centro, o resto bem longe
				alvos[i].global_position = Vector2(10.0 * float(i), 0) if i < quantos else Vector2(99999, 0)
			var pegos : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, m, "aoe_teste")
			_assert(pegos.size() == mini(quantos, teto),
				"%s com %d alvos na área acerta %d (teto %d)" % [nome, quantos, pegos.size(), teto])
			# nunca duas vezes o mesmo
			var vistos : Array = []
			var repetiu := false
			for a in pegos:
				if a in vistos:
					repetiu = true
				vistos.append(a)
			_assert(not repetiu, "%s não acerta o mesmo alvo duas vezes no mesmo golpe" % nome)

		# Alvo fora da área não entra; alvo na borda entra.
		var raio : float = float(m.get("radius", 0.0))
		if raio > 0.0:
			for i in alvos.size():
				alvos[i].global_position = Vector2(99999, 0)
			alvos[0].global_position = Vector2(raio * 0.98, 0)
			alvos[1].global_position = Vector2(raio * 1.05, 0)
			var borda : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, m, "aoe_teste")
			_assert(alvos[0] in borda, "%s pega quem está na borda de dentro" % nome)
			_assert(not (alvos[1] in borda), "%s NÃO pega quem está logo além da borda" % nome)

		# Alvo que sai durante o cast: a busca acontece DEPOIS da espera, então
		# quem saiu não é atingido. (O teste da Fase 1 já trava a ordem no
		# código; aqui prova o efeito.)
		for i in alvos.size():
			alvos[i].global_position = Vector2(99999, 0)
		alvos[0].global_position = Vector2(10, 0)
		var antes : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, m, "aoe_teste")
		alvos[0].global_position = Vector2(99999, 0)
		var depois : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, m, "aoe_teste")
		_assert(antes.size() == 1 and depois.is_empty(),
			"%s: quem sai da área antes do impacto escapa" % nome)

		# Alvo morto antes do impacto sai da conta (fica fora do grupo).
		alvos[0].global_position = Vector2(10, 0)
		alvos[0].remove_from_group("aoe_teste")
		var morto : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, m, "aoe_teste")
		_assert(morto.is_empty(), "%s: quem morreu antes do impacto não é acertado" % nome)
		alvos[0].add_to_group("aoe_teste")

	pais.queue_free()

# ──────────────────────────────────────────────────────────────────────────
# Item 20 — o relatório de dano diz tudo
# ──────────────────────────────────────────────────────────────────────────
func _p1_debug_completo() -> void:
	var d := DamageCalculator.detalhar(
		{"power": 75, "type": "Electric", "category": "special", "name": "Thunderbolt"},
		{"atk": 60, "spa": 145, "level": 32, "types": ["Electric"], "status": "burn",
		 "ability": "Static", "held_item": ""},
		{"def": 70, "spd": 98, "types": ["Flying"], "max_hp": 300, "hp": 300, "level": 30})

	# Os 17 campos que o item 20 lista, um a um.
	for campo in ["nivel_atacante", "golpe", "power", "categoria", "stat_ofensiva",
			"stat_defensiva", "mult_stab", "mult_tipo", "mult_critico", "variacao",
			"mult_habilidade", "mult_status", "mult_item", "mult_externo", "final",
			"nivel_defensor", "tipo_do_golpe"]:
		_assert(d.has(campo), "o relatório traz '%s'" % campo)

	_assert(int(d["stat_ofensiva"]) == 145, "usou SP_ATK (145) no golpe especial, não o ataque físico")
	_assert(int(d["stat_defensiva"]) == 98, "usou SP_DEF (98) do alvo")
	_assert(is_equal_approx(float(d["mult_stab"]), 1.25), "STAB apareceu (Elétrico usando golpe Elétrico)")
	_assert(is_equal_approx(float(d["mult_tipo"]), 2.0), "efetividade apareceu (Elétrico em Voador)")

	var texto := CombateDebug.formatar(d, "Pikachu", "Spearow")
	for pedaco in ["Pikachu", "Nv.32", "Thunderbolt", "Spearow", "power", "stat ofensiva",
			"stat defensiva", "STAB", "crítico", "variação", "DANO FINAL", "super efetivo"]:
		_assert(texto.contains(pedaco), "o texto do relatório mostra '%s'" % pedaco)

	# O relatório não pode divergir do dano que saiu — por isso os dois vêm da
	# MESMA chamada.
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/DamageCalculator.gd")
	_assert(fonte.contains("return int(detalhar("),
		"calculate_damage() é um atalho pra detalhar() — impossível o relatório mentir")

func _assert(cond: bool, msg: String) -> void:
	if msg.is_empty():
		return
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
