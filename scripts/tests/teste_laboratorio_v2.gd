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
## Mesma armadilha de sempre: esta classe toca em `RNGManager`.
var Comportamento : GDScript

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
			Comportamento = load("res://scripts/combat/ComportamentoSelvagem.gd")
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
				_conferir_contratos_do_codex()
				_fase = 4
				_tempo = 0.0
		4:
			# Fase própria só pra medir o deslocamento que a fachada causou:
			# movimento se mede em tempo decorrido, não na linha seguinte.
			if _tempo > 0.6:
				_conferir_fachada_moveu()
				_provocar_o_bando()
				_fase = 5
				_tempo = 0.0
		5:
			# O bando acorda com atraso sorteado (0,4 a 1,8 s): medir antes
			# disso mediria o sorteio, não a regra.
			if _tempo > 3.0:
				_conferir_bando()
				_matar_um_selvagem()
				_fase = 6
				_tempo = 0.0
		6:
			if _tempo > 0.5:
				_conferir_laco_completo()
				_fase = 7
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


# ──────────────────────────────────────────────────────────────────────────────
# Os contratos que o Codex pediu na revisão de 14/09
# ──────────────────────────────────────────────────────────────────────────────
#
# Existem aqui porque ele achou uma API que eu PROMETI na RFC e não construí
# (`EstadoV2.instantaneo()`). Contrato sem teste é promessa — e ele foi montar
# a HUD em cima do vazio.

func _conferir_contratos_do_codex() -> void:
	# 1. Estado inicial tipado — números e ids, não frases.
	var e : Dictionary = _lab.estado()
	_conf(e.has("treinador") and e.has("pokemon") and e.has("inimigos"),
		"estado() devolve as três seções")
	var t : Dictionary = e["treinador"]
	_conf(t.get("stamina") is float, "stamina vem como número, não texto",
		"veio %s" % type_string(typeof(t.get("stamina"))))
	_conf(t.get("tile") is Vector2i, "tile vem como Vector2i")
	var p : Dictionary = e["pokemon"]
	_conf(p.get("kit") is Array and (p["kit"] as Array).size() == 4,
		"o kit vem com os 4 slots")
	if p.get("kit") is Array and not (p["kit"] as Array).is_empty():
		var s0 : Dictionary = (p["kit"] as Array)[0]
		_conf(s0.has("progresso") and s0["progresso"] is float,
			"cada slot traz o progresso da recarga como número")
		_conf(s0.has("slot") and s0.has("nome") and s0.has("tipo"),
			"e identidade suficiente pra desenhar o botão")
	_conf(p.get("id") is int and int(p["id"]) != 0,
		"o Pokémon ativo tem id — é o que a HUD usa pra reconectar")

	# O outro contrato, o de FRASE, continua existindo e separado.
	var ctx : Dictionary = _lab.contexto()
	_conf(ctx["pokemon"]["vida"] is String,
		"contexto() segue sendo texto pra humano (contratos separados)")

	# 2. Fachada pública — a HUD não pode depender de método com "_".
	for metodo in ["estado", "mover", "soltar_movimento", "usar_skill",
			"ordenar", "tocar_no_mundo", "trocar_pokemon", "proximo_pokemon"]:
		_conf(_lab.has_method(metodo), "fachada pública tem %s()" % metodo)

	# 3. A fachada de movimento é a porta do toque: ela precisa mandar no
	#    treinador e tirar o teclado da disputa.
	_pos_antes_da_fachada = _lab.treinador.global_position
	_lab.mover(Vector2(0, 1), false)
	_conf(not _lab.treinador.le_teclado,
		"mover() tira o teclado da disputa (é o que faz o toque funcionar)")
	_conf(_lab.treinador.intencao == Vector2(0, 1),
		"e empurra a intenção pedida")

	# 4. Telegrafia com geometria resolvida, na mesma unidade do impacto.
	var golpe : Dictionary = _lab.pokemon.golpes[0]
	var d : Dictionary = Telegrafia.dados(golpe, Vector2(100, 100), Vector2.RIGHT,
		0.5, false, null, null)
	_conf(d.has("cast_id") and int(d["cast_id"]) > 0, "telegrafia tem cast_id")
	_conf(d["origem"] is Vector2 and d["direcao"] is Vector2,
		"origem e direção em coordenadas de mundo")
	_conf(d["raio"] is float and float(d["raio"]) > 0.0,
		"raio resolvido em pixels", "veio %s" % str(d.get("raio")))
	_conf(d.has("hostil") and d.has("autor_id"), "diz de quem é e se é ameaça")
	_conf(d["abertura"] is float, "abertura do cone em radianos")

	# A garantia que importa: o raio do aviso é o MESMO que FormaDeArea usa.
	var raio_da_forma : float = float(golpe.get("radius", 0.0))
	if raio_da_forma <= 0.0:
		raio_da_forma = float(golpe.get("range", CombatBalance.ALCANCE_PADRAO_TILES)) * CombatBalance.TILE_PX
	_conf(is_equal_approx(float(d["raio"]), raio_da_forma),
		"o raio desenhado é o mesmo que o raio que acerta",
		"telegrafia %.1f, FormaDeArea %.1f" % [d["raio"], raio_da_forma])

	# 5. Contexto de câmera: eu digo qual, com prioridade.
	_conf(_lab.has_signal("contexto_de_camera"), "o sinal de contexto de câmera existe")
	_conf(_lab.has_signal("pokemon_ativo_mudou"), "o sinal de troca de Pokémon existe")
	_conf(_lab.pokemon.has_signal("ordem_mudou"), "ordem_mudou existe")
	_conf(_lab.pokemon.has_signal("recarga_mudou"), "recarga_mudou existe")
	_conf(int(_lab.PRIORIDADE["boss"]) > int(_lab.PRIORIDADE["combate_grande"]),
		"boss tem prioridade maior que combate grande")

