## SpawnManager.gd — Gerencia spawn de WildPokémons no overworld.
## Respeita MAX_WILD_INSTANCES, SPAWN_RADIUS_TILES e DESPAWN_RADIUS_TILES.
## Usa ZoneManager para obter tabela de spawn e RNGManager para sorteio por weight.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const MAX_WILD_INSTANCES    : int   = 60
# Achado: 200/280 tiles fazia sentido pra um mundo contínuo gigante (Kanto
# inteiro) que nunca chegou a ser construído. O world_map real hoje tem só
# 100×120 tiles — um raio de 200 sorteava posição quase sempre fora do mapa
# ou longe demais da tela pra o Gabriel algum dia ver o Pokémon selvagem.
const SPAWN_RADIUS_TILES    : int   = 20
const DESPAWN_RADIUS_TILES  : int   = 35
const SPAWN_INTERVAL_SEC    : float = 3.0   # tempo entre tentativas de spawn
const TILE_SIZE             : int   = 128   # pixels por tile (migração tile128, 03/09)

const WILD_POKEMON_SCENE : String = "res://scenes/entities/pokemon/WildPokemon.tscn"

# ──────────────────────────────────────────────────────────────────────────────
# Spawn fixo por terreno (03/09) — pedido do Gabriel: "quero que os pokémons
# selvagens sempre estejam visíveis e não simplesmente surjam do nada... spawn
# fixo de acordo com o tipo [de terreno] e localização... o mesmo Pokémon pode
# spawnar em várias localizações do mapa". Só vale pro MUNDO ABERTO
# (world_map) — dungeons (Mt Moon, Rock Tunnel, Zona Safari, Cerulean Cave
# etc.) continuam no sistema antigo de tabela curada por zona, que já é mais
# controlado de propósito (e o Mewtwo de Cerulean Cave, por exemplo, nem passa
# por aqui — é um nó fixo direto na cena, sempre foi).
#
# Substitui a tabela curada (`zone.wild_pokemon`, 1 lista fixa por zona) por
# uma tabela GLOBAL de terreno → espécies: a mesma espécie aparece em
# QUALQUER lugar do mapa que tenha aquele terreno, ao entrar na zona pela
# primeira vez (`_populated_zones`), sem timer e sem despawn por distância —
# fica ali de verdade, patrulhando (State.PATROL já existe), até ser
# derrotado/capturado.
# ──────────────────────────────────────────────────────────────────────────────

## Chars marcados "(bloq.)"/"Blocked" na legenda de MapLayouts.gd — usado só
## pra decidir onde NÃO nascer diretamente (categorias "adjacent_to" nascem
## num vizinho livre, não em cima do obstáculo).
const BLOCKED_TILE_CHARS := ["W", "~", "T", "R", "E", "d", "H", "X", "N", "O", "K", "B", "L", "c", "l", "m", "n"]

## category -> {"tiles": [chars onde nasce direto]} OU {"adjacent_to": [chars
## obstáculo, nasce num vizinho livre]}, mais "species" (lista de IDs — a
## mesma categoria pode sortear qualquer uma delas, sem se prender a 1 só).
const TERRAIN_SPECIES := {
	"grass":       {"tiles": ["."],               "species": [43, 44, 70]},        # Oddish, Gloom, Weepinbell
	"tall_grass":  {"tiles": ["A"],                "species": [23, 24, 14, 15]},    # Ekans, Arbok, Kakuna, Beedrill
	"beach_water": {"tiles": ["S", "U"],           "species": [7, 79, 98]},         # Squirtle, Slowpoke, Krabby
	"rocky":       {"adjacent_to": ["R", "L"],     "species": [74, 75, 76, 111]},   # Geodude, Graveler, Golem, Rhyhorn
	"volcanic":    {"adjacent_to": ["c"],          "species": [77, 126, 58]},       # Ponyta, Magmar, Growlithe
	"forest":      {"adjacent_to": ["T", "N", "O"], "species": [10, 11, 16, 25]},   # Caterpie, Metapod, Pidgey, Pikachu
}

const SPAWNS_PER_CATEGORY : int = 2   # quantos de cada categoria, por zona (teto por zona)
const LEVEL_MIN_TERRAIN   : int = 3
const LEVEL_MAX_TERRAIN   : int = 8
const NEIGHBOR_RADIUS     : int = 2   # raio (em tiles) pra categorias "adjacent_to"

var _populated_zones : Array[String] = []

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _wild_instances : Array   = []       # lista de WildPokemon ativos
var _spawn_timer    : float   = 0.0
var _player         : Node2D  = null
var _spawn_parent   : Node    = null     # onde instanciar na árvore

