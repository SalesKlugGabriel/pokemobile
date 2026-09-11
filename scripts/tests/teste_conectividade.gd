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

## Cidades alcançáveis a pé DIRETO no world_map (sem trocar de cena) — desde
## as Fases 1-5 da reestruturação geográfica (10/09), TODAS as cidades da
## espinha principal saíram desta lista: viram cadeia (ver
## `_alcancavel_via_rota` abaixo). Só sobram as áreas de Surf/trava de
## progressão (NAO_A_PE, abaixo) — nenhuma cidade de terra firme falta.
const A_PE : Array[String] = []

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

	# ---- 1a. Viridian e Pewter — alcançáveis por CADEIA de cena+warp, não
	# mais andando direto no world_map (10/09, Fase 1/2 da reestruturação
	# geográfica: a distância real de 1km/3km agora mora dentro de
	# RotaViridianPallet.tscn/RotaPewterViridian.tscn, cenas próprias). A
	# travessia DENTRO de cada rota já é provada, rigorosamente, pelos
	# testes dedicados delas (teste_rota_viridian_pallet.gd,
	# teste_rota_pewter_viridian.gd — inclusive a caverna não-linear da
	# montanha). Aqui só confere a PONTA: dá pra andar de dentro da cidade
	# até o tile onde o warp da rota fica plantado?
	var origem_viridian := _alcancavel_via_rota(tm, origem,
		"WarpRotaViridianPalletSul", "WarpRotaViridianPalletNorte", "viridian_city")
	_assert(origem_viridian.x != -9999,
		"Viridian alcançável por cadeia: Pallet → warp → RotaViridianPallet.tscn (provada à parte) → Viridian")

	var origem_pewter := Vector2i(-9999, -9999)
	if origem_viridian.x != -9999:
		origem_pewter = _alcancavel_via_rota(tm, origem_viridian,
			"WarpRotaPewterViridianSul", "WarpRotaPewterViridianNorte", "pewter_city")
	_assert(origem_pewter.x != -9999,
		"Pewter alcançável por cadeia: Viridian → warp → RotaPewterViridian.tscn (rota+caverna, provada à parte) → Pewter")

	# Cerulean — mesma cadeia, agora via RotaPewterCerulean.tscn (7km, com
	# Mt Moon retrofitada não-linear no meio — travessia obrigatória
	# provada à parte em teste_rota_pewter_cerulean.gd).
	var origem_cerulean := Vector2i(-9999, -9999)
	if origem_pewter.x != -9999:
		origem_cerulean = _alcancavel_via_rota(tm, origem_pewter,
			"WarpRotaPewterCeruleanOeste", "WarpRotaPewterCeruleanLeste", "cerulean_city")
	_assert(origem_cerulean.x != -9999,
		"Cerulean alcançável por cadeia: Pewter → warp → RotaPewterCerulean.tscn (rota+Mt Moon, provada à parte) → Cerulean")

	# Nó central de Saffron (Fase 3): Cerulean→Saffron, depois Saffron
	# ramifica pra Vermilion e Celadon. As 3 rotas novas são provadas à
	# parte em teste_no_central_saffron.gd.
	var origem_saffron := Vector2i(-9999, -9999)
	if origem_cerulean.x != -9999:
		origem_saffron = _alcancavel_via_rota(tm, origem_cerulean,
			"WarpRotaCeruleanSaffronNorte", "WarpRotaCeruleanSaffronSul", "saffron_city")
	_assert(origem_saffron.x != -9999,
		"Saffron alcançável por cadeia: Cerulean → warp → RotaCeruleanSaffron.tscn (provada à parte) → Saffron")

	var origem_vermilion := Vector2i(-9999, -9999)
	if origem_saffron.x != -9999:
		origem_vermilion = _alcancavel_via_rota(tm, origem_saffron,
			"WarpRotaSaffronVermilionNorte", "WarpRotaSaffronVermilionSul", "vermilion_city")
	_assert(origem_vermilion.x != -9999,
		"Vermilion alcançável por cadeia: Saffron → warp → RotaSaffronVermilion.tscn (provada à parte) → Vermilion")

	var origem_celadon := Vector2i(-9999, -9999)
	if origem_saffron.x != -9999:
		origem_celadon = _alcancavel_via_rota(tm, origem_saffron,
			"WarpRotaSaffronCeladonLeste", "WarpRotaSaffronCeladonOeste", "celadon_city")
	_assert(origem_celadon.x != -9999,
		"Celadon alcançável por cadeia: Saffron → warp → RotaSaffronCeladon.tscn (provada à parte) → Celadon")

	# Lavender (Fase 4): Saffron→Rota nova (Rock Tunnel é desvio opcional,
	# não faz parte da cadeia obrigatória — provado à parte em
	# teste_rota_saffron_lavender.gd).
	var origem_lavender := Vector2i(-9999, -9999)
	if origem_saffron.x != -9999:
		origem_lavender = _alcancavel_via_rota(tm, origem_saffron,
			"WarpRotaSaffronLavenderOeste", "WarpRotaSaffronLavenderLeste", "lavender_town")
	_assert(origem_lavender.x != -9999,
		"Lavender alcançável por cadeia: Saffron → warp → RotaSaffronLavender.tscn (provada à parte) → Lavender")

	# Fuchsia (Fase 5, a última da espinha principal): Lavender→Rota nova
	# (12km, a maior jornada do mapa — provada à parte em
	# teste_rota_lavender_fuchsia.gd).
	var origem_fuchsia := Vector2i(-9999, -9999)
	if origem_lavender.x != -9999:
		origem_fuchsia = _alcancavel_via_rota(tm, origem_lavender,
			"WarpRotaLavenderFuchsiaNorte", "WarpRotaLavenderFuchsiaSul", "fuchsia_city")
	_assert(origem_fuchsia.x != -9999,
		"Fuchsia alcançável por cadeia: Lavender → warp → RotaLavenderFuchsia.tscn (provada à parte) → Fuchsia")

	# ---- 1b. Não sobra nenhuma cidade de terra firme ligada direto no
	# world_map — a espinha principal inteira (Pallet até Fuchsia) agora é
	# cadeia (A_PE ficou vazia de propósito, ver comentário na constante).

	# ---- 2. As de mar/trava têm chão andável (existem de verdade) --------
	# Não dá pra exigir caminho a pé nelas, mas dá pra exigir que existam:
	# uma ilha sem um único tile pisável seria inalcançável até de Surf.
	var vazias : Array[String] = []
	# 🔴 10/09: a zona pode viver numa CENA PRÓPRIA (Cinnabar virou
	# 1.200x1.200 na Fase 6, com coordenada local). Procurar o chão dela no
	# TileMap do world_map dava "vazia" — não porque a ilha não tem chão,
	# mas porque a pergunta estava sendo feita no mapa errado. Cada zona é
	# conferida no mapa a que ela pertence.
	for zona in NAO_A_PE:
		var ret := AjudaMapa.retangulo_da_zona(str(zona))
		if ret.size.x <= 0:
			continue     # zona que ainda não existe no jogo — não é falha
		var mapa_da_zona := _map_id_da_zona(str(zona))
		var tm_zona : TileMap = tm
		if mapa_da_zona != "world_map":
			tm_zona = TileMap.new()
			tm_zona.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
			MapLayouts.paint(tm_zona, mapa_da_zona)
		if AjudaMapa.tile_andavel_da_zona(tm_zona, ret).x == -9999:
			vazias.append("%s — %s" % [zona, NAO_A_PE[zona]])
		if tm_zona != tm:
			tm_zona.free()
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

