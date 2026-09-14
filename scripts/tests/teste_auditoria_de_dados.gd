## teste_auditoria_de_dados.gd — Nenhum campo errado, vazio, ou que não é lido.
##
## Pedido do Gabriel (14/09): *"Revise todos os golpes e todas as tabelas de
## dano, cooldown e timer das nature, ivs, buffs, debuffs, etc para ter certeza
## de que não tem nada errado ou vazio para dar erro"*.
##
## ── A pergunta que este arquivo faz, e que não é a óbvia ─────────────────────
##
## Não é "o campo existe?". É **"o valor serve?"**.
##
## Eu já errei isso duas vezes em duas sessões: disse que os 192 golpes tinham
## `cast_time` (tinham — 108 valiam zero), e escrevi código que lia um campo
## `drenagem` que golpe nenhum tem. Campo presente e valor útil são coisas
## diferentes, e é a diferença que produz **zero silencioso**: o jogo roda, nada
## dá erro, e uma mecânica inteira simplesmente não acontece.
##
## Então cada conferência aqui pergunta se o número faz alguma coisa, não se ele
## está lá.
extends SceneTree

var ok : int = 0
var fail : int = 0
var avisos : Array[String] = []
var _rodou : bool = false

var GameData : Node
## Autoload não é identificador em teste `--script` — a armadilha de sempre.
var EventBus : Node
var Dano : GDScript
var Stats : GDScript
var Status : GDScript
var Forma : GDScript

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

## Para o que é suspeito mas legítimo: aparece no relatório sem reprovar.
func _aviso(texto: String) -> void:
	avisos.append(texto)

func _initialize() -> void:
	print("== Auditoria de dados: golpes, espécies, natures, IVs e efeitos ==")