var _wild_scene : PackedScene = null

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("spawn_manager")
	_wild_scene = load(WILD_POKEMON_SCENE) as PackedScene
	if not _wild_scene:
		push_warning("SpawnManager: WildPokemon.tscn não encontrado em %s" % WILD_POKEMON_SCENE)
	# Usa o próprio nó como pai de instâncias por padrão
	_spawn_parent = self
	set_process(true)

func _process(delta: float) -> void:
	if not _player:
		_player = _find_player()
		if not _player:
			return

	_cleanup_invalid_instances()

	if _is_world_map():
		# Mundo aberto: população fixa por terreno, sem timer e sem despawn
		# por distância — só limpa instâncias já mortas/capturadas (acima).
		var zone_manager := _get_zone_manager()
		if zone_manager:
			var zone : Dictionary = zone_manager.get_current_zone()
			if not zone.is_empty():
				_populate_zone_by_terrain(zone)
		return

	# Dungeons/interiores: sistema antigo, intocado.
	_despawn_by_distance()
	_spawn_timer += delta
	if _spawn_timer >= _current_spawn_interval():
		_spawn_timer = 0.0
		_try_spawn()

func _is_world_map() -> bool:
	var scene := get_tree().current_scene
	return scene != null and "map_id" in scene and scene.map_id == "world_map"

# ──────────────────────────────────────────────────────────────────────────────
# Densidade por profundidade na floresta (Fase 10 do motor de combate em
# tempo real, 02/09) — pedido do Gabriel: espécie por área continua fixa
# (tabela de zones.json não muda em nada), só a VELOCIDADE de spawn aumenta
# quanto mais fundo o jogador entra — "vira uma luta de sobrevivência".
# "Fundo" = mais longe de qualquer borda do tile_rect que a zona já tem em
# zones.json (não precisou campo novo). Só zonas com "forest" no id — não é
# convenção de nenhum jogo pesquisado, é design nosso, seguindo a descrição
# do próprio Gabriel. MAX_WILD_INSTANCES continua sendo o teto de segurança
# absoluto (nunca mais que isso no mapa inteiro, protege performance).
# ──────────────────────────────────────────────────────────────────────────────
const FOREST_MAX_DEPTH_TILES  : float = 20.0   # a partir daqui já conta como "o mais fundo"
const FOREST_MIN_INTERVAL_SEC : float = 0.6    # intervalo no fundo da floresta (teto de intensidade)

func _current_spawn_interval() -> float:
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return SPAWN_INTERVAL_SEC
	var zone : Dictionary = zone_manager.get_current_zone()
	if zone.is_empty():
		return SPAWN_INTERVAL_SEC
	var zone_id : String = str(zone.get("id", "")).to_lower()
	if not zone_id.contains("forest"):
		return SPAWN_INTERVAL_SEC
	var ratio : float = clampf(_forest_depth_tiles(zone) / FOREST_MAX_DEPTH_TILES, 0.0, 1.0)
	return lerpf(SPAWN_INTERVAL_SEC, FOREST_MIN_INTERVAL_SEC, ratio)

## Distância (em tiles) até a borda mais próxima do tile_rect da zona —
## 0 = na borda/fora, cresce conforme o jogador entra mais no meio dela.
func _forest_depth_tiles(zone: Dictionary) -> float:
	var rect : Dictionary = zone.get("tile_rect", {})
	if rect.is_empty() or not _player:
		return 0.0
	var px : float = _player.global_position.x / float(TILE_SIZE)
	var py : float = _player.global_position.y / float(TILE_SIZE)
	var x0 : float = rect.get("x", 0)
	var y0 : float = rect.get("y", 0)
	var w  : float = rect.get("w", 0)
	var h  : float = rect.get("h", 0)
	var dist_to_edge : float = min(min(px - x0, (x0 + w) - px), min(py - y0, (y0 + h) - py))
	return max(0.0, dist_to_edge)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Define nó pai para instâncias (chamado pelo KantoWorld).
func set_spawn_parent(parent: Node) -> void:
	_spawn_parent = parent

## Define player manualmente.
func set_player(p: Node2D) -> void:
	_player = p

## Retorna quantidade de instâncias ativas.
func get_active_count() -> int:
	return _wild_instances.size()

