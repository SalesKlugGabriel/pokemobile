## teste_alcance_surf.gd — 10/09. Tudo que só se alcança de Surf continua
## alcançável de Surf?
##
## 🔴 Por que existe: na revisão final da reestruturação eu afirmei que
## Articuno, Zapdos, Seafoam, Arquipélago e Ilha do Deserto estavam
## inalcançáveis "porque Surf não existe". Estava ERRADO em dois níveis:
## Surf existe desde 03/09 (TrainerEntity._is_tile_walkable libera água
## pra quem tem Pokémon de Surf), e os cinco destinos são alcançáveis —
## eu tinha medido com uma busca que só considera caminhada, partindo de
## uma cidade que nem se liga mais por terra ao destino.
##
## Este teste mede do jeito certo: mesma regra do jogo (água passável pra
## quem surfa), partindo da cidade que de fato faz fronteira com aquele
## mar. Se uma fase futura fechar um canal sem perceber, ele reprova.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

## destino => [cidade de partida, tile do destino]
const DESTINOS := {
	"Ilha Gélida (porta do Articuno)": ["cerulean_city", Vector2i(250, -59)],
	"Usina (porta do Zapdos)":         ["vermilion_city", Vector2i(247, 310)],
	"Arquipélago Tropical":            ["vermilion_city", Vector2i(245, 230)],
	"Seafoam Islands":                 ["vermilion_city", Vector2i(245, 265)],
	"Ilha do Deserto":                 ["vermilion_city", Vector2i(245, 345)],
}

func _initialize() -> void:
	print("=== Teste: o que é de Surf continua alcançável de Surf (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tm, "world_map")

	for nome in DESTINOS:
		var d : Array = DESTINOS[nome]
		var origem := AjudaMapa.tile_andavel_da_zona(tm, AjudaMapa.retangulo_da_zona(String(d[0])))
		_assert(origem.x != -9999, "%s: a cidade de partida (%s) tem chão pra sair" % [nome, d[0]])
		if origem.x == -9999:
			continue
		_assert(_alcanca_surfando(tm, origem, d[1]),
			"%s: alcançável de Surf desde %s" % [nome, d[0]])

	# Contraprova: sem Surf (só a pé), esses destinos NÃO podem ser
	# alcançáveis — senão a ilha deixou de ser ilha e o Surf virou enfeite.
	for nome in DESTINOS:
		var d : Array = DESTINOS[nome]
		var origem := AjudaMapa.tile_andavel_da_zona(tm, AjudaMapa.retangulo_da_zona(String(d[0])))
		if origem.x == -9999:
			continue
		_assert(not AjudaMapa.caminho_a_pe(tm, origem, d[1], 1500000),
			"%s: continua sendo ilha de verdade (NÃO dá pra chegar a pé)" % nome)

	tm.free()
	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

## Mesma regra do jogo: água é passável pra quem surfa (TrainerEntity.
## _is_tile_walkable + WorldManager.is_water_tile, inclusive os tiles de
## BEIRA, que são água pra toda regra do jogo).
func _alcanca_surfando(tm: TileMap, de: Vector2i, para: Vector2i, teto: int = 3000000) -> bool:
	var agua : Vector2i = MapLayouts.CHAR_MAP["~"]
	var fila : Array[Vector2i] = [de]
	var vistos := {de: true}
	var visitados := 0
	while not fila.is_empty() and visitados < teto:
		var atual : Vector2i = fila.pop_front()
		visitados += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v : Vector2i = atual + d
			if vistos.has(v):
				continue
			if v == para:
				return true
			if tm.get_cell_source_id(0, v) == -1:
				continue
			var co := tm.get_cell_atlas_coords(0, v)
			if not (co == agua or co in MapLayouts.COSTA_ATLAS):
				var td : TileData = tm.get_cell_tile_data(0, v)
				if td == null or td.get_custom_data("blocked"):
					continue
			vistos[v] = true
			fila.append(v)
	return false

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
