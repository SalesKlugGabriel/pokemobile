## EscolhaInicial.gd — O encontro com o Prof. Carvalho (05/09).
##
## Pedido do Gabriel: "a tela de escolha de Pokémon, em vez de ser ali, poderia
## ser um encontro com o professor Carvalho, onde ele vai estar de frente com as
## três pokébolas, e você escolhe ali qual das três pokébolas você vai querer,
## pra se remeter como era os jogos originais".
##
## O que muda em relação à tela antiga: lá eram três cartões de texto com um
## botão "Escolher" em cada. Aqui é uma cena — o laboratório, o Professor, a
## mesa com as três bolas fechadas. A criança escolhe uma BOLA (sem saber ainda
## o que tem dentro, como no original), a bola ABRE, o Pokémon aparece, e só
## então ela confirma. É o momento mais lembrado da franquia; virar uma lista
## era desperdiçá-lo.
##
## O nome do treinador vem da tela anterior por `nome_treinador` (static var):
## sobrevive à troca de cena sem precisar de autoload novo só pra carregar uma
## string por dois segundos.
class_name EscolhaInicial
extends Control

## Preenchido pela tela de nome antes do fade. "" cai em "Ash", igual antes.
static var nome_treinador : String = ""

const INICIAIS : Array[Dictionary] = [
	{"id": 1, "nome": "Bulbasaur",  "tipo": "Planta / Veneno",
	 "sobre": "Calmo e resistente. Leva vantagem nos primeiros ginásios."},
	{"id": 4, "nome": "Charmander", "tipo": "Fogo",
	 "sobre": "Corajoso e poderoso mais pra frente. O começo é mais difícil."},
	{"id": 7, "nome": "Squirtle",   "tipo": "Água",
	 "sobre": "Equilibrado. Boa defesa e serve pra quase tudo."},
]

const FALAS_ABERTURA : Array[String] = [
	"Olá! Eu sou o Professor Carvalho.\nBem-vindo ao mundo dos Pokémon!",
	"Aqui na minha mesa há três Pokébolas.\nDentro de cada uma dorme um Pokémon.",
	"Escolha uma com as setas e aperte Enter.\nEle será seu companheiro de viagem.",
]

const CAMINHO_FUNDO   := "res://assets/ui/fundo_laboratorio.png"
const CAMINHO_OAK     := "res://assets/sprites/npc/npc_oak.png"
const BOLA_FECHADA    := "res://assets/sprites/itens/pokebola_fechada.png"
const BOLA_BRILHANDO  := "res://assets/sprites/itens/pokebola_brilhando.png"
const BOLA_ABERTA     := "res://assets/sprites/itens/pokebola_aberta.png"

enum Fase { ABERTURA, ESCOLHENDO, REVELANDO, CONFIRMANDO }

var _fase : Fase = Fase.ABERTURA
var _fala : int = 0
var _sel  : int = 0

var _bolas       : Array[TextureRect] = []
var _revelado    : TextureRect
var _texto       : Label
var _dica        : Label
var _nome_poke   : Label
var _tempo       : float = 0.0
## Posição de repouso de cada bola (o balanço é somado a isto, nunca gravado
## por cima — senão a bola "sobe" um pouco a cada quadro).
var _bases       : Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

func _ready() -> void:
	AudioManager.play_bgm("title")
	_montar()
	_atualizar_texto()
	set_process_unhandled_input(true)

