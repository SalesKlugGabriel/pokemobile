## QuestHUD.gd — Faixa de OBJETIVO no alto da tela, com seta e distância.
##
## Reescrito em 04/09. O arquivo antigo existia mas nunca foi instanciado em
## cena nenhuma (achado no teste de gameplay: duas partidas inteiras sem nada
## dizer o que fazer), e ainda lia `quest_data["steps"]`, campo que não existe
## no quests.json — o JSON usa `objectives`. Ou seja: mesmo se alguém tivesse
## colocado a cena no mapa, a faixa apareceria vazia.
##
## O que ele faz agora, na ordem em que uma criança precisa:
##   1. QUAL é o objetivo, em uma frase;
##   2. PRA ONDE ir — seta apontando pro alvo e distância em passos.
## O item 2 é o que faltava de verdade: o mapa tem 29 prédios e nada dizia qual
## deles importa agora.
##
## Vive no GlobalUI (autoload), não em cada mapa — assim vale em todo lugar sem
## ninguém lembrar de arrastar a cena pra cada cena de mapa nova.
class_name QuestHUD
extends CanvasLayer

const ORDEM_QUESTS := ["MAIN-01", "MAIN-02", "MAIN-03", "MAIN-04", "MAIN-05",
	"MAIN-06", "MAIN-07", "MAIN-08", "MAIN-09", "MAIN-10"]

## Frase em português por objetivo. O quests.json guarda o objetivo em formato
## de máquina ("talk"/"oak_intro"); isto traduz pra uma instrução que uma
## criança lê e entende. Chave = tipo do objetivo.
const FRASE_POR_TIPO := {
	"talk":          "Fale com %s",
	"capture":       "Capture %s",
	"defeat":        "Derrote %s",
	"reach_zone":    "Vá até %s",
	"reach_floor":   "Chegue ao andar %s",
	"collect":       "Consiga %s",
	"receive_item":  "Pegue %s",
}

var _painel : PanelContainer
var _titulo : Label
var _passo  : Label
var _rumo   : Label
var _seta_no : Control
var _quest_atual : String = ""
var _alvo   : Vector2i = Vector2i.ZERO
var _tem_alvo : bool = false

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	EventBus.map_changed.connect(func(_f, _t): _atualizar())
	QuestManager.quest_started.connect(func(_q): _atualizar())
	QuestManager.quest_updated.connect(func(_q, _i, _p): _atualizar())
	QuestManager.quest_completed.connect(func(_q): _atualizar())
	_atualizar()

func _montar() -> void:
	_painel = PanelContainer.new()
	_painel.anchor_left = 0.5
	_painel.anchor_right = 0.5
	_painel.offset_left = -230
	_painel.offset_right = 230
	_painel.offset_top = 10
	_painel.offset_bottom = 74
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.06, 0.08, 0.05, 0.82)
	fundo.border_color = Color(0.78, 0.65, 0.25)
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(6)
	fundo.set_content_margin_all(8)
	_painel.add_theme_stylebox_override("panel", fundo)
	add_child(_painel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_painel.add_child(col)

	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 11)
	_titulo.add_theme_color_override("font_color", Color(0.82, 0.72, 0.38))
	col.add_child(_titulo)

	_passo = Label.new()
	_passo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passo.add_theme_font_size_override("font_size", 15)
	col.add_child(_passo)

	var linha_rumo := HBoxContainer.new()
	linha_rumo.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_rumo.add_theme_constant_override("separation", 8)
	col.add_child(linha_rumo)

	_seta_no = SetaDeRumo.new()
	_seta_no.custom_minimum_size = Vector2(18, 18)
	linha_rumo.add_child(_seta_no)

	_rumo = Label.new()
	_rumo.add_theme_font_size_override("font_size", 12)
	_rumo.add_theme_color_override("font_color", Color(0.62, 0.78, 0.58))
	linha_rumo.add_child(_rumo)

	_painel.hide()

func _atualizar() -> void:
	_tem_alvo = false
	if not SaveManager.has_save():
		_painel.hide()
		return

	var id := _quest_ativa()
	if id.is_empty():
		_painel.hide()
		return

	var dados : Dictionary = GameData.get_quest(id)
	if dados.is_empty():
		_painel.hide()
		return

	_quest_atual = id
	_titulo.text = "OBJETIVO — " + str(dados.get("title", "Aventura"))
	_passo.text = _frase_do_objetivo(id, dados)

	var local : Dictionary = dados.get("location_tile", {})
	if local.has("x") and local.has("y"):
		_alvo = Vector2i(int(local["x"]), int(local["y"]))
		_tem_alvo = true
	_rumo.visible = _tem_alvo
	if _seta_no:
		_seta_no.visible = _tem_alvo
	_painel.show()
	_atualizar_rumo()

