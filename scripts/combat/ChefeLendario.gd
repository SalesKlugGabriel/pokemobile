## ChefeLendario.gd — O lendário como CHEFE, não como Pokémon selvagem forte
## (06/09).
##
## Etapa 2 do plano das Dungeons Elementais. A regra do Gabriel: nível 100
## sempre, status muito acima do normal, "incrivelmente difícil de alcançar".
##
## A lição mais transferível da Boss Fight do Suicune (PokeXGames), e o coração
## deste arquivo: **o que faz um chefe não é o número, é o repertório.** Um
## Pokémon nível 100 com um ataque só é uma parede de HP — o jogador bate até
## acabar e não aprende nada. Por isso são SEIS funções, e cada uma existe pra
## punir um erro diferente:
##
##   1. PRESSÃO      — tiro rápido de alvo único.        Pune ficar parado.
##   2. ÁREA         — círculo avisado 1,2 s antes.      Pune ignorar o aviso.
##   3. CONTROLE     — deixa lento 4 s, sem dano.        Pune não guardar movimento.
##   4. PUNIÇÃO      — escudo 4 s que devolve o dano.    Pune atacar no automático.
##   5. PERCENTUAL   — tira 35% da vida MÁXIMA.          Pune confiar em ser gordo.
##   6. AMBIENTE     — congela o chão em volta.          Pune ficar no mesmo lugar.
##
## A 5 é a que mais muda o jogo: sem ela, basta trazer o Pokémon mais gordo
## possível e ganhar por atrito. Ela é não-fatal de propósito (nunca deixa
## abaixo de 1 de vida) — matar por percentual seria tirar do jogador a chance
## de reagir, e aí vira azar, não dificuldade.
##
## ENRAGE aos 4 minutos: dano ×2 e esperas −30%. Existe pra impedir a vitória
## por atrito — sobreviver de raspão com o time inteiro por dez minutos não pode
## ser uma estratégia melhor que aprender a luta.
##
## É um NÓ FILHO do WildPokemon do lendário, não uma classe nova de entidade: o
## selvagem já tem FSM, hitbox, barra de vida e morte com recompensa. O chefe é
## o que se pendura em cima disso — assim nada do que já foi testado precisa ser
## reescrito, e um lendário novo é uma entrada de tabela, não um arquivo novo.
class_name ChefeLendario
extends Node

# ──────────────────────────────────────────────────────────────────────────
# Números (seção 7 do plano)
# ──────────────────────────────────────────────────────────────────────────
const NIVEL           : int   = 100    ## pedido do Gabriel: sempre o teto do jogo
const MULT_HP         : float = 7.0    ## a luta tem que durar o repertório inteiro 2x
const MULT_DEFESA     : float = 1.5
const MULT_ATAQUE     : float = 1.35
const ENRAGE_SEG      : float = 240.0  ## 4 minutos
const ENRAGE_DANO     : float = 2.0
const ENRAGE_ESPERA   : float = 0.7    ## −30%

const FRACAO_PERCENTUAL : float = 0.35 ## quanto a função 5 tira da vida MÁXIMA
const ESCUDO_SEG        : float = 4.0
const LENTIDAO_SEG      : float = 4.0

## O repertório de cada lendário. Seis funções, sempre nesta ordem de papel —
## trocar o nome do golpe muda o tema, nunca a estrutura.
const REPERTORIO : Dictionary = {
	144: {  # Articuno
		"nome": "Articuno", "tipo": "ice",
		"pressao":    {"nome": "Ice Shard",   "espera": 2.5, "dano": 0.9},
		"area":       {"nome": "Blizzard",    "espera": 9.0, "dano": 1.6, "raio": 420.0},
		"controle":   {"nome": "Mist",        "espera": 16.0},
		"punicao":    {"nome": "Ice Barrier", "espera": 21.0},
		"percentual": {"nome": "Sheer Cold",  "espera": 27.0},
		"ambiente":   {"nome": "Permafrost",  "espera": 33.0, "raio_tiles": 4},
	},
	146: {  # Moltres
		"nome": "Moltres", "tipo": "fire",
		"pressao":    {"nome": "Ember",        "espera": 2.3, "dano": 0.95},
		"area":       {"nome": "Fire Blast",   "espera": 8.5, "dano": 1.7, "raio": 440.0},
		"controle":   {"nome": "Smokescreen",  "espera": 16.0},
		"punicao":    {"nome": "Flame Body",   "espera": 21.0},
		"percentual": {"nome": "Burn Out",     "espera": 27.0},
		"ambiente":   {"nome": "Scorched Earth", "espera": 33.0, "raio_tiles": 4},
	},
	145: {  # Zapdos
		"nome": "Zapdos", "tipo": "electric",
		"pressao":    {"nome": "Thunder Shock", "espera": 2.1, "dano": 0.85},
		"area":       {"nome": "Discharge",     "espera": 8.0, "dano": 1.5, "raio": 460.0},
		"controle":   {"nome": "Thunder Wave",  "espera": 15.0},
		"punicao":    {"nome": "Static",        "espera": 20.0},
		"percentual": {"nome": "Overload",      "espera": 26.0},
		"ambiente":   {"nome": "Live Wire",     "espera": 32.0, "raio_tiles": 4},
	},
}

