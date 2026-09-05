## BaseMap.gd — Script base para todas as cenas de mapa.
## Herdar este script em cada mapa. Registra TileMap e Player no WorldManager.
## Pinta tiles automaticamente via MapLayouts e ajusta Camera2D limits.
class_name BaseMap
extends Node2D

## ID único do mapa (ex: "pallet_town", "route_1")
@export var map_id : String = "unknown_map"

## ID da ESTRUTURA de múltiplos andares (ex: "pokemon_tower", "silph_co") —
## bate com o "target" de objetivos reach_floor/traverse_floors em
## quests.json. Vazio = este mapa não conta pra nenhum objetivo desse tipo
## (padrão pra toda cena que já existia antes desta peça de motor, mesmo
## campo que o antigo FloorMap.gd já tinha — unificado aqui porque todo
## andar novo usa BaseMap+MapLayouts, não mais o FloorMap/TileMapLayer
## antigo, que ficou órfão desde antes da arquitetura atual existir).
@export var structure_id : String = ""
## Número deste andar dentro da estrutura acima. 0 = não é andar rastreado
## (não emite floor_reached). Ex: 5 pro 5º andar da Torre Pokémon.
@export var floor_number : int    = 0

@onready var tilemap : TileMap       = $TileMap
@onready var player  : TrainerEntity = $Entities/Player

func _ready() -> void:
	_paint_tiles()
	if not MapOverrides.overrides_loaded.is_connected(_on_map_overrides_loaded):
		MapOverrides.overrides_loaded.connect(_on_map_overrides_loaded)
	# "segundo andar": telhado some ao entrar no prédio
	if not EventBus.player_tile_entered.is_connected(_on_player_tile_entered):
		EventBus.player_tile_entered.connect(_on_player_tile_entered)
	_apply_camera_limits()
	WorldManager.register_map(map_id, tilemap, player)
	WorldManager.apply_pending_spawn()
	EventBus.map_changed.emit("", map_id)
	if structure_id != "" and floor_number > 0:
		EventBus.floor_reached.emit(structure_id, floor_number)
	_setup_world_systems()
	# Lendário do ninho, se este mapa for o fim de um covil (05/09). Depois de
	# `_setup_world_systems` de propósito: precisa do SpawnManager já ligado.
	NinhoLendario.povoar(self, map_id)
	# O mundo aberto tem UM tile condicionado a estado de save (a porta do
	# Ginásio de Viridian, que só abre depois de MAIN-08) — repinta se uma
	# quest completar enquanto o mapa já está carregado, senão o jogador só
	# veria a porta abrir depois de sair e voltar pro mapa.
	if map_id == "world_map":
		QuestManager.quest_completed.connect(_on_quest_completed_repaint)

func _on_quest_completed_repaint(_quest_id: String) -> void:
	_paint_tiles()

func _setup_world_systems() -> void:
	if not player:
		return
	var wild_container := get_node_or_null("Entities/WildPokemons")
	var npc_container  := get_node_or_null("Entities/NPCs")

	var spawn_mgr := get_node_or_null("SpawnManager")
	if spawn_mgr:
		if spawn_mgr.has_method("set_player"):
			spawn_mgr.set_player(player)
		if wild_container and spawn_mgr.has_method("set_spawn_parent"):
			spawn_mgr.set_spawn_parent(wild_container)

	var npc_mgr := get_node_or_null("NPCManager")
	if npc_mgr:
		if npc_mgr.has_method("set_player"):
			npc_mgr.set_player(player)
		if npc_container and npc_mgr.has_method("set_spawn_parent"):
			npc_mgr.set_spawn_parent(npc_container)

func _exit_tree() -> void:
	WorldManager.unregister_map()

# ──────────────────────────────────────────────────────────────────────────────
# Polimento visual
# ──────────────────────────────────────────────────────────────────────────────

func _paint_tiles() -> void:
	if not tilemap:
		return
	MapLayouts.paint(tilemap, map_id)
	MapOverrides.apply_overrides(tilemap, map_id)
	_montar_telhados()

