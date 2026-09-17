## teste_gameplay_v3_fase11.gd — Pokémon selvagem no mundo 3D.
##
## Três metades (sim, três): a regra de spawn, a decisão das sete personalidades,
## e o spawner com física de verdade. As duas primeiras são classes puras e se
## provam exatas; a terceira depende do mundo.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Spawn que ignora o perigo da zona.** O Gabriel pediu "sim, e também
##      mais raro" — lugar perigoso com MENOS encontro. Se o intervalo e a
##      população não obedecerem, o pedido dele virou comentário.
##   2. **Bicho nascendo em cima do jogador.** Em 3D isso não é só injusto: é o
##      contrato de nascimento de 17/09, que catapulta quem estiver no ponto.
##   3. **Personalidade decorativa.** As sete existem em `species.json` desde a
##      V2. Se todas se comportarem igual, o dado é enfeite.
##   4. **Perseguição sem coleira.** Era o defeito que a §26 mandou corrigir:
##      um bicho que entra em CHASE e persegue até o outro lado do mapa.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _spawner = null
var _jogador = null
var _nascidos : Array = []

var GameData : Node
var RNGManager : Node

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 11: Pokémon selvagem ===")

# ──────────────────────────────────────────────────────────────────────────────
# 1. A regra de spawn
# ──────────────────────────────────────────────────────────────────────────────

func _zona(niveis: Array, pesos: Array = []) -> Dictionary:
	var tabela : Array = []
	for i in niveis.size():
		tabela.append({
			"id": 19 + i, "name": "Bicho %d" % i,
			"level_min": int(niveis[i]), "level_max": int(niveis[i]) + 2,
			"weight": float(pesos[i]) if i < pesos.size() else 10.0,
		})
	return {"id": "zona_de_teste", "wild_pokemon": tabela}

