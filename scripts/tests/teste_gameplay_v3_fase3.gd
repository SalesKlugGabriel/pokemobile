## teste_gameplay_v3_fase3.gd — O treinador 3D anda, cai e obedece ao árbitro.
##
## Fase 3 da migração V3. Carrega a cena 3D de verdade, deixa a física rodar e
## confere que a coisa acontece — não que o código compila.
##
## ── A conferência mais importante do arquivo ────────────────────────────────
##
## `_nunca_dois_donos_do_input()`. A §12 do pedido é literal: *"Nunca permitir
## dois controladores processarem input principal simultaneamente."* É o bug que
## toda troca de corpo produz, e ele é invisível em código — só aparece com o
## jogador vendo dois personagens andarem ao mesmo tempo.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _fase : int = 0
var _tempo : float = 0.0
var _lab : Node3D = null

## Autoload não é identificador em teste `--script`.
var PonteDeFeedback : Node

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

func _initialize() -> void:
	print("== Gameplay V3 · Fase 3: treinador 3D ==")

func _process(delta: float) -> bool:
	_tempo += delta
	match _fase:
		0:
			PonteDeFeedback = root.get_node("PonteDeFeedback")
			_montar()
			_fase = 1
			_tempo = 0.0
		1:
			# Tempo pro corpo cair e assentar no chão antes de medir qualquer coisa.
			if _tempo > 1.0:
				_conferir_montagem()
				_andar()
				_fase = 2
				_tempo = 0.0
		2:
			# Meio segundo: tempo de acelerar, e cedo o bastante pra medir
			# "está andando" ANTES de qualquer obstáculo. A primeira versão
			# media em 1,5 s, quando o treinador já tinha encostado num degrau
			# — e reprovava um controlador que estava certo.
			if _tempo > 0.5:
				_conf(not _lab.treinador.esta_parado(),
					"ele se reconhece em movimento enquanto anda")
				_fase = 25
				_tempo = 0.0
		25:
			if _tempo > 1.0:
				_conferir_movimento()
				_fase = 3
				_tempo = 0.0
		3:
			if _tempo > 0.5:
				_conferir_arbitro()
				_conferir_terreno()
				_fase = 4
		_:
			print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
			quit(1 if fail > 0 else 0)
			return true
	return false

func _montar() -> void:
	var cena = load("res://scenes/gameplay_v3/Laboratorio3D.tscn")
	if cena == null:
		_conf(false, "a cena 3D carrega")
		_fase = 9
		return
	_lab = cena.instantiate()
	root.add_child(_lab)

var _pos_inicial : Vector3 = Vector3.ZERO

func _conferir_montagem() -> void:
	_conf(_lab != null, "a cena 3D do Laboratório instancia")
	if _lab == null:
		return
	_conf(_lab.treinador != null, "o treinador 3D existe")
	_conf(_lab.controle != null, "o árbitro de input existe")
	if _lab.treinador == null:
		return

	var t = _lab.treinador
	_conf(t is CharacterBody3D, "e é um corpo 3D de verdade",
		"é %s" % t.get_class())
	_conf(t.camera != null, "tem câmera de 3ª pessoa")
	_conf(t.camera.camera != null, "com uma Camera3D na ponta do braço")

	# A stamina da V2 entrou sem adaptação — é o juro da disciplina de manter
	# regra fora do nó.
	_conf(t.stamina != null, "e a Stamina da V2 entrou sem adaptação")
	_conf(t.stamina.atual > 0.0, "começando cheia", "%.0f" % t.stamina.atual)

	# §11: gravidade. O corpo nasceu a 2 m de altura e tem que ter caído.
	_conf(t.is_on_floor(), "a gravidade trouxe o treinador pro chão (§11)",
		"y = %.2f" % t.global_position.y)

	_pos_inicial = t.global_position

func _andar() -> void:
	if _lab == null or _lab.treinador == null:
		return
	# Pela fachada, como o toque faria — e não simulando tecla.
	_lab.treinador.mover(Vector2(0, 1), true)

