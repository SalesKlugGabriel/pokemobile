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
## E `PokemonInstance3D` usa `GameData` por dentro, então citá-la pelo NOME
## obrigaria a compilá-la antes dos autoloads existirem. Carregada por caminho.
var Pokemon3D : GDScript

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
			Pokemon3D = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
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
				_conferir_pokemon()
				_conferir_modelo_entregue()
				_conferir_companheiro()
				_andar_de_novo()
				_fase = 35
				_tempo = 0.0
		35:
			# O companheiro precisa de tempo pra reagir ao treinador andando.
			if _tempo > 2.0:
				_conferir_companheiro_seguiu()
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


# ──────────────────────────────────────────────────────────────────────────────
# Fase 5 — Pokémon 3D (§14, §15, §16, §19)
# ──────────────────────────────────────────────────────────────────────────────

func _conferir_pokemon() -> void:
	print("-- Fase 5: Pokémon 3D por composição")
	_conf(_lab.pokemons.size() == 3,
		"há 3 Pokémon, um por arquétipo (§16) — não dezenas",
		"tem %d" % _lab.pokemons.size())
	if _lab.pokemons.is_empty():
		return

	var terrestre = _lab.pokemons[0]
	var aquatico = _lab.pokemons[1]
	var voador = _lab.pokemons[2]

	_conf(terrestre is CharacterBody3D, "são corpos 3D de verdade")
	_conf(terrestre.vida_maxima > 1, "com vida vinda da V2, sem adaptação",
		"%d" % terrestre.vida_maxima)
	_conf(terrestre.get_node_or_null("Colisor") != null, "colisor montado")
	_conf(terrestre.get_node_or_null("Hurtbox") != null,
		"e hurtbox SEPARADA (§22)")

	# §6: a altura real vem de heights.json, que já existia. Gigante é
	# comprimido pra caber no jogo sem deixar de ser gigante.
	var onix = Pokemon3D.new()
	_lab.add_child(onix)
	onix.montar(95, 30)   # Onix: 8,8 m
	_conf(onix.altura_real > 8.0, "Onix tem 8,8 m de verdade",
		"%.1f m" % onix.altura_real)
	_conf(onix.altura < onix.altura_real,
		"e é comprimido pra caber no jogo (§6)",
		"%.1f m jogáveis" % onix.altura)
	_conf(onix.altura > 4.0, "mas continua claramente enorme",
		"%.1f m" % onix.altura)

	var diglett = Pokemon3D.new()
	_lab.add_child(diglett)
	diglett.montar(50, 30)   # Diglett: 0,2 m
	_conf(is_equal_approx(float(diglett.altura), float(diglett.altura_real)),
		"o pequeno NÃO é comprimido — só gigante precisa")

	# §19: a câmera de 1ª pessoa precisa ser jogável nos dois extremos.
	# "Jogabilidade > anatomia perfeita", literal no pedido.
	var olhos_diglett : float = CameraProfile.altura_dos_olhos(float(diglett.altura))
	var olhos_onix : float = CameraProfile.altura_dos_olhos(float(onix.altura))
	_conf(olhos_diglett >= CameraProfile.ALTURA_MINIMA,
		"a câmera do Diglett sobe até a altura mínima jogável (§19)",
		"%.2f m, sendo o bicho %.1f m" % [olhos_diglett, diglett.altura])
	_conf(olhos_onix <= CameraProfile.ALTURA_MAXIMA,
		"e a do Onix desce até enxergar o chão",
		"%.2f m, sendo o bicho %.1f m" % [olhos_onix, onix.altura])
	_conf(CameraProfile.fov(float(diglett.altura)) > CameraProfile.fov(float(onix.altura)),
		"bicho pequeno tem FOV maior — perto do chão, campo estreito sufoca")

	# §15: os 8 arquétipos existem como dado; 5 funcionam. O que não funciona
	# cai no terrestre e AVISA — nunca finge.
	_conf(MovementProfile.TODOS.size() == 8, "os 8 arquétipos estão declarados")
	_conf(MovementProfile.IMPLEMENTADOS.size() < 8,
		"e nem todos implementados — é o que o §15 manda")
	_conf(MovementProfile.implementado("ground_biped"), "terrestre funciona")
	_conf(MovementProfile.implementado("aquatic"), "aquático funciona")
	_conf(MovementProfile.implementado("flying"), "voador funciona")
	_conf(not MovementProfile.implementado("serpentine"),
		"serpentino ainda não — declarado, não fingido")
	_conf(not MovementProfile.obter("serpentine").is_empty(),
		"mas pedir um não-implementado devolve perfil válido, sem quebrar")

	# Cada arquétipo se move do seu jeito.
	_conf(MovementProfile.voa("flying"), "voador voa")
	_conf(not MovementProfile.voa("ground_biped"), "terrestre não voa")
	_conf(MovementProfile.nada("aquatic"), "aquático nada")
	_conf(not MovementProfile.nada("ground_biped"), "terrestre não nada")
	_conf(is_equal_approx(MovementProfile.gravidade("flying"), 0.0),
		"voador não cai")
	_conf(MovementProfile.gravidade("aquatic") < MovementProfile.gravidade("ground_biped"),
		"aquático afunda mais devagar que o terrestre cai")

	# Pesado é mais lento E vira mais devagar — peso se lê no controle antes
	# de se ver na animação.
	var v_pesado : float = MovementProfile.velocidade("ground_heavy", 50)
	var v_normal : float = MovementProfile.velocidade("ground_biped", 50)
	_conf(v_pesado < v_normal, "o arquétipo pesado é mais lento")
	_conf(float(MovementProfile.obter("ground_heavy")["giro"])
			< float(MovementProfile.obter("ground_biped")["giro"]),
		"e vira mais devagar")

	# Speed importa, mas não domina — mesma régua da V2.
	_conf(MovementProfile.velocidade("ground_biped", 120)
			> MovementProfile.velocidade("ground_biped", 40),
		"Speed alto anda mais rápido")
	_conf(MovementProfile.velocidade("ground_biped", 120)
			< MovementProfile.velocidade("ground_biped", 40) * 2.0,
		"mas não domina a conta")

	# §14: alcance e hurtbox saem do PERFIL, não do modelo. Um bicho maior
	# alcança mais longe sem ninguém cadastrar isso.
	_conf(onix.alcance_basico() > diglett.alcance_basico(),
		"o maior alcança mais longe",
		"%.1f vs %.1f m" % [onix.alcance_basico(), diglett.alcance_basico()])
	_conf(onix.origem_do_golpe().y > diglett.origem_do_golpe().y,
		"e o golpe sai de mais alto")

	# 🔴 A decisão do Gabriel: modelo 3D. Enquanto não existe, o primitivo
	# entra — mas AVISANDO, nunca em silêncio.
	# O Charizard (#6) JÁ tem modelo desde 14/09 — esta asserção dizia o
	# contrário e envelheceu no dia em que o Codex entregou. O que continua
	# valendo, e é o que importa, é o caminho do que NÃO tem.
	_conf(terrestre.tem_modelo,
		"espécie COM modelo carrega o modelo (Charizard, #6)")
	_conf(not aquatico.tem_modelo,
		"espécie SEM modelo cai no primitivo (Gyarados, #130)")
	var avisou := false
	for e in PonteDeFeedback.linha_do_tempo():
		if str(e["o_que"]).contains("sem modelo 3D"):
			avisou = true
			break
	_conf(avisou,
		"e o modelo ausente AVISA na linha do tempo — nunca cápsula silenciosa")

	# Composição, não herança: nenhum script por espécie.
	_conf(terrestre.get_script() == aquatico.get_script(),
		"terrestre e aquático usam a MESMA classe (§14: sem script por espécie)")
	_conf(terrestre.arquetipo != aquatico.arquetipo,
		"e diferem pelo DADO, não pelo código")
	_conf(voador.arquetipo == "flying", "o voador tem o arquétipo dele")

	onix.queue_free()
	diglett.queue_free()


