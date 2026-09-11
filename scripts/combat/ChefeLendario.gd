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
## 🔴 Fase 2: o nível virou variável (continua nascendo em NIVEL) porque o
## item 10 pede simulação do chefe em Lv30/50/75/100 — sem isso não dá pra
## medir a luta, só torcer.
var nivel : int = NIVEL
## 🔴 Fase 2, medido: com ×7 a luta contra o chefe durava 218-265s e SEMPRE
## alcançava o enrage (que dispara aos 240s) — ou seja, a fase de fúria não era
## uma punição por demorar, era o final garantido de toda luta. Com ×5 a luta
## bem jogada fecha em ~160s e o enrage volta a ser o que deveria: o preço de
## errar demais. O chefe continua com 5x a vida de um selvagem do mesmo nível.
const MULT_HP         : float = 5.0
const MULT_DEFESA     : float = 1.5
const MULT_ATAQUE     : float = 1.35
const ENRAGE_SEG      : float = 240.0  ## 4 minutos
const ENRAGE_DANO     : float = 2.0
const ENRAGE_ESPERA   : float = 0.7    ## −30%

## 🔴 Fase 2: o `dano` de cada função do repertório era um multiplicador solto
## aplicado em `atk_stat × 0.35` — ou seja, o chefe batia FORA da fórmula do
## jogo: ignorava defesa, ignorava tipo, ignorava STAB e, o mais grave,
## ignorava o teto de 90% que impede hit-kill. Um golpe de área do chefe
## enfurecido apagava um Pokémon de nível médio sem passar por conferência
## nenhuma.
##
## Agora o `dano` é convertido em POWER (a mesma escala de moves.json) e o
## golpe passa pelo `DamageCalculator` como qualquer outro. O chefe continua
## perigoso — é o ataque e o HP dele que fazem isso — mas agora resistir a
## Gelo realmente ajuda contra Articuno, e nada mata de um.
const POWER_POR_ESCALA : float = 70.0

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
	_chefe.wild_level = nivel
	# 🔴 Fase 3 (item P4): o chefe passa a ser um POKÉMON DE VERDADE com
	# mecânicas de encontro por cima, em vez de um boneco com repertório
	# próprio e nada mais.
	#
	# A distinção que o Gabriel fez, e que este bloco implementa:
	#
	#   KIT DE POKÉMON       os 7-8 golpes que a espécie aprende, escolhidos
	#                        pela mesma IA, passando pelo mesmo DamageCalculator,
	#                        FormaDeArea, cooldown, status e targeting;
	#   MECÂNICA DE ENCONTRO as seis funções deste arquivo (pressão, área,
	#                        controle, punição, percentual, ambiente), mais
	#                        enrage, escudo e selo.
	#
	# As duas coisas convivem: o chefe alterna entre bater com o kit dele e
	# executar uma função de encontro. Antes, ele NUNCA usava um golpe de
	# Pokémon — só as seis funções —, o que é o que fazia a luta parecer um
	# script em vez de uma batalha.
	if "categoria_de_encontro" in _chefe:
		_chefe.categoria_de_encontro = "lendario"
	if _chefe.has_method("_montar_golpes"):
		_chefe._montar_golpes()
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
		# 🔴 Fase 3 (P5): JANELA DE VULNERABILIDADE. Depois de gastar uma das
		# funções PESADAS, o chefe fica exposto por alguns segundos e recebe
		# mais dano.
		#
		# É a mecânica que faz o KIT importar, que era o pedido: quem tem golpe
		# de BURST guardado aproveita a janela e a luta encurta de verdade; quem
		# só tem dano constante não perde nada, mas também não ganha. Deixar de
		# usar a ultimate na hora errada passa a ser uma decisão, não um
		# detalhe. Sem isso, o chefe era só uma barra grande com um cronômetro.
		if funcao in FUNCOES_QUE_EXPOEM:
			_vulneravel_ate_msec = agora + int(VULNERAVEL_SEG * 1000.0)
			_anunciar("Exposto!")
		return

## Quais funções deixam o chefe exposto. As três mais caras — as que ele
## "carrega" pra usar. A pressão (o golpe barato e frequente) não expõe, senão
## ele passaria a luta inteira vulnerável e a mecânica perderia o sentido.
const FUNCOES_QUE_EXPOEM : Array[String] = ["percentual", "ambiente", "area"]
const VULNERAVEL_SEG : float = 4.0
const VULNERAVEL_MULT : float = 1.6

var _vulneravel_ate_msec : int = 0

## Está exposto agora? Lido pelo WildPokemon na hora de receber dano.
func esta_vulneravel() -> bool:
	return Time.get_ticks_msec() < _vulneravel_ate_msec

## Quanto o dano recebido é multiplicado agora.
func multiplicador_de_dano_recebido() -> float:
	return VULNERAVEL_MULT if esta_vulneravel() else 1.0

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
	alvo.take_damage(dano_em(alvo, escala), _chefe)

## Quanto este golpe do chefe tira DESTE alvo — pela fórmula do jogo, com
## defesa, tipo, STAB, variação e o teto anti-hit-kill valendo.
func dano_em(alvo: Node, escala: float) -> int:
	var golpe : Dictionary = {
		"power": int(round(POWER_POR_ESCALA * escala * _mult_dano())),
		"type": _tipo_em_maiuscula(),
		"category": "special",
		"name": str(_dados.get("nome", "Chefe")),
	}
	var defensor : Dictionary = {}
	if alvo.has_method("get_combat_stats"):
		defensor = alvo.get_combat_stats()
	return DamageCalculator.calculate_damage(golpe, _atacante(), defensor)

## O chefe como atacante. `spa` e `atk` saem do WildPokemon em que ele está
## pendurado — turbinar o chefe continua mudando tudo de uma vez só.
func _atacante() -> Dictionary:
	var a : int = 60
	var sa : int = 60
	if _chefe != null:
		if "atk_stat" in _chefe:
			a = int(_chefe.atk_stat)
		if "spa_stat" in _chefe:
			sa = int(_chefe.spa_stat)
	return {
		"atk": a, "spa": sa, "level": nivel,
		"types": [_tipo_em_maiuscula()],
	}

## "ice" -> "Ice". A tabela de tipos usa maiúscula; o repertório usa minúscula
## (porque a cor do telegraph usa minúscula). Converter num lugar só evita o
## bug silencioso de o tipo nunca casar e toda efetividade virar x1.
func _tipo_em_maiuscula() -> String:
	var s : String = str(_dados.get("tipo", "ice"))
	return s.substr(0, 1).to_upper() + s.substr(1)

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
	var golpe_area : Dictionary = {
		"area_type": "circle", "radius": raio,
		"max_targets": CombatBalance.MAX_ALVOS_PADRAO,
	}
	for a in FormaDeArea.alvos(centro, Vector2.RIGHT, golpe_area,
			["follower_pokemon", "player"], [_chefe]):
		if a.has_method("take_damage"):
			a.take_damage(dano_em(a, float(f.get("dano", 1.5))), _chefe)

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
		# 09/09: a música acelera junto com o chefe — sem precisar de trilha nova.
		var audio = Engine.get_main_loop().root.get_node_or_null("AudioManager")
		if audio != null and audio.has_method("intensificar_bgm"):
			audio.intensificar_bgm()

func esta_enfurecido() -> bool:
	return _enfurecido