# ──────────────────────────────────────────────────────────────────────────────
# Lógica de spawn
# ──────────────────────────────────────────────────────────────────────────────
func _try_spawn() -> void:
	if _wild_instances.size() >= MAX_WILD_INSTANCES:
		return
	if not _wild_scene:
		return

	# Obtém zona atual via ZoneManager (autoload ou nó na árvore)
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return

	var zone : Dictionary = zone_manager.get_current_zone()
	if zone.is_empty():
		return

	var table : Array = zone.get("wild_pokemon", [])
	if table.is_empty():
		return

	# Sorteia pokémon por weight
	var chosen := _weighted_pick(table)
	if chosen.is_empty():
		return

	# Sorteia posição ao redor do player dentro do raio
	var spawn_pos := _random_spawn_pos()
	if spawn_pos == Vector2.ZERO:
		return

	_spawn_pokemon(chosen, spawn_pos, str(zone.get("id", "")))

# ──────────────────────────────────────────────────────────────────────────────
# Spawn fixo por terreno (mundo aberto) — ver comentário no topo do arquivo.
# ──────────────────────────────────────────────────────────────────────────────
## Popula uma zona UMA VEZ (marca em _populated_zones) — acha, pra cada
## categoria de terreno, as posições candidatas dentro do tile_rect da zona e
## nasce até SPAWNS_PER_CATEGORY por categoria encontrada.
func _populate_zone_by_terrain(zone: Dictionary) -> void:
	var zone_id : String = str(zone.get("id", ""))
	if zone_id.is_empty() or zone_id in _populated_zones:
		return
	_populated_zones.append(zone_id)

	var layout : Dictionary = MapLayouts.get_layout("world_map")
	var tiles  : Array = layout.get("tiles", [])
	var rect   : Dictionary = zone.get("tile_rect", {})
	var x0 : int = int(rect.get("x", 0))
	var y0 : int = int(rect.get("y", 0))
	var w  : int = int(rect.get("w", 0))
	var h  : int = int(rect.get("h", 0))
	if w <= 0 or h <= 0 or tiles.is_empty():
		return

	for category in TERRAIN_SPECIES.keys():
		var info : Dictionary = TERRAIN_SPECIES[category]
		var candidatos : Array = _find_terrain_positions(tiles, x0, y0, w, h, info)
		if candidatos.is_empty():
			continue
		candidatos.shuffle()
		var especies : Array = info.get("species", [])
		if especies.is_empty():
			continue
		var quantos : int = mini(SPAWNS_PER_CATEGORY, candidatos.size())
		for i in quantos:
			if _wild_instances.size() >= MAX_WILD_INSTANCES:
				return
			var tile_pos   : Vector2i = candidatos[i]
			var species_id : int = especies[RNGManager.randi_range(0, especies.size() - 1)]
			var level      : int = RNGManager.randi_range(LEVEL_MIN_TERRAIN, LEVEL_MAX_TERRAIN)
			var world_pos  : Vector2 = Vector2((tile_pos.x + 0.5) * TILE_SIZE, (tile_pos.y + 0.5) * TILE_SIZE)
			_spawn_terrain_pokemon(species_id, level, world_pos, zone_id)

## Varre o retângulo (x0,y0,w,h) do grid de tiles cru (o MESMO texto usado
## pra pintar o mapa, não o TileMap já renderizado) procurando tiles que
## batam com a categoria — "tiles" nasce em cima, "adjacent_to" nasce num
## vizinho livre (o obstáculo em si nunca é uma posição válida).
func _find_terrain_positions(tiles: Array, x0: int, y0: int, w: int, h: int, info: Dictionary) -> Array:
	var out    : Array = []
	var height : int = tiles.size()
	var y_fim  : int = mini(y0 + h, height)
	for ty in range(maxi(y0, 0), y_fim):
		var row    : String = tiles[ty]
		var width  : int = row.length()
		var x_fim  : int = mini(x0 + w, width)
		for tx in range(maxi(x0, 0), x_fim):
			var ch : String = row[tx]
			if info.has("tiles"):
				if ch in info["tiles"]:
					out.append(Vector2i(tx, ty))
			elif info.has("adjacent_to"):
				if ch in BLOCKED_TILE_CHARS:
					continue  # o próprio tile é obstáculo — não nasce em cima
				if _tem_vizinho_obstaculo(tiles, tx, ty, info["adjacent_to"]):
					out.append(Vector2i(tx, ty))
	return out

func _tem_vizinho_obstaculo(tiles: Array, tx: int, ty: int, chars: Array) -> bool:
	for dy in range(-NEIGHBOR_RADIUS, NEIGHBOR_RADIUS + 1):
		var ny : int = ty + dy
		if ny < 0 or ny >= tiles.size():
			continue
		var row : String = tiles[ny]
		for dx in range(-NEIGHBOR_RADIUS, NEIGHBOR_RADIUS + 1):
			var nx : int = tx + dx
			if nx < 0 or nx >= row.length():
				continue
			if row[nx] in chars:
				return true
	return false