# ──────────────────────────────────────────────────────────────────────────────
# O primeiro modelo entregue (Charizard, Codex, 14/09)
# ──────────────────────────────────────────────────────────────────────────────

func _conferir_modelo_entregue() -> void:
	print("-- O modelo do Codex contra o contrato")
	var caminho := "res://assets/models/pokemon/6.glb"
	_conf(ResourceLoader.exists(caminho), "o modelo do Charizard está no projeto")
	if not ResourceLoader.exists(caminho):
		return

	var charizard = Pokemon3D.new()
	_lab.add_child(charizard)
	charizard.montar(6, 30, "ground_biped")
	_conf(charizard.tem_modelo, "e a entidade carregou o modelo, não o primitivo")

	var suporte = charizard.get_node_or_null("Modelo")
	_conf(suporte != null, "o modelo entrou dentro do nó de suporte")
	if suporte == null:
		return

	# 🔴 O achado: o modelo veio DEITADO — eixo de altura no −Z em vez do +Y,
	# Blender Z-up sem conversão. Medido no Godot, não estimado na mão: girando
	# 90° em X a altura bate 1,700 m exato e os pés caem em zero.
	_conf(not is_zero_approx(suporte.rotation_degrees.x),
		"o validador detectou o eixo trocado e girou como remendo",
		"girou %+.0f°" % suporte.rotation_degrees.x)

	# Depois do remendo, ele tem que bater o contrato.
	var r : Dictionary = ValidadorDeModelo.conferir(suporte, 6)
	_conf(bool(r["ok"]),
		"com a correção, o modelo passa no contrato",
		", ".join(r["problemas"]))
	_conf(absf(float(r["altura"]) - 1.7) < 0.05,
		"e a altura bate a Pokédex",
		"%.3f m, esperado 1,700" % float(r["altura"]))
	_conf(absf(float(r["pes"])) < ValidadorDeModelo.TOLERANCIA_DOS_PES,
		"com os pés no chão", "pés em %.3f" % float(r["pes"]))

	# As 4 animações do contrato.
	var an : Dictionary = ValidadorDeModelo.conferir_animacoes(charizard)
	_conf(bool(an["ok"]), "as 4 animações exigidas estão lá",
		"faltam: %s" % ", ".join(an["faltando"]))

	# O validador precisa REPROVAR o que está errado, senão ele é decoração.
	# Um cubo de 1 m no lugar de um Charizard de 1,7 m tem que ser pego.
	var falso := Node3D.new()
	_lab.add_child(falso)
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1, 1, 1)
	m.mesh = caixa
	m.position.y = 0.5
	falso.add_child(m)
	var rf : Dictionary = ValidadorDeModelo.conferir(falso, 6)
	_conf(not bool(rf["ok"]),
		"o validador REPROVA um modelo de altura errada (senão é decoração)")
	_conf(str(ValidadorDeModelo.relatorio(falso, 6)).contains("Pokédex"),
		"e o relatório diz contra o que ele foi medido")

	# E não pode inventar correção onde não há: um cubo não vira Charizard
	# girando. Corrigir demais transformaria o contrato em ficção.
	_conf(is_zero_approx(float(rf["correcao_x"])),
		"e NÃO inventa correção pra um modelo que está só errado")

	# A linha do tempo registrou — se o Gabriel reportar "o bicho está deitado",
	# o recado dele já vai dizer que o modelo estava fora do contrato.
	var avisou := false
	for e in PonteDeFeedback.linha_do_tempo():
		if str(e["o_que"]).contains("fora do contrato"):
			avisou = true
			break
	_conf(avisou, "o problema do modelo entra na linha do tempo do feedback")

	falso.queue_free()
	charizard.queue_free()


