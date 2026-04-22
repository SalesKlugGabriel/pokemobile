## GameData.gd — Carrega todos os JSONs de /data/ na inicialização (Autoload/Singleton)
## Todos os sistemas consultam este singleton para ler dados de espécies, moves, items etc.
## NUNCA hardcode stats ou moves de Pokémon no GDScript — sempre consulte aqui.
extends Node

# Dicionários carregados na inicialização
var species: Dictionary = {}      # id (int) → dados da espécie
var learnsets: Dictionary = {}    # id (String) → Array de {level, move}
var evolutions: Dictionary = {}   # id (String) → dados de evolução
var moves: Dictionary = {}        # id (String) → dados do move
var items: Dictionary = {}        # id (String) → dados do item
var spawns: Dictionary = {}       # zone_id (String) → Array de entries de spawn
var quests: Dictionary = {}       # quest_id (String) → dados da quest
var dialogs: Dictionary = {}      # dialog_id (String) → Array de linhas de texto

var _loaded: bool = false

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	species   = _load_json("res://data/pokemon/species.json")
	learnsets = _load_json("res://data/pokemon/learnsets.json")
	evolutions = _load_json("res://data/pokemon/evolutions.json")
	moves     = _load_json("res://data/moves/moves.json")
	items     = _load_json("res://data/items/items.json")
	spawns    = _load_json("res://data/biomes/spawns.json")
	quests    = _load_json("res://data/quests/quests.json")
	dialogs   = _load_json("res://data/dialogs/dialogs.json")
	_loaded = true
	print("[GameData] Todos os JSONs carregados.")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[GameData] Arquivo não encontrado: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("[GameData] Erro ao parsear JSON: %s" % path)
		return {}
	return parsed

# --- CONSULTAS DE ESPÉCIE ---

## Retorna dados da espécie pelo ID numérico (ex: 4 → Charmander)
func get_species(species_id: int) -> Dictionary:
	return species.get(str(species_id), {})

## Retorna lista de moves aprendíveis por uma espécie até um determinado nível
func get_learnable_moves(species_id: int, up_to_level: int) -> Array:
	var set: Array = learnsets.get(str(species_id), [])
	return set.filter(func(entry): return entry.get("level", 0) <= up_to_level)

## Retorna dados de evolução de uma espécie (null se não evolui)
func get_evolution(species_id: int) -> Dictionary:
	return evolutions.get(str(species_id), {})

# --- CONSULTAS DE MOVE ---

## Retorna dados de um move pelo seu ID string (ex: "ember")
func get_move(move_id: String) -> Dictionary:
	return moves.get(move_id, {})

# --- CONSULTAS DE ITEM ---

## Retorna dados de um item pelo seu ID string (ex: "pokeball")
func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

# --- CONSULTAS DE SPAWN ---

## Retorna a lista de entradas de spawn de uma zona/bioma
func get_spawns(zone_id: String) -> Array:
	return spawns.get(zone_id, [])

## Alias semântico para get_spawns (usado pelo PokemonSpawner)
func get_biome_spawns(biome_id: String) -> Array:
	return spawns.get(biome_id, [])

# --- CONSULTAS DE QUEST ---

## Retorna dados de uma quest pelo ID (ex: "MAIN-01")
func get_dialog(dialog_id: String) -> Array:
	return dialogs.get(dialog_id, ["..."])

func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})

## Verifica se todos os dados foram carregados
func is_loaded() -> bool:
	return _loaded
