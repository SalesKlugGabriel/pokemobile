## teste_gameplay_v3_fase14_15.gd — Travessia: água (14) e ar (15).
##
## ── O princípio que decide tudo aqui ────────────────────────────────────────
##
## §27: **travessia é movimento, não teletransporte.** E na V3 isso ganha uma
## consequência que a V2 não tinha: **surfar é assumir um Pokémon que nada.** Não
## existe "o treinador em cima de um bicho" — existe o jogador *sendo* o bicho.
## Voar é o mesmo, com outro arquétipo.
##
## Então estas duas fases quase não inventam nada: elas ligam `MovementProfile`
## (que já sabe quem nada e quem voa), `Terreno3D.superficie_em` (que já sabe
## onde é água) e `Mergulho` (que já tem oxigênio, profundidade e a roupa).
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Parede invisível na beira da praia.** Barrar água rasa quebraria
##      justamente o lugar onde o jogador mais anda.
##   2. **Água profunda deixar de ser obstáculo.** Sem esse limite, o Surf vira
##      enfeite e a travessia não significa nada.
##   3. **O bug de 14/09 voltando.** `profundidade_atual()` lia uma propriedade
##      que nunca existiu e o abismo cobrava oxigênio de água rasa — invisível
##      por três dias, porque não dava erro: só devolvia o padrão.
##   4. **Teto de voo absoluto.** Faria o jogador esbarrar num limite invisível
##      ao subir a montanha, e voar mais alto no vale do que no pico.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _terrestre = null
var _aquatico = null
var _voador = null

var GameData : Node

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fases 14 e 15: travessia ===")
	_agua()
	_mergulho()
	_ar()

# ──────────────────────────────────────────────────────────────────────────────
# Fase 14 — água
# ──────────────────────────────────────────────────────────────────────────────

func _agua() -> void:
	print("\n-- quem pode estar na água --")
	var T = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	var M = load("res://scripts/gameplay_v3/pokemon/MovementProfile.gd")

	_conf("água rasa e profunda contam como água",
		T.e_agua(T.AGUA_RASA) and T.e_agua(T.AGUA_PROFUNDA))
	_conf("areia, terra e rocha não", not T.e_agua(T.AREIA)
		and not T.e_agua(T.TERRA) and not T.e_agua(T.ROCHA))

	# 🔴 A regra que evita a parede invisível na praia.
	_conf("terrestre PODE andar em água rasa",
		T.pode_estar_em(M.GROUND_BIPED, T.AGUA_RASA),
		"barrar isso criaria parede invisível justamente na borda da praia")
	_conf("terrestre NÃO pode em água profunda",
		not T.pode_estar_em(M.GROUND_BIPED, T.AGUA_PROFUNDA),
		"é o limite que dá sentido ao Surf")
	_conf("terrestre anda em terra, óbvio",
		T.pode_estar_em(M.GROUND_BIPED, T.TERRA))

	_conf("aquático vai a qualquer água", T.pode_estar_em(M.AQUATIC, T.AGUA_PROFUNDA))
	_conf("e também em terra — 'nada' não é 'só serve pra água'",
		T.pode_estar_em(M.AQUATIC, T.TERRA))
	# 🔴 O anfíbio ainda NÃO está implementado (§16: "não implementar todos"), e o
	# que importa é que o fallback seja **declarado e avisado**, não silencioso.
	# Minha primeira versão afirmou que ele nadava — e ele cai em GROUND_BIPED.
	_conf("anfíbio ainda não implementado, e o perfil AVISA em vez de fingir",
		not M.implementado(M.AMPHIBIOUS)
		and M.obter(M.AMPHIBIOUS) == M.obter(M.GROUND_BIPED),
		"asset/arquétipo faltando tem de ser visível, nunca um default calado")

	# ⚠️ O voador passa por cima: ele não está NA água.
	_conf("voador atravessa água profunda", T.pode_estar_em(M.FLYING, T.AGUA_PROFUNDA),
		"ele não está na água, está acima dela")

	_conf("terrestre precisa de Surf pra água profunda",
		T.precisa_de_surf(M.GROUND_BIPED, T.AGUA_PROFUNDA))
	_conf("quem nada não precisa", not T.precisa_de_surf(M.AQUATIC, T.AGUA_PROFUNDA))
	_conf("ninguém precisa de Surf pra água rasa",
		not T.precisa_de_surf(M.GROUND_BIPED, T.AGUA_RASA))

