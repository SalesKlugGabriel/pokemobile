## teste_efeitos_e_corpo_v2.gd — Passos 8 e 10 do plano da Gameplay V2.
##
## `LivroDeEfeitos` (§16, §17, §18, §23, §24) e `RegrasDeCorpo` (§28–§31).
##
## Os casos abaixo são, sempre que possível, **os exemplos numéricos que o
## próprio Gabriel escreveu na especificação** — `+15% / −10% = +5%`,
## `Poison 20/tick 8s + 30/tick 5s = 30/tick 8s`. É a forma mais honesta de
## provar que implementei o que ele pediu, e não o que eu entendi.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _rodou : bool = false

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

func _quase(a: float, b: float, tol: float = 0.0001) -> bool:
	return absf(a - b) <= tol

func _initialize() -> void:
	print("== Efeitos e corpo (Gameplay V2) ==")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	_soma_e_compensacao()
	_mesma_skill_nao_empilha()
	_excedente_vira_duracao()
	_status_reaplicado()
	_imunidade_de_um_segundo()
	_cleanse()
	_ordem_dos_eventos()
	_corpo_e_captura()
	_loot()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# §16
# ──────────────────────────────────────────────────────────────────────────────

func _soma_e_compensacao() -> void:
	print("-- §16: soma, compensação e timers independentes")
	var l := LivroDeEfeitos.new()

	# Skills DIFERENTES somam de forma aditiva.
	l.aplicar("swords_dance", "atk", 0.20, 10.0)
	l.aplicar("howl", "atk", 0.10, 10.0)
	_conf(_quase(l.saldo("atk"), 0.30), "skills diferentes somam",
		"deu %.2f" % l.saldo("atk"))

	# O exemplo do Gabriel: +15% e −10% resultam em +5%.
	var m := LivroDeEfeitos.new()
	m.aplicar("buff", "atk", 0.15, 10.0)
	m.aplicar("debuff", "atk", -0.10, 10.0)
	_conf(_quase(m.saldo("atk"), 0.05), "+15% com −10% dá +5%",
		"deu %.2f" % m.saldo("atk"))

	# E o caso que só um livro-razão resolve: +15% e −15% dão ZERO agora, mas
	# os dois continuam correndo — quando um acaba, o outro volta a valer.
	var n := LivroDeEfeitos.new()
	n.aplicar("buff", "atk", 0.15, 10.0)
	n.aplicar("debuff", "atk", -0.15, 4.0)
	_conf(_quase(n.saldo("atk"), 0.0), "+15% com −15% dá zero enquanto os dois vivem")
	_conf(n.linhas.size() == 2, "mas as DUAS linhas continuam ativas",
		"tem %d" % n.linhas.size())
	n.passo(5.0)   # o debuff (4 s) morre; o buff (10 s) segue
	_conf(_quase(n.saldo("atk"), 0.15),
		"quando o debuff acaba, o buff volta a produzir o efeito restante",
		"deu %.2f" % n.saldo("atk"))

func _mesma_skill_nao_empilha() -> void:
	print("-- §16: a mesma skill reaplicada não empilha")
	var l := LivroDeEfeitos.new()
	l.aplicar("growl", "def", -0.10, 5.0)
	l.aplicar("growl", "def", -0.10, 5.0)
	_conf(l.linhas.size() == 1, "duas aplicações da mesma skill = uma linha só",
		"tem %d" % l.linhas.size())
	_conf(_quase(l.saldo("def"), -0.10), "e o saldo não dobra")

	# Maior intensidade E maior duração, escolhidas em SEPARADO: um golpe fraco
	# e longo não pode roubar a intensidade de um forte e curto.
	var m := LivroDeEfeitos.new()
	m.aplicar("x", "atk", 0.30, 3.0)     # forte e curto
	m.aplicar("x", "atk", 0.10, 12.0)    # fraco e longo
	_conf(_quase(m.saldo("atk"), 0.30), "fica a MAIOR intensidade",
		"deu %.2f" % m.saldo("atk"))
	_conf(_quase(float(m.linhas[0]["restante"]), 12.0), "e a MAIOR duração",
		"deu %.1f" % float(m.linhas[0]["restante"]))

# ──────────────────────────────────────────────────────────────────────────────
# §23
# ──────────────────────────────────────────────────────────────────────────────

