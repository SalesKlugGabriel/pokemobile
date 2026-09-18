## teste_gameplay_v3_fase20.gd — Performance: LOD de lógica (Fase 20).
##
## ── O que dá pra provar em headless, e o que não dá ─────────────────────────
##
## **FPS não se mede sem renderizar** — headless não desenha, e alegar FPS a
## partir daqui seria número inventado com cara de medição. Esse erro já quase
## foi cometido neste projeto e está registrado no cabeçalho do `Laboratorio3D`.
##
## O que **é** contável em headless: **quantos corpos pensaram neste quadro**.
## A economia de lógica vira número exato, determinístico, sem navegador — e é
## isso que este arquivo mede. O FPS continua sendo medido no navegador, pelo
## laboratório, e quem roda é o Gabriel.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **O inimigo que trava.** Se a economia alcançar quem persegue, ataca ou
##      foge, o jogo parece desistir do jogador. É a regra que vale mais que a
##      economia inteira.
##   2. **O mundo distante em câmera lenta.** Quem pula quadro precisa andar o
##      que deixou de andar, senão a economia vira bug visual.
##   3. **A velocidade inflada vazando.** A compensação é pro passo, não pro
##      estado: se ficar, o bicho dispara ao se aproximar.
##   4. **O pico a cada 4 quadros.** Sem espalhar a fase, todos os distantes
##      pensam no MESMO quadro — troca-se a média pelo engasgo.
##   5. **Economia que não economiza.** Se a conta der ~0, o código só
##      adicionou complexidade.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 20: LOD de lógica ===")
	_cadencia()
	_a_trava_que_importa()
	_espalhar()
	_compensacao()
	_quanto_economiza()

# ──────────────────────────────────────────────────────────────────────────────
# 1. A cadência por distância
# ──────────────────────────────────────────────────────────────────────────────

func _cadencia() -> void:
	print("\n-- perto pensa sempre, longe pensa às vezes --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeRitmo.gd")

	_conf("colado no jogador: todo quadro", R.divisor(0.0) == 1)
	_conf("no limite do raio total: ainda todo quadro",
		R.divisor(R.RAIO_TOTAL) == 1)
	_conf("um passo além: metade", R.divisor(R.RAIO_TOTAL + 0.1) == R.DIVISOR_MEDIO)
	_conf("longe: um quarto", R.divisor(R.RAIO_MEDIO + 0.1) == R.DIVISOR_LONGE)
	_conf("muito longe não passa de um quarto", R.divisor(9999.0) == R.DIVISOR_LONGE,
		"passo grande demais atravessa parede fina, longe da vista")

	# O raio total tem de cobrir o nascimento, senão a economia pega quem
	# acabou de chegar — e o jogador vê o bicho novo pensando devagar.
	var S = load("res://scripts/gameplay_v3/mundo/RegraDeSpawn.gd")
	_conf("tudo que nasce já nasce pensando todo quadro",
		R.RAIO_TOTAL > S.RAIO_MAXIMO,
		"nascimento vai até %.0f m, ritmo total até %.0f m"
			% [S.RAIO_MAXIMO, R.RAIO_TOTAL])

# ──────────────────────────────────────────────────────────────────────────────
# 2. A trava — vale mais que a economia
# ──────────────────────────────────────────────────────────────────────────────

func _a_trava_que_importa() -> void:
	print("\n-- quem está em jogo nunca desacelera --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeRitmo.gd")

	_conf("protegido a 1000 m ainda pensa todo quadro",
		R.divisor(1000.0, true) == 1,
		"economizar aqui é o inimigo que trava no meio da perseguição")
	for quadro in 8:
		if not R.deve_pensar(quadro, 1000.0, true, 7):
			_conf("protegido pensa em TODOS os quadros", false, "falhou no %d" % quadro)
			return
	_conf("protegido pensa em TODOS os quadros", true)

	# E o não-protegido longe, de fato, pula.
	var pensou : int = 0
	for quadro in 8:
		if R.deve_pensar(quadro, 1000.0, false, 0):
			pensou += 1
	_conf("o ocioso distante pula quadros", pensou < 8, "pensou %d de 8" % pensou)
	_conf("mas nunca some de vez", pensou > 0,
		"bicho que nunca pensa é bicho congelado")

# ──────────────────────────────────────────────────────────────────────────────
# 3. Espalhar o trabalho
# ──────────────────────────────────────────────────────────────────────────────

