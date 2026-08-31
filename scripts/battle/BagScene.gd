## BagScene.gd — Painel de inventário (batalha e Mochila da Pausa).
## Exibe itens do save filtrados por categoria (barra lateral com ícone) e
## emite sinal quando um é usado.
extends PanelContainer

signal item_selected(item_id: String)
signal bag_closed

# Categorias exibidas na batalha (outras ficam bloqueadas)
# Achado: items.json usa "ball" (pokeball/great_ball/ultra_ball/master_ball
# são todos "category":"ball") — aqui estava "pokeball", então a aba nunca
# encontrava nenhuma bola, mesmo com pokébolas no inventário.
const BATTLE_CATEGORIES := ["medicine", "ball"]

# Todas as categorias disponíveis para exibição com abas.
# Achado (auditoria de 2026-08-31): "berry" nunca existiu em nenhum item de
# items.json (aba "Frutas" sempre vazia), a chave real de item-de-história é
# "key" (não "key_item" — aba "Chave" nunca achava nada), e não existia
# nenhuma aba pra "stone" (Pedra do Fogo etc ficavam invisíveis na Mochila
# mesmo depois de compradas).
const ALL_CATEGORIES := ["medicine", "ball", "stone", "tm_hm", "battle", "vitamin", "key", "field"]
const CATEGORY_LABELS := {
	"medicine":  "Remédios",
	"ball":      "Pokébolas",
	"stone":     "Pedras",
	"tm_hm":     "TM/HM",
	"battle":    "Batalha",
	"vitamin":   "Vitaminas",
	"key":       "Chave",
	"field":     "Campo",
}

var _icon_cache : Dictionary = {}

@onready var item_list : VBoxContainer = $Layout/Body/Scroll/ItemList
@onready var btn_close  : Button        = $Layout/Header/BtnClose
@onready var sidebar    : VBoxContainer = $Layout/Body/Sidebar

var _active_category : String = "medicine"
var _battle_mode     : bool   = true  # true = filtrado para batalha

func _ready() -> void:
	btn_close.pressed.connect(func(): bag_closed.emit())
	_build_sidebar()

## Chamado por quem abre a mochila fora de batalha (menu de pausa) para
## liberar todas as categorias (chave, TM/HM), não só as usáveis em combate.
func set_battle_mode(v: bool) -> void:
	_battle_mode = v
	_active_category = (BATTLE_CATEGORIES if v else ALL_CATEGORIES)[0]
	_build_sidebar()

func _icon_for(category: String) -> Texture2D:
	if _icon_cache.has(category):
		return _icon_cache[category]
	var path := "res://assets/ui/icons/%s.png" % category
	var tex : Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[category] = tex
	return tex

func _build_sidebar() -> void:
	if not sidebar:
		return
	for child in sidebar.get_children():
		child.queue_free()
	var cats := BATTLE_CATEGORIES if _battle_mode else ALL_CATEGORIES
	for cat in cats:
		var btn := Button.new()
		btn.text = CATEGORY_LABELS.get(cat, cat)
		btn.icon = _icon_for(cat)
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.toggle_mode = true
		btn.button_pressed = (cat == _active_category)
		btn.add_theme_font_size_override("font_size", 12)
		var cap : String = cat
		btn.pressed.connect(func():
			_active_category = cap
			_build_sidebar()
			refresh(SaveManager.get_inventory())
		)
		sidebar.add_child(btn)

## Popula a lista com itens da categoria ativa.
func refresh(inventory: Dictionary) -> void:
	for child in item_list.get_children():
		child.queue_free()

	var cats := BATTLE_CATEGORIES if _battle_mode else ALL_CATEGORIES
	if _active_category not in cats:
		_active_category = cats[0]

	var has_any := false
	for item_id in inventory.keys():
		var qty : int = int(inventory[item_id])
		if qty <= 0:
			continue
		var item_data := GameData.get_item(item_id)
		if item_data.is_empty():
			continue
		var category : String = item_data.get("category", "")
		if category != _active_category:
			continue

		has_any = true
		var row := _make_row(item_id, item_data, qty)
		item_list.add_child(row)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "Nenhum item nesta categoria."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(0.5, 0.5, 0.5)
		item_list.add_child(lbl)

func _make_row(item_id: String, item_data: Dictionary, qty: int) -> PanelContainer:
	var wrap := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)

	var icon := TextureRect.new()
	icon.texture = _icon_for(item_data.get("category", ""))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var lbl_name := Label.new()
	lbl_name.text = item_data.get("name", item_id)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 14)

	# Tooltip com descrição do item
	var desc : String = item_data.get("description", "")
	if desc:
		lbl_name.tooltip_text = desc

	var lbl_qty := Label.new()
	lbl_qty.text = "x%d" % qty
	lbl_qty.add_theme_font_size_override("font_size", 14)
	lbl_qty.modulate = Color(0.7, 0.7, 0.7)

	var btn := Button.new()
	btn.text = "Usar"
	btn.custom_minimum_size = Vector2(60, 0)
	# Desabilita se categoria não é de batalha
	if _battle_mode and _active_category not in BATTLE_CATEGORIES:
		btn.disabled = true
	var captured_id := item_id
	btn.pressed.connect(func(): _on_use(captured_id))

	row.add_child(lbl_name)
	row.add_child(lbl_qty)
	row.add_child(btn)
	return wrap

func _on_use(item_id: String) -> void:
	AudioManager.play_sfx("menu_select")
	item_selected.emit(item_id)
