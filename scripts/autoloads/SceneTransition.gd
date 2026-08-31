## SceneTransition.gd — Autoload para transições de cena com fade preto.
## Uso: SceneTransition.fade_to("res://scenes/world/maps/PalletTown.tscn")
extends CanvasLayer

var _rect : ColorRect

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 1.0
	add_child(_rect)

	# Fade in ao iniciar qualquer cena
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)

func fade_to(scene_path: String) -> void:
	# Bloqueia input durante a transição
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	AudioManager.stop_bgm(0.3)  # fade áudio junto com a tela
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame

	# Fade de volta pra transparente na cena nova
	var tw2 := create_tween()
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
