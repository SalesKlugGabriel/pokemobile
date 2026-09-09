## BarraDeAcaoRapida.gd — usar item por dois cliques: primeiro no item (arma),
## depois no ALVO (09/09, pedido do Gabriel: "capturar deve ser um clique de
## usar na pokebola escolhida e um clique no Pokémon atordoado como alvo,
## mesma coisa para remédio").
##
## Substitui DOIS fluxos antigos:
## 1. A tecla "pokeball", que escolhia a bola sozinha (pick_best_owned_ball)
##    e mirava sozinha no corpo mais perto — o jogador nunca escolhia nada.
## 2. O picker de lista da Mochila pra usar remédio (só ficou pra vitamina/PP
##    Up, que não fazem sentido como "clique no alvo" — não tratam HP).
##
## Fica sempre visível no canto inferior esquerdo (o joystick invisível é no
## quadrante inferior DIREITO — ver ControlesDeToque.gd — então não disputam
## a mesma área de toque no celular).
extends Control

const BTN_SIZE  : Vector2 = Vector2(48, 48)
const CATEGORIAS_RAPIDAS := ["ball", "medicine"]
const ALCANCE_BOLA : float = 128.0 * 2.0  # BaseEntity.TILE_SIZE × 2 — mesmo alcance de sempre

var _item_armado     : String = ""
var _categoria_armada: String = ""
var _linha           : HBoxContainer
var _botoes          : Dictionary = {}   # item_id -> Button
var _tira_time       : PanelContainer = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	custom_minimum_size = Vector2(240, 60)
	position = Vector2(10, -70)

	_linha = HBoxContainer.new()
	_linha.add_theme_constant_override("separation", 6)
	add_child(_linha)

	EventBus.item_picked_up.connect(func(_id, _q): _reconstruir())
	EventBus.item_used.connect(func(_id, _t): _reconstruir())
	EventBus.capture_success.connect(func(_d): _reconstruir())
	EventBus.corpo_desmaiado_clicado.connect(_on_corpo_desmaiado_clicado)
	# Bola armada e o clique caiu num selvagem de PÉ (não desmaiado) — mesmo
	# aviso que a tecla antiga dava, só que agora reage ao clique de verdade
	# em vez de assumir "o mais perto".
	EventBus.wild_pokemon_selected.connect(func(_p):
		if _categoria_armada == "ball":
			EventBus.notification_requested.emit("Derrote-o primeiro — a Pokébola só funciona em quem já caiu.")
	)
	_reconstruir()

func _reconstruir() -> void:
	for c in _linha.get_children():
		c.queue_free()
	_botoes.clear()

	var inv : Dictionary = SaveManager.get_inventory()
	for item_id in inv.keys():
		var qtd : int = int(inv[item_id])
		if qtd <= 0:
			continue
		var item : Dictionary = GameData.get_item(item_id)
		if not (str(item.get("category", "")) in CATEGORIAS_RAPIDAS):
			continue
		var btn := Button.new()
		btn.custom_minimum_size = BTN_SIZE
		btn.text = "%s\n×%d" % [str(item.get("name", item_id)).left(6), qtd]
		btn.add_theme_font_size_override("font_size", 9)
		btn.toggle_mode = true
		btn.button_pressed = (item_id == _item_armado)
		var cat : String = str(item.get("category", ""))
		btn.pressed.connect(_on_botao_pressionado.bind(item_id, cat))
		_linha.add_child(btn)
		_botoes[item_id] = btn

	# Se o item armado não existir mais (acabou o estoque), desarma.
	if not _item_armado.is_empty() and not _botoes.has(_item_armado):
		_desarmar()

func _on_botao_pressionado(item_id: String, categoria: String) -> void:
	if _item_armado == item_id:
		_desarmar()
	else:
		_armar(item_id, categoria)

func _armar(item_id: String, categoria: String) -> void:
	_item_armado = item_id
	_categoria_armada = categoria
	for id in _botoes:
		_botoes[id].button_pressed = (id == item_id)
	AudioManager.play_sfx("select")
	if categoria == "medicine":
		_mostrar_tira_de_time()
	else:
		_esconder_tira_de_time()
		EventBus.notification_requested.emit("Clique no Pokémon desmaiado pra jogar a bola.")

func _desarmar() -> void:
	_item_armado = ""
	_categoria_armada = ""
	for id in _botoes:
		_botoes[id].button_pressed = false
	_esconder_tira_de_time()

# ──────────────────────────────────────────────────────────────────────────────
# Alvo: Pokébola num corpo desmaiado
# ──────────────────────────────────────────────────────────────────────────────

func _on_corpo_desmaiado_clicado(pokemon: Node) -> void:
	if _categoria_armada != "ball":
		return
	if not is_instance_valid(pokemon):
		return
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador and jogador is Node2D and pokemon is Node2D:
		var dist : float = (jogador as Node2D).global_position.distance_to((pokemon as Node2D).global_position)
		if dist > ALCANCE_BOLA:
			EventBus.notification_requested.emit("Chegue mais perto pra jogar a bola.")
			return
	var ball_id := _item_armado
	SaveManager.remove_item(ball_id, 1)
	CaptureSystem.throw_pokeball(pokemon, ball_id)
	_desarmar()
	_reconstruir()

# ──────────────────────────────────────────────────────────────────────────────
# Alvo: remédio num Pokémon do time (tira de retratos — só o líder está
# fisicamente no mundo, os outros 5 não têm como ser "clicados" lá fora)
# ──────────────────────────────────────────────────────────────────────────────

func _mostrar_tira_de_time() -> void:
	_esconder_tira_de_time()
	var time : Array = SaveManager.get_team()
	if time.is_empty():
		return

	_tira_time = PanelContainer.new()
	# Entra na árvore ANTES de montar o conteúdo: set_anchors_preset() com o
	# painel ainda vazio (tamanho 0x0) calcula um offset errado — achado já
	# registrado em OverworldHUD._build_skill_cooldown_bars(), mesma causa.
	var raiz := get_tree().current_scene if get_tree().current_scene else self
	raiz.add_child(_tira_time)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	_tira_time.add_child(linha)

	for i in time.size():
		var poke : Dictionary = time[i]
		var hp : int = int(poke.get("hp_current", 0))
		var hp_max : int = maxi(1, int(poke.get("hp_max", 1)))
		var especie : Dictionary = GameData.get_species(int(poke.get("species_id", 0)))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 44)
		btn.text = "%s\n%d/%d" % [str(especie.get("name", "?")).left(8), hp, hp_max]
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(_on_alvo_de_time_escolhido.bind(i))
		linha.add_child(btn)

	_tira_time.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	_tira_time.position -= Vector2(0, 90)

func _esconder_tira_de_time() -> void:
	if _tira_time and is_instance_valid(_tira_time):
		_tira_time.queue_free()
	_tira_time = null

func _on_alvo_de_time_escolhido(indice: int) -> void:
	var item_id := _item_armado
	var r : Dictionary = CuraDeCampo.usar_remedio_de_campo(item_id, indice)
	EventBus.notification_requested.emit(str(r.get("texto", "")))
	if bool(r.get("ok", false)):
		EventBus.item_used.emit(item_id, null)
	_desarmar()
	_reconstruir()