## Primeira quest da linha principal que já começou e ainda não terminou.
func _quest_ativa() -> String:
	for id in ORDEM_QUESTS:
		if QuestManager.is_quest_complete(id):
			continue
		var estado : Dictionary = SaveManager.get_quest_state(id)
		if not estado.is_empty():
			return id
		# Ainda não começou: se é a primeira pendente, ela é o próximo passo —
		# mostrar mesmo assim é melhor que deixar a tela sem rumo nenhum.
		return id
	return ""

func _frase_do_objetivo(id: String, dados: Dictionary) -> String:
	var objetivos : Array = dados.get("objectives", [])
	if objetivos.is_empty():
		return str(dados.get("title", ""))
	# Primeiro objetivo ainda não cumprido
	for i in objetivos.size():
		var obj : Dictionary = objetivos[i]
		var falta : int = _quanto_falta(id, i, obj)
		if falta <= 0:
			continue
		var modelo : String = str(FRASE_POR_TIPO.get(str(obj.get("type", "")), "%s"))
		var alvo := _nome_legivel(str(obj.get("target", "")))
		if falta > 1:
			return (modelo % alvo) + "  (%d)" % falta
		return modelo % alvo
	return "Objetivo concluído — volte para quem te pediu."

func _quanto_falta(id: String, indice: int, obj: Dictionary) -> int:
	var preciso : int = int(obj.get("count", 1))
	var feito : int = QuestManager.get_objective_progress(id, indice)
	return maxi(0, preciso - feito)

## "oak_intro" -> "o Prof. Carvalho". Sem isto a faixa mostraria o identificador
## interno, que não quer dizer nada pra quem está jogando.
const NOME_LEGIVEL := {
	"oak_intro": "o Prof. Carvalho",
	"professor_oak": "o Prof. Carvalho",
	"rival_intro": "seu rival",
	"pallet_town": "Pallet Town",
	"viridian_city": "Viridian City",
	"pewter_city": "Pewter City",
	"route_1": "a Rota 1",
	"viridian_forest": "a Floresta de Viridian",
}

func _nome_legivel(alvo: String) -> String:
	if NOME_LEGIVEL.has(alvo):
		return str(NOME_LEGIVEL[alvo])
	return alvo.replace("_", " ").capitalize()

func _process(_delta: float) -> void:
	if _painel.visible and _tem_alvo:
		_atualizar_rumo()

## Seta + distância em passos. É a peça que responde "pra onde eu vou" sem
## precisar de mapa aberto.
func _atualizar_rumo() -> void:
	var jogador := _tile_do_jogador()
	if jogador == Vector2i(-9999, -9999):
		_rumo.visible = false
		_seta_no.visible = false
		return
	var d := _alvo - jogador
	var passos := absi(d.x) + absi(d.y)
	if passos <= 2:
		_seta_no.visible = false
		_rumo.text = "Você chegou!"
		return
	_seta_no.visible = true
	_seta_no.apontar(atan2(float(d.y), float(d.x)))
	_rumo.text = "%d passos" % passos

## Seta desenhada, não escrita. A fonte do jogo não tem os glifos de seta
## (viraram quadradinho na tela em 04/09), e desenhada ela aponta no ângulo
## exato em vez de arredondar pra 8 direções.
class SetaDeRumo extends Control:
	var _angulo : float = 0.0

	func apontar(rad: float) -> void:
		if is_equal_approx(rad, _angulo):
			return
		_angulo = rad
		queue_redraw()

	func _draw() -> void:
		var meio := size / 2.0
		var raio : float = minf(size.x, size.y) / 2.0 - 1.0
		var pontos := PackedVector2Array()
		for graus in [0.0, 140.0, 220.0]:
			var a : float = _angulo + deg_to_rad(graus)
			var r : float = raio if graus == 0.0 else raio * 0.85
			pontos.append(meio + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pontos, Color(0.72, 0.88, 0.62))

func _tile_do_jogador() -> Vector2i:
	var jogador = WorldManager.player
	if jogador == null or not is_instance_valid(jogador):
		return Vector2i(-9999, -9999)
	return WorldManager.pos_para_tile(jogador.global_position)
