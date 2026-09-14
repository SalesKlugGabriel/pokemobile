## SelvagemV2.gd — O Pokémon selvagem da V2 (§25, §26, §27).
##
## O cérebro não é novo: reaproveita `ComportamentoSelvagem.gd` inteiro, que já
## tem as 7 personalidades, a escolha de golpe por nota, a escolha de alvo, o
## raio de aggro e o raio de coleira. Aqui fica só o corpo — patrulhar,
## perseguir, bater, voltar pra casa.
##
## ── §4: quem ele persegue ────────────────────────────────────────────────────
##
## *"Quando existe Pokémon ativo, inimigos focam o Pokémon; o treinador fica
## protegido. Se o Pokémon desmaiar e nenhum outro for enviado, o treinador
## volta a ficar vulnerável."*
##
## É a regra que dá peso à troca: guardar o Pokémon não é neutro, é ficar
## exposto. Ela mora em `_escolher_alvo()`.
##
## ── §27: sem coleira instantânea ─────────────────────────────────────────────
##
## *"Não usar leash artificial instantâneo. Se o Pokémon perseguir o jogador,
## deve retornar de maneira natural ao território depois."* Então ele não
## teleporta nem congela na borda: passa pra VOLTANDO e anda de volta, e durante
## a volta ainda pode ser atacado.
extends CombatenteV2
class_name SelvagemV2

enum Estado { PATRULHA, PERSEGUIR, VOLTANDO }

var personalidade : String = ComportamentoSelvagem.DEFENSIVO
var casa : Vector2 = Vector2.ZERO
var alvo : Node2D = null

var _estado : Estado = Estado.PATRULHA
var _dir_patrulha : Vector2 = Vector2.ZERO
var _t_patrulha : float = 0.0
## §26: quantos "saltos" de grito já aconteceram até chegar neste bicho. Zero =
## ele viu sozinho. Um = foi chamado — e quem foi chamado **não grita de novo**,
## senão A chama B, B chama C e em segundos o mapa inteiro está em cima do
## jogador. É a corrente de aggro que a §27 manda evitar.
var saltos_de_grito : int = 0

## §27: memória temporária — ele lembra de quem o atacou por um tempo depois de
## perder o alvo de vista. Sem isso, sair do raio por meio segundo apaga a briga.
var _memoria : float = 0.0
## §61: o mesmo desencalhe do Pokémon do jogador — um selvagem preso no muro
## enquanto "persegue" é o bug mais fácil de ver e o mais difícil de perdoar.
var _contorno : Contorno = Contorno.new()

const VELOCIDADE_BASE : float = 560.0
const MEMORIA_SEGUNDOS : float = 4.0
const DISTANCIA_DE_ATAQUE : float = 190.0

func _ready() -> void:
	add_to_group("selvagem_v2")
	casa = global_position

func grupos_inimigos() -> Array:
	return ["pokemon_do_jogador", "treinador_v2"]

func e_hostil() -> bool:
	return true

## §19: perseguindo é estar em combate. Voltando pra casa já não é — é por isso
## que ele se cura no caminho de volta, que é o comportamento que a §27 descreve
## ("retornar de maneira natural ao território").
func em_combate() -> bool:
	return _estado == Estado.PERSEGUIR

func velocidade() -> float:
	var spe : int = int(stats.get("spe", 50))
	return VELOCIDADE_BASE * (1.0 + (float(spe) - 50.0) / 100.0 * 0.35)

## §26: apanhar acorda, sempre — mesmo o passivo, que não começa briga.
func ao_ser_atingido(de_quem: Node) -> void:
	if de_quem is Node2D:
		_engajar(de_quem as Node2D, saltos_de_grito)

## Entrar na briga, e — se for do tipo que chama — gritar.
##
## `saltos` é quantos gritos já encadearam até aqui. Um bicho que foi CHAMADO
## entra com 1 e por isso não chama mais ninguém.
func _engajar(quem: Node2D, saltos: int) -> void:
	var ja_estava := _estado == Estado.PERSEGUIR
	alvo = quem
	_estado = Estado.PERSEGUIR
	_memoria = MEMORIA_SEGUNDOS
	saltos_de_grito = saltos
	if ja_estava:
		return
	PonteDeFeedback.anotar("%s partiu pra cima" % nome_exibido)
	if ComportamentoSelvagem.chama_o_bando(personalidade):
		_gritar(quem)

## §26: o bando acorda. Só da MESMA espécie, só dentro do raio, no máximo N —
## e cada um com um atraso sorteado, porque o bando inteiro pulando no mesmo
## quadro parece script, não animal. O atraso é o que dá ao jogador a chance de
## ver o segundo vindo e reagir.
func _gritar(contra: Node2D) -> void:
	var ouviram : Array = ComportamentoSelvagem.quem_ouve_o_grito(
		self, get_tree().get_nodes_in_group("selvagem_v2"), species_id,
		saltos_de_grito)
	if ouviram.is_empty():
		return
	PonteDeFeedback.anotar("%s chamou o bando (%d)" % [nome_exibido, ouviram.size()])
	for n in ouviram:
		if not (n is SelvagemV2) or (n as SelvagemV2).esta_derrotado():
			continue
		var atraso : float = RNGManager.randf_range(
			CombatBalance.ATRASO_DO_BANDO_MIN, CombatBalance.ATRASO_DO_BANDO_MAX)
		(n as SelvagemV2).acordar_em(atraso, contra)

