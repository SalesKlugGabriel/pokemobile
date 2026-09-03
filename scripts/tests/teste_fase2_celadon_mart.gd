## teste_fase2_celadon_mart.gd — Teste headless da Loja de Departamentos de
## Celadon ganhando um vendedor de verdade (antes só o prédio existia, igual
## Silph Co./Torre Pokémon). Mesmo padrão já usado em Viridian
## (opens_shop_on_dialog_end=true) — a loja em si (ShopScene) já é genérica,
## reaproveitada por qualquer vendedor do jogo.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase2_celadon_mart.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 2 (Celadon Mart — vendedor de verdade) ===")

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
	# ---- 1. O vendedor cai dentro do prédio (piso "I", não parede/porta) ----
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	var ce0 := MapLayouts.CELADON_COL_INICIO
	var r0 := MapLayouts.SAFFRON_ROW_INICIO
	_assert(tiles[r0 + 10][ce0 + 54] == "I", "posição do vendedor cai dentro do prédio (piso)")

	# ---- 2. NPC existe no WorldMap, configurado como vendedor de verdade ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var vendedor := inst.get_node_or_null("Entities/CeladonMartVendedor")
		_assert(vendedor != null, "CeladonMartVendedor existe no WorldMap")
		if vendedor:
			_assert(vendedor.opens_shop_on_dialog_end == true, "abre a loja de verdade ao fim do diálogo")
			_assert(vendedor.dialog_id == "celadon_shopkeeper", "usa o diálogo próprio da Loja de Celadon")
			var pos : Vector2 = vendedor.position
			var tile_c := int(pos.x / 128)
			var tile_r := int(pos.y / 128)
			_assert(tile_c == ce0 + 54 and tile_r == r0 + 10,
				"posição bate exatamente com a coordenada real do prédio (%d,%d)" % [tile_c, tile_r])
		inst.free()

	# ---- 3. Diálogo próprio existe (não reaproveita o de Viridian sem querer) ----
	var f := FileAccess.open("res://data/dialogs/dialogs.json", FileAccess.READ)
	var dialogs = JSON.parse_string(f.get_as_text())
	f.close()
	_assert(dialogs.has("celadon_shopkeeper"), "diálogo celadon_shopkeeper existe")
	if dialogs.has("celadon_shopkeeper"):
		_assert(dialogs["celadon_shopkeeper"].size() > 0, "diálogo tem pelo menos uma fala")
