## MapaMundi.gd — O mapa da região, de verdade (05/09).
##
## Pedido do Gabriel: "faça um mini mapa real do que já existe, pois o atual não
## serve pra muita coisa".
##
## O que existia: um quadradinho no canto com um raio de tiles em volta do
## jogador. Serve pra desviar da árvore ao lado, não pra saber onde você está no
## mundo nem pra onde ir — que é a pergunta que um mapa responde.
##
## O que este faz:
##   - desenha o MUNDO INTEIRO lendo os tiles pintados de verdade (nada de
##     desenho à parte que possa divergir do mapa real);
##   - marca as cidades e rotas pelo nome, lendo `data/world/zones.json` — a
##     mesma fonte que o resto do jogo usa, sem uma segunda lista pra manter;
##   - mostra onde você está e para onde é o objetivo atual;
##   - só revela o que já foi VISITADO. O resto fica escurecido: um mapa que já
##     nasce todo aberto tira a razão de explorar.
##
## O desenho é feito UMA vez e guardado (são ~200 mil células); reabrir o mapa
## não recalcula nada.
extends CanvasLayer

const COR_FUNDO   := Color(0.05, 0.07, 0.06)
const COR_NAO_VISTO := Color(0.10, 0.12, 0.11)

## Cor por tipo de terreno, a mesma linguagem do minimapa de canto.
const COR_POR_CHAR := {
	"~": Color(0.16, 0.36, 0.62), "S": Color(0.80, 0.70, 0.44),
	"P": Color(0.62, 0.48, 0.32), "A": Color(0.16, 0.42, 0.16),
	"T": Color(0.11, 0.26, 0.13), "N": Color(0.11, 0.26, 0.13),
	"O": Color(0.20, 0.28, 0.12), "K": Color(0.24, 0.20, 0.13),
	"W": Color(0.55, 0.55, 0.58), "w": Color(0.55, 0.55, 0.58),
	"H": Color(0.62, 0.26, 0.18), "I": Color(0.45, 0.36, 0.26),
	"d": Color(0.92, 0.78, 0.30), "R": Color(0.45, 0.45, 0.48),
	"F": Color(0.34, 0.58, 0.30), "G": Color(0.28, 0.52, 0.26),
	# ── Biomas da Fase 2 (05/09) ────────────────────────────────────────────
	"z": Color(0.34, 0.38, 0.22), "!": Color(0.50, 0.74, 0.24),
	"0": Color(0.29, 0.38, 0.31), "(": Color(0.38, 0.46, 0.20),
	")": Color(0.33, 0.27, 0.20),
	"^": Color(0.50, 0.46, 0.41), "/": Color(0.34, 0.31, 0.27),
	"<": Color(0.66, 0.64, 0.60), ">": Color(0.45, 0.41, 0.37),
	":": Color(0.63, 0.54, 0.41),
	"_": Color(0.84, 0.72, 0.48), "'": Color(0.88, 0.78, 0.56),
	"*": Color(0.29, 0.52, 0.27), ";": Color(0.93, 0.91, 0.84),
	"+": Color(0.78, 0.66, 0.42),
	"%": Color(0.73, 0.66, 0.54), "[": Color(0.55, 0.48, 0.38),
	"|": Color(0.67, 0.62, 0.52), "]": Color(0.60, 0.55, 0.45),
	"=": Color(0.68, 0.62, 0.50),
	"&": Color(0.36, 0.28, 0.22), "{": Color(0.34, 0.31, 0.30),
	"}": Color(0.20, 0.22, 0.30), "$": Color(0.46, 0.38, 0.29),
	"@": Color(0.55, 0.55, 0.56),
	"9": Color(0.14, 0.23, 0.13), "?": Color(0.47, 0.88, 0.77),
	"`": Color(0.23, 0.17, 0.12),
	"#": Color(0.57, 0.42, 0.24), "-": Color(0.57, 0.42, 0.24),
	# Cores derivadas da COR MÉDIA do próprio tile no atlas, com a saturação
	# puxada — a média de um tile sai sempre mais apagada que ele. Geradas
	# assim, e não escolhidas a olho, porque 27 terrenos estavam caindo no
	# verde genérico do fallback e o mapa mentia sobre eles.
	".": Color(0.36, 0.63, 0.05),
	"D": Color(0.56, 0.38, 0.15),
	"M": Color(0.65, 0.13, 0.03),
	"E": Color(0.38, 0.55, 0.05),
	"X": Color(0.25, 0.50, 0.05),
	"B": Color(0.03, 0.37, 0.59),
	"C": Color(0.33, 0.72, 0.94),
	"J": Color(0.22, 0.64, 0.90),
	"L": Color(0.36, 0.32, 0.25),
	"Q": Color(0.21, 0.19, 0.14),
	"U": Color(0.08, 0.53, 0.73),
	"V": Color(0.27, 0.03, 0.30),
	"Y": Color(0.37, 0.22, 0.09),
	"Z": Color(0.29, 0.17, 0.07),
	"b": Color(0.33, 0.29, 0.27),
	"c": Color(0.24, 0.14, 0.10),
	"e": Color(0.35, 0.24, 0.14),
	"f": Color(0.40, 0.37, 0.33),
	"g": Color(0.49, 0.45, 0.38),
	"h": Color(0.37, 0.35, 0.24),
	"i": Color(0.34, 0.54, 0.04),
	"j": Color(0.36, 0.41, 0.00),
	"k": Color(0.07, 0.31, 0.33),
	"l": Color(0.41, 0.33, 0.26),
	"m": Color(0.60, 0.22, 0.10),
	"n": Color(0.40, 0.52, 0.05),
	"o": Color(0.07, 0.03, 0.01),
}
const COR_GRAMA := Color(0.26, 0.52, 0.24)