func _excedente_vira_duracao() -> void:
	print("-- §23: excedente além do limite vira duração")
	var l := LivroDeEfeitos.new()
	# Limite funcional de +50%. Três buffs de 25% somam 75% → excede 25%.
	l.aplicar("a", "atk", 0.25, 10.0, 0.50)
	l.aplicar("b", "atk", 0.25, 10.0, 0.50)
	var r : Dictionary = l.aplicar("c", "atk", 0.25, 10.0, 0.50)

	_conf(_quase(l.saldo("atk"), 0.75), "o saldo cru passa do limite")
	_conf(_quase(l.valor_efetivo("atk", 0.50), 0.50),
		"mas o valor efetivo trava no limite",
		"deu %.2f" % l.valor_efetivo("atk", 0.50))
	# Excedente 0,25 → 2 segundos (cada 10% = 1 s, arredondando pra baixo).
	_conf(_quase(float(r["bonus_de_duracao"]), 2.0),
		"o excedente de 25% virou +2 s", "deu %.1f" % float(r["bonus_de_duracao"]))
	_conf(_quase(float(l.linhas[2]["restante"]), 12.0),
		"e o tempo extra foi pro ÚLTIMO efeito, não pros anteriores",
		"c ficou com %.1f" % float(l.linhas[2]["restante"]))
	_conf(_quase(float(l.linhas[0]["restante"]), 10.0),
		"o primeiro efeito NÃO ganhou tempo")

	# Só uma vez por instância: reaplicar a mesma skill não paga de novo.
	var r2 : Dictionary = l.aplicar("c", "atk", 0.25, 10.0, 0.50)
	_conf(_quase(float(r2["bonus_de_duracao"]), 0.0),
		"a mesma instância não ganha o bônus duas vezes")

	# O tempo extra NÃO some se depois alguém compensar o saldo.
	l.aplicar("d", "atk", -0.40, 10.0, 0.50)
	_conf(_quase(float(l.linhas[2]["restante"]), 12.0),
		"e não some quando outro efeito compensa depois")

	# Vale pro excesso negativo também.
	var n := LivroDeEfeitos.new()
	n.aplicar("p", "spe", -0.35, 8.0, 0.40)
	var rn : Dictionary = n.aplicar("q", "spe", -0.25, 8.0, 0.40)
	_conf(_quase(n.valor_efetivo("spe", 0.40), -0.40), "o piso também trava")
	_conf(float(rn["bonus_de_duracao"]) >= 1.0,
		"e o excesso negativo também vira duração",
		"deu %.1f" % float(rn["bonus_de_duracao"]))

# ──────────────────────────────────────────────────────────────────────────────
# §17 e §18
# ──────────────────────────────────────────────────────────────────────────────

func _status_reaplicado() -> void:
	print("-- §17: status reaplicado nunca piora")
	var l := LivroDeEfeitos.new()
	# O exemplo literal do Gabriel.
	l.aplicar_status("poison", 8.0, 20.0)
	l.aplicar_status("poison", 5.0, 30.0)
	_conf(_quase(l.intensidade_do_status("poison"), 30.0),
		"20/tick por 8 s + 30/tick por 5 s → intensidade 30",
		"deu %.0f" % l.intensidade_do_status("poison"))
	_conf(_quase(float(l.status["poison"]["restante"]), 8.0),
		"...e duração 8 s (a maior das duas)",
		"deu %.1f" % float(l.status["poison"]["restante"]))

	# Nunca reduzir: um veneno pior seguido de um mais fraco não enfraquece.
	l.aplicar_status("poison", 1.0, 5.0)
	_conf(_quase(l.intensidade_do_status("poison"), 30.0), "reaplicar fraco não reduz a intensidade")
	_conf(_quase(float(l.status["poison"]["restante"]), 8.0), "nem a duração")

	# Status sem intensidade: só a duração conta.
	var m := LivroDeEfeitos.new()
	m.aplicar_status("sleep", 3.0, 0.0)
	m.aplicar_status("sleep", 7.0, 0.0)
	_conf(_quase(float(m.status["sleep"]["restante"]), 7.0),
		"sono: fica a maior duração")

