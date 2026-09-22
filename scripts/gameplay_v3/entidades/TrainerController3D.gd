## TrainerController3D.gd — O treinador no mundo 3D (§11).
##
## Terceira pessoa. WASD relativo à câmera, mouse olhando, corrida, colisão real,
## gravidade, inclinação e **a mesma stamina da V2**.
##
## ── O que veio de graça do que já existia ───────────────────────────────────
##
## `Stamina.gd` entra **sem uma linha alterada**. Ela é classe pura: as três
## linhas de progressão, os três degraus de exaustão e a espera de 1 segundo
## depois do zero nunca souberam se o jogo era 2D ou 3D. É o pivô cobrando o
## juro da disciplina de manter regra fora do nó.
##
## ── Quem manda no input ─────────────────────────────────────────────────────
##
## Este nó **não decide** se deve escutar. O `ControlModeManager` liga e desliga
## o processamento de input dele (§12). Quando o jogador assume o Pokémon, este
## controlador para de ter vontade própria — mas **continua no mundo, com
## física**, porque a §17 diz que o treinador permanece lá.
extends CharacterBody3D
class_name TrainerController3D

const PlayerVisualScript = preload("res://scripts/gameplay_v3/presentation/PlayerVisual3D.gd")

## RFC-007, decisão 1 (opção B): **a altura do treinador é 1,60 m.**
##
## Era 1,75 m — um número que nunca representou ninguém: foi escrito quando o
## corpo era uma cápsula amarela e não havia personagem. O asset do Codex
## (`player_v1.glb`) mede **1,600 m**, pés em Y=0. Manter 1,75 deixaria 15 cm de
## colisor invisível acima da cabeça — dois números descrevendo a mesma pessoa e
## discordando, que é exatamente a classe de defeito que este projeto não aceita.
##
## Calibrado agora porque agora é barato: **nada** foi medido contra 1,75 ainda
## (não há porta, teto de caverna, agachar nem altura de passagem no jogo). O dia
## em que houver, mexer aqui passa a quebrar coisas.
const ALTURA_DO_CORPO : float = 1.60

## ⚠️ O raio **não** foi reduzido junto, de propósito. Ele é a largura do corpo,
## não a altura, e 0,35 m já é uma folga razoável pra qualquer adulto. Mexer nos
## dois de uma vez tornaria qualquer regressão de colisão impossível de atribuir
## a um deles.
const RAIO_DO_CORPO : float = 0.35

signal stamina_mudou(atual: float, maximo: float, estado: String)
signal comecou_a_andar()

## Fase 21b: uma captura terminou. Traz `{pegou, guardado, nome, destino,
## foi_pro_pc, mensagem}` — a HUD **mostra** a `mensagem`, não a remonta.
signal capturou(relatorio: Dictionary)
signal parou()

## Fase 21: o atributo Luck do treinador, que a chance de captura consulta.
##
## ⚠️ Vive aqui e não é recalculado: o `Corpo3D` procura por
## `treinador_v3`/`treinador_v2` no grupo e lê este campo, exatamente como o
## `Corpo` da V2 fazia. Quando a árvore de talentos da V3 existir, ela escreve
## aqui — e nada mais precisa mudar.
var sorte : int = 0

var stamina : Stamina = Stamina.new()
var camera : CameraTerceiraPessoa = null
var visual_do_jogador : Node = null

## §11: a §5 da V2 vale igual — correr, nadar, escalar e pular custam fôlego.
var _parado_antes : bool = true

## Preenchido de fora quando o controle vem do toque, como na V2. `mover()` é a
## porta; o teclado é só uma das fontes.
var intencao : Vector2 = Vector2.ZERO
var quer_correr : bool = false
var le_teclado : bool = true

func _ready() -> void:
	add_to_group("treinador_v3")
	add_to_group("player")   # a ponte de feedback já procura este grupo
	_montar_corpo()
	camera = CameraTerceiraPessoa.new()
	add_child(camera)
	# 🔴 `top_level` corrigido em 17/09, e é o bug de arquitetura dos dois.
	#
	# Sendo filha do corpo, o yaw da câmera era RELATIVO a ele — e o corpo gira
	# pra direção do movimento. O laço que o Gabriel sentiu:
	#
	#     aperta W → corpo anda pra −Z → o corpo vira → a câmera vira junto →
	#     "frente da câmera" virou outra direção → W passa a andar pro outro lado
	#
	# Com `top_level`, a câmera deixa de herdar a transformação do pai: ela segue
	# só a POSIÇÃO do treinador (em `_physics_process`) e o ângulo é sempre do
	# mouse, de mais ninguém. É o que a §11 pede — *"o mouse é o indicador de
	# caminho"* — e é o que faz o W andar pra onde se está olhando.
	camera.top_level = true
	camera.seguir(global_position)