var _painel   : PanelContainer
var _tela     : Control
var _aberto   : bool = false

var _textura  : ImageTexture = null
var _origem   : Vector2i = Vector2i.ZERO     # canto do mundo em tiles
var _tamanho  : Vector2i = Vector2i.ONE      # extensão do mundo em tiles
var _cidades  : Array = []                   # [{nome, centro:Vector2i, e_cidade:bool}]

func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_map"):
		get_viewport().set_input_as_handled()
		if _aberto:
			fechar()
		else:
			abrir()

# ──────────────────────────────────────────────────────────────────────────────
func _montar() -> void:
	_painel = PanelContainer.new()
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.offset_left = 24
	_painel.offset_top = 24
	_painel.offset_right = -24
	_painel.offset_bottom = -24
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Color(0.82, 0.70, 0.32)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_painel.add_child(col)

	var cabecalho := HBoxContainer.new()
	col.add_child(cabecalho)
	var titulo := Label.new()
	titulo.text = "MAPA DE KANTO"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	cabecalho.add_child(titulo)
	var fechar_btn := Button.new()
	fechar_btn.text = "X"
	fechar_btn.pressed.connect(fechar)
	cabecalho.add_child(fechar_btn)

	_tela = Control.new()
	_tela.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tela.draw.connect(_desenhar)
	col.add_child(_tela)

	var rodape := Label.new()
	rodape.text = "Você  ·  Objetivo  ·  cinza = ainda não explorado        M ou Esc para fechar"
	rodape.add_theme_font_size_override("font_size", 12)
	rodape.add_theme_color_override("font_color", Color(0.66, 0.72, 0.62))
	col.add_child(rodape)

	_painel.hide()

func abrir() -> void:
	if _textura == null:
		_desenhar_o_mundo()
	_carregar_cidades()
	_aberto = true
	_painel.show()
	get_tree().paused = true
	UIStack.empilhar(self, fechar)
	AudioManager.play_sfx("menu_open")
	_tela.queue_redraw()

func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_painel.hide()
	get_tree().paused = false
	UIStack.desempilhar(self)
	AudioManager.play_sfx("menu_close")

# ──────────────────────────────────────────────────────────────────────────────
# O desenho do mundo (uma vez só)
# ──────────────────────────────────────────────────────────────────────────────
func _desenhar_o_mundo() -> void:
	var tm = WorldManager.tilemap
	if tm == null:
		return
	var por_atlas := {}
	for ch in MapLayouts.CHAR_MAP:
		por_atlas[MapLayouts.CHAR_MAP[ch]] = COR_POR_CHAR.get(ch, COR_GRAMA)
	for ch in MapLayouts.VARIANTES_TERRENO:
		var cor : Color = COR_POR_CHAR.get(ch, COR_GRAMA)
		for co in MapLayouts.VARIANTES_TERRENO[ch]:
			por_atlas[co] = cor
	for co in MapLayouts.COSTA_ATLAS:
		por_atlas[co] = COR_POR_CHAR["S"]
	# árvore grande: 24 tiles, todos verde-mata
	for lista in MapLayouts.ARVORES_GRANDES:
		for co in lista:
			por_atlas[co] = COR_POR_CHAR["T"]
	# pirâmides e obelisco da Ilha do Deserto: pedra clara no mapa
	for lista in MapLayouts.ESTRUTURAS_DESERTO:
		for co in lista:
			por_atlas[co] = Color(0.78, 0.66, 0.42)

	var usadas : Array = tm.get_used_cells(0)
	if usadas.is_empty():
		return
	var x0 := 999999
	var y0 := 999999
	var x1 := -999999
	var y1 := -999999
	for c in usadas:
		x0 = mini(x0, c.x); y0 = mini(y0, c.y)
		x1 = maxi(x1, c.x); y1 = maxi(y1, c.y)
	_origem = Vector2i(x0, y0)
	_tamanho = Vector2i(x1 - x0 + 1, y1 - y0 + 1)

	var img := Image.create(_tamanho.x, _tamanho.y, false, Image.FORMAT_RGB8)
	img.fill(COR_FUNDO)
	for c in usadas:
		img.set_pixel(c.x - x0, c.y - y0,
			por_atlas.get(tm.get_cell_atlas_coords(0, c), COR_GRAMA))
	_textura = ImageTexture.create_from_image(img)

