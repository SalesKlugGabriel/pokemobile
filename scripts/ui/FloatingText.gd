## FloatingText.gd — Texto flutuando sobre um ponto do mapa (Fase 9 do motor
## de combate em tempo real, 02/09) — nome do golpe + dano subindo e
## sumindo, pedido original do Gabriel (print de referência com "POISON
## BOMB! MORTAL GAS!" flutuando em cima do Pokémon lutando no mapa aberto).
## Mesmo padrão de nó-temporário-com-Tween que CaptureSystem.throw_pokeball()
## já usa — sem cena/autoload próprio, só uma função estática.
class_name FloatingText
extends RefCounted

const RISE_DISTANCE : float = 36.0
const DURATION      : float = 0.9

## parent: normalmente get_tree().current_scene. world_pos: onde nasce o
## texto (tipicamente global_position do alvo, um pouco acima da cabeça).
static func show_text(parent: Node, world_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if not parent:
		return
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 100
	label.z_as_relative = false
	parent.add_child(label)
	label.global_position = world_pos - Vector2(label.size.x / 2.0, 0)

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - RISE_DISTANCE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION).set_delay(DURATION * 0.3)
	tween.chain().tween_callback(label.queue_free)