# ──────────────────────────────────────────────────────────────────────────────
# Montagem da cena
# ──────────────────────────────────────────────────────────────────────────────
func _montar() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var fundo := ColorRect.new()
	fundo.color = Color(0.10, 0.09, 0.07)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	if ResourceLoader.exists(CAMINHO_FUNDO):
		var lab := TextureRect.new()
		lab.texture = load(CAMINHO_FUNDO)
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lab.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lab)

	# ── Professor: quadro parado, virado pra frente, da folha do NPC ─────────
	# Mesma folha que o NpcEntity usa no mapa (3 colunas x 4 direções, 128x256),
	# então o Professor da cena e o do jogo são literalmente o mesmo desenho.
	if ResourceLoader.exists(CAMINHO_OAK):
		var folha : Texture2D = load(CAMINHO_OAK)
		var quadro := AtlasTexture.new()
		quadro.atlas = folha
		quadro.region = Rect2(0, 0, folha.get_width() / 3.0, folha.get_height() / 4.0)
		var oak := TextureRect.new()
		oak.texture = quadro
		oak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		oak.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		oak.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Encostado à esquerda, atrás da bancada: deixa o centro livre pro
		# Pokémon revelado. Centralizado, ele ficava debaixo da revelação e os
		# dois se sobrepunham.
		oak.custom_minimum_size = Vector2(230, 460)
		oak.position = Vector2(110, 120)
		oak.size = Vector2(230, 460)
		oak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(oak)

	# ── O Pokémon revelado, acima da bola escolhida ──────────────────────────
	_revelado = TextureRect.new()
	_revelado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_revelado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_revelado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_revelado.custom_minimum_size = Vector2(240, 240)
	_revelado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_revelado.hide()
	add_child(_revelado)

	_nome_poke = Label.new()
	_nome_poke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome_poke.add_theme_font_size_override("font_size", 22)
	_nome_poke.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	_nome_poke.add_theme_constant_override("outline_size", 8)
	_nome_poke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome_poke.hide()
	add_child(_nome_poke)

	# ── As três bolas na mesa ────────────────────────────────────────────────
	for i in INICIAIS.size():
		var indice := i
		var bola := TextureRect.new()
		bola.texture = load(BOLA_FECHADA)
		bola.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bola.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bola.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bola.custom_minimum_size = Vector2(128, 128)
		bola.size = Vector2(128, 128)
		bola.mouse_filter = Control.MOUSE_FILTER_STOP
		bola.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_clicou_na_bola(indice))
		add_child(bola)
		_bolas.append(bola)

	# ── Caixa de fala, no rodapé ─────────────────────────────────────────────
	var caixa := PanelContainer.new()
	caixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caixa.offset_left = 60
	caixa.offset_right = -60
	caixa.offset_top = -150
	caixa.offset_bottom = -24
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.09, 0.07, 0.92)
	estilo.border_color = Color(0.85, 0.72, 0.32)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(16)
	caixa.add_theme_stylebox_override("panel", estilo)
	add_child(caixa)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	caixa.add_child(col)

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 19)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_texto)

	_dica = Label.new()
	_dica.add_theme_font_size_override("font_size", 13)
	_dica.add_theme_color_override("font_color", Color(0.72, 0.80, 0.66))
	col.add_child(_dica)

	_posicionar()

## Posiciona bolas e revelação a partir do tamanho REAL da janela — a cena roda
## no navegador, onde a resolução não é a mesma em todo lugar.
func _posicionar() -> void:
	var tela := get_viewport_rect().size
	# A bancada do fundo tem o tampo em y=452 numa tela de 1280x720; escalado
	# pela altura real, as bolas ficam APOIADAS nela em vez de flutuando.
	var escala := tela.y / 720.0
	var tampo := 452.0 * escala
	var centro_x := 660.0 * (tela.x / 1280.0)
	var passo := 190.0 * escala
	for i in _bolas.size():
		# 118 = distância do topo do sprite até a base da bola desenhada
		_bases[i] = Vector2(centro_x + (i - 1) * passo - 64.0, tampo - 118.0)
		_bolas[i].position = _bases[i]
	# `size` explícito além do mínimo: sem ele o TextureRect fica com 0x0 até o
	# container mandar crescer — e aqui não há container, os nós são
	# posicionados à mão. O sprite saía desenhado no tamanho da fonte (128px)
	# dentro de uma caixa que devia ter 240.
	_revelado.size = Vector2(240, 240)
	_nome_poke.size = Vector2(400, 32)
	_altura_da_revelacao = tampo - 300.0
	_posicionar_revelacao()

## O Pokémon sai da bola QUE FOI ABERTA, não do meio da mesa. Ficava sempre no
## centro: escolhendo a bola da direita, o bicho aparecia sobre a bola do meio
## e a cena mentia sobre qual bola tinha aberto.
var _altura_da_revelacao : float = 0.0

func _posicionar_revelacao() -> void:
	if _sel >= _bases.size():
		return
	var x_bola : float = _bases[_sel].x + 64.0   # centro da bola
	_revelado.position = Vector2(x_bola - 120.0, _altura_da_revelacao)
	_nome_poke.position = Vector2(x_bola - 200.0, _altura_da_revelacao - 36.0)

func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED and not _bolas.is_empty():
		_posicionar()

# ──────────────────────────────────────────────────────────────────────────────
# Vida da cena
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tempo += delta
	# A bola selecionada flutua. É o feedback que diz "é esta" mesmo pra quem
	# não percebeu o halo — movimento chama mais atenção que cor.
	#
	# 🔴 A primeira versão mexia em `offset_top`/`offset_bottom`. Num Control
	# ancorado no canto (que é o caso), o offset É a posição — então as três
	# bolas saltaram pro topo da tela, coladas na parede. A posição de repouso
	# vive em `_bases` e o balanço é somado a ela.
	for i in _bolas.size():
		if i >= _bases.size():
			continue
		var balanco : float = 0.0
		if i == _sel and _fase == Fase.ESCOLHENDO:
			balanco = -9.0 * absf(sin(_tempo * 3.0))
		_bolas[i].position = _bases[i] + Vector2(0, balanco)

