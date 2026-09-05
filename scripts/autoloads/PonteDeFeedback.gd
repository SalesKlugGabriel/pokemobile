## PonteDeFeedback.gd — O Gabriel joga e manda o recado de dentro do jogo (05/09).
##
## Pedido dele: "uma ponte de conexão com o servidor enquanto estamos refinando
## o game, onde eu possa dar feedback enquanto jogo". A ideia é que ele não
## precise sair do jogo, anotar num papel e lembrar depois — aperta F2 (ou o
## botão 💬 no canto, que também funciona no celular), escreve, e continua
## jogando de onde parou.
##
## Três decisões que fazem a diferença entre "caixa de texto" e ferramenta útil:
##
## 1. A PRINT VAI JUNTO, tirada ANTES do painel abrir. "A árvore está estranha"
##    sem imagem me obriga a adivinhar qual árvore; com a print eu vejo.
##
## 2. O CONTEXTO É AUTOMÁTICO — mapa, tile onde ele está, FPS, tamanho da tela,
##    Pokémon ativo. É o dado que ele nunca ia digitar e que é justamente o que
##    me faz achar o problema.
##
## 3. RECADO NUNCA SE PERDE. Se a internet cair ou o servidor estiver fora, a
##    mensagem vai pra uma fila em `user://` e é reenviada na próxima vez que o
##    jogo ligar. O recado dele vale mais que a minha requisição HTTP.
##
## Onde chega: `https://poke.workprog.pro/editor/api/feedback` (o serviço do
## editor, que já estava no ar — nenhum container, domínio ou porta nova). Pra
## ler: página `poke.workprog.pro/editor/feedback.html`, ou o arquivo
## `/root/pokemobile-editor-data/feedback.jsonl` direto na VPS.
extends Node

const URL_FEEDBACK : String = "https://poke.workprog.pro/editor/api/feedback"
const ARQUIVO_FILA : String = "user://feedback_pendente.json"
const LARGURA_PRINT : int = 960   ## a print é reduzida antes de virar JPG

var _camada : CanvasLayer = null
var _painel : Control = null
var _caixa : TextEdit = null
var _aviso : Label = null
var _botao : Button = null
var _print_atual : String = ""
var _fila : Array = []

func _ready() -> void:
	# Precisa continuar respondendo com o jogo pausado: o próprio painel pausa
	# a árvore (mesma convenção do MapaMundi) pra ele não sair andando enquanto
	# digita.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_ui()
	_carregar_fila()
	# Espera o jogo assentar antes de tentar reenviar o que ficou pendente.
	await get_tree().create_timer(3.0).timeout
	_tentar_enviar_fila()

# ──────────────────────────────────────────────────────────────────────────
# UI — construída em código, como o resto das telas globais do projeto
# ──────────────────────────────────────────────────────────────────────────
func _montar_ui() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 90
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada)

	_botao = Button.new()
	_botao.text = "💬"
	_botao.tooltip_text = "Mandar um recado sobre o jogo (F2)"
	_botao.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_botao.offset_left = -64.0
	_botao.offset_top = -64.0
	_botao.offset_right = -12.0
	_botao.offset_bottom = -12.0
	_botao.modulate = Color(1, 1, 1, 0.55)
	_botao.pressed.connect(abrir)
	_camada.add_child(_botao)

	_painel = Control.new()
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.visible = false
	_camada.add_child(_painel)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.add_child(fundo)

	var caixa_painel := PanelContainer.new()
	caixa_painel.set_anchors_preset(Control.PRESET_CENTER)
	caixa_painel.custom_minimum_size = Vector2(520, 300)
	caixa_painel.offset_left = -260.0
	caixa_painel.offset_top = -150.0
	caixa_painel.offset_right = 260.0
	caixa_painel.offset_bottom = 150.0
	_painel.add_child(caixa_painel)

	# PanelContainer com UM filho só — a lição do PartyScene, onde dois filhos
	# diretos deixaram o título flutuando no meio do painel.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	caixa_painel.add_child(col)

	var titulo := Label.new()
	titulo.text = "O que você quer me contar?"
	titulo.add_theme_font_size_override("font_size", 20)
	col.add_child(titulo)

	var dica := Label.new()
	dica.text = "A print da tela e o lugar onde você está vão junto automaticamente."
	dica.add_theme_font_size_override("font_size", 12)
	dica.modulate = Color(1, 1, 1, 0.6)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(dica)

	_caixa = TextEdit.new()
	_caixa.custom_minimum_size = Vector2(0, 150)
	_caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caixa.placeholder_text = "Ex: a árvore aqui do lado da ponte fica por cima do personagem"
	col.add_child(_caixa)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	linha.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(linha)

	var cancelar := Button.new()
	cancelar.text = "Cancelar (Esc)"
	cancelar.pressed.connect(fechar)
	linha.add_child(cancelar)

	var enviar := Button.new()
	enviar.text = "Enviar"
	enviar.pressed.connect(_enviar)
	linha.add_child(enviar)

	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.offset_top = 24.0
	_aviso.offset_left = -260.0
	_aviso.offset_right = 260.0
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.visible = false
	_aviso.add_theme_font_size_override("font_size", 16)
	_camada.add_child(_aviso)

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_F2:
			if _painel.visible:
				fechar()
			else:
				abrir()
			get_viewport().set_input_as_handled()