var _acordar_em : float = -1.0
var _acordar_contra : Node2D = null

## Marcado pra entrar na briga daqui a `segundos`. Não engaja na hora — o
## atraso É a mecânica (§26).
func acordar_em(segundos: float, contra: Node2D) -> void:
	if _estado == Estado.PERSEGUIR or _acordar_em > 0.0:
		return
	_acordar_em = segundos
	_acordar_contra = contra

func _physics_process(delta: float) -> void:
	if esta_derrotado():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_tick_combate(delta)
	if _memoria > 0.0:
		_memoria -= delta
	if _acordar_em > 0.0:
		_acordar_em -= delta
		if _acordar_em <= 0.0 and _acordar_contra != null and is_instance_valid(_acordar_contra):
			# Entra com 1 salto: foi chamado, então não chama mais ninguém.
			_engajar(_acordar_contra, 1)
			_acordar_contra = null

	match _estado:
		Estado.PATRULHA:  _patrulhar(delta)
		Estado.PERSEGUIR: _perseguir(delta)
		Estado.VOLTANDO:  _voltar()

	velocity = _contorno.ajustar(velocity, global_position, delta)
	velocity = WorldManager.filtrar_velocidade(
		global_position + Vector2(0, TILE * 0.25), velocity, false)
	move_and_slide()

# ──────────────────────────────────────────────────────────────────────────────
# Estados
# ──────────────────────────────────────────────────────────────────────────────

func _patrulhar(delta: float) -> void:
	_t_patrulha -= delta
	if _t_patrulha <= 0.0:
		_t_patrulha = RNGManager.randf_range(2.0, 4.0)
		_dir_patrulha = Vector2.ZERO if RNGManager.chance(0.35) \
			else Vector2.RIGHT.rotated(RNGManager.randf_range(0.0, TAU))
	velocity = _dir_patrulha * velocidade() * 0.35

	if not ComportamentoSelvagem.comeca_briga(personalidade):
		return
	var candidato := _escolher_alvo()
	if candidato == null:
		return
	var raio := ComportamentoSelvagem.raio_de_aggro(personalidade) * TILE
	if global_position.distance_to(candidato.global_position) <= raio:
		_engajar(candidato, 0)

func _perseguir(delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo) or _alvo_caiu():
		alvo = _escolher_alvo()
	if alvo == null:
		_estado = Estado.VOLTANDO
		return

	# §27: longe demais de casa E sem memória viva → volta andando.
	var coleira := ComportamentoSelvagem.raio_de_coleira(personalidade) * TILE
	if global_position.distance_to(casa) > coleira and _memoria <= 0.0:
		_estado = Estado.VOLTANDO
		alvo = null
		return

	var d : Vector2 = alvo.global_position - global_position
	var dist := d.length()
	velocity = Vector2.ZERO if dist <= DISTANCIA_DE_ATAQUE else d.normalized() * velocidade()

	if esta_castando() or golpes.is_empty():
		return
	# O cérebro escolhe: nota por golpe, considerando distância. É a mesma
	# função que o selvagem da V1 usa — não há segunda IA na V2.
	var slot : int = ComportamentoSelvagem.escolher_golpe(golpes, recargas, dist, {})
	if slot >= 0:
		usar(slot, d.normalized(), alvo)
	_memoria = MEMORIA_SEGUNDOS

func _voltar() -> void:
	var d : Vector2 = casa - global_position
	if d.length() <= 48.0:
		_estado = Estado.PATRULHA
		velocity = Vector2.ZERO
		return
	velocity = d.normalized() * velocidade() * 0.6

# ──────────────────────────────────────────────────────────────────────────────
# Alvo (§4)
# ──────────────────────────────────────────────────────────────────────────────

func _alvo_caiu() -> bool:
	return alvo is CombatenteV2 and (alvo as CombatenteV2).esta_derrotado()

## Com Pokémon do jogador em pé, é nele que se bate. Sem Pokémon em pé, o
## treinador vira alvo válido — é o preço de andar sem ninguém fora da ball.
func _escolher_alvo() -> Node2D:
	for n in get_tree().get_nodes_in_group("pokemon_do_jogador"):
		if n is CombatenteV2 and not (n as CombatenteV2).esta_derrotado():
			return n as Node2D
	var treinadores := get_tree().get_nodes_in_group("treinador_v2")
	return treinadores[0] as Node2D if not treinadores.is_empty() else null
