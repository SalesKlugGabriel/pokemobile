## MapOverrides.gd — Autoload. Busca ajustes de mapa feitos no Editor Visual
## (poke.workprog.pro/editor) via HTTP, uma vez, ao ligar o jogo.
##
## Arquitetura (02/09, pedido do Gabriel de um editor visual de mapa): em vez
## do editor precisar recompilar/reexportar o jogo inteiro a cada ajuste
## (~3-5 min por publicação), o jogo BUSCA os ajustes prontos de um servidor
## pequeno (o próprio Editor Visual) toda vez que liga. "Publicar" no editor
## só grava um JSON nesse servidor — o jogo já em produção pega a mudança na
## próxima vez que alguém abre, sem precisar de um deploy novo do jogo em si.
##
## Se o servidor do editor estiver fora do ar ou a rede falhar, o jogo
## continua funcionando 100% normal (mapas do jeito que já eram) — nunca
## trava o boot nem quebra nada por causa disso.
extends Node

signal overrides_loaded

const OVERRIDES_URL := "https://poke.workprog.pro/editor/api/map-overrides.json"

var _overrides : Dictionary = {}  # map_id -> {"col,row": "letra_do_char_map"}

func _ready() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_request_completed)
	if req.request(OVERRIDES_URL) != OK:
		overrides_loaded.emit()

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
			_overrides = json.data
	overrides_loaded.emit()

## Repinta em cima do resultado normal de MapLayouts.paint() as células que o
## Gabriel ajustou no editor. Chamado 2x por mapa: uma vez na pintura normal
## (cobre o caso comum, busca já pronta) e de novo quando a busca terminar
## (cobre o boot, quando o 1º mapa pinta antes da rede responder).
func apply_overrides(tilemap: TileMap, map_id: String) -> void:
	var m : Dictionary = _overrides.get(map_id, {})
	for key in m.keys():
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var atlas : Vector2i = MapLayouts.CHAR_MAP.get(String(m[key]), Vector2i(-1, -1))
		if atlas == Vector2i(-1, -1):
			continue
		tilemap.set_cell(0, Vector2i(int(parts[0]), int(parts[1])), 0, atlas)