# ──────────────────────────────────────────────────────────────────────────────
# Fase 6 — o Pokémon companheiro (§6)
# ──────────────────────────────────────────────────────────────────────────────

var _dist_antes : float = 0.0

func _conferir_companheiro() -> void:
	print("-- Fase 6: o companheiro")
	_conf(_lab.companheiro != null, "o treinador tem um companheiro")
	if _lab.companheiro == null:
		return
	_conf(_lab.companheiro.acompanha == _lab.treinador,
		"e ele está acompanhando o treinador")

	# A regra pura, sem depender da cena.
	print("-- §6: a distância sai do TAMANHO dos dois, não de uma constante")
	var perto_grande : float = RegraDeAcompanhar.distancia_de_repouso(0.35, 1.6)
	var perto_pequeno : float = RegraDeAcompanhar.distancia_de_repouso(0.35, 0.1)
	_conf(perto_grande > perto_pequeno,
		"um Pokémon grande fica MAIS longe que um pequeno",
		"grande %.2f m, pequeno %.2f m" % [perto_grande, perto_pequeno])
	# É o que a V2 errava: lá a distância era constante (190 px), e funcionava
	# só porque todo sprite tinha o mesmo tamanho na tela.
	_conf(perto_grande - perto_pequeno > 1.0,
		"e a diferença é grande o bastante pra importar",
		"%.2f m de diferença" % (perto_grande - perto_pequeno))

	print("-- §6: evitar ficar em cima do treinador")
	var repouso : float = 2.0
	_conf(RegraDeAcompanhar.estado(0.3, repouso) == "recuar",
		"colado no treinador, ele RECUA")
	_conf(RegraDeAcompanhar.estado(repouso, repouso) == "parado",
		"na distância certa, fica parado")
	_conf(RegraDeAcompanhar.estado(repouso + 0.1, repouso) == "parado",
		"e não fica tremendo por 10 cm (zona morta)")
	_conf(RegraDeAcompanhar.estado(repouso * 1.5, repouso) == "andar",
		"um pouco longe, anda")
	_conf(RegraDeAcompanhar.estado(repouso * 5.0, repouso) == "correr",
		"muito longe, corre pra alcançar")

	# Teleporte só quando ele já sumiu de vista — teletransportar um companheiro
	# que o jogador está vendo quebra a ilusão inteira.
	_conf(not RegraDeAcompanhar.deve_teleportar(60.0, true),
		"NÃO teleporta se o jogador está vendo")
	_conf(RegraDeAcompanhar.deve_teleportar(60.0, false),
		"teleporta só quando sumiu de vista e está muito longe")
	_conf(not RegraDeAcompanhar.deve_teleportar(10.0, false),
		"e nem por sumir de vista, se estiver perto")

	# O ponto ideal fica ATRÁS — senão ele entra na frente da câmera toda vez
	# que o jogador gira.
	var pos := Vector3.ZERO
	var olhando := Vector3.FORWARD   # -Z
	var ideal := RegraDeAcompanhar.ponto_ideal(pos, olhando, 0.35, 0.5)
	_conf(ideal.z > 0.0, "o ponto ideal fica ATRÁS de quem olha pra frente",
		"z = %.2f" % ideal.z)
	_conf(is_zero_approx(ideal.y), "e no mesmo plano — não flutua (§6)")

	_dist_antes = Vector3(_lab.companheiro.global_position.x, 0,
		_lab.companheiro.global_position.z).distance_to(
		Vector3(_lab.treinador.global_position.x, 0, _lab.treinador.global_position.z))