# ──────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────
var especie : int = 144
var _dados : Dictionary = {}
var _chefe : Node = null                 ## o WildPokemon em que estou pendurado
var _inicio_msec : int = 0
var _proxima : Dictionary = {}           ## função -> msec do próximo uso
var _escudo_ate_msec : int = 0
var _enfurecido : bool = false
## Abaixo disto o chefe considera-se vencido no selo escolhido (0 = só morrendo).
var _hp_para_vencer : int = 0

## Monta o chefe em cima de um WildPokemon já criado.
static func instalar(alvo: Node, id_especie: int) -> Node:
	if alvo == null or not REPERTORIO.has(id_especie):
		return null
	var c := ChefeLendario.new()
	c.name = "ChefeLendario"
	c.especie = id_especie
	alvo.add_child(c)
	return c

func _ready() -> void:
	_chefe = get_parent()
	_dados = REPERTORIO.get(especie, {})
	if _chefe == null or _dados.is_empty():
		return
	_turbinar()
	# O escudo da função 4 mora aqui: escuto o dano em vez de o WildPokemon
	# precisar saber que virou chefe.
	var barramento := _barramento()
	if barramento != null:
		barramento.damage_dealt.connect(_ao_levar_dano)
	_inicio_msec = Time.get_ticks_msec()
	# Cada função começa com a própria espera já correndo, senão o chefe
	# despejaria as seis no primeiro segundo e a luta acabaria antes de o
	# jogador entender o que aconteceu.
	for funcao in ["pressao", "area", "controle", "punicao", "percentual", "ambiente"]:
		_proxima[funcao] = _inicio_msec + int(_espera(funcao) * 1000.0)

## Nível 100 e os status muito acima do normal, como o Gabriel pediu. Feito
## AQUI (e não no spawn) porque o WildPokemon já calculou os stats dele pela
## fórmula normal — aqui é onde eles viram os de um chefe.
func _turbinar() -> void:
	if not ("max_hp" in _chefe):
		return
	_chefe.wild_level = NIVEL
	var base_hp : int = int(_chefe.max_hp)
	_chefe.max_hp = int(round(base_hp * MULT_HP))
	_chefe.current_hp = _chefe.max_hp
	if "def_stat" in _chefe:
		_chefe.def_stat = int(round(_chefe.def_stat * MULT_DEFESA))
	if "atk_stat" in _chefe:
		_chefe.atk_stat = int(round(_chefe.atk_stat * MULT_ATAQUE))
	# SELO (Etapa 3): no Bronze basta tirar 40% da vida do chefe pra vencer —
	# ele foge, e a recompensa é menor. É o mesmo chefe, com objetivo diferente,
	# em vez de três chefes.
	_hp_para_vencer = int(round(float(_chefe.max_hp) * (1.0 - RegrasDeCovil.fracao_do_chefe())))
	if _chefe.has_method("_update_health_bar"):
		_chefe._update_health_bar()
	var barramento := _barramento()
	if barramento != null:
		barramento.wild_pokemon_hp_changed.emit(_chefe, _chefe.current_hp, _chefe.max_hp)

## Pelo nó, nunca pelo identificador global: uma classe com `class_name` que
## cita um autoload direto não carrega nos testes headless — armadilha já
## conhecida do projeto (foi por isso que a tabela de ninhos saiu de
## NinhoLendario pra CovisLendarios em 05/09).
func _barramento() -> Node:
	var raiz = Engine.get_main_loop().root if Engine.get_main_loop() else null
	return raiz.get_node_or_null("EventBus") if raiz else null

func _espera(funcao: String) -> float:
	var f : Dictionary = _dados.get(funcao, {})
	var s : float = float(f.get("espera", 10.0))
	return s * (ENRAGE_ESPERA if _enfurecido else 1.0)

func _mult_dano() -> float:
	return ENRAGE_DANO if _enfurecido else 1.0