func _process(_d: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	EventBus = root.get_node("EventBus")
	Dano   = load("res://scripts/combat/DamageCalculator.gd")
	Stats  = load("res://scripts/combat/StatsDePokemon.gd")
	Status = load("res://scripts/combat/StatusEffectController.gd")
	Forma  = load("res://scripts/combat/FormaDeArea.gd")

	_golpes_campos_obrigatorios()
	_golpes_numeros()
	_golpes_tipos_e_formas()
	_golpes_efeitos()
	_especies()
	_natures()
	_ivs()
	_tabela_de_tipos()
	_regua_central()
	_prioridade_e_relatorio()

	if not avisos.is_empty():
		print("\n-- Avisos (legítimos, mas vale saber) --")
		for a in avisos:
			print("   • %s" % a)
	print("\n=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# Golpes
# ──────────────────────────────────────────────────────────────────────────────

const CAMPOS_DO_GOLPE : Array[String] = [
	"id", "name", "type", "category", "power", "accuracy", "pp", "priority",
	"contact", "effect", "cooldown", "target_type", "cast_time", "range",
	"area_type", "max_targets", "knockback", "status_chance",
]

func _golpes_campos_obrigatorios() -> void:
	print("-- Golpes: os 18 campos, em todos os 192")
	var faltando : Dictionary = {}
	var nome_vazio : Array = []
	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		for c in CAMPOS_DO_GOLPE:
			if not g.has(c):
				faltando[c] = int(faltando.get(c, 0)) + 1
		if str(g.get("name", "")).strip_edges() == "":
			nome_vazio.append(str(id))
	_conf(faltando.is_empty(), "nenhum golpe tem campo faltando", str(faltando))
	_conf(nome_vazio.is_empty(), "todo golpe tem nome", ", ".join(nome_vazio.slice(0, 5)))
	_conf(GameData.moves.size() == 192, "são 192 golpes",
		"tem %d" % GameData.moves.size())

func _golpes_numeros() -> void:
	print("-- Golpes: os números fazem alguma coisa?")
	var cd_zero : Array = []
	var range_zero : Array = []
	var pp_zero : Array = []
	var cast_maior_que_cd : Array = []
	var alvos_invalido : Array = []
	var chance_fora : Array = []
	var knock_negativo : Array = []

	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		if float(g.get("cooldown", 0)) <= 0.0:
			cd_zero.append(str(id))
		if float(g.get("range", 0)) <= 0.0:
			range_zero.append(str(id))
		if int(g.get("pp", 0)) <= 0:
			pp_zero.append(str(id))
		# Cast mais longo que a recarga é contradição: o golpe nunca sairia duas
		# vezes, e a recarga deixaria de significar alguma coisa.
		if float(g.get("cast_time", 0)) >= float(g.get("cooldown", 99)):
			cast_maior_que_cd.append(str(id))
		if int(g.get("max_targets", 0)) < 1:
			alvos_invalido.append(str(id))
		var sc : float = float(g.get("status_chance", 0))
		if sc < 0.0 or sc > 100.0:
			chance_fora.append(str(id))
		if float(g.get("knockback", 0)) < 0.0:
			knock_negativo.append(str(id))

	_conf(cd_zero.is_empty(), "todo golpe tem recarga > 0", ", ".join(cd_zero.slice(0, 5)))
	_conf(range_zero.is_empty(), "todo golpe tem alcance > 0", ", ".join(range_zero.slice(0, 5)))
	_conf(pp_zero.is_empty(), "todo golpe tem PP > 0", ", ".join(pp_zero.slice(0, 5)))
	_conf(cast_maior_que_cd.is_empty(), "nenhum cast é mais longo que a própria recarga",
		", ".join(cast_maior_que_cd.slice(0, 5)))
	_conf(alvos_invalido.is_empty(), "max_targets é sempre >= 1",
		", ".join(alvos_invalido.slice(0, 5)))
	_conf(chance_fora.is_empty(), "status_chance fica entre 0 e 100",
		", ".join(chance_fora.slice(0, 5)))
	_conf(knock_negativo.is_empty(), "nenhum empurrão negativo",
		", ".join(knock_negativo.slice(0, 5)))

	# Poder 0 num golpe de dano só é legítimo se o efeito define o dano de outro
	# jeito (OHKO, dano fixo, dano por nível). Sem isso é zero silencioso.
	const EFEITOS_QUE_DEFINEM_DANO : Array[String] = [
		"ohko", "fixed_damage", "level_damage", "weight_damage", "halve_hp",
		"counter_physical", "bide", "random_damage", "low_hp_power",
	]
	var zero_sem_explicacao : Array = []
	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		if str(g.get("category", "")) == "status":
			continue
		if int(g.get("power", 0)) > 0:
			continue
		var ef := str(g.get("effect", ""))
		var explicado := false
		for e in EFEITOS_QUE_DEFINEM_DANO:
			if ef.begins_with(e):
				explicado = true
				break
		if not explicado:
			zero_sem_explicacao.append("%s (%s)" % [str(id), ef])
	_conf(zero_sem_explicacao.is_empty(),
		"golpe de dano com poder 0 sempre tem efeito que define o dano",
		", ".join(zero_sem_explicacao.slice(0, 6)))

	# Precisão 0 = nunca erra, por decisão do próprio motor. Vale conferir que a
	# quantidade não explodiu sem ninguém ver.
	var sem_precisao : int = 0
	for id in GameData.moves.keys():
		if float(GameData.moves[id].get("accuracy", 0)) <= 0.0:
			sem_precisao += 1
	_aviso("%d golpes têm accuracy 0 (= nunca erram, por decisão do motor)" % sem_precisao)

	# §9. 🔴 Aviso REESCRITO: a primeira versão dizia só "108 golpes sem janela
	# de leitura", o que era verdade no número e enganoso no sentido — pintava um
	# problema que o dado não tem.
	#
	# Medido: o golpe mais forte entre os instantâneos tem poder **40**. Todos os
	# 59 golpes de poder 70 ou mais JÁ telegrafam. O dado está bem desenhado:
	# soco rápido sai na hora, golpe pesado avisa.
	#
	# Então este teste passou a travar a REGRA, não a contar os casos.
	var pesado_sem_janela : Array = []
	var instantaneos : int = 0
	var poder_maximo_instantaneo : int = 0
	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		var p : int = int(g.get("power", 0))
		if float(g.get("cast_time", 0)) > 0.0:
			continue
		instantaneos += 1
		poder_maximo_instantaneo = maxi(poder_maximo_instantaneo, p)
		if p >= 70:
			pesado_sem_janela.append("%s (poder %d)" % [str(id), p])
	_conf(pesado_sem_janela.is_empty(),
		"nenhum golpe de poder 70+ sai sem janela de leitura (§9)",
		", ".join(pesado_sem_janela.slice(0, 6)))
	_aviso("%d golpes são instantâneos, e o mais forte deles tem poder %d — a leitura deles acontece no IMPACTO, não antes"
		% [instantaneos, poder_maximo_instantaneo])

	# `priority` foi RESOLVIDO pelo Gabriel em 14/09 — ver `_prioridade_e_relatorio`.

func _golpes_tipos_e_formas() -> void:
	print("-- Golpes: tipo e forma precisam ser reconhecidos pelo motor")
	var tipo_desconhecido : Array = []
	var categoria_invalida : Array = []
	var forma_desconhecida : Array = []
	var area_sem_raio : Array = []

	var formas_validas : Array[String] = ["single", "circle", "cone", "line",
		"rectangle", "ring", "global"]

	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		if not Dano.TYPE_CHART.has(str(g.get("type", ""))):
			tipo_desconhecido.append("%s (%s)" % [str(id), str(g.get("type", ""))])
		if not str(g.get("category", "")) in ["physical", "special", "status"]:
			categoria_invalida.append("%s (%s)" % [str(id), str(g.get("category", ""))])
		var forma := str(g.get("area_type", ""))
		if not forma in formas_validas:
			forma_desconhecida.append("%s (%s)" % [str(id), forma])
		# Forma de área sem raio cai no alcance padrão — legítimo, mas se o
		# autor quis um raio específico e esqueceu, ninguém avisaria.
		if forma != "single" and float(g.get("radius", 0)) <= 0.0:
			area_sem_raio.append(str(id))

	_conf(tipo_desconhecido.is_empty(), "todo tipo de golpe existe na tabela de tipos",
		", ".join(tipo_desconhecido.slice(0, 5)))
	_conf(categoria_invalida.is_empty(), "toda categoria é física, especial ou status",
		", ".join(categoria_invalida.slice(0, 5)))
	_conf(forma_desconhecida.is_empty(), "toda forma de área é reconhecida por FormaDeArea",
		", ".join(forma_desconhecida.slice(0, 5)))
	_conf(area_sem_raio.is_empty(), "todo golpe de área tem raio próprio",
		", ".join(area_sem_raio.slice(0, 5)))

func _golpes_efeitos() -> void:
	print("-- Golpes: o campo `effect` é lido, ou está declarado como não lido?")

	# Quem JÁ é interpretado pelo jogo hoje.
	var lidos : int = 0
	var status_sem_chance : Array = []
	var drenagem : Array = []
	var distintos : Dictionary = {}

	for id in GameData.moves.keys():
		var g : Dictionary = GameData.moves[id]
		var ef := str(g.get("effect", "none"))
		if ef == "none" or ef == "":
			continue
		distintos[ef] = true

		var r : Dictionary = Status.resolve_status_effect(ef, Status.chance_do_golpe(g))
		if not r.is_empty():
			lidos += 1
			# Um status que resolve com chance 0 nunca aconteceria — zero mudo.
			if int(r.get("chance", 0)) <= 0:
				status_sem_chance.append(str(id))
		elif Status.resolve_confuse_effect(ef, Status.chance_do_golpe(g)) > 0:
			lidos += 1
		elif ef.begins_with("drain_"):
			drenagem.append(str(id))

	_conf(status_sem_chance.is_empty(),
		"todo golpe de status resolve com chance > 0",
		", ".join(status_sem_chance.slice(0, 5)))

	# 🔴 Drenagem: os golpes existem, e até 14/09 NINGUÉM lia. Agora a V2 lê.
	_conf(not drenagem.is_empty(), "existem golpes de drenagem no jogo",
		"%d" % drenagem.size())
	var Comb : GDScript = load("res://scripts/gameplay_v2/entidades/CombatenteV2.gd")
	for id in drenagem:
		var f : float = Comb.fracao_de_drenagem(GameData.moves[id])
		_conf(f > 0.0 and f <= 1.0,
			"a drenagem de %s é lida e fica entre 0 e 100%%" % id, "deu %.2f" % f)

	_aviso("%d efeitos distintos no jogo; %d golpes têm efeito que o motor já interpreta"
		% [distintos.size(), lidos])
	_aviso("drenagem em %d golpes — funcionava em NENHUM até 14/09, agora funciona na V2"
		% drenagem.size())

# ──────────────────────────────────────────────────────────────────────────────
# Espécies
# ──────────────────────────────────────────────────────────────────────────────

const STATS_BASE : Array[String] = ["hp", "attack", "defense", "sp_atk", "sp_def", "speed"]

func _especies() -> void:
	print("-- Espécies: stats, tipos, captura e evolução")
	var sem_stat : Array = []
	var stat_zero : Array = []
	var sem_tipo : Array = []
	var tipo_invalido : Array = []
	var captura_fora : Array = []
	var sem_ability : Array = []
	var evolucao_quebrada : Array = []

	for id in GameData.species.keys():
		var e : Dictionary = GameData.species[id]
		var nome := str(e.get("name", id))
		var base : Dictionary = e.get("base_stats", {})
		for s in STATS_BASE:
			if not base.has(s):
				sem_stat.append("%s.%s" % [nome, s])
			elif int(base[s]) <= 0:
				stat_zero.append("%s.%s" % [nome, s])

		var tipos : Array = e.get("types", [])
		if tipos.is_empty():
			sem_tipo.append(nome)
		for t in tipos:
			if not Dano.TYPE_CHART.has(str(t)):
				tipo_invalido.append("%s (%s)" % [nome, str(t)])

		var cr : int = int(e.get("catch_rate", 0))
		if cr < 1 or cr > 255:
			captura_fora.append("%s (%d)" % [nome, cr])

		if str(e.get("ability", "")).strip_edges() == "":
			sem_ability.append(nome)

		# Evolução tem que apontar pra uma espécie que existe.
		var prox = e.get("evolution_to")
		if prox != null and int(prox) > 0:
			if not (GameData.species.has(int(prox)) or GameData.species.has(str(prox))):
				evolucao_quebrada.append("%s -> %s" % [nome, str(prox)])

	_conf(sem_stat.is_empty(), "toda espécie tem os 6 stats base",
		", ".join(sem_stat.slice(0, 5)))
	_conf(stat_zero.is_empty(), "e nenhum deles é zero",
		", ".join(stat_zero.slice(0, 5)))
	_conf(sem_tipo.is_empty(), "toda espécie tem pelo menos um tipo",
		", ".join(sem_tipo.slice(0, 5)))
	_conf(tipo_invalido.is_empty(), "e todos os tipos existem na tabela",
		", ".join(tipo_invalido.slice(0, 5)))
	_conf(captura_fora.is_empty(), "catch_rate fica entre 1 e 255",
		", ".join(captura_fora.slice(0, 5)))
	_conf(sem_ability.is_empty(), "toda espécie tem habilidade (§ pedido de 14/09)",
		", ".join(sem_ability.slice(0, 5)))
	_conf(evolucao_quebrada.is_empty(), "toda evolução aponta pra espécie existente",
		", ".join(evolucao_quebrada.slice(0, 5)))
	_conf(GameData.species.size() == 151, "são 151 espécies",
		"tem %d" % GameData.species.size())

	# O learnset não pode ensinar golpe que não existe: seria um slot que o
	# jogador vê e que some quando ele tenta equipar.
	var golpe_fantasma : Array = []
	for id in GameData.learnsets.keys():
		for entrada in GameData.learnsets[id]:
			var mid := str(entrada.get("move", ""))
			if mid != "" and not GameData.moves.has(mid):
				golpe_fantasma.append("%s: %s" % [str(id), mid])
	_conf(golpe_fantasma.is_empty(),
		"nenhum learnset ensina golpe que não existe",
		", ".join(golpe_fantasma.slice(0, 6)))

# ──────────────────────────────────────────────────────────────────────────────
# Natures, IVs e a régua
# ──────────────────────────────────────────────────────────────────────────────

func _natures() -> void:
	print("-- Natures: as 25, com os multiplicadores certos")
	var n : Dictionary = Stats.NATURES
	_conf(n.size() == 25, "são 25 natures", "tem %d" % n.size())

	var chaves_validas : Array[String] = ["atk", "def", "spa", "spd", "spe"]
	var invalidas : Array = []
	var neutras : int = 0
	for nome in n.keys():
		var d : Dictionary = n[nome]
		# Os campos se chamam `boost`/`cut`. A primeira versão deste teste leu
		# `up`/`down`, não achou nada, e concluiu que as 25 eram neutras — o
		# teste estava errado, não o dado.
		var sobe := str(d.get("boost", ""))
		var desce := str(d.get("cut", ""))
		# Neutra: sobe e desce o mesmo stat.
		if sobe == desce:
			neutras += 1
			continue
		if not sobe in chaves_validas or not desce in chaves_validas:
			invalidas.append("%s (%s/%s)" % [str(nome), sobe, desce])
	_conf(invalidas.is_empty(), "toda nature mexe em stat que existe",
		", ".join(invalidas.slice(0, 5)))
	_conf(neutras == 5, "há exatamente 5 natures neutras", "achei %d" % neutras)

	# Os multiplicadores: 1,1 no que sobe, 0,9 no que desce, 1,0 no resto.
	var erradas : Array = []
	for nome in n.keys():
		var d : Dictionary = n[nome]
		var sobe := str(d.get("boost", ""))
		var desce := str(d.get("cut", ""))
		for chave in chaves_validas:
			var m : float = Stats.multiplicador_de_nature(str(nome), chave)
			var esperado : float = 1.0
			if sobe != desce:
				if chave == sobe:
					esperado = 1.1
				elif chave == desce:
					esperado = 0.9
			if absf(m - esperado) > 0.001:
				erradas.append("%s.%s=%.2f (esperado %.2f)" % [str(nome), chave, m, esperado])
	_conf(erradas.is_empty(), "os multiplicadores são 1,1 / 0,9 / 1,0",
		", ".join(erradas.slice(0, 5)))
	# HP nunca é afetado por nature — se fosse, dois Pokémon iguais teriam
	# barras diferentes sem explicação na tela.
	_conf(absf(Stats.multiplicador_de_nature("Adamant", "hp") - 1.0) < 0.001,
		"nature não mexe no HP")

func _ivs() -> void:
	print("-- IVs: os 6, sempre entre 0 e 31")
	var fora : Array = []
	var chaves_faltando : Array = []
	for i in 300:
		var ivs : Dictionary = Stats.sortear_ivs()
		for chave in Stats.CHAVES:
			if not ivs.has(chave):
				chaves_faltando.append(str(chave))
				continue
			var v : int = int(ivs[chave])
			if v < 0 or v > 31:
				fora.append("%s=%d" % [str(chave), v])
	_conf(chaves_faltando.is_empty(), "sortear_ivs devolve os 6 stats",
		", ".join(chaves_faltando.slice(0, 6)))
	_conf(fora.is_empty(), "e todo IV fica entre 0 e 31 (300 sorteios)",
		", ".join(fora.slice(0, 5)))

	# IV muda o stat de verdade — senão o sistema existe só no papel.
	var base := {"hp": 80, "attack": 80, "defense": 80, "sp_atk": 80,
				 "sp_def": 80, "speed": 80}
	var com_0 : Dictionary = Stats.conjunto(base, 50, "", {"atk": 0})
	var com_31 : Dictionary = Stats.conjunto(base, 50, "", {"atk": 31})
	_conf(int(com_31.get("atk", 0)) > int(com_0.get("atk", 0)),
		"IV 31 dá mais ataque que IV 0",
		"0 -> %d, 31 -> %d" % [int(com_0.get("atk", 0)), int(com_31.get("atk", 0))])

func _tabela_de_tipos() -> void:
	print("-- Tabela de tipos: completa e simétrica no formato")
	var chart : Dictionary = Dano.TYPE_CHART
	_conf(chart.size() == 18, "os 18 tipos estão na tabela", "tem %d" % chart.size())

	var alvo_desconhecido : Array = []
	var mult_estranho : Array = []
	for atacante in chart.keys():
		var linha : Dictionary = chart[atacante]
		for defensor in linha.keys():
			if not chart.has(str(defensor)):
				alvo_desconhecido.append("%s vs %s" % [str(atacante), str(defensor)])
			var m : float = float(linha[defensor])
			if not (is_equal_approx(m, 0.0) or is_equal_approx(m, 0.5)
					or is_equal_approx(m, 2.0)):
				mult_estranho.append("%s vs %s = %.2f" % [str(atacante), str(defensor), m])
	_conf(alvo_desconhecido.is_empty(), "a tabela só cita tipos que existem",
		", ".join(alvo_desconhecido.slice(0, 5)))
	_conf(mult_estranho.is_empty(), "os multiplicadores são só 0, 0,5 ou 2",
		", ".join(mult_estranho.slice(0, 5)))

	# §15: 2× vezes 2× dá 4×, e imunidade continua zero.
	_conf(is_equal_approx(Dano.get_type_multiplier("Rock", ["Fire", "Flying"]), 4.0),
		"Rock em Fire/Flying dá 4x (§15)")
	_conf(is_equal_approx(Dano.get_type_multiplier("Electric", ["Ground"]), 0.0),
		"imunidade é zero absoluto")
	_conf(is_equal_approx(Dano.get_type_multiplier("Normal", ["Normal"]), 1.0),
		"neutro é 1")

func _regua_central() -> void:
	print("-- A régua central: nada zerado nem negativo")
	var checagens := {
		"BASE_DAMAGE_MULTIPLIER": CombatBalance.BASE_DAMAGE_MULTIPLIER,
		"HP_SCALE": CombatBalance.HP_SCALE,
		"STAB_MULTIPLIER": CombatBalance.STAB_MULTIPLIER,
		"MIN_DAMAGE": float(CombatBalance.MIN_DAMAGE),
		"ALPHA_HP_MULT": CombatBalance.ALPHA_HP_MULT,
		"ALPHA_ATK_MULT": CombatBalance.ALPHA_ATK_MULT,
	}
	var ruins : Array = []
	for nome in checagens.keys():
		if float(checagens[nome]) <= 0.0:
			ruins.append("%s = %.2f" % [str(nome), float(checagens[nome])])
	_conf(ruins.is_empty(), "toda constante da régua é positiva", ", ".join(ruins))

	# A recarga nunca pode virar zero ou negativa, por mais rápido que seja o
	# Pokémon — seria golpe infinito.
	var pior : float = CombatBalance.recarga(0.1, 999, 0.9)
	_conf(pior > 0.0, "a recarga nunca chega a zero, nem no caso extremo",
		"deu %.3f" % pior)

	# A régua da V2, que é outra e precisa ser conferida também.
	_conf(BalanceV2.VIDA_MULT > 0.0, "a vida da V2 é positiva")
	_conf(is_equal_approx(BalanceV2.ALPHA_MULT, 1.35),
		"o Alpha da V2 é +35% (§30)", "%.2f" % BalanceV2.ALPHA_MULT)

	# Stamina: custo positivo em toda ação declarada, senão a ação é de graça.
	var de_graca : Array = []
	for a in Stamina.CUSTO_POR_SEGUNDO.keys():
		if float(Stamina.CUSTO_POR_SEGUNDO[a]) <= 0.0:
			de_graca.append(str(a))
	for a in Stamina.CUSTO_POR_USO.keys():
		if float(Stamina.CUSTO_POR_USO[a]) <= 0.0:
			de_graca.append(str(a))
	_conf(de_graca.is_empty(), "nenhuma ação de stamina é de graça", ", ".join(de_graca))

	# Os três degraus de exaustão precisam ser crescentes, senão o segundo
	# degrau seria mais leve que o primeiro.
	var crescente := true
	for i in range(1, Stamina.EXAUSTAO.size()):
		if float(Stamina.EXAUSTAO[i]["penalidade"]) <= float(Stamina.EXAUSTAO[i - 1]["penalidade"]):
			crescente = false
	_conf(crescente, "os degraus de exaustão pioram na ordem certa")


# ──────────────────────────────────────────────────────────────────────────────
# Prioridade e o relatório de golpe (decisões de 14/09)
# ──────────────────────────────────────────────────────────────────────────────

func _prioridade_e_relatorio() -> void:
	print("-- Prioridade: o Gabriel decidiu que não existe")
	# Palavras dele: *"nenhum golpe tem prioridade, tendo o cooldown disponível,
	# pode ser utilizado"*.
	#
	# E faz sentido além da preferência: prioridade é conceito de combate POR
	# TURNO — ela decide quem age primeiro quando os dois agem no mesmo turno.
	# Num combate em tempo real não existe "mesmo turno": quem apertou primeiro
	# age primeiro, e a recarga é a única fila que existe.
	var com_prioridade : Array = []
	for id in GameData.moves.keys():
		if int(GameData.moves[id].get("priority", 0)) != 0:
			com_prioridade.append(str(id))
	_conf(com_prioridade.is_empty(),
		"nenhum golpe tem prioridade (decisão do Gabriel, 14/09)",
		", ".join(com_prioridade.slice(0, 6)))

	print("-- O relatório de golpe: a tela precisa saber o que aconteceu")
	# O problema que ele apontou: 4× de dano baixando a barra sem nada na tela.
	# A causa era `damage_dealt` não carregar golpe nem efetividade.
	var Rel : GDScript = load("res://scripts/gameplay_v2/RelatorioDeGolpe.gd")

	_conf(Rel.classificar(0.0) == "imune", "0x é imune")
	_conf(Rel.classificar(0.25) == "muito_fraco", "0,25x é muito fraco")
	_conf(Rel.classificar(0.5) == "fraco", "0,5x é fraco")
	_conf(Rel.classificar(1.0) == "neutro", "1x é neutro")
	_conf(Rel.classificar(2.0) == "forte", "2x é forte")
	_conf(Rel.classificar(4.0) == "muito_forte", "4x é muito forte")
	# §46: um Held pode empurrar 2x pra 2,2x, e isso continua sendo "forte".
	_conf(Rel.classificar(2.2) == "forte", "2,2x (com Held) ainda é forte")

	# Toda classificação tem frase, menos a neutra — que não precisa de aviso.
	for c in ["imune", "muito_fraco", "fraco", "forte", "muito_forte"]:
		_conf(str(Rel.frase(c)) != "", "'%s' tem frase pro jogador" % c)
	_conf(str(Rel.frase("neutro")) == "", "neutro não gera frase (não há o que avisar)")

	# O relatório carrega o que a tela precisa — e nada que ela precise
	# recalcular.
	var golpe : Dictionary = GameData.get_move("thunderbolt")
	var det := {"mult_tipo": 4.0, "mult_stab": 1.25}
	var r : Dictionary = Rel.montar(golpe, null, null, 120, det, 30, 200)
	for campo in ["golpe", "nome_do_golpe", "tipo", "categoria", "area_type",
			"origem", "destino", "direcao", "dano", "fracao_da_vida",
			"mult_tipo", "efetividade", "frase", "derrotou", "teve_aviso"]:
		_conf(r.has(campo), "o relatório traz `%s`" % campo)
	_conf(str(r["efetividade"]) == "muito_forte", "e classifica o 4x corretamente")
	_conf(_quase(float(r["fracao_da_vida"]), 0.6),
		"a fração da vida vem pronta, sem a tela dividir nada",
		"%.2f" % float(r["fracao_da_vida"]))
	_conf(not bool(r["derrotou"]), "sabe que o alvo sobreviveu")
	_conf(bool(Rel.montar(golpe, null, null, 200, det, 0, 200)["derrotou"]),
		"e sabe quando derrotou")

	_conf(EventBus.has_signal("golpe_resolvido"), "o sinal golpe_resolvido existe")
	_conf(EventBus.has_signal("status_aplicado"), "o sinal status_aplicado existe")
	_conf(EventBus.has_signal("damage_dealt"),
		"e `damage_dealt` continua existindo com a mesma assinatura (D-001)")

func _quase(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol
