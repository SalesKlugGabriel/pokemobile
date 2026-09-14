## Laboratorio.gd — A área de testes da Gameplay V2 (§2 da especificação).
##
## Pedido do Gabriel: *"Antes de remodelar todo o jogo, construa apenas uma área
## de testes"* — 1 treinador, 1 Pokémon, 3 espécies selvagens, grupos de
## inimigos, skills funcionais, um Alpha, colisões, obstáculos, HUD mínima.
##
## E a regra que governa tudo (§68): esta cena existe pra responder **três
## perguntas** — controlar o personagem é divertido, andar é divertido, lutar é
## divertido. Não pra ser o jogo.
##
## ── Isolamento ───────────────────────────────────────────────────────────────
##
## Nada aqui é alcançável a partir do jogo normal. A entrada continua sendo
## `TitleScreen.tscn`; esta cena se abre sozinha, por build de teste — foi o que
## o Codex pediu na revisão da RFC, pra não existir item de menu de produção
## apontando pra um protótipo.
##
## ── Visual ───────────────────────────────────────────────────────────────────
##
## ⚠️ Formas coloridas, de propósito. A §2 pede "efeitos visuais provisórios", e
## arte é do Codex. Nada daqui é proposta visual: é o mínimo pra dar pra ver
## quem é quem enquanto a mecânica é testada.
extends Node2D

const TILE : int = 128
const LARGURA : int = 40
const ALTURA : int = 30

## O time de teste (§2: "possibilidade de trocar entre alguns Pokémon de
## teste"). Escolhidos por cobrirem papéis diferentes: um equilibrado, um
## rápido e frágil, um lento e duro.
const TIME_DE_TESTE : Array[Dictionary] = [
	{"id": 6,   "nivel": 40, "golpes": ["ember", "dragon_rage", "slash", "fire_spin"]},
	{"id": 25,  "nivel": 40, "golpes": ["thundershock", "quick_attack", "thunder_wave", "swift"]},
	{"id": 143, "nivel": 40, "golpes": ["body_slam", "rest", "headbutt", "amnesia"]},
]

## As 3 espécies selvagens da §2, com personalidades diferentes de propósito —
## é a única forma de sentir se as personalidades fazem diferença.
const SELVAGENS : Array[Dictionary] = [
	{"id": 19, "nivel": 36, "personalidade": "aggressive", "golpes": ["tackle", "quick_attack"]},
	{"id": 41, "nivel": 36, "personalidade": "pack",       "golpes": ["gust", "bite"]},
	{"id": 74, "nivel": 38, "personalidade": "territorial","golpes": ["rock_throw", "tackle"]},
]

## Contratos pedidos pelo Codex na revisão de 14/09.
signal pokemon_ativo_mudou(estado: Dictionary)
signal contexto_de_camera(nome: String, prioridade: int)
signal corpo_mudou(id: int, estado: Dictionary)
signal corpo_removido(id: int, motivo: String)
signal xp_ganho(quem: String, quanto: int, subiu: int)

var treinador : TreinadorV2 = null
var pokemon : PokemonAtivoV2 = null
var _indice_do_time : int = 0
var _camera : Camera2D = null

func _ready() -> void:
	_montar_terreno()
	_montar_treinador()
	_trocar_para(0)
	_montar_selvagens()
	_montar_alpha()
	_registrar_no_feedback()
	PonteDeFeedback.anotar("Laboratório V2 aberto")

# ──────────────────────────────────────────────────────────────────────────────
# Terreno
# ──────────────────────────────────────────────────────────────────────────────