var _pos_antes_da_fachada : Vector2 = Vector2.ZERO

## Medido meio segundo depois, numa fase própria: deslocamento é efeito ao longo
## do tempo, e conferir na linha seguinte à chamada media zero por construção.
func _conferir_fachada_moveu() -> void:
	var andou : float = _lab.treinador.global_position.distance_to(_pos_antes_da_fachada)
	_conf(andou > 50.0, "e o treinador de fato andou por causa dela",
		"andou %.0f px" % andou)
	_lab.soltar_movimento()
	_conf(_lab.treinador.le_teclado, "soltar_movimento() devolve o teclado")


# ──────────────────────────────────────────────────────────────────────────────
# §26: o grito do bando
# ──────────────────────────────────────────────────────────────────────────────

var _gritador = null
var _perseguindo_antes : Array = []

## Monta a situação que se quer medir, em vez de torcer pra ela acontecer.
##
## A primeira versão deste teste bateu num selvagem que **já estava lutando** —
## e quem já está na briga não grita de novo, de propósito. O teste media a
## ausência do grito e chamava de bug. Agora ele arruma dois bichos de bando da
## mesma espécie, parados e perto um do outro, e só então provoca.
func _provocar_o_bando() -> void:
	var bando : Array = []
	for n in root.get_tree().get_nodes_in_group("selvagem_v2"):
		if not n.esta_derrotado() and str(n.personalidade) == "pack":
			bando.append(n)
	if bando.size() < 2:
		_conf(false, "havia pelo menos 2 selvagens de bando na área",
			"achei %d" % bando.size())
		return

	_gritador = bando[0]
	var vizinho = bando[1]
	# Longe da briga, parados, e um ao lado do outro — dentro do raio do grito.
	_gritador.global_position = Vector2(6000, 6000)
	vizinho.global_position = Vector2(6000, 6000) + Vector2(CombatBalance.TILE_PX * 2, 0)
	for n in [_gritador, vizinho]:
		n._estado = 0            # PATRULHA
		n.alvo = null
		n.saltos_de_grito = 0
		n.casa = n.global_position

	_perseguindo_antes = _quem_persegue()
	_gritador.sofrer(1, _lab.pokemon)

func _quem_persegue() -> Array:
	var out : Array = []
	for s in root.get_tree().get_nodes_in_group("selvagem_v2"):
		if not s.esta_derrotado() and int(s._estado) == 1:
			out.append(s)
	return out

func _conferir_bando() -> void:
	if _gritador == null:
		return
	_conf(int(_gritador._estado) == 1, "quem apanhou entrou em perseguição")

	var agora : Array = _quem_persegue()
	var novos : Array = []
	for s in agora:
		if s != _gritador and not (s in _perseguindo_antes):
			novos.append(s)

	_conf(novos.size() >= 1, "o grito acordou vizinho da MESMA espécie (§26)",
		"acordaram %d" % novos.size())

	# §27: quem foi CHAMADO entra com 1 salto e não pode gritar de novo. Sem
	# isso, A chama B, B chama C, e o mapa inteiro vem junto.
	var com_salto_errado : int = 0
	for s in novos:
		if int(s.saltos_de_grito) != 1:
			com_salto_errado += 1
	_conf(com_salto_errado == 0,
		"todo chamado entra marcado como chamado (sem corrente de aggro)",
		"%d com salto errado" % com_salto_errado)

	_conf(novos.size() <= CombatBalance.MAX_PACK_SIZE,
		"o grito respeita o teto do bando",
		"acordaram %d, teto %d" % [novos.size(), CombatBalance.MAX_PACK_SIZE])

	# O bicho de bando é o único que grita: um territorial apanhando não chama.
	_conf(Comportamento.chama_o_bando("pack")
			and not Comportamento.chama_o_bando("territorial"),
		"só a personalidade de bando chama os outros")

	# A linha do tempo registrou — é o que transforma "apareceu um monte de
	# bicho do nada" num relatório que dá pra investigar.
	var achou := false
	for e in PonteDeFeedback.linha_do_tempo():
		if str(e["o_que"]).contains("chamou o bando"):
			achou = true
			break
	_conf(achou, "o grito aparece na linha do tempo do feedback")

