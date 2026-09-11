## teste_subsolos_cavernas.gd — 10/09. Os subsolos de Mt Moon e Rock Tunnel.
##
## Este teste existe por causa de um achado específico da auditoria da
## reestruturação geográfica (`docs/mundo-novo-escala.md`, seção 5, item 4):
## havia 5 cenas `MtMoon_B1..B3` / `RockTunnel_B1..B2` que eram CASCAS
## VAZIAS — cena montada, TileMap sem nada dentro, nenhum warp de volta.
## Elas foram apagadas na Fase 2 justamente por isso.
##
## Então o que este arquivo prova não é "o andar existe": é que ele NÃO É
## CASCA. Em ordem:
##   1. o andar gera piso de verdade (não uma grade toda de rocha);
##   2. dá pra ir de qualquer escada a qualquer outra A PÉ (quem desce
##      consegue subir — andar de subsolo não pode depender de sorte de
##      sorteio, e por isso o gerador fecha o que faltou com um corredor);
##   3. o warp de ida e o de volta se apontam, e o tile de chegada de cada
##      um é andável no mapa de destino (o jeito clássico de nascer preso
##      dentro da pedra);
##   4. a zona de spawn existe — andar sem fauna é corredor decorativo;
##   5. o Rock Tunnel B1 é um SEGUNDO TRAJETO pela caverna (as duas
##      escadas caem longe uma da outra lá em cima) e tem bicho que o
##      andar de cima não tem — o motivo dele existir.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["I", "D", "P", ".", ":"]

