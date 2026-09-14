## teste_laboratorio_v2.gd — O protótipo vertical roda de verdade?
##
## Diferente de `teste_gameplay_v2.gd`, que prova CONTAS, este carrega a cena,
## deixa o jogo rodar frames de verdade e confere que a coisa acontece:
## o treinador anda, o Pokémon obedece, o selvagem persegue e alguém cai.
##
## Por que isso importa: as três perguntas da §68 são sobre SENTIR, e nenhum
## teste responde isso. Mas "o Pokémon nunca chega perto do alvo" é um bug que
## um teste pega, e é o tipo de coisa que faria o Gabriel perder a sessão de
## playtest inteira descobrindo o que eu podia ter descoberto aqui.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _fase : int = 0
## Tempo REAL, não quadros. Em headless o laço principal corre muito mais rápido
## que a física de 60 Hz: contar quadros media quase nenhum tempo simulado, e o
## treinador aparecia "andando 0 px" quando o código estava certo. Foi o
## primeiro achado deste teste, e era do teste, não do jogo.
var _tempo : float = 0.0
var _lab : Node2D = null
var _erro_ao_montar : String = ""

## Autoload não é identificador em teste `--script` — preenchido no 1º quadro.
var PonteDeFeedback : Node

# Nenhuma classe da V2 é citada por NOME neste arquivo, de propósito: citar
# `TreinadorV2` obriga o Godot a compilá-la agora, e ela usa autoload — que
# ainda não existe. A cena é carregada por caminho e o resto é acesso por nome
# de campo. Mesma armadilha de `teste_gameplay_v2.gd`, outra saída.

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

func _initialize() -> void:
	print("== Laboratório V2: a cena roda? ==")

func _process(delta: float) -> bool:
	_tempo += delta
	match _fase:
		0:
			PonteDeFeedback = root.get_node("PonteDeFeedback")
			_montar()
			_fase = 1
			_tempo = 0.0
		1:
			if _tempo > 0.4:      # tudo assentar
				_conferir_montagem()
				_fase = 2
				_tempo = 0.0
		2:
			_andar(delta)
			if _tempo > 1.5:      # andando de verdade
				_conferir_movimento()
				_fase = 3
				_tempo = 0.0
		3:
			if _tempo > 6.0:      # tempo de a briga acontecer
				_conferir_combate()
				_fase = 4
		_:
			print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
			quit(1 if fail > 0 else 0)
			return true
	return false

# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	var cena := load("res://scenes/gameplay_v2/Laboratorio.tscn")
	if cena == null:
		_erro_ao_montar = "a cena não carregou"
		return
	_lab = cena.instantiate()
	if _lab == null:
		_erro_ao_montar = "a cena não instanciou"
		return
	root.add_child(_lab)

var _pos_inicial : Vector2 = Vector2.ZERO

func _conferir_montagem() -> void:
	_conf(_erro_ao_montar == "", "a cena do Laboratório carrega", _erro_ao_montar)
	if _lab == null:
		_fase = 9
		return

	_conf(_lab.treinador != null, "o treinador existe")
	_conf(_lab.pokemon != null, "o Pokémon ativo existe")
	if _lab.pokemon != null:
		_conf(_lab.pokemon.vida_maxima > 1, "o Pokémon tem vida calculada",
			"vida %d" % _lab.pokemon.vida_maxima)
		_conf(_lab.pokemon.golpes.size() == 4, "e 4 golpes carregados",
			"tem %d" % _lab.pokemon.golpes.size())

	var selvagens := root.get_tree().get_nodes_in_group("selvagem_v2")
	_conf(selvagens.size() >= 4, "há selvagens na área", "achei %d" % selvagens.size())

	# §30: o Alpha precisa ser claramente mais forte, senão não é miniboss.
	var alpha = null
	var comum = null
	for s in selvagens:
		if String(s.name).ends_with("_ALPHA"):
			alpha = s
		elif comum == null:
			comum = s
	_conf(alpha != null, "o Alpha está na área")
	if alpha != null and comum != null:
		_conf(alpha.vida_maxima > comum.vida_maxima,
			"o Alpha tem mais vida que um selvagem comum",
			"alpha %d, comum %d" % [alpha.vida_maxima, comum.vida_maxima])

	# A fonte de contexto do feedback — o pedido do Gabriel desta rodada.
	var ctx : Dictionary = _lab.contexto()
	_conf(ctx.has("treinador") and ctx.has("pokemon"),
		"o contexto de feedback descreve treinador e Pokémon")
	_conf(ctx.has("selvagens_em_pe"), "e quantos selvagens ainda estão em pé")

	if _lab.treinador != null:
		_pos_inicial = _lab.treinador.global_position