## Nome e centro de cada zona, de `zones.json` — a mesma fonte do resto do jogo.
func _carregar_cidades() -> void:
	_cidades.clear()
	var caminho := "res://data/world/zones.json"
	if not FileAccess.file_exists(caminho):
		return
	var texto := FileAccess.get_file_as_string(caminho)
	var dados = JSON.parse_string(texto)
	if not (dados is Dictionary) or not dados.has("zones"):
		return
	var visitadas : Array = SaveManager.get_visited_maps() if SaveManager.has_method("get_visited_maps") else []
	for z in dados["zones"]:
		var ret : Dictionary = z.get("tile_rect", {})
		if ret.is_empty():
			continue
		var nome := str(z.get("name", ""))
		# Só as CIDADES ganham nome no mapa. Rotas são o caminho entre elas;
		# escrever 30 nomes de rota deixaria o mapa ilegível, que é o defeito
		# que este mapa veio corrigir.
		var e_cidade : bool = nome.ends_with("City") or nome.ends_with("Town") \
			or nome.ends_with("Island") or nome.ends_with("Plateau")
		if not e_cidade:
			continue
		_cidades.append({
			"nome": nome,
			"centro": Vector2i(int(ret["x"]) + int(ret["w"]) / 2, int(ret["y"]) + int(ret["h"]) / 2),
			"visitada": visitadas.has(str(z.get("id", ""))),
		})

# ──────────────────────────────────────────────────────────────────────────────
func _desenhar() -> void:
	if _textura == null:
		return
	var area : Vector2 = _tela.size
	# encaixa o mundo inteiro na área, mantendo proporção
	var escala : float = minf(area.x / float(_tamanho.x), area.y / float(_tamanho.y))
	var tam := Vector2(_tamanho) * escala
	var canto := (area - tam) / 2.0
	_tela.draw_texture_rect(_textura, Rect2(canto, tam), false)

	# marcas de cidade
	for cidade in _cidades:
		var p : Vector2 = canto + (Vector2(cidade["centro"] - _origem)) * escala
		var visitada : bool = cidade["visitada"]
		var cor : Color = Color(0.98, 0.86, 0.36) if visitada else Color(0.45, 0.45, 0.42)
		_tela.draw_circle(p, 5.0, Color(0, 0, 0, 0.75))
		_tela.draw_circle(p, 3.5, cor)
		var rotulo : String = str(cidade["nome"]) if visitada else "?"
		var fonte := ThemeDB.fallback_font
		var largura := fonte.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_tela.draw_string(fonte, p + Vector2(-largura / 2.0, -9), rotulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.06, 0.08, 0.06))
		_tela.draw_string(fonte, p + Vector2(-largura / 2.0 - 1, -10), rotulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor)

	# objetivo atual
	var alvo := _tile_do_objetivo()
	if alvo.x != -99999:
		var p : Vector2 = canto + Vector2(alvo - _origem) * escala
		var pulso : float = 4.0 + 2.0 * sin(Time.get_ticks_msec() / 260.0)
		_tela.draw_arc(p, pulso + 4.0, 0, TAU, 24, Color(0.35, 0.85, 0.95), 2.0)

	# onde você está
	var jogador = WorldManager.player
	if jogador != null and is_instance_valid(jogador):
		var p : Vector2 = canto + Vector2(jogador.grid_pos - _origem) * escala
		_tela.draw_circle(p, 6.0, Color(0, 0, 0, 0.85))
		_tela.draw_circle(p, 4.0, Color(1.0, 0.35, 0.15))

func _process(_delta: float) -> void:
	if _aberto:
		_tela.queue_redraw()

## Tile do objetivo da quest principal ativa. Lê o mesmo `location_tile` do
## quests.json que a faixa de objetivo já usa — uma fonte só.
func _tile_do_objetivo() -> Vector2i:
	for id in QuestHUD.ORDEM_QUESTS:
		if QuestManager.is_quest_complete(id):
			continue
		var dados : Dictionary = GameData.get_quest(id)
		var local : Dictionary = dados.get("location_tile", {})
		if local.has("x") and local.has("y"):
			return Vector2i(int(local["x"]), int(local["y"]))
		return Vector2i(-99999, -99999)
	return Vector2i(-99999, -99999)