func _imunidade_de_um_segundo() -> void:
	print("-- §18: 1 s de imunidade ao MESMO status")
	var l := LivroDeEfeitos.new()
	l.aplicar_status("burn", 2.0, 10.0)
	var acabaram : Array[String] = l.passo(2.0)
	_conf(acabaram.has("burn"), "o burn acabou e o livro avisou")
	_conf(l.imune_a("burn"), "e nasceu imunidade a burn")

	_conf(not l.aplicar_status("burn", 5.0, 10.0),
		"reaplicar burn dentro de 1 s FALHA")
	_conf(not l.tem_status("burn"), "e o status não entrou")

	# Mas só àquele status — os outros passam normalmente.
	_conf(l.aplicar_status("poison", 5.0, 10.0),
		"poison passa normalmente durante a imunidade a burn")

	l.passo(1.1)
	_conf(not l.imune_a("burn"), "passado 1 s, a imunidade some")
	_conf(l.aplicar_status("burn", 5.0, 10.0), "e o burn volta a entrar")

# ──────────────────────────────────────────────────────────────────────────────
# §21 e §24
# ──────────────────────────────────────────────────────────────────────────────

func _cleanse() -> void:
	print("-- §21: cleanse limpa tudo, menos Held")
	var l := LivroDeEfeitos.new()
	l.aplicar("skill_boa", "atk", 0.20, 10.0)
	l.aplicar("skill_ruim", "def", -0.20, 10.0)
	l.aplicar("held_gold", "def", 0.15, 999.0, 0.0, true)   # de item
	l.aplicar_status("poison", 10.0, 20.0)

	l.limpar()
	_conf(not l.tem_status("poison"), "o status saiu")
	_conf(l.linhas.size() == 1, "sobrou só a linha do Held",
		"sobraram %d" % l.linhas.size())
	_conf(_quase(l.saldo("def"), 0.15), "e o Held continua valendo (§49)")
	# Cleanse não é o status acabando sozinho: não dá imunidade de brinde,
	# senão cleanse viraria escudo.
	_conf(not l.imune_a("poison"), "cleanse NÃO concede a imunidade da §18")

func _ordem_dos_eventos() -> void:
	print("-- §24: expira primeiro, aplica depois")
	var l := LivroDeEfeitos.new()
	l.aplicar("velho", "atk", 0.20, 1.0)
	l.passo(1.0)                       # o velho expira
	_conf(l.linhas.is_empty(), "o efeito expirado saiu do livro")
	l.aplicar("novo", "atk", 0.10, 5.0)
	_conf(_quase(l.saldo("atk"), 0.10),
		"o novo entra sobre o saldo JÁ recalculado, não sobre o antigo",
		"deu %.2f" % l.saldo("atk"))

# ──────────────────────────────────────────────────────────────────────────────
# §28 a §31
# ──────────────────────────────────────────────────────────────────────────────

func _corpo(extra: Dictionary = {}) -> Dictionary:
	var c := {"nome": "Rattata", "catch_rate": 255, "nivel": 10,
			  "restante": 12.0, "tentativa_usada": false, "capturavel": true,
			  "shiny": false, "lendario": false}
	for k in extra.keys():
		c[k] = extra[k]
	return c

