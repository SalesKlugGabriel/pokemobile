## MinimapControl.gd — Minimap simples: dot do player sobre mapa de zonas.
extends Control

const MAP_W : int = 100
const MAP_H : int = 120

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sz : Vector2 = size

	# Fundo semi-transparente
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.05, 0.05, 0.82))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.3, 0.3, 0.3, 0.6), false, 1.0)

	# Zonas coloridas (Viridian / Route 1 / Pallet)
	var vir_end : float = (38.0 / MAP_H) * sz.y
	var rt1_end : float = (79.0 / MAP_H) * sz.y
	draw_rect(Rect2(0.0, 0.0,      sz.x, vir_end),                Color(0.1, 0.4, 0.15, 0.45))
	draw_rect(Rect2(0.0, vir_end,  sz.x, rt1_end - vir_end),      Color(0.15, 0.55, 0.15, 0.45))
	draw_rect(Rect2(0.0, rt1_end,  sz.x, sz.y - rt1_end),         Color(0.2, 0.65, 0.2, 0.45))

	# Ponto do player
	var player := WorldManager.player
	if player:
		var gp : Vector2i = player.grid_pos
		var px : float = (float(gp.x) / MAP_W) * sz.x
		var py : float = (float(gp.y) / MAP_H) * sz.y
		draw_circle(Vector2(px, py), 2.5, Color(1.0, 0.3, 0.1, 1.0))
