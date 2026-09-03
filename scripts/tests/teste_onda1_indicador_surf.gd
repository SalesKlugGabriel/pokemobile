## teste_onda1_indicador_surf.gd — Teste headless do indicador visual de
## "surfando" (Onda 1, item 9 do roteiro geral, 03/09). Roda com:
## godot4 --headless --script res://scripts/tests/teste_onda1_indicador_surf.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node

func _initialize() -> void:
	print("=== Teste Onda 1 (Indicador visual de surfando) ===")
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteIndicadorSurf", 1)

	var trainer_scene : PackedScene = load("res://scenes/entities/TrainerEntity.tscn")
	var trainer = trainer_scene.instantiate()
	root.add_child(trainer)

	_assert(trainer.sprite.modulate == Color(1, 1, 1), "sprite começa sem nenhum tingimento (terra firme)")

	trainer._apply_sprite_mode("surf")
	_assert(trainer.sprite.modulate == TrainerEntity.SURF_TINT, "entrar em modo surf tinge o sprite de azul")
	_assert(trainer._surf_ripple != null, "a ondulação embaixo dos pés é criada na primeira vez que surfa")
	_assert(trainer._surf_ripple.visible, "a ondulação fica visível enquanto surfa")

	trainer._apply_sprite_mode("walk")
	_assert(trainer.sprite.modulate == Color(1, 1, 1), "sair do modo surf remove o tingimento")
	_assert(not trainer._surf_ripple.visible, "a ondulação some ao sair da água (sem recriar o nó)")

	# Voltar a surfar reaproveita a MESMA ondulação já criada, não duplica nó.
	var ripple_antes : Sprite2D = trainer._surf_ripple
	trainer._apply_sprite_mode("surf")
	_assert(trainer._surf_ripple == ripple_antes, "voltar a surfar reaproveita a mesma ondulação, não cria outra")
	_assert(trainer._surf_ripple.visible, "a ondulação reaparece ao voltar a surfar")

	# Outras marchas (bike/mount/fly) não acionam o indicador de surf.
	trainer._apply_sprite_mode("bike")
	_assert(trainer.sprite.modulate == Color(1, 1, 1), "modo bicicleta não tinge de azul (só surf)")
	_assert(not trainer._surf_ripple.visible, "ondulação continua escondida na bicicleta")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