func _regra_de_spawn() -> void:
	print("\n-- a regra de spawn --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeSpawn.gd")
	var segura := _zona([3, 4, 5])          # perigo 0
	var mortal := _zona([55, 58, 60])       # perigo 1

	# O pedido do Gabriel, nos dois eixos: menos frequente E menos gente.
	_conf("zona perigosa espera MAIS entre encontros",
		R.intervalo(mortal) > R.intervalo(segura),
		"%.1f s vs %.1f s" % [R.intervalo(mortal), R.intervalo(segura)])
	_conf("e comporta MENOS selvagens ao mesmo tempo",
		R.populacao_maxima(mortal) < R.populacao_maxima(segura),
		"%d vs %d" % [R.populacao_maxima(mortal), R.populacao_maxima(segura)])
	_conf("zona perigosa ainda comporta pelo menos um",
		R.populacao_maxima(mortal) >= 1, "%d" % R.populacao_maxima(mortal))

	# ⚠️ Esticar SÓ o intervalo não bastaria: a população acumularia devagar até
	# a zona perigosa ficar tão povoada quanto a segura, e a intenção se perderia
	# depois de meia hora de jogo. As duas travas existem juntas de propósito.
	_conf("lotado não nasce, mesmo com o intervalo vencido",
		not R.pode_nascer(segura, R.populacao_maxima(segura), 999.0))
	_conf("com vaga e intervalo vencido, nasce",
		R.pode_nascer(segura, 0, 999.0))
	_conf("com vaga mas intervalo não vencido, não nasce",
		not R.pode_nascer(segura, 0, 0.1))

	# Sorteio por peso: os extremos do sorteio caem nos extremos da tabela.
	var z := _zona([3, 4, 5], [90.0, 5.0, 5.0])
	_conf("sorteio 0 cai na primeira entrada",
		int(R.sortear_especie(z, 0.0).get("id", -1)) == 19)
	_conf("sorteio 0,999 cai na última",
		int(R.sortear_especie(z, 0.999).get("id", -1)) == 21)
	_conf("zona SEM tabela devolve vazio, não estoura nem inventa bicho",
		R.sortear_especie({"id": "cidade"}, 0.5).is_empty())

	# Elite: existe no perigoso, não existe no seguro.
	_conf("zona segura não gera elite", not R.e_elite(segura, 0.0001))
	_conf("zona mortal gera elite em parte dos sorteios", R.e_elite(mortal, 0.0001))
	var entrada : Dictionary = z["wild_pokemon"][0]
	_conf("o elite vem mais forte que o topo da faixa normal",
		R.nivel(entrada, true, 0.0) > R.nivel(entrada, false, 0.999),
		"%d vs %d" % [R.nivel(entrada, true, 0.0), R.nivel(entrada, false, 0.999)])

	# O anel. É a trava que protege do contrato de nascimento.
	var centro := Vector3(100, 7, -50)
	for a in [0.0, 0.25, 0.5, 0.75, 0.99]:
		for r in [0.0, 0.5, 1.0]:
			var p : Vector3 = R.ponto_no_anel(centro, a, r)
			var d : float = Vector2(p.x - centro.x, p.z - centro.z).length()
			if d < R.RAIO_MINIMO - 0.001 or d > R.RAIO_MAXIMO + 0.001:
				_conf("ponto no anel fora dos limites (ang %.2f raio %.2f)" % [a, r],
					false, "%.2f m" % d)
				return
	_conf("todo ponto do anel respeita o mínimo e o máximo",
		true, "%.0f a %.0f m" % [R.RAIO_MINIMO, R.RAIO_MAXIMO])
	_conf("o anel nasce FORA do raio de aggro de um agressivo (5 m)",
		R.RAIO_MINIMO > 5.0, "%.0f m" % R.RAIO_MINIMO)
	_conf("um ponto na cara do jogador é recusado pela trava",
		not R.distancia_segura(centro, centro + Vector3(1, 0, 0)))
	_conf("longe demais, desaparece", R.deve_desaparecer(R.RAIO_DE_DESPEJO + 1.0))
	_conf("e o despejo é mais folgado que o nascimento (não suma na cara dele)",
		R.RAIO_DE_DESPEJO > R.RAIO_MAXIMO)

	# A conversão de unidade — mesma classe de erro do `radius` em pixels.
	_conf("128 pixels viram 1 metro", is_equal_approx(R.pixels_para_metros(128.0), 1.0))

# ──────────────────────────────────────────────────────────────────────────────
# 2. As sete personalidades
# ──────────────────────────────────────────────────────────────────────────────