func _mergulho() -> void:
	print("\n-- profundidade, e o bug de 14/09 --")
	var T = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	var M = load("res://scripts/gameplay_v3/pokemon/MovementProfile.gd")

	# 🔴 A profundidade sai da ALTURA DO TERRENO — a fonte única da geografia.
	# A versão 2D lia uma propriedade inexistente e devolvia o padrão em silêncio.
	_conf("acima do nível do mar não é água", T.profundidade_em(3.0) == "")
	_conf("logo abaixo é raso", T.profundidade_em(-1.0) == Mergulho.RASO)
	_conf("mais fundo é meio", T.profundidade_em(-3.0) == Mergulho.MEIO)
	_conf("bem fundo é abismo", T.profundidade_em(-30.0) == Mergulho.ABISSO,
		"o abismo cobrando oxigênio de água rasa foi o bug de 14/09")

	# 🔴 E a conferência que a primeira versão deste teste NÃO tinha, e por isso
	# não pegou que eu havia inventado os limiares: o abismo precisa ser
	# ALCANÇÁVEL no terreno real. Com −4 m e −12 m cravados, e o fundo do mundo
	# em −7,27 m, ele não existia.
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	var mais_fundo : float = 999.0
	for x in range(0, 300, 5):
		for z in range(0, 300, 5):
			mais_fundo = minf(mais_fundo, Ter.altura_em(float(x), float(z)))
	_conf("as TRÊS profundidades existem no terreno de verdade",
		T.profundidade_em(mais_fundo) == Mergulho.ABISSO,
		"o ponto mais fundo do mundo é %.2f m e caiu em '%s'"
			% [mais_fundo, T.profundidade_em(mais_fundo)])
	_conf("e o limiar do raso é o MESMO que o terreno usa",
		T.profundidade_em(Ter.AGUA_RASA_ATE - 0.01) != Mergulho.RASO
		and T.profundidade_em(Ter.AGUA_RASA_ATE + 0.01) == Mergulho.RASO,
		"duas definições de 'fundo' discordando foi o erro da primeira versão")

	# A prova de que as três profundidades são MESMO diferentes: o consumo muda.
	var c_raso := Mergulho.consumo_por_segundo(Mergulho.RASO, false)
	var c_meio := Mergulho.consumo_por_segundo(Mergulho.MEIO, false)
	var c_abisso := Mergulho.consumo_por_segundo(Mergulho.ABISSO, false)
	_conf("o abismo consome mais que o meio, que consome mais que o raso",
		c_abisso > c_meio and c_meio > c_raso,
		"%.1f > %.1f > %.1f" % [c_abisso, c_meio, c_raso])
	_conf("com a roupa, o consumo cai",
		Mergulho.consumo_por_segundo(Mergulho.ABISSO, true) < c_abisso,
		"a quest desbloqueia a PERMANÊNCIA, não a área")

	_conf("não dá pra mergulhar em água rasa",
		not T.pode_mergulhar(M.AQUATIC, -1.0),
		"seria raspar a barriga na areia")
	_conf("dá pra mergulhar onde há fundo", T.pode_mergulhar(M.AQUATIC, -3.0))
	_conf("quem não nada não mergulha", not T.pode_mergulhar(M.GROUND_BIPED, -3.0))

# ──────────────────────────────────────────────────────────────────────────────
# Fase 15 — ar
# ──────────────────────────────────────────────────────────────────────────────

func _ar() -> void:
	print("\n-- voo, e as três zonas (§29) --")
	var T = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	var M = load("res://scripts/gameplay_v3/pokemon/MovementProfile.gd")

	var livre := {"id": "campo"}
	var restrito := {"id": "desfiladeiro", "voo": T.VOO_RESTRITO}
	var proibido := {"id": "caverna", "voo": T.VOO_PROIBIDO}

	_conf("zona sem declaração é voo livre (padrão permissivo)",
		T.regra_de_voo_da_zona(livre) == T.VOO_LIVRE)
	_conf("zona com valor inválido também cai em livre, não estoura",
		T.regra_de_voo_da_zona({"voo": "voar_muito"}) == T.VOO_LIVRE)

	_conf("voador decola em zona livre", bool(T.pode_voar(M.FLYING, livre)["pode"]))
	_conf("terrestre não decola em lugar nenhum",
		not bool(T.pode_voar(M.GROUND_BIPED, livre)["pode"]))
	_conf("e a recusa DIZ por quê",
		str(T.pode_voar(M.GROUND_BIPED, livre)["motivo"]).length() > 10,
		str(T.pode_voar(M.GROUND_BIPED, livre)["motivo"]))
	_conf("em zona proibida, nem o voador decola",
		not bool(T.pode_voar(M.FLYING, proibido)["pode"]),
		"voar por cima de uma dungeon precisa ser decisão declarada no dado")
	_conf("em zona restrita ele decola", bool(T.pode_voar(M.FLYING, restrito)["pode"]))

	_conf("o teto restrito é mais baixo que o livre",
		T.teto_de_voo(restrito) < T.teto_de_voo(livre),
		"%.0f vs %.0f m" % [T.teto_de_voo(restrito), T.teto_de_voo(livre)])
	_conf("em zona proibida o teto é zero", is_zero_approx(T.teto_de_voo(proibido)))

	# 🔴 O teto é RELATIVO ao terreno. Absoluto faria o jogador esbarrar num
	# limite invisível ao subir a montanha.
	var no_vale : float = T.altitude_maxima(2.0, livre)
	var no_pico : float = T.altitude_maxima(80.0, livre)
	_conf("o teto acompanha o terreno — no pico dá pra voar mais alto",
		no_pico > no_vale,
		"vale %.0f m, pico %.0f m — absoluto seria parede invisível na subida"
			% [no_vale, no_pico])
	_conf("e a folga é a MESMA nos dois",
		is_equal_approx(no_pico - 80.0, no_vale - 2.0))

	_conf("acima do teto é detectado", T.acima_do_teto(200.0, 2.0, livre))
	_conf("dentro do teto, não", not T.acima_do_teto(50.0, 2.0, livre))