func _initialize() -> void:
	print("=== Teste: subsolos de Mt Moon e Rock Tunnel (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- 1. Os três andares geram piso de verdade ----
	var dims := {
		"mtmoon_b1": Vector2i(30, 40),
		"mtmoon_b2": Vector2i(26, 26),
		"rocktunnel_b1": Vector2i(36, 30),
	}
	var tiles_de := {}
	for id in dims:
		var l : Dictionary = MapLayouts.get_layout(id)
		var esperado : Vector2i = dims[id]
		_assert(int(l.get("width", 0)) == esperado.x and int(l.get("height", 0)) == esperado.y,
			"%s gera %dx%d" % [id, esperado.x, esperado.y])
		var t : Array = l.get("tiles", [])
		tiles_de[id] = t
		var andaveis := _conta_andavel(t)
		_assert(andaveis > 120,
			"%s tem piso escavado de verdade, não é grade de rocha (%d tiles andáveis)" % [id, andaveis])

	# ---- 2. Escada alcança escada, a pé, em todo andar ----
	for id in MapLayouts.SUBSOLOS:
		var cfg : Dictionary = MapLayouts.SUBSOLOS[id]
		var t : Array = tiles_de[id]
		var escadas : Array = cfg["escadas"]
		for e in escadas:
			_assert(String(t[e.y])[e.x] in ANDAVEL,
				"%s: a escada %s é tile andável (não ficou emparedada por um ramo)" % [id, e])
		for i in range(1, escadas.size()):
			_assert(_liga(t, escadas[0], escadas[i]),
				"%s: dá pra ir da escada %s até a %s a pé" % [id, escadas[0], escadas[i]])
		if bool(cfg.get("camara", false)):
			var centro := Vector2i(int(cfg["w"]) / 2, int(cfg["h"]) / 2 - 2)
			_assert(String(t[centro.y])[centro.x] in ANDAVEL,
				"%s: o centro da Câmara da Pedra da Lua é chão livre" % id)
			_assert(_liga(t, escadas[0], centro),
				"%s: a escada alcança a Câmara (o prêmio do andar não está emparedado)" % id)

	# ---- 3. Ida e volta: cada warp cai num tile andável do destino ----
	var mapa_de_cena := {
		"res://scenes/world/dungeons/MtMoon_B1.tscn": "mtmoon_b1",
		"res://scenes/world/dungeons/MtMoon_B2.tscn": "mtmoon_b2",
		"res://scenes/world/dungeons/RockTunnel_B1.tscn": "rocktunnel_b1",
		"res://scenes/world/maps/MtMoon.tscn": "mt_moon",
		"res://scenes/world/maps/RockTunnel.tscn": "rock_tunnel",
	}
	for caminho in mapa_de_cena:
		if not tiles_de.has(mapa_de_cena[caminho]):
			tiles_de[mapa_de_cena[caminho]] = MapLayouts.get_layout(mapa_de_cena[caminho]).get("tiles", [])

	var esperados := {
		"res://scenes/world/dungeons/MtMoon_B1.tscn": ["SubirF1", "DescerB2"],
		"res://scenes/world/dungeons/MtMoon_B2.tscn": ["SubirB1"],
		"res://scenes/world/dungeons/RockTunnel_B1.tscn": ["SubirSul", "SubirNorte"],
		"res://scenes/world/maps/MtMoon.tscn": ["DescerB1"],
		"res://scenes/world/maps/RockTunnel.tscn": ["DescerSul", "DescerNorte"],
	}
	for caminho in esperados:
		var cena : PackedScene = load(caminho)
		_assert(cena != null, "%s carrega" % caminho.get_file())
		if cena == null:
			continue
		var inst = cena.instantiate()
		var wz = inst.get_node_or_null("WarpZones")
		for nome in esperados[caminho]:
			var w = wz.get_node_or_null(nome) if wz else null
			_assert(w != null, "%s: warp '%s' existe" % [caminho.get_file(), nome])
			if w == null:
				continue
			var destino : String = String(w.target_map)
			_assert(mapa_de_cena.has(destino),
				"%s/%s aponta pra um dos 5 mapas desta cadeia (%s)" % [caminho.get_file(), nome, destino])
			if mapa_de_cena.has(destino):
				var td : Array = tiles_de[mapa_de_cena[destino]]
				var st : Vector2i = w.spawn_tile
				_assert(st.y >= 0 and st.y < td.size() and String(td[st.y])[st.x] in ANDAVEL,
					"%s/%s: o tile de chegada %s é andável no destino (ninguém nasce dentro da pedra)" % [caminho.get_file(), nome, st])
		inst.queue_free()

	# ---- 4. Fauna: cada andar tem zona de spawn própria ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var fauna := {}
	for z in zj.get("zones", []):
		var mid := String(z.get("map_id", ""))
		if mid in ["mtmoon_b1", "mtmoon_b2", "rocktunnel_b1"]:
			fauna[mid] = z.get("wild_pokemon", [])
	for id in dims:
		_assert(fauna.has(id) and not fauna[id].is_empty(),
			"%s tem fauna em zones.json (andar sem bicho é corredor decorativo)" % id)
	if fauna.has("mtmoon_b2"):
		var ids : Array = []
		for m in fauna["mtmoon_b2"]:
			ids.append(int(m.get("id", 0)))
		_assert(35 in ids and 36 in ids,
			"Câmara da Pedra da Lua tem Clefairy E Clefable — é o motivo do andar existir")

	# ---- 5. Rock Tunnel B1 é um SEGUNDO TRAJETO, não uma porta ao lado de si
	# mesma — e tem bicho que o andar de cima não tem ----
	#
	# 🔴 A primeira versão deste teste exigia que o caminho por baixo fosse
	# MAIS CURTO (a ideia era vender o B1 como atalho). Ele não é: 35 passos
	# por baixo contra 30 por cima. O Rock Tunnel de cima é pequeno demais
	# pra ter atalho — o diâmetro inteiro dele é 35 passos. Em vez de
	# empurrar o gerador até o número fechar, a afirmação foi trocada pela
	# que os números sustentam.
	var t_rt : Array = tiles_de["rock_tunnel"]
	var t_b1 : Array = tiles_de["rocktunnel_b1"]
	var entre_bocas := _distancia(t_rt, Vector2i(19, 33), Vector2i(14, 14))
	var por_baixo := _distancia(t_b1, Vector2i(18, 26), Vector2i(6, 3))
	_assert(por_baixo > 0, "dá pra atravessar o B1 de uma escada à outra (%d passos)" % por_baixo)
	_assert(entre_bocas > 25,
		"as duas escadas caem em pontos REALMENTE distantes do andar de cima (%d passos entre elas) — é um segundo trajeto, não uma porta ao lado de si mesma" % entre_bocas)

	var especies_cima : Array = []
	var especies_baixo : Array = []
	for z in zj.get("zones", []):
		if String(z.get("map_id", "")) == "rock_tunnel":
			for w in z.get("wild_pokemon", []):
				especies_cima.append(int(w.get("id", 0)))
		if String(z.get("map_id", "")) == "rocktunnel_b1":
			for w in z.get("wild_pokemon", []):
				especies_baixo.append(int(w.get("id", 0)))
	_assert(66 in especies_baixo and not (66 in especies_cima),
		"Machop só existe no B1 — é a razão de descer (o andar de cima não tem)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _conta_andavel(tiles: Array) -> int:
	var n := 0
	for r in tiles.size():
		var linha := String(tiles[r])
		for c in linha.length():
			if linha[c] in ANDAVEL:
				n += 1
	return n

func _liga(tiles: Array, de: Vector2i, para: Vector2i) -> bool:
	return _distancia(tiles, de, para) >= 0

## Busca em largura na grade de caracteres — devolve o número de passos, ou
## -1 se não há caminho. Feita aqui em vez de `AjudaMapa.caminho_a_pe`
## porque esta precisa da DISTÂNCIA (o item 5 compara dois trajetos), não só
## de um sim/não.
func _distancia(tiles: Array, de: Vector2i, para: Vector2i) -> int:
	if tiles.is_empty():
		return -1
	var H := tiles.size()
	var W := String(tiles[0]).length()
	var fila : Array[Vector2i] = [de]
	var dist := {de: 0}
	while not fila.is_empty():
		var atual : Vector2i = fila.pop_front()
		if atual == para:
			return int(dist[atual])
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n : Vector2i = atual + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or dist.has(n):
				continue
			if not (String(tiles[n.y])[n.x] in ANDAVEL):
				continue
			dist[n] = int(dist[atual]) + 1
			fila.append(n)
	return -1

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
