## teste_gameplay_v3_fase13.gd — Voltar a ser o treinador (Fase 13).
##
## É a fase que **fecha o laço da fantasia**, e a própria RFC avisa qual é o
## risco:
##
## > *"A transferência e a volta são o que precisa ser provado primeiro. Um
## > combate bom que não devolve o controle direito quebra a fantasia inteira."*
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Ficar preso no Pokémon.** Se a volta falhar, o jogador perde o
##      treinador pra sempre — e, como na Fase 12, é o tipo de bug que não trava
##      o jogo, só prende quem está jogando.
##   2. **O treinador virar saída de emergência.** Se desse pra voltar com cinco
##      mobs em cima, o perigo do mundo aberto evaporaria apertando uma tecla.
##   3. **Voltar virado pra trás.** A luta gira o jogador; devolvê-lo olhando
##      pro outro lado é desorientação gratuita.
##   4. **Vitória forçando transição.** Vencer NÃO devolve o controle — no mundo
##      aberto, o jogador continua sendo o Pokémon até decidir o contrário.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _treinador = null
var _pokemon = null
var _selvagem = null
var _retorno = null
var _combate = null
var _arbitro = null
var _voltas : Array = []
var _recusas : Array = []

var EventBus : Node
var GameData : Node

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 13: voltar a ser o treinador ===")
	_regras()

# ──────────────────────────────────────────────────────────────────────────────
# 1. As regras
# ──────────────────────────────────────────────────────────────────────────────

func _regras() -> void:
	print("\n-- quando a volta é forçada --")
	var R = load("res://scripts/gameplay_v3/controle/RegraDeRetorno.gd")
	var C = load("res://scripts/gameplay_v3/combate/RegraDeCombate.gd")

	_conf("derrota devolve o controle sozinha (§4)", R.volta_forcada(C.DERROTA))
	_conf("e deixa o treinador VULNERÁVEL", R.treinador_vulneravel(C.DERROTA, false))

	# 🔴 A decisão que separa isto de um jogo de transições.
	_conf("VITÓRIA não devolve nada", not R.volta_forcada(C.VITORIA),
		"forçar a volta a cada vitória viraria uma sequência de telas de transição")
	_conf("fuga também não", not R.volta_forcada(C.FUGA))
	_conf("com outro Pokémon em pé, a derrota não devolve",
		not R.volta_forcada(C.DERROTA, true))
	_conf("e aí o treinador não fica vulnerável",
		not R.treinador_vulneravel(C.DERROTA, true))

	print("\n-- quando a volta por vontade é recusada --")
	var pode := func(vivo, anunciando, hostis, ja): return R.pode_voltar(vivo, anunciando, hostis, ja)

	_conf("sem ninguém por perto, pode voltar", bool(pode.call(true, false, 0, false)["pode"]))

	# 🔴 A regra que impede o corpo do treinador de virar esconderijo.
	var com_hostil : Dictionary = pode.call(true, false, 5, false)
	_conf("com hostil por perto, NÃO pode", not bool(com_hostil["pode"]),
		"senão o treinador vira saída de emergência e o perigo do mundo evapora")
	_conf("e a recusa DIZ quantos são, em português",
		str(com_hostil["motivo"]).contains("5"), str(com_hostil["motivo"]))

	_conf("no meio de um golpe anunciado, não pode",
		not bool(pode.call(true, true, 0, false)["pode"]))
	_conf("já sendo o treinador, não faz sentido",
		not bool(pode.call(true, false, 0, true)["pode"]))
	_conf("com o Pokémon caído, a volta já aconteceu sozinha",
		not bool(pode.call(false, false, 0, false)["pode"]))
	for caso in [[true, true, 0, false], [true, false, 3, false], [false, false, 0, false]]:
		_conf("toda recusa traz motivo legível", str(pode.callv(caso)["motivo"]).length() > 10)

	print("\n-- quem conta como ameaça --")
	var centro := Vector3.ZERO
	var perto_hostil := {"posicao": Vector3(0, 0, -2), "hostil": true, "vivo": true}
	var perto_pacifico := {"posicao": Vector3(0, 0, -2), "hostil": false, "vivo": true}
	var perto_morto := {"posicao": Vector3(0, 0, -2), "hostil": true, "vivo": false}
	var longe_hostil := {"posicao": Vector3(0, 0, -50), "hostil": true, "vivo": true}
	_conf("hostil perto conta", R.contar_hostis(centro, [perto_hostil]) == 1)
	_conf("pacífico perto NÃO conta", R.contar_hostis(centro, [perto_pacifico]) == 0,
		"um bicho passivo ao lado não é motivo pra prender o jogador no Pokémon")
	_conf("hostil morto não conta", R.contar_hostis(centro, [perto_morto]) == 0)
	_conf("hostil longe não conta", R.contar_hostis(centro, [longe_hostil]) == 0)
	_conf("conta todos os que valem",
		R.contar_hostis(centro, [perto_hostil, perto_hostil, longe_hostil, perto_morto]) == 2)
	_conf("o raio de ameaça é MAIOR que a distância de engajamento",
		R.RAIO_DE_AMEACA > C.DISTANCIA_DE_ENGAJAMENTO,
		"%.1f vs %.1f m — sair no milímetro antes de apanhar é a mesma esquiva"
			% [R.RAIO_DE_AMEACA, C.DISTANCIA_DE_ENGAJAMENTO])

	_conf("o yaw da volta é o do Pokémon (não se volta virado pra trás)",
		is_equal_approx(R.yaw_de_volta(1.234), 1.234))
	for r in [C.VITORIA, C.DERROTA, C.FUGA]:
		_conf("o fim '%s' tem frase de volta" % r, R.frase(r, false).length() > 10)
	_conf("a volta forçada tem frase própria, e ela avisa da solidão",
		R.frase(C.DERROTA, true).contains("sozinho"), R.frase(C.DERROTA, true))