func _unhandled_input(event: InputEvent) -> void:
	var confirmar : bool = event.is_action_pressed("interact") or (
		event is InputEventKey and event.pressed and not event.is_echo()
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	var voltar : bool = event.is_action_pressed("pause")

	match _fase:
		Fase.ABERTURA:
			if confirmar:
				get_viewport().set_input_as_handled()
				_fala += 1
				if _fala >= FALAS_ABERTURA.size():
					_fase = Fase.ESCOLHENDO
				_atualizar_texto()
		Fase.ESCOLHENDO:
			if event.is_action_pressed("move_right"):
				get_viewport().set_input_as_handled()
				_mover_selecao(1)
			elif event.is_action_pressed("move_left"):
				get_viewport().set_input_as_handled()
				_mover_selecao(-1)
			elif confirmar:
				get_viewport().set_input_as_handled()
				_abrir_bola()
		Fase.CONFIRMANDO:
			if confirmar:
				get_viewport().set_input_as_handled()
				_fechar_negocio()
			elif voltar:
				get_viewport().set_input_as_handled()
				_desistir()

func _mover_selecao(passo: int) -> void:
	_sel = (_sel + passo + INICIAIS.size()) % INICIAIS.size()
	AudioManager.play_sfx("menu_select")
	_atualizar_texto()

func _clicou_na_bola(indice: int) -> void:
	if _fase == Fase.ABERTURA:
		_fase = Fase.ESCOLHENDO
	if _fase != Fase.ESCOLHENDO:
		return
	if _sel != indice:
		_sel = indice
		AudioManager.play_sfx("menu_select")
		_atualizar_texto()
		return
	_abrir_bola()

## A bola abre e o Pokémon aparece. Só DEPOIS de ver é que se confirma — como
## no original, onde dá pra abrir uma, olhar, e ainda escolher outra.
func _abrir_bola() -> void:
	_fase = Fase.REVELANDO
	AudioManager.play_sfx("catch_throw")
	_bolas[_sel].texture = load(BOLA_ABERTA)

	var dados : Dictionary = INICIAIS[_sel]
	_revelado.texture = PokemonIcon.textura(int(dados["id"]))
	_posicionar_revelacao()
	_revelado.scale = Vector2(0.2, 0.2)
	_revelado.pivot_offset = _revelado.size / 2.0
	_revelado.show()
	_nome_poke.text = "%s   —   %s" % [dados["nome"], dados["tipo"]]
	_nome_poke.show()

	var tw := create_tween()
	tw.tween_property(_revelado, "scale", Vector2(1.0, 1.0), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		AudioManager.play_sfx("catch_success")
		_fase = Fase.CONFIRMANDO
		_atualizar_texto())

func _desistir() -> void:
	AudioManager.play_sfx("cancel")
	_bolas[_sel].texture = load(BOLA_FECHADA)
	_revelado.hide()
	_nome_poke.hide()
	_fase = Fase.ESCOLHENDO
	_atualizar_texto()

func _fechar_negocio() -> void:
	AudioManager.play_sfx("confirm")
	var nome := nome_treinador.strip_edges()
	if nome.is_empty():
		nome = "Ash"
	SaveManager.new_game(nome, int(INICIAIS[_sel]["id"]))
	QuestManager.reload_from_save()
	SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# Texto e destaque
# ──────────────────────────────────────────────────────────────────────────────
func _atualizar_texto() -> void:
	for i in _bolas.size():
		if _fase == Fase.ESCOLHENDO:
			_bolas[i].texture = load(BOLA_BRILHANDO if i == _sel else BOLA_FECHADA)
		elif _fase == Fase.ABERTURA:
			_bolas[i].texture = load(BOLA_FECHADA)

	match _fase:
		Fase.ABERTURA:
			_texto.text = FALAS_ABERTURA[mini(_fala, FALAS_ABERTURA.size() - 1)]
			_dica.text = "Enter para continuar"
			_revelado.hide()
			_nome_poke.hide()
		Fase.ESCOLHENDO:
			_texto.text = "Qual das três você quer abrir?"
			_dica.text = "Setas  escolher      Enter  abrir a Pokébola"
			_revelado.hide()
			_nome_poke.hide()
		Fase.REVELANDO:
			_texto.text = "A Pokébola está abrindo..."
			_dica.text = ""
		Fase.CONFIRMANDO:
			var dados : Dictionary = INICIAIS[_sel]
			_texto.text = "%s!  %s\nQuer levar este com você?" % [dados["nome"], dados["sobre"]]
			_dica.text = "Enter  ficar com ele     Esc  ver outra Pokébola"