# ──────────────────────────────────────────────────────────────────────────
# O laço do chefe
# ──────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _chefe == null or not is_instance_valid(_chefe) or _dados.is_empty():
		return
	if "state" in _chefe and _chefe.state == 3:   # State.DEAD
		return
	# Venceu pelo objetivo do selo: o chefe foge em vez de morrer, e a
	# recompensa sai do mesmo jeito (é vitória, só que menor).
	if _hp_para_vencer > 0 and "current_hp" in _chefe and int(_chefe.current_hp) <= _hp_para_vencer:
		_hp_para_vencer = 0
		_anunciar("Recuou!")
		RecompensasDeCovil.ao_vencer_chefe(especie)
		_chefe.queue_free()
		return

	var agora := Time.get_ticks_msec()

	if not _enfurecido and agora - _inicio_msec >= int(ENRAGE_SEG * 1000.0):
		_enfurecer()

	var alvo := _alvo()
	if alvo == null:
		return

	# Uma função por vez, na ordem em que venceram — nunca duas no mesmo
	# quadro. Duas áreas simultâneas viram sopa visual, e o jogador perde a
	# capacidade de ler o que está acontecendo (regra 2 da seção 11 do plano).
	for funcao in ["percentual", "punicao", "ambiente", "controle", "area", "pressao"]:
		if agora < int(_proxima.get(funcao, 0)):
			continue
		_proxima[funcao] = agora + int(_espera(funcao) * 1000.0)
		_usar(funcao, alvo)
		return

func _alvo() -> Node2D:
	var arvore := get_tree()
	if arvore == null:
		return null
	for grupo in ["follower_pokemon", "player"]:
		for n in arvore.get_nodes_in_group(grupo):
			if is_instance_valid(n) and n is Node2D:
				if n.has_method("is_fainted") and n.is_fainted():
					continue
				return n
	return null

func _usar(funcao: String, alvo: Node2D) -> void:
	var f : Dictionary = _dados.get(funcao, {})
	var nome : String = str(f.get("nome", "?"))
	match funcao:
		"pressao":
			_anunciar(nome)
			_bater(alvo, float(f.get("dano", 1.0)))
		"area":
			_area(f, nome)
		"controle":
			_anunciar(nome + "!")
			if alvo.has_method("aplicar_lentidao"):
				alvo.aplicar_lentidao(LENTIDAO_SEG)
			else:
				_lentidao_no_jogador()
		"punicao":
			_anunciar(nome + "!")
			_escudo_ate_msec = Time.get_ticks_msec() + int(ESCUDO_SEG * 1000.0)
		"percentual":
			_anunciar(nome + "!")
			_percentual(alvo)
		"ambiente":
			_anunciar(nome + "!")
			_congelar_chao(int(f.get("raio_tiles", 4)))

func _anunciar(texto: String) -> void:
	var cena := get_tree().current_scene if get_tree() else null
	if cena != null and _chefe is Node2D:
		FloatingText.show_text(cena, (_chefe as Node2D).global_position + Vector2(0, -220), texto, Color(0.7, 0.95, 1.0))

# ── 1. Pressão ────────────────────────────────────────────────────────────
func _bater(alvo: Node2D, escala: float) -> void:
	if not alvo.has_method("take_damage"):
		return
	var dano : int = maxi(1, int(round(_dano_base() * escala * _mult_dano())))
	alvo.take_damage(dano, _chefe)

## Base do dano do chefe: sai do ataque dele, não de uma tabela solta — assim
## turbinar o chefe (ou enfurecê-lo) muda tudo de uma vez só.
func _dano_base() -> float:
	if "atk_stat" in _chefe:
		return float(_chefe.atk_stat) * 0.35
	return 30.0

# ── 2. Área telegrafada ───────────────────────────────────────────────────
func _area(f: Dictionary, nome: String) -> void:
	var cena := get_tree().current_scene if get_tree() else null
	if cena == null or not (_chefe is Node2D):
		return
	var centro : Vector2 = (_chefe as Node2D).global_position
	var raio : float = float(f.get("raio", 400.0))
	TelegraphDeArea.disparar(cena, centro, raio, TelegraphDeArea.cor_do_tipo(str(_dados.get("tipo", "ice"))), _chefe)
	_anunciar(nome + "!")
	await get_tree().create_timer(TelegraphDeArea.ATE_O_DANO).timeout
	if not is_instance_valid(self) or not is_instance_valid(_chefe):
		return
	# Mira quem está dentro AGORA, não quem estava quando o golpe começou —
	# é o que faz desviar funcionar de verdade.
	for a in AreaTargeting.find_targets_in_radius(centro, raio, ["follower_pokemon", "player"]):
		if a.has_method("take_damage"):
			a.take_damage(maxi(1, int(round(_dano_base() * float(f.get("dano", 1.5)) * _mult_dano()))), _chefe)