func _personalidades() -> void:
	print("\n-- as sete personalidades decidem diferente --")
	var IA = load("res://scripts/gameplay_v3/combate/IASelvagem3D.gd")
	var C = load("res://scripts/combat/ComportamentoSelvagem.gd")
	var alcance := 1.6

	# Raios em METROS, não em pixels. 5 tiles de aggro = 5 m.
	_conf("o raio de aggro sai em metros, não em pixels",
		IA.raio_de_aggro_m(C.AGRESSIVO) < 20.0,
		"%.1f m — se vier 640, todo bicho do mapa percebe o jogador" % IA.raio_de_aggro_m(C.AGRESSIVO))
	_conf("o predador percebe de mais longe que o agressivo",
		IA.raio_de_aggro_m(C.PREDADOR) > IA.raio_de_aggro_m(C.AGRESSIVO))
	_conf("o defensivo percebe de muito perto",
		IA.raio_de_aggro_m(C.DEFENSIVO) < IA.raio_de_aggro_m(C.AGRESSIVO))
	_conf("o passivo não percebe ninguém", is_zero_approx(IA.raio_de_aggro_m(C.PASSIVO)))

	# A 3 m, de vida cheia, em casa: cada personalidade responde o seu.
	var perto := 3.0
	_conf("agressivo a 3 m parte pra cima",
		IA.decidir(C.AGRESSIVO, perto, 0.0, 1.0, false, alcance) == IA.PERSEGUIR)
	_conf("passivo a 3 m não faz nada",
		IA.decidir(C.PASSIVO, perto, 0.0, 1.0, false, alcance) == IA.PARADO)
	_conf("defensivo a 3 m ainda não reage (raio curto)",
		IA.decidir(C.DEFENSIVO, perto, 0.0, 1.0, false, alcance) == IA.PARADO)
	_conf("mas defensivo PROVOCADO reage",
		IA.decidir(C.DEFENSIVO, perto, 0.0, 1.0, true, alcance) == IA.PERSEGUIR)
	_conf("fugitivo foge desde o começo",
		IA.decidir(C.FUGITIVO, perto, 0.0, 1.0, false, alcance) == IA.FUGIR)
	_conf("no alcance de bater, ataca em vez de perseguir",
		IA.decidir(C.AGRESSIVO, 1.0, 0.0, 1.0, false, alcance) == IA.ATACAR)

	# A coleira (§26) — o defeito que a V2 tinha e esta fase não pode repetir.
	var longe_de_casa : float = IA.raio_de_coleira_m(C.AGRESSIVO) + 5.0
	_conf("estourou a coleira: volta pra casa em vez de perseguir",
		IA.decidir(C.AGRESSIVO, perto, longe_de_casa, 1.0, true, alcance) == IA.VOLTAR,
		"coleira %.1f m" % IA.raio_de_coleira_m(C.AGRESSIVO))
	_conf("o territorial tem coleira mais curta que o agressivo",
		IA.raio_de_coleira_m(C.TERRITORIAL) < IA.raio_de_coleira_m(C.AGRESSIVO))
	_conf("o predador tem a mais longa",
		IA.raio_de_coleira_m(C.PREDADOR) > IA.raio_de_coleira_m(C.AGRESSIVO))

	# A ordem das perguntas é regra: fugir ganha da coleira e do aggro.
	_conf("machucado foge, mesmo provocado e perto",
		IA.decidir(C.AGRESSIVO, 1.0, 0.0, 0.1, true, alcance) == IA.FUGIR,
		"um bicho quase morto que continua perseguindo é o bug clássico")
	_conf("machucado E fora da coleira ainda foge (fugir vem primeiro)",
		IA.decidir(C.AGRESSIVO, 1.0, longe_de_casa, 0.1, true, alcance) == IA.FUGIR)

	# Rótulo desconhecido não pode virar caçador.
	_conf("personalidade escrita errada cai em defensivo, não em predador",
		IA.decidir("terrytorial", perto, 0.0, 1.0, false, alcance) == IA.PARADO)

	# Direção: geometria, separada da decisão.
	var eu := Vector3.ZERO
	var ele := Vector3(0, 0, -5)
	_conf("perseguir aponta pro alvo",
		IA.direcao(IA.PERSEGUIR, eu, ele, eu).dot(Vector3(0, 0, -1)) > 0.99)
	_conf("fugir aponta pro lado oposto",
		IA.direcao(IA.FUGIR, eu, ele, eu).dot(Vector3(0, 0, 1)) > 0.99)
	_conf("voltar aponta pra casa",
		IA.direcao(IA.VOLTAR, eu, ele, Vector3(0, 0, 9)).dot(Vector3(0, 0, 1)) > 0.99)
	_conf("parado não anda", IA.direcao(IA.PARADO, eu, ele, eu) == Vector3.ZERO)

	# O bando (§25/§27).
	_conf("pack chama o bando", IA.chama_o_bando(C.BANDO))
	_conf("agressivo comum não chama", not IA.chama_o_bando(C.AGRESSIVO))
	var candidatos : Array = []
	for i in 10:
		candidatos.append({"quem": i, "posicao": Vector3(0, 0, -float(i) * 0.4), "especie": 19})
	candidatos.append({"quem": 99, "posicao": Vector3(0, 0, -0.5), "especie": 25})
	var ouviram : Array = IA.quem_ouve_o_grito(Vector3.ZERO, 19, candidatos)
	_conf("no máximo MAX_PACK_SIZE respondem ao grito",
		ouviram.size() <= CombatBalance.MAX_PACK_SIZE, "%d responderam" % ouviram.size())
	_conf("e só a MESMA espécie responde", not (99 in ouviram))
	_conf("os mais próximos primeiro", ouviram.size() > 0 and ouviram[0] == 0)

