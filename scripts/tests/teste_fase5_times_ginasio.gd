## teste_fase5_times_ginasio.gd — Confere que cada líder de ginásio tem o
## time completo do tipo certo (pedido do Gabriel, 02/09): Brock 6 Pedra,
## Misty 5 Água, Lt.Surge 6 Elétrico, Erika 6 Planta, Koga 6 Planta+Veneno,
## Sabrina 6 Psíquico, Giovanni 6 Terra, Blaine 5 Fogo, Morty (novo, Lavender)
## Fantasma/Terra. Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_times_ginasio.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (times de ginásio temáticos) ===")
	GameData = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var world_scene : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var cinnabar_scene : PackedScene = load("res://scenes/world/maps/CinnabarIsland.tscn")
	var world := world_scene.instantiate()
	var cinnabar := cinnabar_scene.instantiate()

	_checa_lider(world, "Brock",    6, ["Rock"])
	_checa_lider(world, "Misty",    5, ["Water"])
	_checa_lider(world, "Lt. Surge",6, ["Electric"])
	_checa_lider(world, "Erika",    6, ["Grass"])
	_checa_lider(world, "Koga",     6, ["Grass", "Poison"])
	_checa_lider(world, "Sabrina",  6, ["Psychic"])
	_checa_lider(world, "Giovanni", 6, ["Ground"])
	_checa_lider(world, "Morty",    5, ["Ghost", "Ground"])  # Gen1 só tem 3 Fantasma puros
	_checa_lider(cinnabar, "Blaine", 5, ["Fire"])

	world.free()
	cinnabar.free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

## Acha o NpcEntity pelo nome em qualquer profundidade da árvore (não sei o
## caminho exato de cada mapa) e confere quantidade + tipo de cada Pokémon.
func _checa_lider(root_node: Node, npc_name: String, esperado_count: int, tipos_aceitos: Array) -> void:
	var npc := _find_by_npc_name(root_node, npc_name)
	if not npc:
		_assert(false, "%s: NPC encontrado no mapa" % npc_name)
		return

	var time : Array = npc.trainer_team
	_assert(time.size() == esperado_count, "%s tem exatamente %d Pokémon (tem %d)" % [npc_name, esperado_count, time.size()])

	var especies := {}
	for entry in time:
		var species_id : int = int(entry.get("species_id", 0))
		especies[species_id] = especies.get(species_id, 0) + 1
		var species_data : Dictionary = GameData.get_species(species_id)
		var tipos : Array = species_data.get("types", [])
		var bate := false
		for t in tipos:
			if t in tipos_aceitos:
				bate = true
				break
		_assert(bate, "%s: %s (id %d, tipos %s) bate com o tema %s" % [npc_name, species_data.get("name","?"), species_id, tipos, tipos_aceitos])

	for species_id in especies:
		_assert(especies[species_id] == 1, "%s: espécie %d não se repete no mesmo time" % [npc_name, species_id])

func _find_by_npc_name(node: Node, npc_name: String) -> Node:
	if "npc_name" in node and node.npc_name == npc_name:
		return node
	for child in node.get_children():
		var achou := _find_by_npc_name(child, npc_name)
		if achou:
			return achou
	return null

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