# ──────────────────────────────────────────────────────────────────────────────
# 2. Com mundo
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

	var T = load("res://scripts/gameplay_v3/entidades/TrainerController3D.gd")
	_treinador = T.new()
	_treinador.position = Vector3.ZERO
	mundo.add_child(_treinador)

	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_pokemon = P.nascer(mundo, 6, 40, Vector3(2, 0, 0), "ground_biped")

	var CM = load("res://scripts/gameplay_v3/controle/ControlModeManager.gd")
	_arbitro = CM.new()
	mundo.add_child(_arbitro)
	_arbitro.registrar(ControlModeManager.WORLD, _treinador)
	_arbitro.registrar(ControlModeManager.COMBAT, _pokemon)

	var Cb = load("res://scripts/gameplay_v3/combate/Combate1v1.gd")
	_combate = Cb.new()
	mundo.add_child(_combate)
	_combate.pokemon_do_jogador = _pokemon

	var Rt = load("res://scripts/gameplay_v3/controle/RetornoAoMundo.gd")
	_retorno = Rt.new()
	_retorno.treinador = _treinador
	_retorno.pokemon = _pokemon
	_retorno.arbitro = _arbitro
	mundo.add_child(_retorno)
	_retorno.escutar(_combate)
	_retorno.voltou.connect(func(f, v, m): _voltas.append({"forcada": f, "vulneravel": v, "motivo": m}))
	_retorno.recusou.connect(func(m): _recusas.append(m))

	# O jogador assume o Pokémon: é o estado de onde a volta parte.
	_arbitro.trocar_para(ControlModeManager.COMBAT)
	_pokemon.assumir_controle(1.5)

	# Um selvagem hostil, longe o bastante pra não atrapalhar ainda.
	_selvagem = P.nascer(mundo, 19, 20, Vector3(60, 0, 0))
	_selvagem.virar_selvagem(_pokemon)
	_selvagem.provocado = true

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			EventBus = root.get_node("EventBus")
			GameData = root.get_node("GameData")
			_montar()
		4:
			_volta_por_vontade()
		8:
			_com_hostil_nao_sai()
		12:
			_a_queda_devolve()
		16:
			_terminar()
			return true
	return false