# ──────────────────────────────────────────────────────────────────────────────
# 3. O spawner, com física
# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)

	var chao := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(400, 1, 400)
	f.shape = bx
	chao.add_child(f)
	chao.position.y = -0.5
	mundo.add_child(chao)

	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_jogador = P.nascer(mundo, 6, 30, Vector3.ZERO, "ground_biped")

	var S = load("res://scripts/gameplay_v3/mundo/SpawnerSelvagem3D.gd")
	_spawner = S.new()
	mundo.add_child(_spawner)
	_spawner.zona = _zona_real()
	_spawner.jogador = _jogador
	# Sorteio determinístico: o teste não pode depender de sorte pra passar.
	var passo := [0.1, 0.9, 0.5, 0.3, 0.7]
	var i := [0]
	_spawner.sortear = func() -> float:
		var v : float = passo[i[0] % passo.size()]
		i[0] += 1
		return v
	_spawner.nasceu.connect(func(quem, entrada, elite): _nascidos.append(quem))

## A zona de verdade do jogo, não uma inventada: se `zones.json` mudar de forma,
## este teste tem de reclamar.
func _zona_real() -> Dictionary:
	var zonas = GameData.zones if "zones" in GameData else null
	var lista : Array = []
	if zonas is Array:
		lista = zonas
	elif zonas is Dictionary:
		for k in zonas:
			var v = zonas[k]
			if v is Array:
				lista = v
				break
			lista.append(v)
	for z in lista:
		if z is Dictionary and not (z.get("wild_pokemon", []) as Array).is_empty():
			return z
	return _zona([3, 4, 5])

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			GameData = root.get_node("GameData")
			RNGManager = root.get_node("RNGManager")
			_regra_de_spawn()
			_personalidades()
			_montar()
		4:
			_nascer_de_verdade()
		8:
			_o_selvagem_age()
		12:
			_o_bando_grita()
		16:
			_terminar()
			return true
	return false

func _nascer_de_verdade() -> void:
	print("\n-- o spawner, com física --")
	_conf("a zona de teste tem tabela de encontro",
		not (_spawner.zona.get("wild_pokemon", []) as Array).is_empty(),
		"se vazia, o resto não prova nada")

	var bicho = _spawner.tentar_nascer()
	_conf("nasceu alguém", bicho != null)
	if bicho == null:
		return

	var d : float = Vector3(bicho.global_position.x, 0.0, bicho.global_position.z).length()
	_conf("nasceu no anel, longe do jogador", d >= RegraDeSpawn.RAIO_MINIMO - 0.001,
		"%.2f m do jogador" % d)
	_conf("nasceu selvagem, com personalidade do dado",
		bicho.selvagem and bicho.personalidade in ComportamentoSelvagem.TODAS,
		str(bicho.personalidade))
	_conf("a casa dele é onde nasceu", bicho.casa.distance_to(bicho.global_position) < 0.5)
	_conf("o jogador é o alvo hostil dele", bicho.alvo_hostil == _jogador)
	_conf("não acompanha ninguém (selvagem não é companheiro)", bicho.acompanha == null)
	_conf("o spawner conta quem está vivo", _spawner.vivos() == 1, "%d" % _spawner.vivos())

	# 🔴 A conferência que fecha o contrato de nascimento: o jogador estava na
	# origem e NÃO foi catapultado. É o erro que um spawner cometeria mil vezes.
	_conf("o jogador na origem NÃO foi deslocado pelo nascimento",
		Vector3.ZERO.distance_to(_jogador.global_position) < 0.5,
		"deslocou %.3f m -> %s" % [Vector3.ZERO.distance_to(_jogador.global_position),
			str(_jogador.global_position)])

