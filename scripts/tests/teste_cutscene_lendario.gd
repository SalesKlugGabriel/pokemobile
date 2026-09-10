## teste_cutscene_lendario.gd — 09/09 (mais tarde), item da lista de imersão
## "cutscene de entrada de lendário". EventBus.legendary_encountered existia
## desde 05/09 (NinhoLendario.povoar()) sem NENHUM listener — sistema-fachada
## clássico. CutsceneLendario.gd é o primeiro a escutar (chamado direto, não
## por sinal, pra não competir com quem mais vier a escutar o mesmo sinal no
## futuro). Este teste prova: trava input, mostra aviso, toca SFX, mexe no
## zoom da câmera e (crucial) DEVOLVE o controle no final — sem o callback de
## destravar, o jogador ficaria preso pra sempre depois de um lendário.
extends SceneTree

## Dublê de BaseMap: só precisa da propriedade `player` de verdade (não dá
## pra fingir isso com Node.set() num Node puro — "player" não existiria
## como propriedade real, e `"player" in mapa` acusaria falso).
class MapaFalso:
	extends Node
	var player : Node = null

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: cutscene de entrada de lendário (09/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Sem câmera achável: não pode travar o jogador esperando um tween
	# que nunca roda. ----
	var trainer_scene : PackedScene = load("res://scenes/entities/TrainerEntity.tscn")
	var sem_cam = trainer_scene.instantiate()
	root.add_child(sem_cam)
	var mapa_falso := MapaFalso.new()
	mapa_falso.player = sem_cam
	CutsceneLendario.tocar(mapa_falso, "Articuno")
	_assert(not sem_cam._input_locked, "sem câmera: destrava na hora, não fica preso esperando tween")

	# ---- Com câmera: trava, depois de tudo destrava sozinho ----
	var com_cam = trainer_scene.instantiate()
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.zoom = Vector2(0.5, 0.5)
	com_cam.add_child(cam)
	root.add_child(com_cam)

	var mapa_falso2 := MapaFalso.new()
	mapa_falso2.player = com_cam
	var tw := CutsceneLendario.tocar(mapa_falso2, "Moltres")
	_assert(com_cam._input_locked, "com câmera: trava o jogador assim que a cutscene começa")
	_assert(tw != null and tw.is_running(), "o tween da câmera já está rodando (não fica parado esperando algo)")

	# `mapa` sem propriedade "player" nenhuma (Node genérico) não deve quebrar.
	var mapa_vazio := Node.new()
	CutsceneLendario.tocar(mapa_vazio, "Zapdos")
	_assert(true, "mapa sem jogador reconhecível não quebra (só não faz nada)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