# ── 3. Controle ───────────────────────────────────────────────────────────
func _lentidao_no_jogador() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("aplicar_lentidao"):
			p.aplicar_lentidao(LENTIDAO_SEG)

# ── 5. Percentual ─────────────────────────────────────────────────────────
## Tira uma fatia da vida MÁXIMA, ignorando defesa — e nunca mata. É a função
## que quebra a estratégia de "trago o mais gordo e ganho por atrito".
func _percentual(alvo: Node2D) -> void:
	if not alvo.has_method("take_damage") or not ("max_hp" in alvo and "current_hp" in alvo):
		return
	var tirar : int = int(round(float(alvo.max_hp) * FRACAO_PERCENTUAL))
	# Não-fatal: deixa pelo menos 1 de vida. Morrer por percentual é azar, e
	# azar não ensina nada.
	tirar = mini(tirar, maxi(0, int(alvo.current_hp) - 1))
	if tirar > 0:
		alvo.take_damage(tirar, _chefe)

# ── 6. Ambiente ───────────────────────────────────────────────────────────
## Muda o chão da arena: um anel de gelo em volta do chefe. Usa o MESMO tile de
## gelo do resto do covil (`,`), então o deslize já existente vale aqui sem
## uma linha de código nova — quem ficar parado perto dele perde o controle de
## onde vai parar.
func _congelar_chao(raio_tiles: int) -> void:
	var mapa := get_tree().current_scene if get_tree() else null
	if mapa == null or not (_chefe is Node2D):
		return
	var tm := mapa.get_node_or_null("TileMap") as TileMap
	if tm == null:
		return
	var centro := Vector2i(
		int(floor((_chefe as Node2D).global_position.x / 128.0)),
		int(floor((_chefe as Node2D).global_position.y / 128.0))
	)
	var atlas_gelo : Vector2i = MapLayouts.CHAR_MAP.get(EfeitosDeTerreno.CHAR_GELO, Vector2i(0, 24))
	for dy in range(-raio_tiles, raio_tiles + 1):
		for dx in range(-raio_tiles, raio_tiles + 1):
			if dx * dx + dy * dy > raio_tiles * raio_tiles:
				continue
			var c := centro + Vector2i(dx, dy)
			if tm.get_cell_source_id(0, c) == -1:
				continue
			var td : TileData = tm.get_cell_tile_data(0, c)
			# Não desmancha parede: congelar o chão não pode abrir caminho onde
			# não havia, nem entupir a arena.
			if td != null and td.get_custom_data("blocked"):
				continue
			tm.set_cell(0, c, 0, atlas_gelo)

# ── 4. Punição de dano ────────────────────────────────────────────────────
## Ligado por NinhoLendario ao instalar: enquanto o escudo está de pé, quem
## bate no chefe leva o próprio dano de volta.
func escudo_ativo() -> bool:
	return Time.get_ticks_msec() < _escudo_ate_msec

## Enquanto o escudo está de pé, o dano volta pra quem bateu. Não anula o dano
## recebido de propósito: anular E devolver faria a janela de 4 s ser uma
## parede, e o jogador aprenderia "não posso fazer nada" em vez de "tenho que
## parar de bater agora".
func _ao_levar_dano(alvo: Node, dano: int, _critico: bool, atacante: Node) -> void:
	if alvo != _chefe or not escudo_ativo() or dano <= 0:
		return
	if atacante == null or not is_instance_valid(atacante) or atacante == _chefe:
		return
	if not atacante.has_method("take_damage"):
		return
	_anunciar("Refletido!")
	atacante.take_damage(dano, _chefe)

func _enfurecer() -> void:
	_enfurecido = true
	_anunciar("ENFURECIDO!")
	if _chefe is Node2D and _chefe.get("sprite") != null:
		_chefe.sprite.modulate = Color(1.0, 0.6, 0.6)
	var camera := get_node_or_null("/root")
	if camera != null and Engine.get_main_loop() is SceneTree:
		var fi = Engine.get_main_loop().root.get_node_or_null("FeedbackDeImpacto")
		if fi != null and fi.has_method("tremer_camera"):
			fi.tremer_camera(1.0)

func esta_enfurecido() -> bool:
	return _enfurecido