## Confere uma cadeia cidade→(warp)→rota (cena própria)→(warp)→cidade. A
## travessia DENTRO da rota já foi provada à parte, rigorosamente, pelo
## teste dedicado dela (inclusive a caverna, quando houver) — aqui só
## confere as duas pontas: dá pra andar da origem até o tile do warp de
## saída, e o warp de chegada encosta de verdade no resto da cidade de
## destino? Devolve um tile andável da cidade de destino (pra virar a
## próxima origem da cadeia) ou (-9999,-9999) se qualquer ponta falhar.
func _alcancavel_via_rota(tm: TileMap, origem: Vector2i, nome_warp_saida: String,
		nome_warp_entrada: String, zona_destino: String) -> Vector2i:
	var falha := Vector2i(-9999, -9999)
	var wm_cena := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	var wm := wm_cena.instantiate()
	root.add_child(wm)

	var warp_saida = wm.get_node_or_null("WarpZones/%s" % nome_warp_saida)
	if warp_saida == null:
		wm.queue_free()
		return falha
	var tile_saida := Vector2i(int(warp_saida.position.x / 128), int(warp_saida.position.y / 128))
	if not AjudaMapa.caminho_a_pe(tm, origem, tile_saida):
		wm.queue_free()
		return falha

	var warp_entrada = wm.get_node_or_null("WarpZones/%s" % nome_warp_entrada)
	if warp_entrada == null:
		wm.queue_free()
		return falha
	var tile_entrada := Vector2i(int(warp_entrada.position.x / 128), int(warp_entrada.position.y / 128))
	wm.queue_free()

	var ret_destino := AjudaMapa.retangulo_da_zona(zona_destino)
	var destino := AjudaMapa.tile_andavel_da_zona(tm, ret_destino)
	if destino.x == -9999:
		return falha
	if not AjudaMapa.caminho_a_pe(tm, tile_entrada, destino):
		return falha
	return destino

## Em que mapa esta zona mora? (zones.json; sem `map_id` = world_map)
func _map_id_da_zona(zone_id: String) -> String:
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	for z in zj.get("zones", []):
		if String(z.get("id", "")) == zone_id:
			return String(z.get("map_id", "world_map"))
	return "world_map"

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