# ──────────────────────────────────────────────────────────────────────────────
# "Segundo andar" — telhado que some ao entrar no prédio (04/09, ideia do
# Gabriel)
#
# Problema que isto resolve: quando os Centros Pokémon viraram "entra andando"
# (sem warp), o prédio passou a mostrar o piso interno visto de fora — parecia
# um tapete no chão, não uma construção. A saída clássica de RPG top-down é
# desenhar o telhado numa camada POR CIMA e escondê-lo quando o jogador entra.
#
# Assim ganha-se os dois lados: de fora o prédio é uma massa sólida com telhado
# (a "perspectiva" que faltava), e ao atravessar a porta o telhado some e
# revela o interior onde o jogador de fato está andando.
#
# A camada de telhado é derivada do mapa já pintado (MapLayouts.agrupar_
# interiores), então qualquer prédio novo ganha telhado sozinho — não existe
# lista de prédios pra manter em sincronia.
# ──────────────────────────────────────────────────────────────────────────────
const CAMADA_TELHADO : int = 1

var _predios       : Array = []    # cada item: Array[Vector2i] com as células de um prédio
var _predio_atual  : int   = -1    # índice do prédio em que o jogador está (-1 = nenhum)

func _montar_telhados() -> void:
	_predios = MapLayouts.agrupar_interiores(tilemap)
	_predio_atual = -1
	if _predios.is_empty():
		return
	while tilemap.get_layers_count() <= CAMADA_TELHADO:
		tilemap.add_layer(-1)
	# acima do chão E das entidades: quem está dentro fica escondido pelo
	# telhado, que é exatamente o efeito desejado
	tilemap.set_layer_z_index(CAMADA_TELHADO, 5)
	tilemap.set_layer_y_sort_enabled(CAMADA_TELHADO, false)
	for i in _predios.size():
		_pintar_telhado(i, true)

func _pintar_telhado(indice: int, visivel: bool) -> void:
	if indice < 0 or indice >= _predios.size():
		return
	var celulas : Array = _predios[indice]
	if not visivel:
		for celula in celulas:
			tilemap.erase_cell(CAMADA_TELHADO, celula)
		return
	# Usa o KIT (cumeeira/beiral/arestas/cantos) em vez de repetir o tile
	# central — é o que dá à casa a silhueta de construção fechada em vez de
	# uma chapa de telha (regra obrigatória 2, 04/09).
	var conjunto := {}
	for celula in celulas:
		conjunto[celula] = true
	for celula in celulas:
		var peca : String = MapLayouts.peca_de_telhado(celula, conjunto)
		tilemap.set_cell(CAMADA_TELHADO, celula, 0, MapLayouts.CHAR_MAP[peca])

## Índice do prédio que contém este tile, ou -1 se o jogador está do lado de fora.
func predio_em(tile: Vector2i) -> int:
	for i in _predios.size():
		if tile in _predios[i]:
			return i
	return -1

## Chamado quando o jogador muda de tile: esconde o telhado do prédio em que ele
## entrou e devolve o do prédio de onde saiu.
func _on_player_tile_entered(tile: Vector2i) -> void:
	var indice := predio_em(tile)
	if indice == _predio_atual:
		return
	_pintar_telhado(_predio_atual, true)   # devolve o telhado do anterior
	_predio_atual = indice
	_pintar_telhado(indice, false)         # esconde o do prédio em que entrou

## Cobre o caso em que este mapa já pintou ANTES da busca de ajustes do
## Editor Visual terminar (achado esperado no boot — a 1ª tela do jogo não
## espera a rede pra não travar o jogador à toa).
func _on_map_overrides_loaded() -> void:
	if tilemap:
		MapOverrides.apply_overrides(tilemap, map_id)

func _apply_camera_limits() -> void:
	var cam : Camera2D = _find_camera()
	if not cam:
		return
	var bounds := MapLayouts.get_pixel_bounds(map_id)
	cam.limit_left   = bounds.position.x
	cam.limit_top    = bounds.position.y
	cam.limit_right  = bounds.position.x + bounds.size.x
	cam.limit_bottom = bounds.position.y + bounds.size.y

func _find_camera() -> Camera2D:
	if player:
		for child in player.get_children():
			if child is Camera2D:
				return child
	return null
