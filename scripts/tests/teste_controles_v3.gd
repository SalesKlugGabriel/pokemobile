## teste_controles_v3.gd — Os dois bugs de controle do playtest, travados.
##
## O Gabriel relatou em 16/09: *"se aperto W ele vem em direção da câmera e não
## na direção do mouse"*. Eram **dois** bugs somados, e este teste existe pra
## nenhum dos dois voltar:
##
##   1. `girar_para` devolvia o ângulo 180° errado (`atan2(d.x, d.z)` em vez de
##      `atan2(-d.x, -d.z)`);
##   2. a câmera era filha do corpo que gira, então o yaw dela era relativo a
##      ele — realimentação: o corpo virava, a câmera virava junto, e a "frente"
##      do W mudava de lugar.
##
## ── Por que o segundo precisa de cena de verdade ────────────────────────────
##
## O primeiro é aritmética e dá pra conferir isolado. O segundo é uma relação
## entre nós: só aparece com o corpo rodando física de verdade e a câmera
## pendurada nele. Conferir isso lendo o código foi o que me fez diagnosticar
## certo e **não perceber** que consertar o `top_level` enfiaria a câmera no
## chão — a altura do ombro deixa de ser relativa quando o nó vira top_level.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _treinador : CharacterBody3D = null
var _y_inicial_da_camera : float = 0.0
var _pos_antes_da_lateral : Vector3 = Vector3.ZERO

func _checar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Controles da V3: girar_para e a câmera independente ===")
	_aritmetica_do_giro()
	# ⚠️ A cena NÃO pode ser montada aqui. Em `_initialize` a janela raiz ainda
	# não está pronta, e `root.add_child` não põe o nó na árvore de verdade —
	# `is_inside_tree()` volta false e `global_position` erra em silêncio. Foi o
	# que aconteceu na primeira versão deste teste, e é a convenção que
	# `teste_gameplay_v3_fase3.gd` já seguia: montar no primeiro `_process`.

# ──────────────────────────────────────────────────────────────────────────────
# Bug 1 — aritmética, conferida isolada
# ──────────────────────────────────────────────────────────────────────────────

func _aritmetica_do_giro() -> void:
	var Loco = load("res://scripts/gameplay_v3/movimento/Locomocao3D.gd")
	# Em Godot, rotation.y = 0 olha pra −Z. Cada linha é uma direção de
	# movimento e o ângulo que o corpo precisa ter pra ESTAR olhando pra ela.
	var casos : Array = [
		[Vector3(0, 0, -1), 0.0],           # frente
		[Vector3(0, 0, 1), PI],             # trás
		[Vector3(1, 0, 0), -PI / 2.0],      # direita
		[Vector3(-1, 0, 0), PI / 2.0],      # esquerda
	]
	for caso in casos:
		var d : Vector3 = caso[0]
		var esperado : float = caso[1]
		# delta enorme pra chegar no alvo num passo só — aqui a conferência é do
		# ALVO, não da suavização.
		var achado : float = Loco.girar_para(0.0, d * 5.0, 10.0)
		var erro : float = absf(angle_difference(achado, esperado))
		_checar("girar_para %s → %.2f rad" % [str(d), esperado], erro < 0.001,
			"veio %.4f, esperado %.4f" % [achado, esperado])

	# Parado não gira: sem isto o personagem volta pra frente sozinho ao soltar
	# o teclado, e some a direção que o jogador tinha escolhido.
	_checar("parado não muda o ângulo",
		is_equal_approx(Loco.girar_para(1.23, Vector3.ZERO, 1.0), 1.23))

# ──────────────────────────────────────────────────────────────────────────────
# Bug 2 — a relação entre câmera e corpo, com física rodando
# ──────────────────────────────────────────────────────────────────────────────

func _montar_cena() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)

	# Chão, pra o corpo não cair pra sempre.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200, 1, 200)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position.y = -0.5
	mundo.add_child(chao)

	var Trainer = load("res://scripts/gameplay_v3/entidades/TrainerController3D.gd")
	_treinador = Trainer.new()
	mundo.add_child(_treinador)
	_treinador.global_position = Vector3(10, 2, 10)

	_checar("a câmera existe", _treinador.camera != null)
	if _treinador.camera == null:
		_terminar()
		return

	_checar("a câmera é top_level — não herda a rotação do corpo",
		_treinador.camera.top_level == true)

	# A altura do ombro NÃO é conferida aqui de propósito: o `_ready` roda no
	# `add_child`, quando o corpo ainda está na origem, e o teleporte vem na linha
	# seguinte. A câmera alcança no primeiro passo de física — conferido no fim,
	# em `_conferir_depois_de_andar`. Conferir antes disso mediria um estado
	# intermediário que o jogo nunca mostra.