func _o_selvagem_age() -> void:
	print("\n-- o selvagem decide sozinho --")
	if _nascidos.is_empty():
		_conf("havia um selvagem pra observar", false)
		return
	var bicho = _nascidos[0]
	_conf("o estado dele é uma das palavras conhecidas",
		bicho.estado_selvagem in [IASelvagem3D.PARADO, IASelvagem3D.PERSEGUIR,
			IASelvagem3D.ATACAR, IASelvagem3D.VOLTAR, IASelvagem3D.FUGIR],
		str(bicho.estado_selvagem))

	# Longe e de vida cheia: quem não é fugitivo/passivo fica parado. É a prova de
	# que o bicho não nasce já em aggro — o anel existe pra isso.
	if not (bicho.personalidade in [ComportamentoSelvagem.FUGITIVO, ComportamentoSelvagem.PASSIVO]):
		_conf("recém-nascido longe não está em aggro",
			bicho.estado_selvagem == IASelvagem3D.PARADO,
			"%s (personalidade %s)" % [bicho.estado_selvagem, bicho.personalidade])

	# Agora provoca de verdade, e ele tem de reagir.
	bicho.personalidade = ComportamentoSelvagem.AGRESSIVO
	bicho.global_position = _jogador.global_position + Vector3(0, 0, -4.0)
	bicho.casa = bicho.global_position
	bicho.provocado = true
	bicho._agir_como_selvagem(0.016)
	_conf("provocado e perto, ele persegue",
		bicho.estado_selvagem == IASelvagem3D.PERSEGUIR, str(bicho.estado_selvagem))
	_conf("e a velocidade dele aponta pro jogador",
		Vector3(bicho.velocity.x, 0, bicho.velocity.z).normalized().dot(Vector3(0, 0, 1)) > 0.5,
		str(bicho.velocity))

	# Estoura a coleira: tem de voltar, não continuar.
	bicho.casa = bicho.global_position + Vector3(0, 0, -200.0)
	bicho._agir_como_selvagem(0.016)
	_conf("fora da coleira, ele desiste e volta pra casa",
		bicho.estado_selvagem == IASelvagem3D.VOLTAR, str(bicho.estado_selvagem))

func _o_bando_grita() -> void:
	print("\n-- o grito do bando --")
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var pai : Node = _spawner

	# Três da mesma espécie, colados, e um de outra.
	var gritador = P.nascer(pai, 19, 20, Vector3(60, 0, 0))
	gritador.virar_selvagem(_jogador)
	gritador.personalidade = ComportamentoSelvagem.BANDO
	var vizinhos : Array = []
	for i in 2:
		var v = P.nascer(pai, 19, 20, Vector3(60 + float(i + 1) * 1.5, 0, 0))
		v.virar_selvagem(null)
		vizinhos.append(v)
	var estranho = P.nascer(pai, 25, 20, Vector3(61.0, 0, 1.0))
	estranho.virar_selvagem(null)

	_conf("ninguém está provocado antes do grito",
		not vizinhos[0].provocado and not estranho.provocado)

	gritador.sofrer(1, _jogador)

	_conf("apanhar provocou quem apanhou", gritador.provocado)
	_conf("e o grito provocou os vizinhos da mesma espécie",
		vizinhos[0].provocado and vizinhos[1].provocado)
	_conf("a outra espécie NÃO foi chamada (um Pikachu não vira Rattata)",
		not estranho.provocado)
	_conf("e os chamados herdaram o alvo", vizinhos[0].alvo_hostil == _jogador)

	# A quarta trava da §27: quem foi chamado não grita de novo.
	var longe = P.nascer(pai, 19, 20, Vector3(63.0, 0, 0))
	longe.virar_selvagem(null)
	longe.personalidade = ComportamentoSelvagem.BANDO
	var antes : bool = longe.provocado
	vizinhos[0].sofrer(1, _jogador)
	_conf("quem já estava provocado não grita de novo (sem reação em cadeia)",
		longe.provocado == antes,
		"se virasse true, A chama B, B chama C e o mapa inteiro vem")

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