## Chão liso com obstáculos espalhados. Obstáculo existe porque sem nada pra
## contornar não dá pra saber se a colisão presta — e "posicionamento importa"
## (§9) é vazio num campo aberto sem nenhuma parede.
func _montar_terreno() -> void:
	var chao := ColorRect.new()
	chao.color = Color(0.22, 0.30, 0.22)
	chao.size = Vector2(LARGURA * TILE, ALTURA * TILE)
	chao.z_index = -10
	add_child(chao)

	# Grade fraca: é o que deixa medir distância a olho enquanto testa. Sai
	# quando o Codex trouxer terreno de verdade.
	for x in range(0, LARGURA + 1, 4):
		var l := ColorRect.new()
		l.color = Color(1, 1, 1, 0.05)
		l.size = Vector2(2, ALTURA * TILE)
		l.position = Vector2(x * TILE, 0)
		l.z_index = -9
		add_child(l)

	var muros := StaticBody2D.new()
	muros.name = "Obstaculos"
	add_child(muros)
	for r in [Rect2(6, 6, 4, 2), Rect2(20, 4, 2, 8), Rect2(12, 16, 8, 2),
			  Rect2(28, 14, 3, 6), Rect2(4, 20, 6, 2)]:
		_muro(muros, r)
	# Paredes da borda: sem elas dá pra sair do mapa e o teste vira nada.
	_muro(muros, Rect2(0, -1, LARGURA, 1))
	_muro(muros, Rect2(0, ALTURA, LARGURA, 1))
	_muro(muros, Rect2(-1, -1, 1, ALTURA + 2))
	_muro(muros, Rect2(LARGURA, -1, 1, ALTURA + 2))

func _muro(pai: StaticBody2D, r: Rect2) -> void:
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = r.size * TILE
	forma.shape = caixa
	forma.position = (r.position + r.size / 2.0) * TILE
	pai.add_child(forma)

	var vis := ColorRect.new()
	vis.color = Color(0.35, 0.28, 0.22)
	vis.size = r.size * TILE
	vis.position = r.position * TILE
	vis.z_index = -5
	add_child(vis)

# ──────────────────────────────────────────────────────────────────────────────
# Entidades
# ──────────────────────────────────────────────────────────────────────────────

func _corpo_visual(pai: Node2D, cor: Color, raio: float) -> void:
	var p := Polygon2D.new()
	var pontos : PackedVector2Array = []
	for i in 16:
		pontos.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * raio)
	p.polygon = pontos
	p.color = cor
	pai.add_child(p)

func _colisao(pai: CollisionObject2D, raio: float) -> void:
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = raio
	forma.shape = circ
	pai.add_child(forma)

func _montar_treinador() -> void:
	treinador = TreinadorV2.new()
	treinador.name = "TreinadorV2"
	treinador.global_position = Vector2(5, 5) * TILE
	_corpo_visual(treinador, Color(0.95, 0.85, 0.35), 34.0)
	_colisao(treinador, 34.0)
	add_child(treinador)

	# ⚠️ Câmera PROVISÓRIA. Enquadramento, zoom, curva e transição são do Codex
	# (RFC-GAMEPLAY-V2, resposta 1). Isto aqui só existe pra dar pra ver a cena
	# enquanto a mecânica é testada — não é proposta de câmera.
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.75, 0.75)
	treinador.add_child(_camera)

func _montar_selvagens() -> void:
	var posicoes := [Vector2(14, 8), Vector2(26, 10), Vector2(10, 24),
					 Vector2(30, 22), Vector2(18, 12), Vector2(34, 6)]
	for i in posicoes.size():
		var molde : Dictionary = SELVAGENS[i % SELVAGENS.size()]
		_criar_selvagem(molde, posicoes[i], false)

## §30: o Alpha é miniboss — +35% em todos os stats, ~1,35× de tamanho, não
## foge, não é capturável. Os números vêm de `CombatBalance`, não daqui.
func _montar_alpha() -> void:
	var alpha := _criar_selvagem(
		{"id": 74, "nivel": 42, "personalidade": "territorial",
		 "golpes": ["rock_throw", "tackle", "body_slam"]},
		Vector2(34, 26), true)
	alpha.nome_exibido = "%s Alpha" % alpha.nome_exibido

func _criar_selvagem(molde: Dictionary, tile: Vector2, alpha: bool) -> SelvagemV2:
	var s := SelvagemV2.new()
	s.global_position = tile * TILE
	s.montar(int(molde["id"]), int(molde["nivel"]), molde["golpes"])
	s.personalidade = str(molde["personalidade"])

	if alpha:
		# §30, literal: "+35% em todos os SEIS stats clássicos". Um número só,
		# aplicado igual nos seis — a régua da V1 (`ALPHA_HP_MULT = 3.0`) é da
		# Fase 2, anterior a esta especificação, e a especificação ganha.
		s.vida_maxima = BalanceV2.alpha(s.vida_maxima)
		s.vida = s.vida_maxima
		for chave in ["atk", "def", "spa", "spd", "spe"]:
			s.stats[chave] = BalanceV2.alpha(int(s.stats.get(chave, 50)))

	var raio : float = 46.0 * (BalanceV2.ALPHA_ESCALA_VISUAL if alpha else 1.0)
	_corpo_visual(s, Color(0.85, 0.3, 0.3) if alpha else Color(0.6, 0.4, 0.75), raio)
	_colisao(s, raio)
	s.name = "Selvagem_%s%s" % [s.nome_exibido, "_ALPHA" if alpha else ""]
	s.derrotado.connect(_ao_cair_selvagem)
	add_child(s)
	return s

## O laço que a §2 pede só fecha aqui: COMBATE → LOOT/CAPTURA → PROGRESSÃO.
func _ao_cair_selvagem(quem: Node) -> void:
	var c : CombatenteV2 = quem as CombatenteV2
	PonteDeFeedback.anotar("%s foi derrotado" % c.nome_exibido)
	var e_alpha : bool = String(c.name).ends_with("_ALPHA")
	_dar_xp(c, e_alpha)
	_nascer_corpo(c, not e_alpha)   # §30: Alpha não é capturável

## §28: o corpo nasce onde ele caiu e vive de 10 a 15 s.
func _nascer_corpo(de_quem: CombatenteV2, capturavel: bool) -> void:
	var corpo := Corpo.new()
	corpo.montar(de_quem, capturavel, RNGManager.randf())
	corpo.mudou.connect(func(id, est): corpo_mudou.emit(id, est))
	corpo.removido.connect(func(id, motivo): corpo_removido.emit(id, motivo))
	add_child(corpo)

## §32/§33: XP por DANO causado, 60% treinador e 40% Pokémon. O corpo vai por
## quem deu o último golpe — são duas moedas separadas, ver `RegrasDeXP`.
func _dar_xp(de_quem: CombatenteV2, e_alpha: bool) -> void:
	var total : int = RegrasDeXP.xp_do_inimigo(de_quem.nivel, e_alpha)
	# Um jogador só neste protótipo, mas a divisão passa pela mesma função que
	# vai servir pra vários — não há um caminho "simples" que diverge depois.
	var participou : bool = false
	for id in de_quem.dano_recebido_por.keys():
		if int(de_quem.dano_recebido_por[id]) > 0:
			participou = true
			break
	if not participou:
		return

	var do_treinador : int = int(round(float(total) * RegrasDeXP.FRACAO_DO_TREINADOR))
	var do_pokemon : int = total - do_treinador

	var r_t : Dictionary = RegrasDeXP.ganhar(treinador.nivel, treinador.xp, do_treinador)
	treinador.nivel = int(r_t["nivel"])
	treinador.xp = int(r_t["xp"])
	xp_ganho.emit("treinador", do_treinador, int(r_t["subiu"]))

	# §33: só o Pokémon consciente que causou dano recebe.
	if pokemon != null and is_instance_valid(pokemon) and not pokemon.esta_derrotado():
		var quem : int = RegrasDeXP.pokemon_que_recebe([{
			"id": pokemon.get_instance_id(),
			"dano": int(de_quem.dano_recebido_por.get(pokemon.get_instance_id(), 0)),
			"consciente": true, "ativo": true, "nivel": pokemon.nivel,
		}])
		if quem != 0:
			var r_p : Dictionary = RegrasDeXP.ganhar(pokemon.nivel, pokemon.xp, do_pokemon)
			pokemon.nivel = int(r_p["nivel"])
			pokemon.xp = int(r_p["xp"])
			xp_ganho.emit(pokemon.nome_exibido, do_pokemon, int(r_p["subiu"]))
			if int(r_p["subiu"]) > 0:
				PonteDeFeedback.anotar("%s subiu pro nível %d"
					% [pokemon.nome_exibido, pokemon.nivel])

# ──────────────────────────────────────────────────────────────────────────────
# Troca de Pokémon (§8)
# ──────────────────────────────────────────────────────────────────────────────

## §8: *"troca praticamente instantânea, sem cooldown artificial; consome
## stamina do treinador; interrompe skills em execução do Pokémon recolhido;
## cooldowns dessas skills continuam contando."*
##
## O último ponto é o que impede a troca de virar reset grátis de recarga — que
## seria a jogada ótima e mataria a decisão.
func _trocar_para(indice: int) -> void:
	if indice < 0 or indice >= TIME_DE_TESTE.size():
		return
	if pokemon != null and is_instance_valid(pokemon):
		if not treinador.stamina.gastar("troca_rapida"):
			PonteDeFeedback.anotar("troca recusada: sem stamina")
			return
		pokemon.interromper("recolhido")
		pokemon.queue_free()

	var molde : Dictionary = TIME_DE_TESTE[indice]
	_indice_do_time = indice
	pokemon = PokemonAtivoV2.new()
	pokemon.montar(int(molde["id"]), int(molde["nivel"]), molde["golpes"])
	pokemon.treinador = treinador
	pokemon.global_position = treinador.global_position + Vector2(0, 160)
	_corpo_visual(pokemon, Color(0.35, 0.7, 0.95), 42.0)
	_colisao(pokemon, 42.0)
	pokemon.name = "PokemonAtivo"
	add_child(pokemon)
	treinador.pokemon = pokemon
	PonteDeFeedback.anotar("enviou %s" % pokemon.nome_exibido)
	# A HUD precisa desconectar do antigo e conectar no novo — sem este sinal
	# ela ficaria escutando um nó que já foi embora (achado do Codex).
	pokemon_ativo_mudou.emit(EstadoV2.do_pokemon(pokemon))

# ──────────────────────────────────────────────────────────────────────────────
# Entrada
# ──────────────────────────────────────────────────────────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_clicar(get_global_mouse_position())
		return
	if not (e is InputEventKey and e.pressed and not e.is_echo()):
		return

	# Skills 1-4 (§2 pede 4 funcionais).
	for i in 4:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			if pokemon != null and is_instance_valid(pokemon):
				pokemon.usar_skill(i)
			return

	match (e as InputEventKey).keycode:
		KEY_1, KEY_2, KEY_3:
			pass   # já tratados acima como skill_1..3
		KEY_Q: _trocar_para((_indice_do_time + 1) % TIME_DE_TESTE.size())
		KEY_E: _ordem(MesaDeComandos.SEGUIR)
		KEY_R: _ordem(MesaDeComandos.RECUAR)
		KEY_F: _ordem(MesaDeComandos.MANTER)

## Clique esquerdo faz as duas coisas da §7 conforme o que tem embaixo: em cima
## de um inimigo é "ataque este"; no chão é "vá até ali".
func _clicar(onde: Vector2) -> void:
	if pokemon == null or not is_instance_valid(pokemon):
		return
	var mais_perto : Node2D = null
	var melhor : float = 110.0
	for n in get_tree().get_nodes_in_group("selvagem_v2"):
		if not (n is CombatenteV2) or (n as CombatenteV2).esta_derrotado():
			continue
		var d : float = (n as Node2D).global_position.distance_to(onde)
		if d < melhor:
			melhor = d
			mais_perto = n as Node2D
	if mais_perto != null:
		pokemon.ordenar(MesaDeComandos.ATACAR, {"alvo": mais_perto})
	else:
		pokemon.ordenar(MesaDeComandos.IR, {"ponto": onde})

func _ordem(qual: String) -> void:
	if pokemon != null and is_instance_valid(pokemon):
		pokemon.ordenar(qual)