func _volta_por_vontade() -> void:
	print("\n-- voltar por vontade, com o caminho livre --")
	_conf("o jogador está controlando o Pokémon", _pokemon.controlado_pelo_jogador)
	_conf("e o árbitro concorda", str(_arbitro.modo) == ControlModeManager.COMBAT)

	var r : Dictionary = _retorno.tentar_voltar()
	_conf("a volta foi aceita", bool(r["pode"]), str(r))
	_conf("o árbitro trocou pro mundo", str(_arbitro.modo) == ControlModeManager.WORLD)
	_conf("o Pokémon largou o controle", not _pokemon.controlado_pelo_jogador)

	# §12: um dono de input por vez — e é aqui que a troca poderia deixar dois.
	_conf("só um controlador ativo depois da troca", _arbitro.quantos_ativos() == 1)
	_conf("o treinador voltou a escutar", _treinador.is_processing_input())
	_conf("e o Pokémon parou de escutar", not _pokemon.is_processing_input())

	# 🔴 O ângulo. A luta girou o jogador (yaw 1.5); ele não pode voltar olhando
	# pro norte do mundo como se nada tivesse acontecido.
	_conf("a câmera do treinador herdou o ângulo da luta",
		absf(angle_difference(_treinador.camera.yaw(), 1.5)) < 0.01,
		"veio %.3f, esperado 1.500" % _treinador.camera.yaw())

	_conf("o Pokémon voltou a acompanhar o treinador", _pokemon.acompanha == _treinador)
	_conf("a volta foi anunciada como NÃO forçada",
		_voltas.size() == 1 and not bool(_voltas[0]["forcada"]))
	_conf("e sem vulnerabilidade — ninguém caiu", not bool(_voltas[0]["vulneravel"]))

func _com_hostil_nao_sai() -> void:
	print("\n-- com hostil por perto, não sai --")
	# Volta a ser o Pokémon e traz o selvagem pra cima.
	_arbitro.trocar_para(ControlModeManager.COMBAT)
	_pokemon.assumir_controle(0.0)
	_selvagem.global_position = _pokemon.global_position + Vector3(0, 0, -2.0)
	_selvagem.provocado = true

	var antes : int = _voltas.size()
	var r : Dictionary = _retorno.tentar_voltar()
	_conf("a volta foi recusada", not bool(r["pode"]), str(r))
	_conf("e o jogador CONTINUA sendo o Pokémon", _pokemon.controlado_pelo_jogador,
		"se saísse, o treinador seria saída de emergência")
	_conf("nenhuma volta foi anunciada", _voltas.size() == antes)
	_conf("a recusa chegou na tela com motivo",
		_recusas.size() > 0 and str(_recusas[-1]).length() > 10, str(_recusas))

func _a_queda_devolve() -> void:
	print("\n-- a queda devolve, e deixa o treinador sozinho --")
	var antes : int = _voltas.size()

	# Começa uma briga de verdade e derruba o Pokémon do jogador.
	_combate.iniciar(_pokemon, _selvagem)
	_conf("a briga começou", _combate.em_combate())
	_pokemon.sofrer(999999, _selvagem)
	_combate._tick(0.016)

	_conf("a briga terminou em derrota", not _combate.em_combate())
	_conf("e a volta aconteceu SOZINHA", _voltas.size() == antes + 1,
		"cair não é escolha, é consequência (§4)")
	if _voltas.size() <= antes:
		return
	var v : Dictionary = _voltas[-1]
	_conf("marcada como forçada", bool(v["forcada"]))
	_conf("e com o treinador VULNERÁVEL", bool(v["vulneravel"]),
		"é o estado que dá peso a estar sem ninguém fora da ball")
	_conf("a frase avisa que ele está sozinho", str(v["motivo"]).contains("sozinho"),
		str(v["motivo"]))
	_conf("o jogador é o treinador de novo", str(_arbitro.modo) == ControlModeManager.WORLD)

	# 🔴 Um Pokémon desmaiado não segue ninguém.
	_conf("o Pokémon caído NÃO voltou a acompanhar", _pokemon.acompanha == null,
		"um desmaiado andando atrás do treinador seria zumbi")

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