func _process(delta: float) -> bool:
	_quadros += 1
	if _quadros == 1:
		_montar_cena()
		return false
	if _treinador == null:
		return true

	# Gira a câmera 90° com o "mouse" e manda andar pra frente. Com a câmera
	# independente, W anda pra onde a câmera OLHA — o pedido da §11.
	if _quadros == 6:
		_treinador.camera.girar(Vector2(-deg_to_rad(90.0) / _treinador.camera.sensibilidade, 0.0))
		_treinador.mover(Vector2(0, -1))   # frente

	if _quadros == 61:
		_conferir_depois_de_andar()
		# W e a câmera compartilham a mesma frente; testar só W não distinguiria
		# corpo-para-câmera de corpo-para-movimento. A passada lateral mede a
		# fronteira que o relato do Gabriel realmente exige.
		_pos_antes_da_lateral = _treinador.global_position
		_treinador.mover(Vector2(1, 0))
		return false

	if _quadros == 91:
		_conferir_lateral()
		_terminar()
		return true
	return false

func _conferir_depois_de_andar() -> void:
	var cam = _treinador.camera

	# A conferência que pega a realimentação: o corpo girou (ele vira pra onde
	# anda), e o yaw da câmera tem de continuar o que o mouse pediu.
	var yaw_da_camera : float = cam.yaw()
	var yaw_global_da_camera : float = cam.global_rotation.y
	_checar("o yaw da câmera é o do mouse, não o do corpo",
		absf(angle_difference(yaw_da_camera, yaw_global_da_camera)) < 0.01,
		"pedido %.3f, no mundo %.3f — a câmera está herdando rotação de alguém" % [yaw_da_camera, yaw_global_da_camera])

	# A mira é uma fonte só, pra pokébola e ataque saírem pra onde se olha.
	var mira : Vector3 = _treinador.direcao_de_mira()
	var olhar_da_camera : Vector3 = -cam.camera.global_transform.basis.z
	_checar("a mira do treinador é a da câmera (uma conta só, não duas)",
		mira.normalized().dot(olhar_da_camera.normalized()) > 0.999,
		"%s vs %s" % [str(mira), str(olhar_da_camera)])
	_checar("a ação sai da altura do ombro, não dos pés",
		_treinador.origem_da_mira().y > _treinador.global_position.y + 1.0,
		"y = %.2f" % _treinador.origem_da_mira().y)

	# Andou pra frente da câmera, não pra dentro dela.
	var andou := _treinador.global_position - Vector3(10, _treinador.global_position.y, 10)
	var frente_da_camera : Vector3 = -cam.global_transform.basis.z
	frente_da_camera.y = 0.0
	var alinhamento : float = andou.normalized().dot(frente_da_camera.normalized())
	_checar("W andou PRA ONDE a câmera olha",
		alinhamento > 0.9,
		"alinhamento %.3f (1 = exatamente pra frente, −1 = em direção à câmera)" % alinhamento)

	# E o conserto do top_level não deixou a câmera no chão.
	_checar("a câmera continua na altura do ombro depois de andar",
		cam.global_position.y > _treinador.global_position.y + 1.0,
		"câmera y=%.2f, treinador y=%.2f" % [cam.global_position.y, _treinador.global_position.y])

func _conferir_lateral() -> void:
	var andou := _treinador.global_position - _pos_antes_da_lateral
	andou.y = 0.0
	var frente_do_corpo := -_treinador.global_transform.basis.z
	frente_do_corpo.y = 0.0
	# ⚠️ O limiar é DERIVADO da velocidade, não cravado.
	#
	# Estava `> 0.5`, calibrado quando a caminhada era 4,5 m/s. Em 21/09 o
	# Gabriel fixou a régua humana (1,5 m/s andando) e o teste reprovou com
	# 0,280 m — reprovou o código CERTO, porque o número envelheceu junto com a
	# constante. É a mesma classe do "número cravado que mede o cadastro do
	# Gabriel" que já está na disciplina de teste.
	#
	# ⚠️ E o limiar também NÃO pode sair de "30 quadros são meio segundo": em
	# headless o laço roda o mais rápido que consegue, e `_process` não anda no
	# passo da física. Derivei assim na primeira tentativa e reprovei de novo,
	# agora por um motivo diferente (0,280 m contra 0,375 esperados).
	#
	# A pergunta que o teste faz é **"o corpo saiu do lugar pro lado?"**, não
	# "andou X metros". Três quadros de física de caminhada é o piso: acima
	# disso o deslocamento é intencional, não ruído de um tique solto.
	var esperado : float = Locomocao3D.VELOCIDADE_CAMINHADA * (3.0 / 60.0)
	_checar("A/D desloca o corpo lateralmente de verdade", andou.length() > esperado,
		"andou %.3f m" % andou.length())
	_checar("o corpo encara a própria direção ao andar lateralmente",
		frente_do_corpo.normalized().dot(andou.normalized()) > 0.85,
		"alinhamento %.3f" % frente_do_corpo.normalized().dot(andou.normalized()))
	_checar("o corpo não fica travado no yaw da câmera",
		absf(angle_difference(_treinador.rotation.y, _treinador.camera.yaw())) > 0.4,
		"corpo %.3f, câmera %.3f" % [_treinador.rotation.y, _treinador.camera.yaw()])

func _terminar() -> void:
	# `tools/rodar_testes.sh` exige ESTA linha, além do código de saída: um teste
	# que morre antes de rodar também sai com 0, e silêncio não é aprovação.
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
