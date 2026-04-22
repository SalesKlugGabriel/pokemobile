## WorldMapUI.gd — UI do Mapa-Múndi global. Abre com tecla M ou Escape.
## Mostra grid de regiões com status de unlock e localização atual do player.
extends CanvasLayer

# ──────────────────────────────────────────────────────────────────────────────
# Referências de nós (conectadas via @onready)
# ──────────────────────────────────────────────────────────────────────────────
@onready var _panel       : Control    = $Panel
@onready var _grid        : GridContainer = $Panel/VBox/RegionsGrid
@onready var _close_btn   : Button     = $Panel/VBox/Header/CloseButton
@onready var _popup_panel : PanelContainer = $ComingSoonPopup
@onready var _popup_label : Label      = $ComingSoonPopup/VBox/MessageLabel
@onready var _popup_btn   : Button     = $ComingSoonPopup/VBox/OkButton

# ──────────────────────────────────────────────────────────────────────────────
# Constantes de estilo (padrão dark do projeto)
# ──────────────────────────────────────────────────────────────────────────────
const COLOR_BG          : Color = Color("#0a0a0a")
const COLOR_CARD        : Color = Color("#111111")
const COLOR_ACCENT      : Color = Color("#f15a22")
const COLOR_TEXT        : Color = Color.WHITE
const COLOR_TEXT_MUTED  : Color = Color("#9ca3af")
const COLOR_BORDER      : Color = Color(1, 1, 1, 0.06)
const COLOR_LOCKED      : Color = Color(1, 1, 1, 0.3)

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _is_open : bool = false

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 80
	visible = false
	_popup_panel.visible = false

	_close_btn.pressed.connect(close)
	_popup_btn.pressed.connect(_close_popup)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		close()
		get_viewport().set_input_as_handled()

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
func open() -> void:
	_build_grid()
	visible  = true
	_is_open = true
	get_tree().paused = true

func close() -> void:
	visible  = false
	_is_open = false
	get_tree().paused = false

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

# ──────────────────────────────────────────────────────────────────────────────
# Construção do grid de regiões
# ──────────────────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	# Limpa itens anteriores
	for child in _grid.get_children():
		child.queue_free()

	var region_manager := _get_region_manager()
	if not region_manager:
		push_warning("WorldMapUI: RegionManager não encontrado")
		return

	var all_regions : Array    = region_manager.get_all_regions()
	var active_id   : String   = region_manager.get_active_region().get("id", "kanto")

	# Organiza em grid 3×3 por grid_position
	var grid_data : Dictionary = {}
	for region in all_regions:
		var gpos = region.get("grid_position", [0, 0])
		var key  := Vector2i(gpos[0], gpos[1])
		grid_data[key] = region

	# Preenche o GridContainer (3 colunas, 3 linhas)
	_grid.columns = 3
	for row in range(3):
		for col in range(3):
			var key := Vector2i(col, row)
			if grid_data.has(key):
				var region : Dictionary = grid_data[key]
				_grid.add_child(_build_region_card(region, active_id))
			else:
				# Célula vazia
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(140, 100)
				_grid.add_child(spacer)

## Cria card de uma região.
func _build_region_card(region: Dictionary, active_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 100)

	var style := StyleBoxFlat.new()
	style.bg_color       = COLOR_CARD
	style.border_color   = COLOR_ACCENT if region["id"] == active_id else COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Nome da região
	var name_label := Label.new()
	name_label.text              = region.get("name", "?")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	if not region.get("unlocked", false):
		name_label.modulate = COLOR_LOCKED
	vbox.add_child(name_label)

	# Indicador "Você está aqui"
	if region["id"] == active_id:
		var here_label := Label.new()
		here_label.text = "★ Você está aqui"
		here_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		here_label.add_theme_font_size_override("font_size", 9)
		here_label.modulate = COLOR_ACCENT
		vbox.add_child(here_label)

	# Indicador de bloqueio
	if region.get("coming_soon", false):
		var lock_label := Label.new()
		lock_label.text = "[Em breve]"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 9)
		lock_label.modulate = COLOR_TEXT_MUTED
		vbox.add_child(lock_label)

		# Clique para ver mensagem coming soon
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_popup(region.get("coming_soon_message", "Em breve!"))
		)

	return panel

# ──────────────────────────────────────────────────────────────────────────────
# Popup Coming Soon
# ──────────────────────────────────────────────────────────────────────────────
func _show_popup(message: String) -> void:
	_popup_label.text    = message
	_popup_panel.visible = true

func _close_popup() -> void:
	_popup_panel.visible = false

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
func _get_region_manager() -> Node:
	var world := get_tree().current_scene
	if world:
		for child in world.get_children():
			if child.name == "RegionManager":
				return child
	return null