func _corpo_e_captura() -> void:
	print("-- §28: derrotar, então capturar — uma vez só")
	_conf(RegrasDeCorpo.duracao(0.0) >= 10.0 and RegrasDeCorpo.duracao(1.0) <= 15.0,
		"o corpo dura entre 10 e 15 segundos")

	var c := _corpo()
	_conf(bool(RegrasDeCorpo.pode_tentar(c)["pode"]), "dá pra tentar num corpo fresco")

	# A tentativa gasta a chance, mesmo falhando.
	var r : Dictionary = RegrasDeCorpo.tentar(c, "pokeball", 0.999)
	_conf(not bool(r["pegou"]), "sorteio ruim falha")
	c["tentativa_usada"] = true
	var p : Dictionary = RegrasDeCorpo.pode_tentar(c)
	_conf(not bool(p["pode"]), "e a SEGUNDA tentativa é recusada")
	_conf(str(p["motivo"]) != "", "com motivo em português pra mostrar na tela",
		str(p["motivo"]))

	# Corpo expirado não aceita mais nada.
	_conf(not bool(RegrasDeCorpo.pode_tentar(_corpo({"restante": 0.0}))["pode"]),
		"corpo que já sumiu não aceita tentativa")

	# §30: Alpha não é capturável, ponto.
	_conf(not bool(RegrasDeCorpo.pode_tentar(_corpo({"capturavel": false}))["pode"]),
		"Alpha não pode ser capturado")

	print("-- A chance (escondida do jogador)")
	var facil := RegrasDeCorpo.chance(255, 5, "pokeball")
	var dificil := RegrasDeCorpo.chance(3, 100, "pokeball")
	_conf(facil > dificil, "Caterpie Lv5 é mais fácil que um lendário Lv100",
		"%.3f contra %.3f" % [facil, dificil])

	_conf(RegrasDeCorpo.chance(45, 30, "ultraball") > RegrasDeCorpo.chance(45, 30, "pokeball"),
		"Ultra Ball ajuda mais que Pokéball")
	_conf(_quase(RegrasDeCorpo.chance(3, 100, "masterball"), 1.0),
		"Master Ball é certeza, inclusive em lendário")

	_conf(RegrasDeCorpo.chance(45, 30, "pokeball", 0, true)
			< RegrasDeCorpo.chance(45, 30, "pokeball", 0, false),
		"§31: shiny é mais difícil de capturar")

	var lend := RegrasDeCorpo.chance(3, 100, "ultraball", 50, false, true)
	var comum_ruim := RegrasDeCorpo.chance(3, 100, "ultraball", 50, false, false)
	_conf(lend < comum_ruim, "§29: lendário é ainda mais difícil que a taxa dele já indica",
		"%.4f contra %.4f" % [lend, comum_ruim])
	_conf(lend >= RegrasDeCorpo.CHANCE_MINIMA,
		"mas nunca chega a zero — caçar lendário continua possível")

	_conf(RegrasDeCorpo.chance(255, 5, "ultraball", 999) <= RegrasDeCorpo.CHANCE_MAXIMA,
		"nem o melhor caso vira certeza (só a Master Ball)")

	# Sorte ajuda, mas pouco.
	var sem_sorte := RegrasDeCorpo.chance(45, 30, "pokeball", 0)
	var com_sorte := RegrasDeCorpo.chance(45, 30, "pokeball", 100)
	_conf(com_sorte > sem_sorte, "sorte ajuda")
	_conf(com_sorte < sem_sorte * 1.5, "mas não domina a conta",
		"%.3f contra %.3f" % [com_sorte, sem_sorte])

func _loot() -> void:
	print("-- §30/§35: o que o corpo larga")
	# Sorteios forçados: o teste não pode depender de sorte pra ser verdade.
	var tudo_cai : Array = [0.0, 0.0, 0.0]
	var nada_cai : Array = [0.99, 0.99, 0.99]

	_conf(RegrasDeCorpo.loot(30, false, 0, tudo_cai).size() >= 1,
		"selvagem comum pode largar item")
	_conf(RegrasDeCorpo.loot(30, false, 0, nada_cai).is_empty(),
		"e pode não largar nada")

	var de_alpha : Array = RegrasDeCorpo.loot(40, true, 0, tudo_cai)
	var itens : Array = []
	for d in de_alpha:
		itens.append(str(d["item"]))
	_conf(itens.has("held_bronze"), "Alpha pode largar Held Bronze (§30)")
	_conf(itens.has("solvente_de_held"), "e o item que remove Held (§51)")

	# §30: "Luck NÃO modifica drops exclusivos de Alpha". Provado no limiar:
	# um sorteio logo acima da chance base não pode passar a cair só por sorte.
	var no_limiar : Array = [0.99, 0.085, 0.99]   # 0.085 > 0.08 (chance do bronze)
	_conf(_exclusivos(RegrasDeCorpo.loot(40, true, 0, no_limiar)) ==
			_exclusivos(RegrasDeCorpo.loot(40, true, 999, no_limiar)),
		"sorte NÃO melhora o drop exclusivo de Alpha (§30)")

	# E o contraste que prova que a comparação acima diz alguma coisa: a sorte
	# melhora, sim, o drop COMUM. Sem isto, o teste passaria com um `loot()`
	# que ignorasse sorte em tudo.
	var quase : Array = [0.55, 0.99, 0.99]
	_conf(RegrasDeCorpo.loot(30, false, 0, quase).is_empty()
			and not RegrasDeCorpo.loot(30, false, 90, quase).is_empty(),
		"mas a sorte melhora o drop COMUM (senão o teste acima não prova nada)")

	# E nem sorte absurda garante drop — o teto tem que valer DEPOIS da sorte.
	_conf(RegrasDeCorpo.loot(100, false, 9999, [0.95, 0.99, 0.99]).is_empty(),
		"sorte absurda não transforma drop comum em garantido")

## Só os itens que existem exclusivamente em Alpha (§30).
func _exclusivos(lista: Array) -> Array:
	var out : Array = []
	for d in lista:
		var i := str(d["item"])
		if i == "held_bronze" or i == "solvente_de_held":
			out.append(i)
	return out