func _conferir_movimento() -> void:
	if _lab == null or _lab.treinador == null:
		return
	var t = _lab.treinador
	var andou : float = t.global_position.distance_to(_pos_inicial)
	_conf(andou > 3.0, "o treinador andou de verdade", "andou %.1f m" % andou)
	_conf(t.stamina.atual < t.stamina.maximo(),
		"correr gastou stamina (§5 da V2, intacta)",
		"sobrou %.0f" % t.stamina.atual)
	t.soltar_movimento()
	_conf(t.le_teclado, "soltar_movimento devolve o teclado")

	# A matemática pura, sem depender da cena.
	var reta := Locomocao3D.velocidade_alvo(Vector2(0, 1), false, Basis.IDENTITY)
	var diag := Locomocao3D.velocidade_alvo(Vector2(1, 1), false, Basis.IDENTITY)
	_conf(absf(reta.length() - diag.length()) < 0.01,
		"diagonal não é mais rápida que a reta (regra herdada da V2)",
		"reta %.2f, diagonal %.2f" % [reta.length(), diag.length()])
	_conf(Locomocao3D.velocidade_alvo(Vector2(1, 0), true, Basis.IDENTITY).length()
			> reta.length(), "correr é mais rápido que andar")
	_conf(absf(Locomocao3D.velocidade_alvo(Vector2(0.5, 0), false, Basis.IDENTITY).length()
			- Locomocao3D.VELOCIDADE_CAMINHADA * 0.5) < 0.01,
		"analógico pela metade anda pela metade")

	# §11: a regra de inclinação. Uma rampa se sobe, uma parede não.
	_conf(Locomocao3D.e_chao(Vector3.UP), "chão plano é chão")
	_conf(Locomocao3D.e_chao(Vector3(0.4, 1, 0).normalized()),
		"ladeira de ~22° é chão que se sobe")
	_conf(not Locomocao3D.e_chao(Vector3(1, 0.2, 0).normalized()),
		"parede de ~79° NÃO é chão")

	# O movimento segue a câmera, não o norte do mundo.
	var virada := Basis(Vector3.UP, PI / 2.0)
	var pra_frente_virado := Locomocao3D.velocidade_alvo(Vector2(0, 1), false, virada)
	_conf(absf(pra_frente_virado.x) > absf(pra_frente_virado.z),
		"com a câmera girada 90°, o W anda pro lado — segue o olhar, não o mundo")

	# Gravidade: no ar acelera pra baixo; no chão não afunda.
	_conf(Locomocao3D.aplicar_gravidade(0.0, false, 0.1) < 0.0, "no ar, cai")
	_conf(Locomocao3D.aplicar_gravidade(-100.0, false, 1.0)
			>= -Locomocao3D.VELOCIDADE_TERMINAL, "a queda tem velocidade terminal")
	_conf(Locomocao3D.aplicar_gravidade(-30.0, true, 0.1) > -2.0,
		"no chão, a queda para (mas não zera, pra colar na ladeira)")

func _conferir_arbitro() -> void:
	print("-- §12: nunca dois donos do input")
	if _lab == null or _lab.controle == null:
		return
	var c = _lab.controle

	_conf(c.modo == "world", "começa no modo WORLD", c.modo)
	_conf(c.quantos_ativos() <= 1, "no máximo UM controlador recebe input",
		"%d ativos" % c.quantos_ativos())
	_conf(c.controlador_ativo() == _lab.treinador,
		"e o ativo é o treinador")

	# A troca pra um modo sem controlador registrado: ninguém pode sobrar
	# escutando. É o caso que produz o bug dos dois personagens andando.
	c.trocar_para("combat")
	_conf(c.modo == "combat", "trocou pro modo COMBAT")
	_conf(c.quantos_ativos() == 0,
		"com o Pokémon ainda não registrado, NINGUÉM recebe input",
		"%d ativos" % c.quantos_ativos())
	_conf(not _lab.treinador.is_processing_input(),
		"o treinador parou de escutar")
	_conf(_lab.treinador.is_physics_processing(),
		"mas continua com física — ele permanece no mundo (§17)")
	_conf(_lab.treinador.intencao == Vector2.ZERO,
		"e a intenção dele foi zerada, senão ele andaria pra sempre")

	c.trocar_para("world")
	_conf(c.quantos_ativos() == 1, "voltando pro mundo, o treinador reassume")
	_conf(_lab.treinador.is_processing_input(), "e volta a escutar")

	_conf(not c.trocar_para("world"), "trocar pro modo em que já se está é recusado")
	_conf(not c.trocar_para("inexistente"), "modo desconhecido é recusado")

	# A troca aparece na linha do tempo do feedback — quando o Gabriel reportar
	# "travou no meio da batalha", é isto que vai dizer em que modo ele estava.
	var achou := false
	for e in PonteDeFeedback.linha_do_tempo():
		if str(e["o_que"]).contains("modo de controle"):
			achou = true
			break
	_conf(achou, "a troca de modo entra na linha do tempo do feedback")


# ──────────────────────────────────────────────────────────────────────────────
# Fase 4 — o terreno (§23, §26)
# ──────────────────────────────────────────────────────────────────────────────

