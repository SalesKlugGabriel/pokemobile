## Cena de conferência visual dos componentes do Codex. Os dados abaixo são
## fixtures de apresentação e não representam regra de gameplay.
extends Node2D

@onready var camera : CameraDeCombate = $CameraDeCombate
@onready var hud : HudV2 = $HudV2
@onready var telegraph : TelegraphV2 = $TelegraphV2
@onready var treinador : Node2D = $Treinador
@onready var pokemon : Node2D = $Pokemon
@onready var alpha : Node2D = $Alpha

var _cast_id := 0
var _forma_indice := 0
var _formas := ["circle", "cone", "line", "ring"]

func _ready() -> void:
	camera.definir_alvos(treinador, pokemon)
	hud.aplicar_estado_inicial({
		"treinador": {"nome": "Treinador", "hp": 86, "hp_max": 100},
		"stamina": {"atual": 63.0, "maximo": 100.0, "estado": "normal"},
		"pokemon": {"nome": "Pikachu", "hp": 74, "hp_max": 100, "status": "none", "ativo": true},
		"alvo": {"nome": "Alpha Onix", "hp": 640, "hp_max": 1000, "nivel": 18, "categoria": "Alpha"},
		"ordem": {"tipo": "atacar", "rotulo": "ALPHA ONIX"},
		"capacidade_skills": 4,
		"skills": [
			{"nome": "Impacto", "atalho": "1", "progresso": 1.0, "disponivel": true},
			{"nome": "Onda", "atalho": "2", "progresso": 0.42, "disponivel": false},
			{"nome": "Pulso", "atalho": "3", "progresso": 1.0, "disponivel": true},
			{"nome": "Dreno", "atalho": "4", "progresso": 0.78, "disponivel": false},
		],
	})
	hud.definir_ajuda("1–4 CÂMERA  •  T NOVA GEOMETRIA  •  X CANCELAR")
	hud.skill_solicitada.connect(_ao_skill_visual)
	mostrar_proxima_geometria()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			camera.ao_contexto_de_camera("exploracao", 0)
		KEY_2:
			camera.ao_contexto_de_camera("combate_grande", 20)
		KEY_3:
			camera.ao_contexto_de_camera("boss", 30)
		KEY_4:
			camera.ao_contexto_de_camera("interior", 10)
		KEY_T:
			mostrar_proxima_geometria()
		KEY_X:
			telegraph.encerrar_golpe(_cast_id, "cancelado")

func mostrar_proxima_geometria() -> void:
	if _cast_id > 0:
		telegraph.encerrar_golpe(_cast_id, "cancelado")
	_cast_id += 1
	var forma : String = _formas[_forma_indice % _formas.size()]
	_forma_indice += 1
	var dados := {
		"area_type": forma,
		"origem": alpha.global_position + Vector2(-30, 34),
		"direcao": (treinador.global_position - alpha.global_position).normalized(),
		"duracao": 2.4,
		"hostil": true,
		"raio": 210.0,
		"raio_interno": 92.0,
		"largura": 150.0,
		"comprimento": 520.0,
		"abertura": deg_to_rad(64.0),
	}
	telegraph.mostrar_golpe(_cast_id, dados)

func _ao_skill_visual(slot: int) -> void:
	if slot == 0 or slot == 2:
		mostrar_proxima_geometria()

func _draw() -> void:
	# Arena orgânica simples: chão navegável claro, água com margem, obstáculos
	# escuros e um caminho central. Serve para medir leitura, não é mapa final.
	draw_rect(Rect2(0, 0, 2400, 1600), Color("203c35"))
	for y in range(0, 1600, 128):
		for x in range(0, 2400, 128):
			var alterna := int(x / 128) + int(y / 128)
			var cor := Color("2d5544") if alterna % 2 == 0 else Color("315c48")
			draw_rect(Rect2(x, y, 128, 128), cor)
	# Caminho e margem de água.
	draw_rect(Rect2(0, 650, 2400, 330), Color("8e7248"))
	draw_rect(Rect2(0, 650, 2400, 18), Color("b49a66"))
	draw_rect(Rect2(0, 962, 2400, 18), Color("5f482e"))
	draw_rect(Rect2(0, 1280, 2400, 320), Color("17475b"))
	draw_rect(Rect2(0, 1250, 2400, 30), Color("c3a76d"))
	for x in range(40, 2400, 110):
		draw_line(Vector2(x, 1340), Vector2(x + 50, 1340), Color(0.3, 0.72, 0.82, 0.32), 6.0)
	# Pedras/árvores delimitam sem criar muralha contínua.
	for p in [Vector2(280, 350), Vector2(520, 260), Vector2(1840, 310), Vector2(2090, 410), Vector2(360, 1130), Vector2(2020, 1120)]:
		draw_circle(p, 62, Color("132820"))
		draw_circle(p + Vector2(0, -18), 52, Color("3b6f4b"))
		draw_arc(p + Vector2(0, -18), 52, 0, TAU, 24, Color("74a85d"), 5.0)