func _espalhar() -> void:
	print("\n-- espalhar a fase: média, não engasgo --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeRitmo.gd")

	# 100 corpos distantes. Sem fase, os 100 pensariam no mesmo quadro.
	var distancias : Array = []
	for i in 100:
		distancias.append(1000.0)

	var por_quadro : Array = []
	for quadro in R.DIVISOR_LONGE:
		por_quadro.append(R.quantos_pensam(quadro, distancias))

	var maior : int = 0
	var menor : int = 999
	for n in por_quadro:
		maior = maxi(maior, int(n))
		menor = mini(menor, int(n))
	_conf("nenhum quadro carrega todos", maior < distancias.size(),
		"pico de %d de %d — sem fase seriam 100 num quadro só"
			% [maior, distancias.size()])
	_conf("e nenhum quadro fica vazio", menor > 0, str(por_quadro))
	_conf("o pico é próximo da média",
		float(maior) <= float(distancias.size()) / float(R.DIVISOR_LONGE) * 1.5,
		"pico %d, média %.1f" % [maior, float(distancias.size()) / float(R.DIVISOR_LONGE)])

	# Ao longo de um ciclo, cada corpo pensa o número certo de vezes.
	var vezes : int = 0
	for quadro in R.DIVISOR_LONGE:
		if R.deve_pensar(quadro, 1000.0, false, 3):
			vezes += 1
	_conf("um corpo distante pensa 1 vez a cada 4 quadros", vezes == 1,
		"pensou %d vezes no ciclo" % vezes)

# ──────────────────────────────────────────────────────────────────────────────
# 4. A compensação
# ──────────────────────────────────────────────────────────────────────────────

func _compensacao() -> void:
	print("\n-- quem pulou quadro anda o que deixou de andar --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeRitmo.gd")

	_conf("sem pular, nada muda", is_equal_approx(R.fator_de_avanco(0), 1.0))
	_conf("pulou 3, anda 4×", is_equal_approx(R.fator_de_avanco(3), 4.0))
	_conf("pulado negativo não encolhe o passo", is_equal_approx(R.fator_de_avanco(-5), 1.0),
		"um fator < 1 faria o bicho andar pra trás no tempo")

	_conf("o tempo acumulado acompanha o passo",
		is_equal_approx(R.delta_acumulado(0.016, 3), 0.016 * 4.0),
		"esfriamento e aviso são contados em segundos: não podem correr devagar")
	_conf("sem pular, o delta é o delta",
		is_equal_approx(R.delta_acumulado(0.016, 0), 0.016))

# ──────────────────────────────────────────────────────────────────────────────
# 5. A economia vale a pena?
# ──────────────────────────────────────────────────────────────────────────────

func _quanto_economiza() -> void:
	print("\n-- a economia, como número --")
	var R = load("res://scripts/gameplay_v3/mundo/RegraDeRitmo.gd")

	# Um cenário parecido com um mundo aberto: poucos perto, muitos longe.
	var distancias : Array = []
	for i in 4:
		distancias.append(10.0)          # em volta do jogador
	for i in 8:
		distancias.append(50.0)          # no meio
	for i in 28:
		distancias.append(150.0)         # longe, ocioso

	var economia : float = R.economia_media(distancias)
	_conf("a economia é substancial", economia > 0.5,
		"%.0f%% do trabalho de IA deixa de acontecer" % (economia * 100.0))
	print("      → %.1f%% de economia em %d corpos" % [economia * 100.0, distancias.size()])

	# O mesmo cenário com TODOS protegidos (o pior caso, uma horda inteira em
	# cima do jogador) não pode economizar nada — e isso é o correto.
	var todos_protegidos : Array = []
	for i in distancias.size():
		todos_protegidos.append(true)
	_conf("horda inteira engajada: economia zero, e está certo",
		is_equal_approx(R.economia_media(distancias, todos_protegidos), 0.0),
		"o 1v10 que o Gabriel pediu paga o preço cheio, de propósito")

	# Só corpos perto: nada a economizar.
	var perto : Array = [1.0, 2.0, 3.0]
	_conf("mundo todo colado no jogador: economia zero",
		is_equal_approx(R.economia_media(perto), 0.0))

# ──────────────────────────────────────────────────────────────────────────────
# Com corpo de verdade
# ──────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			_no_mundo()
		5:
			_terminar()
			return true
	return false

