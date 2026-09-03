## SpriteOverrides.gd — Autoload. Mesma ideia do MapOverrides, pra sprites de
## Pokémon editadas no Editor Visual (poke.workprog.pro/editor). Busca a
## lista de sprites customizadas + as próprias imagens, uma vez, ao ligar o
## jogo — sem precisar reexportar/republicar o jogo a cada edição de sprite.
extends Node

signal overrides_loaded

const MANIFEST_URL : String = "https://poke.workprog.pro/editor/api/sprites/manifest.json"
const SPRITE_BASE_URL : String = "https://poke.workprog.pro/editor/api/sprites/file/"

var _textures : Dictionary = {}  # "mon_025.png" -> Texture2D
var _pending  : int = 0

func _ready() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_manifest_done)
	if req.request(MANIFEST_URL) != OK:
		overrides_loaded.emit()

func _on_manifest_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		overrides_loaded.emit()
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not (json.data is Array):
		overrides_loaded.emit()
		return
	var filenames : Array = json.data
	if filenames.is_empty():
		overrides_loaded.emit()
		return
	for filename in filenames:
		_fetch_one(String(filename))

func _fetch_one(filename: String) -> void:
	_pending += 1
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body): _on_one_done(filename, result, code, body))
	req.request(SPRITE_BASE_URL + filename)

func _on_one_done(filename: String, result: int, code: int, body: PackedByteArray) -> void:
	_pending -= 1
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK:
			_textures[filename] = ImageTexture.create_from_image(img)
	if _pending <= 0:
		overrides_loaded.emit()

func has_override(filename: String) -> bool:
	return _textures.has(filename)

func get_texture(filename: String) -> Texture2D:
	return _textures.get(filename, null)