func _andar_de_novo() -> void:
	# O treinador foge; o companheiro tem que ir atrás.
	_lab.treinador.mover(Vector2(1, 0), true)

func _conferir_companheiro_seguiu() -> void:
	if _lab.companheiro == null:
		return
	_lab.treinador.soltar_movimento()
	var c = _lab.companheiro
	var t = _lab.treinador
	var distancia : float = Vector3(c.global_position.x, 0, c.global_position.z) \
		.distance_to(Vector3(t.global_position.x, 0, t.global_position.z))

	# O teste que importa: ele acompanhou de verdade, andando. Se tivesse
	# ficado parado, a distância teria explodido — o treinador correu 2 s.
	_conf(distancia < 12.0,
		"o companheiro acompanhou o treinador correndo",
		"ficou a %.1f m" % distancia)
	_conf(c.estado_de_acompanhar in ["parado", "andar", "correr", "recuar"],
		"e reporta um estado válido", c.estado_de_acompanhar)

	# §6: "não deve parecer flutuar". Ele tem que estar sobre o terreno.
	var chao : float = Terreno3D.altura_em(c.global_position.x, c.global_position.z)
	_conf(c.global_position.y > chao - 1.0 and c.global_position.y < chao + 3.0,
		"e está sobre o terreno, não flutuando nem afundado",
		"y %.2f, chão %.2f" % [c.global_position.y, chao])

	# E não está em cima do treinador.
	_conf(distancia > 0.5, "sem ficar em cima do treinador (§6)",
		"%.2f m" % distancia)
