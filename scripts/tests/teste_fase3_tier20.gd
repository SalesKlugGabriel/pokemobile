## teste_fase3_tier20.gd — Teste headless do Tier 20 (Power Plant — ilha
## artificial no mar, continuando ao sul do Seafoam Islands). Fachada de
## prédio (mesmo padrão de Silph Co./Torre Pokémon), SEM warp — só
## alcançável quando Surf/Fly existir (mesma regra do Arquipélago/Seafoam).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier20.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 20 (Power Plant) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	_teste_geral()
	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % label)
	else:
		_fail += 1
		print("  FALHA - %s" % label)

func _teste_geral() -> void:
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]

	# Colunas 400+vc, linhas 156+cr (offset PEWTER+COASTLINE+ARQUIPELAGO+SEAFOAM=156)
	_assert(tiles[156 + 8][400 + 27] == "H", "Power Plant: telhado do prédio existe")
	_assert(tiles[156 + 12][400 + 27] == "I", "Power Plant: interior é piso")
	_assert(tiles[156 + 20][400 + 27] == "P", "Power Plant: porta existe")
	_assert(tiles[156 + 15][400 + 20] == "W" or tiles[156 + 15][400 + 20] == "I" or tiles[156 + 15][400 + 20] == "S",
		"Power Plant: ilha ao redor do prédio é sólida (não mar)")
	_assert(tiles[156 + 15][400 + 2] == "~", "fora da ilha (dentro da faixa de Vermilion, mas longe do centro) é mar aberto")
	_assert(tiles[156 + 15][400 + 55] == "~", "fora da ilha (bem a leste) é mar aberto")

	# Não pode ter vazado pra fora da faixa de colunas de Vermilion
	_assert(tiles[156 + 15][399] != "H" and tiles[156 + 15][399] != "I",
		"prédio da usina não vaza pra fora da faixa de colunas de Vermilion")

	# Sem warp — mesma regra das ilhas anteriores
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_powerplant_warp := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("PowerPlant"):
					achou_powerplant_warp = true
		_assert(not achou_powerplant_warp, "nenhum warp criado pro Power Plant (só alcançável com Surf/Fly no futuro)")
		inst.free()

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var pp : Dictionary = by_id.get("power_plant", {})
	var r : Dictionary = pp.get("tile_rect", {})
	_assert(r.get("x", 0) == 400 and r.get("y", 0) == 156 and r.get("w", 0) == 60 and r.get("h", 0) == 30,
		"zones.json: power_plant aponta pra coordenada real (400,156,60,30)")
	var achou_zapdos := false
	for w in pp.get("wild_pokemon", []):
		if int(w.get("id", 0)) == 145:
			achou_zapdos = true
	_assert(achou_zapdos, "power_plant mantém o Zapdos pré-cadastrado do plano mestre")