# ──────────────────────────────────────────────────────────────────────────────
# Fachada pública — a porta da HUD e do toque
# ──────────────────────────────────────────────────────────────────────────────
#
# Pedido do Codex: *"falta uma fachada pública estável para movimento/corrida,
# skill, ordem, seleção de alvo ou ponto e troca. Hoje parte disso está em
# métodos com `_` de uso interno; a HUD não deve depender deles silenciosamente."*
#
# Ele está certo, e o motivo é concreto: método com `_` é combinado de que pode
# mudar sem aviso. Se a HUD dele passar a chamar `_trocar_para()`, eu quebro a
# tela dele numa refatoração e nenhum dos dois vai entender por quê.

## O retrato do agora, pra HUD nascer certa ao abrir (§ RFC, item 1).
func estado() -> Dictionary:
	return EstadoV2.instantaneo(treinador, pokemon,
		get_tree().get_nodes_in_group("selvagem_v2"))

## Movimento vindo do toque. `intencao` é vetor bruto (analógico pela metade
## anda pela metade); chamar isto desliga a leitura de teclado deste quadro.
func mover(intencao: Vector2, correndo: bool = false) -> void:
	if treinador == null or not is_instance_valid(treinador):
		return
	treinador.le_teclado = false
	treinador.intencao = intencao
	treinador.quer_correr = correndo

## Devolve o controle ao teclado (quando o jogador larga o direcional na tela).
func soltar_movimento() -> void:
	if treinador != null and is_instance_valid(treinador):
		treinador.intencao = Vector2.ZERO
		treinador.quer_correr = false
		treinador.le_teclado = true

## Usa um golpe. Devolve "" se saiu, ou o motivo da recusa em português.
func usar_skill(slot: int) -> String:
	if pokemon == null or not is_instance_valid(pokemon):
		return "sem Pokémon ativo"
	return pokemon.usar_skill(slot)

## Dá uma ordem ao Pokémon. `dados` leva `alvo` (Node) ou `ponto` (Vector2).
func ordenar(ordem: String, dados: Dictionary = {}) -> bool:
	if pokemon == null or not is_instance_valid(pokemon):
		return false
	return pokemon.ordenar(ordem, dados)

## Um toque no mundo: em cima de inimigo vira ATACAR, no chão vira IR.
func tocar_no_mundo(onde: Vector2) -> void:
	_clicar(onde)

## Troca de Pokémon (§8). Devolve false se faltou stamina.
func trocar_pokemon(indice: int) -> bool:
	var antes := pokemon
	_trocar_para(indice)
	return pokemon != antes

func proximo_pokemon() -> bool:
	return trocar_pokemon((_indice_do_time + 1) % TIME_DE_TESTE.size())

## Os corpos no chão agora, pra HUD desenhar. Sem a chance de captura (§28).
func corpos() -> Array:
	var out : Array = []
	for c in get_tree().get_nodes_in_group("corpo_v2"):
		if is_instance_valid(c):
			out.append(c.estado())
	return out

## Tenta capturar. Uma vez por corpo — a regra é do gameplay, não da tela.
func capturar(id_do_corpo: int, ball: String = "pokeball") -> Dictionary:
	for c in get_tree().get_nodes_in_group("corpo_v2"):
		if is_instance_valid(c) and int(c.dados["id"]) == id_do_corpo:
			return c.tentar_capturar(ball, treinador.sorte if treinador else 0)
	return {"pegou": false, "motivo": "Esse Pokémon já desapareceu."}

## Pega um item do chão (§35: um por vez, sem "pegar tudo").
func pegar_item(id_do_corpo: int, indice: int) -> Dictionary:
	for c in get_tree().get_nodes_in_group("corpo_v2"):
		if is_instance_valid(c) and int(c.dados["id"]) == id_do_corpo:
			return c.pegar(indice)
	return {}

