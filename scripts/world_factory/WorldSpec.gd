## WorldSpec — configuração explícita e versionada da World Factory.
##
## Não usa autoload, RNG global nem valores financeiros/visuais ocultos. O
## consumidor cria uma instância e entrega a spec que pretende gerar.
class_name WorldSpec
extends RefCounted

const WORLD_LAB_PATH := "res://data/world/biomes/world_lab_v1.json"

static func carregar_world_lab() -> Dictionary:
	var arquivo := FileAccess.open(WORLD_LAB_PATH, FileAccess.READ)
	if arquivo == null:
		push_error("WorldSpec: não abriu %s" % WORLD_LAB_PATH)
		return {}
	var json := JSON.new()
	if json.parse(arquivo.get_as_text()) != OK:
		push_error("WorldSpec: JSON inválido: %s" % json.get_error_message())
		return {}
	return json.data if json.data is Dictionary else {}

static func validar(spec: Dictionary) -> PackedStringArray:
	var erros := PackedStringArray()
	for chave in ["id", "version", "world_seed", "bounds_m", "terrain", "manual_reservations"]:
		if not spec.has(chave):
			erros.append("campo obrigatório ausente: %s" % chave)
	var bounds: Dictionary = spec.get("bounds_m", {})
	var terrain: Dictionary = spec.get("terrain", {})
	for chave in ["min_x", "min_z", "width", "depth"]:
		if not bounds.has(chave):
			erros.append("bounds_m.%s ausente" % chave)
	for chave in ["sample_step_m", "chunk_size_m", "sea_level_m", "beach_width_m", "shoreline_width_m", "shallow_depth_m"]:
		if not terrain.has(chave):
			erros.append("terrain.%s ausente" % chave)
	if not erros.is_empty():
		return erros
	var passo: float = float(terrain["sample_step_m"])
	var chunk: float = float(terrain["chunk_size_m"])
	if passo <= 0.0 or chunk <= 0.0 or not is_equal_approx(fmod(chunk, passo), 0.0):
		erros.append("chunk_size_m precisa ser múltiplo positivo de sample_step_m")
	if float(bounds["width"]) <= 0.0 or float(bounds["depth"]) <= 0.0:
		erros.append("bounds_m precisa ter dimensões positivas")
	for chave in ["beach_width_m", "shoreline_width_m", "shallow_depth_m"]:
		if float(terrain[chave]) <= 0.0:
			erros.append("terrain.%s precisa ser positivo" % chave)
	return erros
