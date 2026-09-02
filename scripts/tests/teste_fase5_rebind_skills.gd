## teste_fase5_rebind_skills.gd — Teste headless: skill_1-4/pokebola viraram
## reatribuíveis (pedido do Gabriel, motor de combate em tempo real, 02/09) —
## antes ficavam de fora da lista porque "nunca tinham sido ligadas a nenhuma
## função no jogo"; agora comandam o Follower/a captura de verdade. Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_rebind_skills.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var KeybindManager : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (rebind de skill_1-4/pokebola) ===")
	KeybindManager = root.get_node("KeybindManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	for action in ["skill_1", "skill_2", "skill_3", "skill_4", "pokeball"]:
		_assert(action in KeybindManager.REBINDABLE_ACTIONS, "%s está na lista de reatribuíveis" % action)
		_assert(KeybindManager.ACTION_LABELS.has(action), "%s tem rótulo legível pra tela de Controles" % action)

	# ---- rebind de verdade funciona pra skill_1 ----
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_T
	KeybindManager.rebind("skill_1", evento)
	_assert(KeybindManager.key_label("skill_1") == OS.get_keycode_string(KEY_T), "rebind('skill_1', T) muda a tecla de verdade")

	# ---- conflito: reatribuir skill_2 pra mesma tecla tira de skill_1 ----
	var evento2 := InputEventKey.new()
	evento2.physical_keycode = KEY_T
	var conflito : String = KeybindManager.find_conflict(KEY_T, "skill_2")
	_assert(conflito == "skill_1", "find_conflict() acha que skill_1 já usa essa tecla")
	KeybindManager.rebind("skill_2", evento2)
	_assert(KeybindManager.key_label("skill_2") == OS.get_keycode_string(KEY_T), "skill_2 ganhou a tecla T")
	_assert(KeybindManager.key_label("skill_1") == "—", "skill_1 perdeu a tecla (conflito resolvido, 1 tecla por ação)")

	KeybindManager.reset_all_to_default()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
