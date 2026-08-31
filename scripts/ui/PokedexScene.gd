## PokedexScene.gd — Pokédex UI: lista de Pokémon vistos e capturados.
## Abre/fecha com a tecla M (input action "map" reutilizado como Pokédex por ora).
## Exibe: número, nome, tipo, status (visto/capturado/desconhecido).
extends CanvasLayer

## Emitido sempre que a Pokédex fecha (botão ou tecla) — usado por quem a abriu
## de um contexto pausado (menu de pausa) para saber a hora de despausar.
signal closed_by_user()

# ──────────────────────────────────────────────────────────────────────────────
# Referências de nós (definidas na .tscn)
# ──────────────────────────────────────────────────────────────────────────────
@onready var panel        : Panel        = $Panel
@onready var list_container : VBoxContainer = $Panel/Scroll/VBox
@onready var title_label  : Label        = $Panel/Header/Title
@onready var close_btn    : Button       = $Panel/Header/CloseBtn
@onready var counter_label: Label        = $Panel/Footer/Counter

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _is_open : bool = false

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 60
	panel.hide()
	close_btn.pressed.connect(close)
	EventBus.pokedex_opened.connect(open)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_pokedex"):
		if _is_open:
			close()
		else:
			open()

# ──────────────────────────────────────────────────────────────────────────────
# Abrir / Fechar
# ──────────────────────────────────────────────────────────────────────────────
func open() -> void:
	_is_open = true
	_populate()
	panel.show()
	AudioManager.play_sfx("menu_open")
	get_viewport().set_input_as_handled()

func close() -> void:
	_is_open = false
	panel.hide()
	AudioManager.play_sfx("menu_close")
	closed_by_user.emit()

# ──────────────────────────────────────────────────────────────────────────────
# População da lista
# ──────────────────────────────────────────────────────────────────────────────
func _populate() -> void:
	# Limpa lista anterior
	for child in list_container.get_children():
		child.queue_free()

	var pokedex := SaveManager.get_pokedex()
	var seen_count := 0
	var caught_count := 0

	for id in range(1, 152):
		var is_seen   := SaveManager.is_seen(id)
		var is_caught := SaveManager.is_caught(id)
		if is_seen:
			seen_count += 1
		if is_caught:
			caught_count += 1

		var row := _make_row(id, is_seen, is_caught)
		list_container.add_child(row)

	counter_label.text = "Vistos: %d   Capturados: %d / 151" % [seen_count, caught_count]

func _make_row(species_id: int, is_seen: bool, is_caught: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	# Número
	var num := Label.new()
	num.text = "#%03d" % species_id
	num.custom_minimum_size = Vector2(52, 0)
	num.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	row.add_child(num)

	# Sprite pequeno (se visto)
	var sprite_rect := TextureRect.new()
	sprite_rect.custom_minimum_size = Vector2(20, 20)
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_seen:
		var tex_path := "res://assets/sprites/pokemon/mon_%03d.png" % species_id
		if ResourceLoader.exists(tex_path):
			sprite_rect.texture = load(tex_path)
	row.add_child(sprite_rect)

	# Nome (oculto se não visto)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_seen:
		var species := GameData.get_species(species_id)
		name_label.text = species.get("name", "???")
		name_label.add_theme_color_override("font_color",
			Color.WHITE if is_caught else Color(0.8, 0.8, 0.8))
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	row.add_child(name_label)

	# Badge de status
	var badge := Label.new()
	badge.custom_minimum_size = Vector2(64, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_caught:
		badge.text = "CAPTURADO"
		badge.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	elif is_seen:
		badge.text = "VISTO"
		badge.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))
	else:
		badge.text = "-"
		badge.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	row.add_child(badge)

	# Destaque ao passar o mouse
	row.mouse_entered.connect(func(): _highlight_row(row, true))
	row.mouse_exited.connect(func(): _highlight_row(row, false))

	return row

func _highlight_row(row: HBoxContainer, on: bool) -> void:
	var style := StyleBoxFlat.new()
	if on:
		style.bg_color = Color(1, 1, 1, 0.04)
	else:
		style.bg_color = Color(0, 0, 0, 0)
	row.add_theme_stylebox_override("panel", style)