## Corpo físico. A malha e animação vivem no componente visual do Codex; a
## cápsula abaixo é apenas colisão e não pode voltar a ser o boneco amarelo.
func _montar_corpo() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = RAIO_DO_CORPO
	capsula.height = ALTURA_DO_CORPO
	forma.shape = capsula
	forma.position.y = ALTURA_DO_CORPO * 0.5
	add_child(forma)

	visual_do_jogador = PlayerVisualScript.new()
	add_child(visual_do_jogador)

	# §11: inclinação. Sem isto o corpo trava na primeira ladeira e "sobe"
	# qualquer parede vertical — os dois ficam errados ao mesmo tempo.
	floor_max_angle = Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA
	floor_snap_length = 0.4

# ──────────────────────────────────────────────────────────────────────────────
# Input
# ──────────────────────────────────────────────────────────────────────────────

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and camera != null:
		camera.girar((evento as InputEventMouseMotion).relative)
	# Fase 21. A ação `pokeball` **já existia** no InputMap (Espaço) e nada a
	# lia — o mesmo padrão do kit vazio da Fase 17 e do Alpha que nunca nascia
	# da Fase 18: a tecla existia, apertar não fazia nada, e não dava erro.
	elif evento.is_action_pressed("pokeball"):
		arremessar_pokebola()

## Arremessa uma pokébola no corpo mais próximo dentro do alcance.
##
## ── Por que a mira é do mouse, e por que isto estava previsto ───────────────
##
## É a decisão do Gabriel de 18/09: *"o mouse precisa ser a mira para todas as
## ações, inclusive em combate, para arremessar pokébolas"*. O `origem_da_mira()`
## foi escrito naquele dia **com esta bola em mente** — o comentário dele diz,
## com todas as letras, que uma pokébola nascendo no chão atravessaria o próprio
## corpo no primeiro passo.
##
## ── Por que existe alvo, se a mira é livre ──────────────────────────────────
##
## Porque a §28 diz que a tensão está na **escolha**, não na pontaria. Exigir
## acerto milimétrico num corpo pequeno, com o Alpha vindo por cima, tornaria a
## captura um teste de mira — e a decisão de arriscar deixaria de ser a parte
## difícil. Então a mira escolhe o alvo, e a bola vai atrás dele.
func arremessar_pokebola(qual_ball: String = "pokeball") -> Dictionary:
	var corpo := corpo_mirado()
	if corpo == null:
		return {"lancou": false,
			"motivo": "Nenhum corpo por perto pra tentar capturar."}

	var alcance : Dictionary = RegraDeArremesso.no_alcance(
		global_position, corpo.global_position)
	if not bool(alcance["pode"]):
		return {"lancou": false, "motivo": str(alcance["motivo"])}

	var bola := PokebolaLancada3D.lancar(get_parent(), origem_da_mira(),
		direcao_de_mira(), corpo, qual_ball, sorte)
	# 🔴 O ouvinte que faltava. Até 21/09 a bola emitia `resolveu` e **ninguém
	# escutava**: o jogador capturava e o Pokémon evaporava. Conferido — nenhum
	# arquivo fora da própria bola se conectava a este sinal.
	bola.resolveu.connect(_guardar_captura)
	return {"lancou": true, "motivo": "", "alvo": corpo}

