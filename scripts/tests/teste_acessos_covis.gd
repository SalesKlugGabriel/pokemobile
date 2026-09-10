## teste_acessos_covis.gd — 10/09. Os três covis lendários são alcançáveis
## DE VERDADE, da superfície até o ninho?
##
## 🔴 Por que existe: os 33 andares dos covis (Ilha Gélida/Articuno, Cratera
## do Vulcão/Moltres, Usina/Zapdos) estavam todos construídos, gerados,
## testados por `teste_covis_lendarios.gd` — e DOIS deles não tinham porta
## de entrada nenhuma. `Cratera_B1` e `Usina_S1` só eram citados pelo
## andar seguinte da própria cadeia; ninguém no mundo apontava pra eles.
## Um covil de 10 andares perfeito que o jogador nunca alcança não é
## conteúdo difícil, é conteúdo invisível — e nenhum teste pegava isso,
## porque cada peça sozinha estava certa.
##
## Este teste percorre a CADEIA INTEIRA, começando na superfície: entrada →
## andar 1 → ... → ninho. Se um elo sumir, ou uma porta apontar pra um
## tile onde não dá pra pisar, ele reprova.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

## Cada covil: onde a porta de superfície mora, e a sequência esperada de
## cenas até o ninho.
const COVIS := {
	"Articuno (Ilha Gélida)": {
		"superficie": "res://scenes/world/maps/WorldMap.tscn",
		"cadeia": [
			"IlhaGelida_Entrada", "IlhaGelida_Vestibulo",
			"IlhaGelida_F1", "IlhaGelida_F2", "IlhaGelida_F3", "IlhaGelida_F4",
			"IlhaGelida_F5", "IlhaGelida_F6", "IlhaGelida_F7", "IlhaGelida_F8",
			"IlhaGelida_F9", "IlhaGelida_F10",
			"IlhaGelida_B1", "IlhaGelida_B2", "IlhaGelida_B3", "IlhaGelida_B4",
			"IlhaGelida_B5",
		],
		"ninho": "ilha_gelida_b5",
	},
	"Moltres (Cratera do Vulcão)": {
		"superficie": "res://scenes/world/maps/CinnabarIsland.tscn",
		"cadeia": [
			"Cratera_B1", "Cratera_B2", "Cratera_B3", "Cratera_B4", "Cratera_B5",
			"Cratera_B6", "Cratera_B7", "Cratera_B8", "Cratera_B9", "Cratera_B10",
		],
		"ninho": "cratera_b10",
	},
	"Zapdos (Usina)": {
		"superficie": "res://scenes/world/maps/WorldMap.tscn",
		"cadeia": [
			"Usina_S1", "Usina_S2", "Usina_S3", "Usina_S4", "Usina_S5", "Usina_S6",
		],
		"ninho": "usina_s6",
	},
}

func _initialize() -> void:
	print("=== Teste: os 3 covis lendários têm porta de entrada de verdade (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	for nome in COVIS:
		var covil : Dictionary = COVIS[nome]
		print("\n-- %s --" % nome)
		_checar_covil(nome, covil)

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _checar_covil(nome: String, covil: Dictionary) -> void:
	var cadeia : Array = covil["cadeia"]
	var primeiro : String = "res://scenes/world/dungeons/%s.tscn" % cadeia[0]

	# ---- 1. A SUPERFÍCIE aponta pro primeiro andar (a porta que faltava) ----
	var cena_sup : PackedScene = load(covil["superficie"])
	_assert(cena_sup != null, "%s: a cena de superfície carrega" % nome)
	if cena_sup == null:
		return
	var sup = cena_sup.instantiate()
	root.add_child(sup)
	var entrada = null
	var warps = sup.get_node_or_null("WarpZones")
	if warps:
		for w in warps.get_children():
			if w.target_map == primeiro:
				entrada = w
				break
	_assert(entrada != null,
		"%s: existe warp na superfície apontando pro %s" % [nome, cadeia[0]])

	# A porta tem que estar num tile que o jogador consegue pisar. Conferido
	# no TileMap PINTADO, não na grade de texto: o world_map tem ramos em
	# linha/coluna NEGATIVA (Rota 24/25 → Ilha Gélida, Rota 22 → Liga), que
	# só existem depois da pintura — ler `layout["tiles"]` daria vazio ali.
	if entrada != null:
		var tm := _tilemap_pintado(String(sup.map_id))
		var t := Vector2i(int(entrada.position.x / 128), int(entrada.position.y / 128))
		var td : TileData = tm.get_cell_tile_data(0, t)
		_assert(td != null and not td.get_custom_data("blocked"),
			"%s: a porta de superfície está num tile pisável (%s)" % [nome, t])
	sup.queue_free()

	# ---- 2. A CADEIA inteira: cada andar existe, aponta pro próximo E
	# tem volta pro anterior ----
	for i in cadeia.size():
		var atual : String = cadeia[i]
		var caminho : String = "res://scenes/world/dungeons/%s.tscn" % atual
		var cena : PackedScene = load(caminho)
		_assert(cena != null, "%s: %s existe e carrega" % [nome, atual])
		if cena == null:
			continue
		var inst = cena.instantiate()
		root.add_child(inst)

		var alvos : Array[String] = []
		var wz = inst.get_node_or_null("WarpZones")
		if wz:
			for w in wz.get_children():
				alvos.append(String(w.target_map))

		# aponta pro próximo andar?
		if i + 1 < cadeia.size():
			var proximo : String = "res://scenes/world/dungeons/%s.tscn" % cadeia[i + 1]
			_assert(proximo in alvos, "%s: %s desce/sobe pro %s" % [nome, atual, cadeia[i + 1]])
		else:
			# último andar = ninho: NÃO pode ter saída pra frente
			_assert(inst.map_id == covil["ninho"],
				"%s: o último andar é o ninho registrado (%s)" % [nome, covil["ninho"]])
			_assert(CovisLendarios.NINHOS.has(inst.map_id),
				"%s: o ninho está na tabela de lendários (CovisLendarios.NINHOS)" % nome)
			_assert(inst.get_node_or_null("SpawnManager") != null,
				"%s: o ninho tem SpawnManager (o lendário precisa dele pra nascer)" % nome)
			_assert(inst.get_node_or_null("TileMap") != null,
				"%s: o ninho tem TileMap (o lendário precisa de chão pra nascer)" % nome)

		# tem volta? (o 1º volta pra superfície; os demais, pro andar anterior)
		var anterior : String = covil["superficie"] if i == 0 \
			else "res://scenes/world/dungeons/%s.tscn" % cadeia[i - 1]
		_assert(anterior in alvos, "%s: %s tem volta pro passo anterior" % [nome, atual])

		inst.queue_free()

## Pinta um mapa uma vez só e guarda — o world_map aparece em 2 covis
## (Articuno e Zapdos) e Cinnabar é grande; repintar por covil seria puro
## desperdício de tempo de suíte.
var _pintados := {}

func _tilemap_pintado(map_id: String) -> TileMap:
	if _pintados.has(map_id):
		return _pintados[map_id]
	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tm, map_id)
	_pintados[map_id] = tm
	return tm

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