# ──────────────────────────────────────────────────────────────────────────────
# O laço da §2: COMBATE → LOOT/CAPTURA → PROGRESSÃO
# ──────────────────────────────────────────────────────────────────────────────
#
# 🔴 Este teste existe porque eu tinha reportado os passos 8 e 10 como
# entregues quando o que existia eram as REGRAS, sem ninguém chamando:
# `LivroDeEfeitos` e `RegrasDeCorpo` tinham zero consumidores fora de teste.
# Regra provada e não ligada não é gameplay — é biblioteca.

var _xp_antes_do_pokemon : int = 0
var _xp_antes_do_treinador : int = 0
var _nivel_da_vitima : int = 0

func _matar_um_selvagem() -> void:
	var vitima = null
	for n in root.get_tree().get_nodes_in_group("selvagem_v2"):
		if not n.esta_derrotado() and not String(n.name).ends_with("_ALPHA"):
			vitima = n
			break
	if vitima == null:
		_conf(false, "havia um selvagem comum pra derrotar")
		return

	_xp_antes_do_pokemon = int(_lab.pokemon.xp)
	_xp_antes_do_treinador = int(_lab.treinador.xp)
	_nivel_da_vitima = int(vitima.nivel)
	# O Pokémon do jogador precisa ter causado o dano, senão a §32 manda não
	# dar XP a ninguém — e o teste estaria medindo o caminho errado.
	vitima.sofrer(vitima.vida_maxima * 2, _lab.pokemon)

func _conferir_laco_completo() -> void:
	print("-- O laço: derrotar → corpo → loot/captura → XP")

	var corpos : Array = _lab.corpos()
	_conf(corpos.size() >= 1, "derrotar um selvagem faz nascer um corpo",
		"achei %d" % corpos.size())
	if corpos.is_empty():
		return

	var c : Dictionary = corpos[0]
	_conf(float(c["segundos_restantes"]) >= 9.0
			and float(c["segundos_restantes"]) <= 15.0,
		"o corpo dura entre 10 e 15 s (§28)",
		"%.1f s" % float(c["segundos_restantes"]))
	_conf(not c.has("chance"), "o estado do corpo NÃO expõe a chance de captura (§28)")
	_conf(c.has("loot"), "e traz o loot do chão")

	# §32: o XP entrou, nos dois, na proporção 60/40.
	var ganhou_treinador : int = int(_lab.treinador.xp) - _xp_antes_do_treinador
	var ganhou_pokemon : int = int(_lab.pokemon.xp) - _xp_antes_do_pokemon
	_conf(ganhou_treinador > 0, "o treinador ganhou XP", "%d" % ganhou_treinador)
	_conf(ganhou_pokemon > 0, "o Pokémon também", "%d" % ganhou_pokemon)
	# 60/40 — a menos que algum dos dois tenha subido de nível no caminho, que
	# zera a sobra. Por isso a comparação é de ordem, não de igualdade exata.
	_conf(ganhou_treinador >= ganhou_pokemon or int(_lab.treinador.nivel) > 1,
		"e o treinador leva a parte maior (60/40)",
		"treinador %d, pokemon %d" % [ganhou_treinador, ganhou_pokemon])

	# §35: pegar item é um ato por item, e o item sai do chão.
	var quantos_antes : int = (c["loot"] as Array).size()
	if quantos_antes > 0:
		var item : Dictionary = _lab.pegar_item(int(c["id"]), 0)
		_conf(not item.is_empty(), "dá pra pegar um item do chão")
		var depois : Array = _lab.corpos()
		if not depois.is_empty():
			_conf((depois[0]["loot"] as Array).size() == quantos_antes - 1,
				"e ele sai do chão (um por vez, sem 'pegar tudo')")

	# §28: uma tentativa por corpo. Falhando ou acertando, o corpo some.
	var r : Dictionary = _lab.capturar(int(c["id"]), "pokeball")
	_conf(r.has("pegou"), "a captura devolve um resultado", str(r))
	_conf(not r.has("chance"), "sem revelar a chance")
	var r2 : Dictionary = _lab.capturar(int(c["id"]), "pokeball")
	_conf(not bool(r2["pegou"]), "a segunda tentativa no mesmo corpo não pega")
	_conf(str(r2["motivo"]) != "", "e explica por quê", str(r2["motivo"]))

	# O livro de efeitos agora TEM consumidor.
	_conf(_lab.pokemon.efeitos != null, "o Pokémon tem livro de efeitos")
	_lab.pokemon.efeitos.aplicar_status("sleep", 3.0, 0.0)
	_conf(_lab.pokemon.incapacitado(),
		"dormindo, ele fica incapaz de agir (§11)")
	_conf(_lab.pokemon.usar_skill(0) != "",
		"e o golpe é recusado com motivo")
	_lab.pokemon.efeitos.limpar()
	_conf(not _lab.pokemon.incapacitado(), "limpar o status devolve o controle")