## Uma bola resolveu. Se pegou, o Pokémon vai pro save.
##
## ⚠️ Nada aqui é conta nova: `_make_pokemon_data` monta (IVs, natureza, golpes
## do nível), `add_pokemon` escolhe entre time e PC, `mark_caught` cuida da
## Pokédex — tudo em uso desde a V1. A única decisão nova é **o que contar ao
## jogador**, e ela mora em `RegraDeGuardarCaptura`.
func _guardar_captura(resultado: Dictionary) -> void:
	var pode : Dictionary = RegraDeGuardarCaptura.deve_guardar(resultado)
	if not bool(pode["guardar"]):
		capturou.emit({"pegou": false, "motivo": str(resultado.get("motivo", ""))})
		return

	# ⚠️ `get_node_or_null`, nunca o identificador do autoload — a lição de
	# cinco fases. E sem save (laboratório, teste headless) a captura ainda
	# acontece: ela só não é guardada, e o relatório diz isso em vez de estourar.
	var save := get_node_or_null("/root/SaveManager")
	var jogo := get_node_or_null("/root/GameData")
	var id : int = int(resultado["species_id"])
	var nivel : int = int(resultado["nivel"])
	var nome : String = "Pokémon"
	if jogo != null:
		nome = str(jogo.get_species(id).get("name", nome))

	if save == null:
		capturou.emit({"pegou": true, "guardado": false, "nome": nome,
			"motivo": "sem save nesta cena — a captura não foi guardada"})
		return

	var dados : Dictionary = save._make_pokemon_data(id, nivel)
	var destino : String = str(save.add_pokemon(dados))
	save.mark_caught(id)
	save.save_game()

	var rel : Dictionary = RegraDeGuardarCaptura.relatorio(id, nivel, nome, destino)
	rel["guardado"] = true
	rel["pegou"] = true
	capturou.emit(rel)

## O corpo que a mira escolhe: o mais próximo dentro do alcance, entre os que
## ainda aceitam tentativa.
##
## ⚠️ Filtra por `pode_tentar` ANTES de escolher, não depois. Escolher o mais
## próximo e só então descobrir que ele é um Alpha faria a bola ser desperdiçada
## num alvo impossível enquanto um capturável estava logo atrás.
func corpo_mirado() -> Node3D:
	if not is_inside_tree():
		return null
	var melhor : Node3D = null
	var menor : float = INF
	for c in get_tree().get_nodes_in_group("corpo_v3"):
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		if c.get("dados") != null \
				and not bool(RegrasDeCorpo.pode_tentar(c.dados)["pode"]):
			continue
		var d : float = global_position.distance_to((c as Node3D).global_position)
		if d < menor and d <= RegraDeArremesso.alcance_maximo():
			menor = d
			melhor = c
	return melhor

func _ler_teclado() -> void:
	if not le_teclado:
		return
	# Uma fonte só de intenção, como na V2: o toque preenche o MESMO campo, pra
	# nenhuma regra precisar ser escrita duas vezes.
	intencao = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	quer_correr = Input.is_action_pressed("run") and stamina.atual > 0.0

## A porta do toque e do teste. Desliga o teclado sozinho, como na V2.
func mover(nova_intencao: Vector2, correndo: bool = false) -> void:
	le_teclado = false
	intencao = nova_intencao
	quer_correr = correndo

func soltar_movimento() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true

# ──────────────────────────────────────────────────────────────────────────────
# O laço
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_ler_teclado()
	_tick_stamina(delta)

	var base : Basis = camera.base_do_movimento() if camera != null else Basis.IDENTITY
	var alvo := Locomocao3D.velocidade_alvo(
		intencao, quer_correr, base, stamina.fator_de_velocidade())
	velocity = Locomocao3D.avancar(velocity, alvo, delta)
	velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta)

	move_and_slide()
	if visual_do_jogador != null:
		# RFC-007: o visual consome exclusivamente o estado efetivo, nunca
		# `quer_correr` ou qualquer outra intenção de input.
		visual_do_jogador.call("apresentar_locomocao", estado_visual_de_locomocao())

	# Decisão do Gabriel, 21/09: em terceira pessoa o corpo olha para onde
	# CAMINHA. Atrelá-lo ao yaw da câmera fazia o modelo ficar de frente para o
	# observador e ler W como uma caminhada de costas. A mira continua sendo a
	# câmera em `direcao_de_mira()`; orientação corporal não decide ataques.
	rotation.y = Locomocao3D.girar_para(rotation.y, velocity, delta)

	# A câmera é `top_level`: não herda mais nada do corpo, então a posição dela
	# tem de ser acompanhada à mão. É de propósito — herdar a posição traria a
	# rotação junto, que é exatamente o bug que isto conserta.
	if camera != null:
		camera.seguir(global_position)

	_conferir_parada()

func _tick_stamina(delta: float) -> void:
	var acoes : Array = []
	# Correr parado não é corrida. Cobrar isso seria armadilha invisível — mesma
	# decisão da V2.
	if quer_correr and intencao != Vector2.ZERO:
		acoes.append("correr")
	if stamina.passo(delta, acoes, esta_parado()):
		stamina_mudou.emit(stamina.atual, stamina.maximo(), stamina.estado())

