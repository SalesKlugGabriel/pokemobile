## teste_gameplay_v3_fase12.gd — Combate 1v1 (Fase 12).
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Briga que nunca termina.** Dois lutadores presos em lados opostos de
##      uma pedra ficariam "em combate" pra sempre, e o jogador jamais
##      recuperaria o treinador. É o pior bug possível desta fase, porque não
##      trava o jogo — só o prende.
##   2. **Vitória com o próprio Pokémon desmaiado.** Se os dois caírem no mesmo
##      quadro, perder empatado é perder.
##   3. **1v1 que vira 1v3.** Sem arena, nada impede o terceiro de entrar
##      andando. E o remédio errado — congelar todo mundo — é tão ruim quanto o
##      problema.
##   4. **Fim sem evento.** Já dava pra bater num selvagem e vê-lo cair antes
##      desta fase. O que não existia era alguém poder dizer *que uma batalha
##      começou, terminou, e como*.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _mundo : Node3D = null
var _combate = null
var _meu = null
var _selvagem = null
var _terceiro = null
var _comecos : Array = []
var _fins : Array = []

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
	print("=== Fase 12: combate 1v1 ===")
	_regras()

# ──────────────────────────────────────────────────────────────────────────────
# 1. As regras, sem mundo
# ──────────────────────────────────────────────────────────────────────────────

func _regras() -> void:
	print("\n-- começar e terminar, como regra --")
	var R = load("res://scripts/gameplay_v3/combate/RegraDeCombate.gd")

	# Começar.
	_conf("hostil e perto começa briga",
		R.pode_comecar(2.0, true, true, true, false))
	_conf("hostil mas longe, ainda não",
		not R.pode_comecar(9.0, true, true, true, false))
	_conf("perto mas não hostil, não",
		not R.pode_comecar(2.0, false, true, true, false))
	_conf("com alguém morto, não",
		not R.pode_comecar(2.0, true, false, true, false))
	_conf("já em combate, NENHUMA outra começa (é a trava do 1v1)",
		not R.pode_comecar(2.0, true, true, true, true))
	_conf("engajar acontece mais perto que perceber (5 m de aggro)",
		R.DISTANCIA_DE_ENGAJAMENTO < 5.0,
		"%.1f m — o bicho vê, vem, e SÓ ENTÃO a briga começa" % R.DISTANCIA_DE_ENGAJAMENTO)

	# Terminar.
	_conf("selvagem caiu = vitória",
		R.resultado(true, false, 2.0, 0.0) == R.VITORIA)
	_conf("meu Pokémon caiu = derrota",
		R.resultado(false, true, 2.0, 0.0) == R.DERROTA)

	# 🔴 A ordem, e o caso que justifica ela existir.
	_conf("os DOIS caindo no mesmo quadro é DERROTA, não vitória",
		R.resultado(false, false, 2.0, 0.0) == R.DERROTA,
		"perder empatado é perder — vitória com o próprio Pokémon desmaiado não existe")

	_conf("longe demais = fuga", R.resultado(true, true, 99.0, 0.0) == R.FUGA)
	_conf("quem caiu NÃO fugiu (morte ganha da distância)",
		R.resultado(false, true, 99.0, 0.0) == R.DERROTA)
	_conf("tempo demais sem ninguém apanhar = fuga",
		R.resultado(true, true, 2.0, R.SEGUNDOS_SEM_NADA_ATE_DESFAZER + 1.0) == R.FUGA,
		"é a válvula contra a briga pendurada pra sempre")
	_conf("os dois vivos, perto e trocando golpes = em curso",
		R.resultado(true, true, 2.0, 0.5) == R.EM_CURSO)
	_conf("fugir é MAIS longe que engajar (dois passos pra trás não encerram)",
		R.DISTANCIA_DE_FUGA > R.DISTANCIA_DE_ENGAJAMENTO * 3.0,
		"%.0f vs %.1f m" % [R.DISTANCIA_DE_FUGA, R.DISTANCIA_DE_ENGAJAMENTO])

	_conf("acabou() reconhece os três finais e só eles",
		R.acabou(R.VITORIA) and R.acabou(R.DERROTA) and R.acabou(R.FUGA)
		and not R.acabou(R.EM_CURSO))
	for r in [R.VITORIA, R.DERROTA, R.FUGA]:
		_conf("o resultado '%s' tem frase em português" % r, R.frase(r).length() > 10)

	_conf("terceiro NÃO engaja quem já está em combate", not R.pode_engajar(true))
	_conf("mas engaja quem está livre", R.pode_engajar(false))