# ──────────────────────────────────────────────────────────────────────────
# Abrir / fechar
# ──────────────────────────────────────────────────────────────────────────
func abrir() -> void:
	if _painel.visible:
		return
	# A print é tirada ANTES de mostrar o painel — senão eu recebo a foto do
	# painel, não a do problema.
	_print_atual = await _capturar_print()
	_caixa.text = ""
	_painel.visible = true
	_botao.visible = false
	get_tree().paused = true
	UIStack.empilhar(self, Callable(self, "fechar"))
	_caixa.grab_focus()

func fechar() -> void:
	if not _painel.visible:
		return
	_painel.visible = false
	_botao.visible = true
	get_tree().paused = false
	UIStack.desempilhar(self)

## A print sai reduzida e em JPG: o recado tem que caber numa conexão de
## celular sem virar upload de megabytes.
func _capturar_print() -> String:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ""
	if img.get_width() > LARGURA_PRINT:
		var altura := int(round(img.get_height() * float(LARGURA_PRINT) / float(img.get_width())))
		img.resize(LARGURA_PRINT, altura, Image.INTERPOLATE_BILINEAR)
	var bytes := img.save_jpg_to_buffer(0.72)
	if bytes.is_empty():
		return ""
	return Marshalls.raw_to_base64(bytes)

# ──────────────────────────────────────────────────────────────────────────
# Envio
# ──────────────────────────────────────────────────────────────────────────
func _enviar() -> void:
	var texto := _caixa.text.strip_edges()
	if texto == "":
		fechar()
		return
	var recado := {
		"texto": texto,
		"contexto": coletar_contexto(),
		"print": _print_atual,
	}
	fechar()
	_mostrar_aviso("Recado enviado. Obrigado!")
	_fila.append(recado)
	_gravar_fila()
	_tentar_enviar_fila()

## Público e sem efeito colateral pra dar pra testar headless: é o dado que ele
## nunca ia digitar à mão e que é o que de fato me faz achar o problema.
func coletar_contexto() -> Dictionary:
	# `get_setting(chave, padrão)` só usa o padrão quando a chave NÃO EXISTE —
	# aqui ela existe e é vazia, então o padrão nunca entrava e o recado
	# chegava com "versao": "". Achado no primeiro recado real que a ponte
	# entregou, não a olho no código.
	var versao := str(ProjectSettings.get_setting("application/config/version", ""))
	if versao.strip_edges() == "":
		versao = "dev"
	var ctx := {
		"versao": versao,
		"fps": Engine.get_frames_per_second(),
		"tela": "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
	}
	var mundo := get_node_or_null("/root/WorldManager")
	if mundo != null and "current_map_id" in mundo:
		var id_mapa : String = str(mundo.current_map_id)
		ctx["mapa"] = id_mapa if id_mapa != "" else "world_map"
	var jogadores := get_tree().get_nodes_in_group("player")
	if not jogadores.is_empty():
		var p : Node = jogadores[0]
		if p is Node2D:
			var pos : Vector2 = (p as Node2D).global_position
			ctx["tile"] = "%d,%d" % [int(floor(pos.x / 128.0)), int(floor(pos.y / 128.0))]
	var salvar := get_node_or_null("/root/SaveManager")
	if salvar != null and salvar.has_method("get_team"):
		var time : Array = salvar.get_team()
		if not time.is_empty() and time[0] is Dictionary:
			var ativo : Dictionary = time[0]
			# Mesma armadilha do campo de versão: `nickname` EXISTE e é vazio
			# quando o Pokémon não foi apelidado, então o padrão do `get()`
			# nunca entrava. Cai pro nome da espécie, e só depois pro número.
			var nome := str(ativo.get("nickname", ""))
			if nome.strip_edges() == "":
				var id_especie : int = int(ativo.get("species_id", 0))
				var dados := GameData.get_species(id_especie) if id_especie > 0 else {}
				nome = str(dados.get("name", "")) if not dados.is_empty() else ""
				if nome == "":
					nome = "#%d" % id_especie
			ctx["pokemon"] = nome
			ctx["nivel"] = int(ativo.get("level", 0))
	return ctx

func _tentar_enviar_fila() -> void:
	if _fila.is_empty():
		return
	var recado : Dictionary = _fila[0]
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(req)
	req.request_completed.connect(func(_r, codigo, _h, _b):
		req.queue_free()
		if codigo >= 200 and codigo < 300:
			# Só sai da fila quando o servidor confirmou. Se cair no meio, o
			# recado continua guardado e vai de novo na próxima vez.
			if not _fila.is_empty():
				_fila.pop_front()
			_gravar_fila()
			_tentar_enviar_fila()
	)
	var erro := req.request(
		URL_FEEDBACK,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(recado)
	)
	if erro != OK:
		req.queue_free()

func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.visible = true
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(2.0)
	t.tween_property(_aviso, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		_aviso.visible = false
		_aviso.modulate.a = 1.0
	)

# ──────────────────────────────────────────────────────────────────────────
# Fila em disco — o recado sobrevive a queda de internet e a fechar o jogo
# ──────────────────────────────────────────────────────────────────────────
func _carregar_fila() -> void:
	if not FileAccess.file_exists(ARQUIVO_FILA):
		return
	var f := FileAccess.open(ARQUIVO_FILA, FileAccess.READ)
	if f == null:
		return
	var dados = JSON.parse_string(f.get_as_text())
	f.close()
	if dados is Array:
		_fila = dados

func _gravar_fila() -> void:
	var f := FileAccess.open(ARQUIVO_FILA, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_fila))
	f.close()