func _conferir_terreno() -> void:
	print("-- Fase 4: terreno com altura, praia e água")
	_conf(_lab.terreno != null, "o terreno existe na cena")
	if _lab.terreno == null:
		return

	# Visual e colisão leem a MESMA função de altura. Se divergirem, o jogador
	# anda no ar ou afunda — e é bug difícil de enxergar.
	_conf(_lab.terreno.get_node_or_null("Superficie") != null, "tem malha visível")
	_conf(_lab.terreno.get_node_or_null("Colisao") != null, "e corpo de colisão")
	_conf(_lab.terreno.get_node_or_null("Agua") != null, "e o plano de água")

	# Determinismo: a mesma coordenada dá sempre a mesma altura. É o que permite
	# nascer entidade sem raycast e o que faz colisão e visual concordarem.
	var a1 : float = Terreno3D.altura_em(12.0, -8.0)
	var a2 : float = Terreno3D.altura_em(12.0, -8.0)
	_conf(is_equal_approx(a1, a2), "a altura é determinística")

	# §23: o terreno tem relevo de verdade, não é um plano disfarçado.
	var menor : float = 9999.0
	var maior : float = -9999.0
	for i in 40:
		for j in 40:
			var x : float = -70.0 + i * 3.5
			var z : float = -70.0 + j * 3.5
			var y : float = Terreno3D.altura_em(x, z)
			menor = minf(menor, y)
			maior = maxf(maior, y)
	_conf(maior - menor > 12.0, "há desnível de verdade no terreno",
		"de %.1f a %.1f m" % [menor, maior])

	# §26: as quatro superfícies existem, e a praia não é uma linha.
	var achadas : Dictionary = {}
	var pontos_de_areia : int = 0
	for i in 60:
		for j in 60:
			var x : float = -75.0 + i * 2.5
			var z : float = -75.0 + j * 2.5
			var sup := Terreno3D.superficie_em(x, z)
			achadas[sup] = true
			if sup == "areia":
				pontos_de_areia += 1
	for esperada in ["terra", "areia", "agua_rasa", "agua_profunda"]:
		_conf(achadas.has(esperada), "existe superfície '%s' no mapa" % esperada)
	_conf(pontos_de_areia > 60,
		"a praia é uma FAIXA caminhável, não uma linha (§26)",
		"%d pontos de areia" % pontos_de_areia)

	# §26: a transição tem que ser contínua. Um degrau na costa é exatamente a
	# "parede artificial entre mar e terra" que o pedido proíbe.
	var maior_degrau : float = 0.0
	for j in 200:
		var z : float = -78.0 + j * 0.78
		var d : float = absf(Terreno3D.altura_em(0.0, z) - Terreno3D.altura_em(0.0, z + 0.78))
		maior_degrau = maxf(maior_degrau, d)
	_conf(maior_degrau < 1.2,
		"nenhum degrau abrupto atravessando a costa (§26)",
		"maior salto foi %.2f m em 0,78 m" % maior_degrau)

	# Caminhável: terra sim, fundo do mar não — ali é surf (§27).
	var achou_caminhavel := false
	var achou_agua := false
	for i in 60:
		for j in 60:
			var x : float = -75.0 + i * 2.5
			var z : float = -75.0 + j * 2.5
			if Terreno3D.caminhavel(x, z):
				achou_caminhavel = true
			else:
				achou_agua = true
	_conf(achou_caminhavel and achou_agua,
		"existe chão pra andar E água pra não andar")

	# `ponto_em` põe a entidade SOBRE o terreno — é como o treinador nasceu.
	var p := Terreno3D.ponto_em(20.0, 20.0, 1.0)
	_conf(is_equal_approx(p.y, Terreno3D.altura_em(20.0, 20.0) + 1.0),
		"ponto_em coloca a entidade sobre o terreno, sem raycast")

	# O treinador nasceu no chão, não dentro dele nem caindo do céu.
	var t = _lab.treinador
	var chao_ali : float = Terreno3D.altura_em(t.global_position.x, t.global_position.z)
	_conf(t.global_position.y > chao_ali - 1.0,
		"o treinador está sobre o terreno, não afundado",
		"y %.2f, chão %.2f" % [t.global_position.y, chao_ali])

	# A inclinação lida bate com a regra de subida do controlador.
	var tem_subivel := false
	var tem_ingreme := false
	for i in 50:
		for j in 50:
			var x : float = -70.0 + i * 3.0
			var z : float = -70.0 + j * 3.0
			var ang : float = Terreno3D.inclinacao_em(x, z)
			if ang < Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA:
				tem_subivel = true
			else:
				tem_ingreme = true
	_conf(tem_subivel, "há encosta que o treinador sobe")
	_conf(tem_ingreme, "e encosta íngreme demais — o par que prova a regra",
		"(se faltar, o terreno é plano demais pra testar inclinação)")