# ──────────────────────────────────────────────────────────────────────────────
# Contexto de câmera (§3)
# ──────────────────────────────────────────────────────────────────────────────
#
# Eu digo QUAL contexto está ativo; o zoom, a curva e a duração são do Codex.
# A prioridade resolve o empate que ele levantou: com boss e interior ao mesmo
# tempo, vence o maior número, e a UI não precisa adivinhar.

const PRIORIDADE : Dictionary = {
	"exploracao": 0, "combate": 10, "combate_grande": 20, "boss": 30,
}

var _contexto_atual : String = ""

func _avaliar_contexto_de_camera() -> void:
	var em_briga : int = 0
	var tem_alpha : bool = false
	for n in get_tree().get_nodes_in_group("selvagem_v2"):
		if not (n is SelvagemV2) or (n as SelvagemV2).esta_derrotado():
			continue
		if (n as SelvagemV2).alvo == null:
			continue
		em_briga += 1
		if String(n.name).ends_with("_ALPHA"):
			tem_alpha = true

	var novo : String = "exploracao"
	if tem_alpha:
		novo = "boss"
	elif em_briga >= 3:
		novo = "combate_grande"
	elif em_briga >= 1:
		novo = "combate"

	if novo == _contexto_atual:
		return
	_contexto_atual = novo
	contexto_de_camera.emit(novo, int(PRIORIDADE[novo]))

## Reavaliado uma vez por segundo, não por quadro: contexto que oscila faz o
## zoom pulsar, que foi exatamente o risco que o Codex levantou.
var _relogio_da_camera : float = 0.0

func _process(delta: float) -> void:
	_relogio_da_camera += delta
	if _relogio_da_camera < 1.0:
		return
	_relogio_da_camera = 0.0
	_avaliar_contexto_de_camera()

# ──────────────────────────────────────────────────────────────────────────────
# Feedback (§ pedido do Gabriel, 14/09)
# ──────────────────────────────────────────────────────────────────────────────

## *"o sistema de feedback é importantíssimo para conseguir explicar onde estão
## os bugs e erros do jogo, aplique na V2 também"*.
##
## A ponte já colhe mapa, FPS e tela sozinha. O que ela não tem como saber é o
## estado da V2 — e é justamente esse estado que explica quase todo bug daqui:
## "o Pokémon não atacou" quase sempre é uma ordem que não era a que o jogador
## pensava, ou uma recarga que não tinha acabado.
func _registrar_no_feedback() -> void:
	PonteDeFeedback.registrar_fonte("gameplay_v2", Callable(self, "contexto"))

func contexto() -> Dictionary:
	var c := {"cena": "Laboratorio V2"}
	if treinador != null and is_instance_valid(treinador):
		c["treinador"] = {
			"pos": "%.0f, %.0f" % [treinador.global_position.x, treinador.global_position.y],
			"tile": "%d,%d" % [treinador.grid_pos.x, treinador.grid_pos.y],
			"velocidade": "%.0f px/s" % treinador.velocity.length(),
			"stamina": "%.0f / %.0f" % [treinador.stamina.atual, treinador.stamina.maximo()],
			"estado_da_stamina": treinador.stamina.estado(),
			"vida": "%d / %d" % [treinador.vida, treinador.vida_maxima],
		}
	if pokemon != null and is_instance_valid(pokemon):
		var recargas : Array = []
		for i in pokemon.golpes.size():
			recargas.append("%s %d%%" % [
				str(pokemon.golpes[i].get("name", "?")),
				int(pokemon.progresso_da_recarga(i) * 100.0)])
		c["pokemon"] = {
			"quem": "%s Nv.%d" % [pokemon.nome_exibido, pokemon.nivel],
			"vida": "%d / %d" % [pokemon.vida, pokemon.vida_maxima],
			"ordem": pokemon.comandos.descricao(),
			"castando": pokemon.esta_castando(),
			"recargas": recargas,
		}
	var vivos : int = 0
	for n in get_tree().get_nodes_in_group("selvagem_v2"):
		if n is CombatenteV2 and not (n as CombatenteV2).esta_derrotado():
			vivos += 1
	c["selvagens_em_pe"] = vivos
	return c