# ──────────────────────────────────────────────────────────────────────────────
# Com mundo
# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	var terreno = Ter.new()
	mundo.add_child(terreno)

	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	# Um de cada arquétipo, como manda a §16: um basta pra provar.
	_terrestre = P.nascer(mundo, 6, 30, _ponto_seco(), "ground_biped")
	_aquatico  = P.nascer(mundo, 130, 30, _ponto_seco() + Vector3(4, 0, 0), "aquatic")
	_voador    = P.nascer(mundo, 18, 30, _ponto_seco() + Vector3(8, 0, 0), "flying")

## Um ponto de terra firme, achado pelo próprio terreno — não chutado.
func _ponto_seco() -> Vector3:
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	for x in range(0, 200, 7):
		for z in range(0, 200, 7):
			if Ter.superficie_em(float(x), float(z)) == RegraDeTravessia.TERRA:
				return Vector3(float(x), Ter.altura_em(float(x), float(z)), float(z))
	return Vector3.ZERO

## E um ponto de água profunda, idem.
func _ponto_fundo() -> Vector3:
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	for x in range(0, 200, 5):
		for z in range(0, 200, 5):
			if Ter.superficie_em(float(x), float(z)) == RegraDeTravessia.AGUA_PROFUNDA:
				return Vector3(float(x), 1.0, float(z))
	return Vector3.ZERO

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			GameData = root.get_node("GameData")
			_montar()
		5:
			_no_mundo()
		9:
			_terminar()
			return true
	return false

func _no_mundo() -> void:
	print("\n-- com o terreno de verdade --")
	var fundo := _ponto_fundo()
	_conf("o terreno tem água profunda pra testar", fundo != Vector3.ZERO,
		"sem isso o resto não prova nada")
	if fundo == Vector3.ZERO:
		return

	# O terrestre é devolvido; o aquático fica.
	_terrestre.global_position = fundo
	_terrestre._tick_travessia(0.016)
	_conf("o terrestre foi DEVOLVIDO da água profunda",
		Vector2(_terrestre.global_position.x - fundo.x,
				_terrestre.global_position.z - fundo.z).length() > 0.5,
		"empurrar de volta é melhor que parede invisível")

	_aquatico.global_position = fundo
	_aquatico._tick_travessia(0.016)
	_conf("o aquático FICA na água profunda",
		Vector2(_aquatico.global_position.x - fundo.x,
				_aquatico.global_position.z - fundo.z).length() < 0.01)

	# Mergulhar, e o oxigênio caindo.
	var r : Dictionary = _aquatico.alternar_mergulho()
	_conf("o aquático consegue mergulhar onde há fundo", bool(r["pode"]), str(r))
	var antes : float = _aquatico.oxigenio
	for i in 20:
		_aquatico._tick_travessia(0.1)
	_conf("o oxigênio cai enquanto submerso", _aquatico.oxigenio < antes,
		"%.1f -> %.1f" % [antes, _aquatico.oxigenio])

	var no_fundo : float = _aquatico.oxigenio
	_aquatico.alternar_mergulho()
	for i in 20:
		_aquatico._tick_travessia(0.1)
	_conf("e volta a subir depois de emergir", _aquatico.oxigenio > no_fundo,
		"%.1f -> %.1f" % [no_fundo, _aquatico.oxigenio])

	# O terrestre nem tenta mergulhar.
	var rt : Dictionary = _terrestre.alternar_mergulho()
	_conf("o terrestre não mergulha, e ouve o motivo",
		not bool(rt["pode"]) and str(rt["motivo"]).length() > 10, str(rt))

	# Teto de voo.
	_voador.zona = {"voo": RegraDeTravessia.VOO_RESTRITO}
	var chao := Terreno3D.altura_em(_voador.global_position.x, _voador.global_position.z)
	_voador.global_position.y = chao + 500.0
	_voador._tick_travessia(0.016)
	_conf("o voador é segurado no teto da zona restrita",
		_voador.global_position.y <= chao + RegraDeTravessia.TETO_RESTRITO + 0.1,
		"y = %.1f, teto = %.1f" % [_voador.global_position.y, chao + RegraDeTravessia.TETO_RESTRITO])

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
