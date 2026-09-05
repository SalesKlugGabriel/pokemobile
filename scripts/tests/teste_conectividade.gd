## teste_conectividade.gd — Dá pra chegar em todo lugar? (Fase 0, 05/09)
##
## É a rede de segurança das Fases 3 a 5 do plano de mundo. Quando a costa for
## reondulada, os biomas entrarem e as cidades forem encaixadas no contorno
## novo, o pior acidente possível não é um tile feio: é uma cidade ficar ilhada
## atrás de uma parede de mata ou de um braço de mar, e ninguém perceber até um
## jogador tentar chegar lá — depois de já ter jogado duas horas.
##
## Nenhum teste que existia pegava isso. Todos conferem tile a tile; nenhum
## perguntava "existe caminho". Este pergunta, com a MESMA regra de colisão do
## jogo (`blocked` no TileSet), partindo de Pallet Town.
##
## O que ele NÃO exige: que dê pra chegar a pé em tudo. Cinnabar, Seafoam e as
## ilhas são de Surf por design, e a Liga Indigo é trancada por insígnia. Essas
## estão listadas com o motivo — uma exceção sem motivo escrito viraria um bug
## silencioso disfarçado de decisão.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_conectividade.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

## Cidades que TÊM que ser alcançáveis a pé desde Pallet.
const A_PE : Array[String] = [
	"viridian_city", "pewter_city", "cerulean_city", "saffron_city",
	"vermilion_city", "celadon_city", "lavender_town", "fuchsia_city",
]

## Alcançáveis só por mar ou por trava de progressão — com o motivo.
const NAO_A_PE := {
	"cinnabar_island": "ilha: só de Surf ou pelo barco",
	"indigo_plateau":  "trancada até as 8 insígnias",
	"seafoam_islands": "ilhas: só de Surf",
}

## Autoload não é identificador em teste headless (convenção do projeto).
var GameData : Node

func _initialize() -> void:
	print("=== Teste: dá pra chegar em todo lugar? (05/09) ===")
	GameData = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
	MapLayouts.paint(tm, "world_map")

	var r_pallet := AjudaMapa.retangulo_da_zona("pallet_town")
	var origem := AjudaMapa.tile_andavel_da_zona(tm, r_pallet)
	_assert(origem.x != -9999, "Pallet Town tem chão andável pra sair (origem %s)" % origem)

	# ---- 1. Toda cidade de terra firme é alcançável a pé desde Pallet -----
	var ilhadas : Array[String] = []
	for zona in A_PE:
		var ret := AjudaMapa.retangulo_da_zona(zona)
		if ret.size.x <= 0:
			ilhadas.append("%s (sem retângulo no zones.json)" % zona)
			continue
		var destino := AjudaMapa.tile_andavel_da_zona(tm, ret)
		if destino.x == -9999:
			ilhadas.append("%s (nenhum tile andável dentro dela)" % zona)
			continue
		if not AjudaMapa.caminho_a_pe(tm, origem, destino):
			ilhadas.append("%s (sem caminho a pé desde Pallet)" % zona)
	_assert(ilhadas.is_empty(), "as 8 cidades de terra firme são alcançáveis a pé — %s" % (
		"ok" if ilhadas.is_empty() else str(ilhadas)))

	# ---- 2. As de mar/trava têm chão andável (existem de verdade) --------
	# Não dá pra exigir caminho a pé nelas, mas dá pra exigir que existam:
	# uma ilha sem um único tile pisável seria inalcançável até de Surf.
	var vazias : Array[String] = []
	for zona in NAO_A_PE:
		var ret := AjudaMapa.retangulo_da_zona(str(zona))
		if ret.size.x <= 0:
			continue     # zona que ainda não existe no jogo — não é falha
		if AjudaMapa.tile_andavel_da_zona(tm, ret).x == -9999:
			vazias.append("%s — %s" % [zona, NAO_A_PE[zona]])
	_assert(vazias.is_empty(), "toda ilha/área trancada tem chão pra pisar quando se chega nela — %s" % (
		"ok" if vazias.is_empty() else str(vazias)))

	# ---- 3. O objetivo da primeira quest é alcançável --------------------
	# Se o jogo manda a criança falar com o Prof. Carvalho, tem que dar pra
	# chegar nele andando. Parece óbvio; é exatamente o tipo de coisa que
	# quebra quando o mapa muda e ninguém confere.
	var quest : Dictionary = GameData.get_quest("MAIN-01")
	var local : Dictionary = quest.get("location_tile", {})
	if local.has("x"):
		var alvo := Vector2i(int(local["x"]), int(local["y"]))
		var perto := _tile_andavel_perto(tm, alvo, 6)
		_assert(perto.x != -9999, "o objetivo da 1ª quest tem chão andável em volta")
		if perto.x != -9999:
			_assert(AjudaMapa.caminho_a_pe(tm, origem, perto),
				"dá pra chegar a pé no objetivo da primeira quest (%s)" % alvo)

	# ---- 4. Conferência do próprio detector ------------------------------
	# Um teste de conectividade que só sabe dizer "sim" é um teste que sempre
	# passa. Aqui ele tem que dizer NÃO pra um ponto no meio do oceano: se
	# disser sim, a busca está atravessando parede e as conferências acima não
	# valem nada.
	var no_mar := Vector2i(r_pallet.position.x + 40, r_pallet.position.y + 60)
	var e_agua : bool = tm.get_cell_atlas_coords(0, no_mar) == MapLayouts.CHAR_MAP["~"]
	_assert(e_agua, "o ponto de controle %s é mesmo mar" % no_mar)
	_assert(not AjudaMapa.caminho_a_pe(tm, origem, no_mar, 60000),
		"o detector sabe dizer NÃO: não existe caminho a pé até o meio do mar")

	tm.free()
	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

## Tile andável mais próximo de um alvo — o alvo pode ser a própria porta ou um
## NPC, que não são posições pisáveis.
func _tile_andavel_perto(tm: TileMap, alvo: Vector2i, raio: int) -> Vector2i:
	for r in range(raio + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := Vector2i(alvo.x + dx, alvo.y + dy)
				if tm.get_cell_source_id(0, c) == -1:
					continue
				var td : TileData = tm.get_cell_tile_data(0, c)
				if td != null and not td.get_custom_data("blocked"):
					return c
	return Vector2i(-9999, -9999)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