## Igual _spawn_pokemon() — WildPokemon já guarda `_spawn_pos` sozinho no
## próprio _ready() (existia, nunca era usado); só precisou ensinar
## _pick_patrol_dir() a respeitar essa "casa" (ver WildPokemon.gd).
func _spawn_terrain_pokemon(species_id: int, level: int, pos: Vector2, zone_id: String) -> void:
	var instance := _wild_scene.instantiate()
	if not instance:
		return
	instance.global_position = pos
	if instance.has_method("initialize"):
		instance.initialize(species_id, level, "neutral", zone_id)
	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	EventBus.wild_pokemon_spawned.emit(instance)

func _spawn_pokemon(entry: Dictionary, pos: Vector2, zone_id: String = "") -> void:
	var instance := _wild_scene.instantiate()
	if not instance:
		return

	instance.global_position = pos

	# Injeta dados no WildPokemon se ele tiver método de inicialização
	var level : int = RNGManager.randi_range(
		entry.get("level_min", 1),
		entry.get("level_max", 5)
	)
	if instance.has_method("initialize"):
		instance.initialize(entry.get("id", 1), level, entry.get("behavior", "aggressive"), zone_id)

	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	EventBus.wild_pokemon_spawned.emit(instance)

## Cria um WildPokemon específico (espécie/nível já escolhidos por fora) numa
## posição exata — usado pela pesca (Fase 2 do Diário): o peixe fisgado não
## "persegue" o jogador como um spawn normal, a mordida já é o encontro.
## Retorna a instância (quem chamou decide o que fazer com ela, ex: emitir
## wild_encounter_started na hora, sem esperar o WildPokemon perceber o player).
func spawn_specific(species_id: int, level: int, pos: Vector2) -> Node:
	var instance := _wild_scene.instantiate()
	if not instance:
		return null
	instance.global_position = pos
	if instance.has_method("initialize"):
		instance.initialize(species_id, level, "neutral")
	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	return instance

## Sorteia posição aleatória dentro de SPAWN_RADIUS_TILES ao redor do player,
## garantindo que não seja na mesma tile do player.
func _random_spawn_pos() -> Vector2:
	if not _player:
		return Vector2.ZERO

	var center   : Vector2 = _player.global_position
	var radius_px : float  = SPAWN_RADIUS_TILES * TILE_SIZE
	var min_dist  : float  = TILE_SIZE * 5  # mínimo 5 tiles de distância

	for _attempt in range(20):
		var angle : float  = RNGManager.randf() * TAU
		var dist  : float  = RNGManager.randf_range(min_dist, radius_px)
		var pos   : Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		return pos

	return Vector2.ZERO

# ──────────────────────────────────────────────────────────────────────────────
# Lógica de despawn
# ──────────────────────────────────────────────────────────────────────────────
## Só limpa a LISTA (instâncias já mortas/capturadas/liberadas por fora) —
## nunca derruba um Pokémon vivo. Roda sempre, mundo aberto ou dungeon.
func _cleanup_invalid_instances() -> void:
	var to_remove : Array = []
	for inst in _wild_instances:
		if not is_instance_valid(inst):
			to_remove.append(inst)
	for inst in to_remove:
		_wild_instances.erase(inst)

## Despawn por distância — só pras dungeons/interiores (sistema antigo). O
## mundo aberto (03/09) NUNCA usa isto: terreno alargado é pra ficar visível
## de verdade, não sumir quando o jogador se afasta.
func _despawn_by_distance() -> void:
	if not _player:
		return

	var despawn_px : float = DESPAWN_RADIUS_TILES * TILE_SIZE
	var to_remove  : Array = []

	for inst in _wild_instances:
		if not is_instance_valid(inst):
			continue
		var dist : float = _player.global_position.distance_to(inst.global_position)
		if dist > despawn_px:
			to_remove.append(inst)

	for inst in to_remove:
		_wild_instances.erase(inst)
		if is_instance_valid(inst):
			inst.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
## Sorteio por peso: entry deve ter campo "weight" (int).
func _weighted_pick(table: Array) -> Dictionary:
	var total : int = 0
	for entry in table:
		total += entry.get("weight", 1)

	if total <= 0:
		return {}

	var roll : int = RNGManager.randi_range(0, total - 1)
	var acc  : int = 0
	for entry in table:
		acc += entry.get("weight", 1)
		if roll < acc:
			return entry

	return table[table.size() - 1]

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _get_zone_manager() -> Node:
	# Tenta encontrar ZoneManager como irmão na árvore
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "ZoneManager":
				return child
	return null