# ──────────────────────────────────────────────────────────────────────────────
# 2. Com mundo
# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	EventBus.battle_started.connect(func(): _comecos.append(true))
	EventBus.battle_ended.connect(func(d): _fins.append(d))

	_mundo = Node3D.new()
	root.add_child(_mundo)
	var chao := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(400, 1, 400)
	f.shape = bx
	chao.add_child(f)
	chao.position.y = -0.5
	_mundo.add_child(chao)

	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_meu = P.nascer(_mundo, 6, 40, Vector3.ZERO, "ground_biped")
	_meu.assumir_controle(0.0)

	_selvagem = P.nascer(_mundo, 19, 20, Vector3(0, 0, -2.0))
	_selvagem.virar_selvagem(_meu)
	_selvagem.personalidade = ComportamentoSelvagem.AGRESSIVO

	_terceiro = P.nascer(_mundo, 19, 20, Vector3(0, 0, -4.0))
	_terceiro.virar_selvagem(_meu)
	_terceiro.personalidade = ComportamentoSelvagem.AGRESSIVO

	var C = load("res://scripts/gameplay_v3/combate/Combate1v1.gd")
	_combate = C.new()
	_mundo.add_child(_combate)
	_combate.pokemon_do_jogador = _meu
	_combate.comecou.connect(func(a, b): pass)
	_combate.terminou.connect(func(r, a, b): pass)

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			EventBus = root.get_node("EventBus")
			GameData = root.get_node("GameData")
			_montar()
		4:
			_comecou_sozinho()
		8:
			_o_terceiro_fica_de_fora()
		12:
			_vitoria()
		16:
			_fuga()
		20:
			_terminar()
			return true
	return false

func _comecou_sozinho() -> void:
	print("\n-- a briga começa sozinha, por proximidade --")
	_conf("o combate começou", _combate.em_combate(),
		"o selvagem agressivo estava a 2 m")
	if not _combate.em_combate():
		return
	_conf("com o meu Pokémon de um lado", _combate.defensor == _meu)
	_conf("e o selvagem do outro", _combate.selvagem == _selvagem)
	_conf("o sinal do EventBus saiu pra tela", _comecos.size() == 1)

	# O alvo do selvagem trocou: ele mirava o Pokémon do jogador, e continua —
	# mas agora é oficial, e ele está provocado.
	_conf("o selvagem está mirando quem vai lutar com ele",
		_selvagem.alvo_hostil == _meu and _selvagem.provocado)

	# A trava do 1v1.
	_conf("nenhuma outra briga começa enquanto esta corre",
		not _combate.iniciar(_meu, _terceiro))

func _o_terceiro_fica_de_fora() -> void:
	print("\n-- o terceiro não entra, e também não congela --")
	_terceiro._agir_como_selvagem(0.016)
	_conf("o terceiro largou o alvo que está em combate",
		_terceiro.alvo_hostil == null,
		"se continuasse mirando, viraria 1v2")
	# ⚠️ E o remédio não pode ser pior que a doença.
	_conf("mas ele NÃO está congelado — a IA dele continua rodando",
		_terceiro.estado_selvagem in [IASelvagem3D.PARADO, IASelvagem3D.PERSEGUIR,
			IASelvagem3D.VOLTAR, IASelvagem3D.FUGIR, IASelvagem3D.ATACAR],
		"estado: %s" % str(_terceiro.estado_selvagem))

func _vitoria() -> void:
	print("\n-- vencer --")
	_selvagem.sofrer(999999, _meu)
	_combate._tick(0.016)
	_conf("derrubar o selvagem termina a briga", not _combate.em_combate())
	_conf("e o resultado é vitória",
		_fins.size() == 1 and str(_fins[0].get("resultado")) == RegraDeCombate.VITORIA,
		str(_fins))

func _fuga() -> void:
	print("\n-- fugir --")
	# O terceiro vira o adversário da vez.
	_terceiro.provocado = true
	_terceiro.alvo_hostil = _meu
	_terceiro.global_position = _meu.global_position + Vector3(0, 0, -2.0)
	_conf("uma briga nova pode começar depois da anterior acabar",
		_combate.iniciar(_meu, _terceiro))

	# Agora o jogador vai embora.
	_meu.global_position += Vector3(0, 0, 200.0)
	_combate._tick(0.016)
	_conf("afastar-se encerra a briga", not _combate.em_combate())
	_conf("e o resultado é fuga",
		_fins.size() == 2 and str(_fins[1].get("resultado")) == RegraDeCombate.FUGA,
		str(_fins))

	# 🔴 E o selvagem que sobreviveu volta a viver a vida dele. Se continuasse
	# provocado e mirando, ele perseguiria o jogador pelo mapa — e a coleira da
	# Fase 11 o traria pra casa com o alvo errado na cabeça.
	_conf("quem sobreviveu à fuga deixa de estar provocado",
		not _terceiro.provocado and _terceiro.alvo_hostil == null)

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
