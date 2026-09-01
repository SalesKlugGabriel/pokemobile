## teste_zone_manager.gd — Teste headless da correção do risco sistêmico
## registrado em 01/09 (Tier 15): ZoneManager.get_zone_id_at() varria TODAS as
## zonas por coordenada bruta, sem saber em qual cena o jogador está — como
## Mt Moon/Rock Tunnel/Safari Zone/Rocket Hideout/Cinnabar Island têm tile_rect
## começando perto de (0,0) na própria cena, a mesma coordenada bruta batia com
## várias zonas ao mesmo tempo, e a primeira da lista (Mt Moon) sempre vencia.
## Roda com: godot4 --headless --script res://scripts/tests/teste_zone_manager.gd
extends SceneTree

# Rodando via --script, os autoloads não ficam disponíveis como identificador
# global de compilação em tempo de PARSE (preload falha) — só depois que a
# árvore sobe, então este script carrega via load() dentro de _initialize(),
# não preload() no topo do arquivo (mesma lição de teste_quest_manager.gd).
var ZoneManagerScript : GDScript

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste ZoneManager (find_zone_id por map_id) ===")
	ZoneManagerScript = load("res://scripts/world/systems/ZoneManager.gd")

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
	var zones := _carregar_zones()
	_assert(zones.size() > 0, "zones.json carregado (%d zonas)" % zones.size())

	# As 5 zonas de cena própria, todas com tile_rect começando em (0,0) na
	# própria cena — a MESMA coordenada bruta (5,5) precisa resolver pra zonas
	# diferentes dependendo só do map_id, nunca "a primeira que bater".
	var casos := [
		["mt_moon",        Vector2i(5, 5)],
		["rock_tunnel",    Vector2i(5, 5)],
		["safari_zone",    Vector2i(5, 5)],
		["rocket_hideout", Vector2i(5, 5)],
		["cinnabar_island",Vector2i(5, 5)],
	]
	for caso in casos:
		var map_id : String = caso[0]
		var tile   : Vector2i = caso[1]
		var achado : String = ZoneManagerScript.find_zone_id(tile, zones, map_id)
		_assert(achado == map_id,
			"tile (5,5) em '%s' resolve pra '%s' (achou '%s')" % [map_id, map_id, achado])

	# Mesma coordenada bruta, mundo aberto (world_map) — não deve cair em
	# nenhuma das 5 zonas de cena própria (elas exigem map_id específico).
	var achado_world : String = ZoneManagerScript.find_zone_id(Vector2i(5, 5), zones, "world_map")
	_assert(achado_world != "mt_moon" and achado_world != "rock_tunnel"
		and achado_world != "safari_zone" and achado_world != "rocket_hideout"
		and achado_world != "cinnabar_island",
		"tile (5,5) em 'world_map' NÃO cai em nenhuma zona de cena própria (achou '%s')" % achado_world)

	# Fora de qualquer rect conhecido — deve devolver vazio, não a zona errada.
	var fora : String = ZoneManagerScript.find_zone_id(Vector2i(9999, 9999), zones, "rock_tunnel")
	_assert(fora == "", "tile fora de qualquer rect devolve vazio (achou '%s')" % fora)

func _carregar_zones() -> Array:
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()
	return json.get_data()["zones"]