## 🎯 A MIRA — uma fonte só, pra toda ação do treinador.
##
## Pedido do Gabriel (18/09): o mouse é a mira de tudo. Pokébola, ataque, o que
## vier. Por isso isto é **função**, e não cada lugar calculando a sua direção:
## duas contas pro mesmo "pra onde" é como um jogo passa a mirar num lugar e
## acertar em outro.
##
## Vem COM o pitch — quem mira pra cima arremessa pra cima. A direção de ANDAR é
## outra coisa (`camera.base_do_movimento()`, achatada), e a diferença é de
## propósito: andar pro chão quando se olha pra baixo seria bug.
func direcao_de_mira() -> Vector3:
	if camera != null and camera.camera != null:
		return -camera.camera.global_transform.basis.z
	return -global_transform.basis.z

## De onde a ação sai: a altura do ombro, não os pés. Uma pokébola que nasce no
## chão atravessa o próprio corpo no primeiro passo.
func origem_da_mira() -> Vector3:
	if camera != null:
		return camera.global_position
	# RFC-007: o 1,5 cravado aqui era uma SEGUNDA cópia da altura do ombro, e
	# copiada de um corpo de 1,75 m. Ler a constante da câmera faz o fallback
	# acompanhar a recalibração sozinho — duas cópias do mesmo número é como o
	# fallback passaria a mirar de outra altura que o caminho normal.
	return global_position + Vector3.UP * CameraTerceiraPessoa.ALTURA_DO_OMBRO

func esta_parado() -> bool:
	return Locomocao3D.esta_parado(velocity)

## A velocidade **horizontal de fato**, em m/s. O `y` fica de fora de propósito:
## cair não é andar, e uma queda faria a animação correr no ar.
func velocidade_horizontal() -> float:
	return Vector2(velocity.x, velocity.z).length()

## RFC-007, decisão 2 (opção A): **o único contrato do visual de locomoção.**
##
## Devolve `idle`, `walk` ou `run`, derivado do que o corpo **faz** — nunca do
## que ele quer. A diferença não é filosófica, é medida:
##
##   - `quer_correr` é intenção. A velocidade real passa por
##     `Stamina.fator_de_velocidade()`, que no nível 3 de exaustão vale **0,50**.
##     Correr exausto dá 8,0 × 0,5 = **4,0 m/s** — *abaixo* dos 4,5 m/s de
##     caminhada. Uma animação que lesse `quer_correr` tocaria CORRIDA num corpo
##     andando mais devagar que um passo normal.
##   - E as duas portas de entrada discordam: o teclado exige
##     `stamina.atual > 0.0` pra ligar `quer_correr`, mas `mover()` — a porta do
##     toque, que é a do celular — aceita `correndo` sem conferir nada.
##
## Por isso a fachada `esta_parado()` + `quer_correr` (opção B da RFC) foi
## recusada: ela obrigaria o visual a reimplementar a conta da stamina pra não
## errar, e reimplementar é como os dois lados passam a discordar.
func estado_visual_de_locomocao() -> String:
	if esta_parado():
		return "idle"
	# O meio do caminho entre andar e correr. Não é um número escolhido por
	# gosto: é o único ponto que fica igualmente longe das duas velocidades
	# nominais, então nem a caminhada plena nem a corrida plena ficam perto da
	# fronteira — que é onde a animação piscaria entre dois clipes.
	var meio : float = (Locomocao3D.VELOCIDADE_CAMINHADA
		+ Locomocao3D.VELOCIDADE_CORRIDA) * 0.5
	return "run" if velocidade_horizontal() >= meio else "walk"

func _conferir_parada() -> void:
	var agora := esta_parado()
	if agora == _parado_antes:
		return
	_parado_antes = agora
	if agora:
		parou.emit()
	else:
		comecou_a_andar.emit()

# ──────────────────────────────────────────────────────────────────────────────
# Ganchos do ControlModeManager (§12)
# ──────────────────────────────────────────────────────────────────────────────

## Chamado quando o jogador volta a ser o treinador.
func ao_assumir_controle() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera != null and camera.camera != null:
		camera.camera.current = true

## Chamado quando o jogador assume o Pokémon. A intenção é zerada de propósito:
## sem isso, o treinador continuaria andando pra sempre na última direção que o
## jogador segurava quando a batalha começou.
func ao_perder_controle() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true