func _no_mundo() -> void:
	print("\n-- no mundo, com corpo --")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	mundo.add_child(Ter.new())
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var IA = load("res://scripts/gameplay_v3/combate/IASelvagem3D.gd")

	# Um "jogador" parado na origem, e um selvagem MUITO longe dele.
	var jogador := CharacterBody3D.new()
	mundo.add_child(jogador)
	jogador.global_position = Vector3.ZERO

	var longe = P.nascer(mundo, 19, 10, Vector3(200, 2, 0), "ground_biped")
	longe.virar_selvagem(jogador)
	_conf("o selvagem distante existe e sabe quem é o jogador",
		longe.selvagem and longe.alvo_hostil == jogador)
	_conf("e a distância é lida de verdade",
		longe._distancia_do_jogador() > 150.0,
		"%.0f m" % longe._distancia_do_jogador())

	# Ocioso e longe: não é protegido.
	longe.estado_selvagem = IA.PARADO
	longe.provocado = false
	_conf("ocioso e longe NÃO é protegido", not longe._protegido_do_ritmo())

	# Perseguindo: protegido, por mais longe que esteja.
	longe.estado_selvagem = IA.PERSEGUIR
	_conf("perseguindo a 200 m É protegido", longe._protegido_do_ritmo(),
		"esta é a linha que impede o inimigo de travar")
	longe.estado_selvagem = IA.ATACAR
	_conf("atacando também", longe._protegido_do_ritmo())
	longe.estado_selvagem = IA.FUGIR
	_conf("fugindo também — a fuga é do jogador", longe._protegido_do_ritmo())

	# VOLTAR não é protegido: é serviço interno, longe da vista.
	longe.estado_selvagem = IA.VOLTAR
	_conf("voltando pra casa NÃO é protegido", not longe._protegido_do_ritmo(),
		"é o caso em que a economia vive — e onde a compensação importa")

	# Provocado protege mesmo parado.
	longe.estado_selvagem = IA.PARADO
	longe.provocado = true
	_conf("provocado é protegido mesmo PARADO", longe._protegido_do_ritmo())
	longe.provocado = false

	_o_passo_compensado(mundo, jogador, P, IA)

## 🔴 O bug que a compensação existe pra impedir: o mundo distante em câmera
## lenta. Dois corpos iguais, mesma velocidade, um perto e um longe — depois do
## mesmo número de quadros têm de ter andado aproximadamente o mesmo tanto.
func _o_passo_compensado(mundo: Node3D, jogador: Node3D, P, IA) -> void:
	var perto = P.nascer(mundo, 19, 10, Vector3(5, 2, 0), "ground_biped")
	var longe = P.nascer(mundo, 19, 10, Vector3(300, 2, 0), "ground_biped")
	for b in [perto, longe]:
		b.virar_selvagem(jogador)
		b.estado_selvagem = IA.VOLTAR        # anda, e não é protegido
		b.casa = b.global_position + Vector3(40, 0, 0)

	# ⚠️ **Deslocamento não serve de prova aqui.** `move_and_slide()` chamado
	# fora do passo de física real não move o corpo — medido: o Rattata fica
	# em `(5, 2, 0)` depois de 10 quadros, com velocidade correta de 4,96 m/s.
	# Então a conferência é sobre o avanço **pedido** a cada passo, que é
	# exatamente o número que a compensação decide. A prova de que o corpo anda
	# de verdade é o jogo no navegador, e quem roda isso é o Gabriel.
	var somou_perto : float = 0.0
	var somou_longe : float = 0.0
	for i in 40:
		perto._physics_process(1.0 / 60.0)
		longe._physics_process(1.0 / 60.0)
		somou_perto += absf(perto.ultimo_avanco.x)
		somou_longe += absf(longe.ultimo_avanco.x)
		# `ultimo_avanco` só é escrito por quem pensou; zerar aqui evita contar
		# de novo o passo do quadro anterior em quem pulou este.
		perto.ultimo_avanco = Vector3.ZERO
		longe.ultimo_avanco = Vector3.ZERO

	_conf("os dois pediram avanço", somou_perto > 1.0 and somou_longe > 1.0,
		"perto %.1f, longe %.1f" % [somou_perto, somou_longe])
	_conf("o distante NÃO anda em câmera lenta",
		somou_longe > somou_perto * 0.6,
		"perto %.1f, longe %.1f — sem compensação o longe pediria ~1/4"
			% [somou_perto, somou_longe])

	# E a velocidade não fica inflada depois do passo compensado.
	_conf("a compensação não vaza pra velocidade",
		longe.velocity.length() <= perto.velocity.length() * 1.5 + 0.01,
		"perto %.2f, longe %.2f — velocidade inflada faz o bicho disparar ao chegar perto"
			% [perto.velocity.length(), longe.velocity.length()])

## A guarda da Fase 16: teste que aborta calado é teste que passa mentindo.
const CONFERENCIAS_ESPERADAS : int = 33

func _terminar() -> void:
	var total : int = ok + fail
	if total < CONFERENCIAS_ESPERADAS:
		fail += 1
		print("  FALHOU  só %d de %d conferências rodaram — alguma abortou calada"
			% [total, CONFERENCIAS_ESPERADAS])
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