func _andar(_delta: float) -> void:
	if _lab == null or _lab.treinador == null:
		return
	# Empurra a intenção direto, sem simular tecla: o que está sendo testado é
	# o movimento, não o mapeamento de entrada.
	# Desliga a leitura de teclado: senão `_ler_entrada()` sobrescreve a
	# intenção todo quadro de física e nada se move.
	_lab.treinador.le_teclado = false
	_lab.treinador.intencao = Vector2(1, 0)
	_lab.treinador.quer_correr = true

func _conferir_movimento() -> void:
	if _lab == null or _lab.treinador == null:
		return
	var t = _lab.treinador
	var andou : float = t.global_position.distance_to(_pos_inicial)
	_conf(andou > 100.0, "o treinador realmente se moveu", "andou %.0f px" % andou)
	_conf(t.grid_pos != Vector2i(floori(_pos_inicial.x / 128.0), floori(_pos_inicial.y / 128.0)),
		"e o tile derivado acompanhou o movimento")
	_conf(t.stamina.atual < t.stamina.maximo(),
		"correr gastou stamina", "sobrou %.0f" % t.stamina.atual)

	t.intencao = Vector2.ZERO
	t.quer_correr = false

	# O Pokémon segue sem comando nenhum (ordem de repouso é SEGUIR).
	if _lab.pokemon != null:
		var dist : float = _lab.pokemon.global_position.distance_to(t.global_position)
		_conf(dist < 900.0, "o Pokémon acompanhou o treinador",
			"ficou a %.0f px" % dist)

	# Manda atacar o selvagem mais próximo — é o que a fase 3 vai medir.
	var alvo : Node2D = null
	var melhor := INF
	for s in root.get_tree().get_nodes_in_group("selvagem_v2"):
		var d : float = (s as Node2D).global_position.distance_to(t.global_position)
		if d < melhor:
			melhor = d
			alvo = s as Node2D
	if alvo != null and _lab.pokemon != null:
		_conf(_lab.pokemon.ordenar("atacar", {"alvo": alvo}),
			"a ordem de atacar foi aceita")
		_alvo_da_briga = alvo
		_vida_do_alvo = alvo.vida

var _alvo_da_briga : Node2D = null
var _vida_do_alvo : int = 0

func _conferir_combate() -> void:
	if _alvo_da_briga == null or not is_instance_valid(_alvo_da_briga):
		_conf(true, "o alvo saiu da cena (foi derrotado)")
		return
	var c = _alvo_da_briga

	# O ataque básico é automático: sem apertar nada, o alvo tem que perder vida.
	_conf(c.vida < _vida_do_alvo,
		"o ataque básico automático causou dano sozinho",
		"vida foi de %d pra %d" % [_vida_do_alvo, c.vida])

	if _lab.pokemon != null:
		var dist : float = _lab.pokemon.global_position.distance_to(c.global_position)
		_conf(dist < 400.0, "o Pokémon se aproximou do alvo que recebeu a ordem",
			"ficou a %.0f px" % dist)

	# E a briga é de mão dupla: o selvagem revida.
	var revidou : bool = _lab.pokemon != null and _lab.pokemon.vida < _lab.pokemon.vida_maxima
	_conf(revidou, "o selvagem revidou (o Pokémon do jogador apanhou)",
		"vida do Pokémon: %d/%d" % [_lab.pokemon.vida, _lab.pokemon.vida_maxima])

	# A linha do tempo do feedback registrou a briga — é o que faz um recado
	# do Gabriel virar relatório em vez de palpite.
	var linha : Array = PonteDeFeedback.linha_do_tempo()
	_conf(linha.size() > 0, "a linha do tempo do feedback gravou acontecimentos",
		"%d eventos" % linha.size())
