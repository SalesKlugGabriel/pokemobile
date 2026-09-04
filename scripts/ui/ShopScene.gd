## ShopScene.gd — Loja: compra itens com dinheiro do jogador e vende itens
## do inventário por metade do preço (regra clássica dos jogos Pokémon).
## Pedido do Gabriel (2026-08-31): "loots vendáveis pra conseguir cash e
## comprar itens no shopping", com aparência de loja de RPG (barra lateral
## de categorias com ícone, como referência mandada por ele). Item de chave
## ("key") e de campo ("field", ex: bicicleta) não entram na loja — não
## fazem sentido comprados/vendidos.
extends CanvasLayer

signal closed_by_user()

const CATEGORIES := ["medicine", "ball", "stone", "tm_hm", "battle", "vitamin"]
const CATEGORY_LABELS := {
	"medicine": "Poções",
	"ball":     "Poké Bolas",
	"stone":    "Pedras",
	"tm_hm":    "TM/HM",
	"battle":   "Itens de Batalha",
	"vitamin":  "Vitaminas",
}
const SELL_RATIO := 0.5

@onready var panel        : Panel           = $Panel
@onready var title_label  : Label           = $Panel/Header/Title
@onready var money_label  : Label           = $Panel/Header/MoneyLabel
@onready var close_btn    : Button          = $Panel/Header/CloseBtn
@onready var btn_buy_tab  : Button          = $Panel/TabBar/BtnBuyTab
@onready var btn_sell_tab : Button          = $Panel/TabBar/BtnSellTab
@onready var sidebar      : VBoxContainer   = $Panel/Body/Sidebar
@onready var list         : VBoxContainer   = $Panel/Body/Scroll/List

var _mode : String = "buy"  # "buy" ou "sell"
var _active_category : String = "medicine"
var _icon_cache : Dictionary = {}

func _ready() -> void:
	layer = 60
	panel.hide()
	close_btn.pressed.connect(close)
	btn_buy_tab.pressed.connect(func(): _set_mode("buy"))
	btn_sell_tab.pressed.connect(func(): _set_mode("sell"))
	_build_sidebar()

func open() -> void:
	_set_mode("buy")
	panel.show()
	UIStack.empilhar(self, close)
	AudioManager.play_sfx("menu_open")

func close() -> void:
	panel.hide()
	UIStack.desempilhar(self)
	AudioManager.play_sfx("cancel")
	closed_by_user.emit()

func _icon_for(category: String) -> Texture2D:
	if _icon_cache.has(category):
		return _icon_cache[category]
	var path := "res://assets/ui/icons/%s.png" % category
	var tex : Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[category] = tex
	return tex

func _build_sidebar() -> void:
	for child in sidebar.get_children():
		child.queue_free()
	for cat in CATEGORIES:
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
			_refresh()
		)
		sidebar.add_child(btn)

func _set_mode(mode: String) -> void:
	_mode = mode
	btn_buy_tab.button_pressed  = mode == "buy"
	btn_sell_tab.button_pressed = mode == "sell"
	_refresh()

func _refresh() -> void:
	money_label.text = "₽%d" % SaveManager.get_money()
	for child in list.get_children():
		child.queue_free()

	if _mode == "buy":
		_populate_buy()
	else:
		_populate_sell()

func _populate_buy() -> void:
	var any := false
	var ids := GameData.items.keys()
	ids.sort()
	for item_id in ids:
		var item : Dictionary = GameData.items[item_id]
		var price : int = int(item.get("price", 0))
		if price <= 0 or item.get("category", "") != _active_category:
			continue
		any = true
		list.add_child(_make_row(item_id, item, price, true))
	if not any:
		list.add_child(_empty_label())

func _populate_sell() -> void:
	var any := false
	var inv := SaveManager.get_inventory()
	var ids := inv.keys()
	ids.sort()
	for item_id in ids:
		var qty : int = int(inv[item_id])
		if qty <= 0:
			continue
		var item : Dictionary = GameData.get_item(item_id)
		var price : int = int(item.get("price", 0))
		if price <= 0 or item.get("category", "") != _active_category:
			continue
		any = true
		var sell_price := maxi(1, int(price * SELL_RATIO))
		list.add_child(_make_row(item_id, item, sell_price, false, qty))
	if not any:
		list.add_child(_empty_label())

func _empty_label() -> Label:
	var lbl := Label.new()
	lbl.text = "Nada aqui." if _mode == "buy" else "Nenhum item pra vender."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.5, 0.5, 0.5)
	return lbl

func _make_row(item_id: String, item: Dictionary, unit_price: int, is_buy: bool, qty: int = -1) -> PanelContainer:
	var wrap := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)

	var icon := TextureRect.new()
	icon.texture = _icon_for(item.get("category", ""))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var lbl_name := Label.new()
	var name_text : String = item.get("name", item_id)
	if qty > 0:
		name_text += " x%d" % qty
	lbl_name.text = name_text
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 14)
	var desc : String = item.get("description", "")
	if desc:
		lbl_name.tooltip_text = desc
	row.add_child(lbl_name)

	var lbl_price := Label.new()
	lbl_price.text = "₽%d" % unit_price
	lbl_price.custom_minimum_size = Vector2(60, 0)
	lbl_price.modulate = Color(0.7, 0.7, 0.7)
	row.add_child(lbl_price)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 0)
	if is_buy:
		btn.text = "Comprar"
		btn.disabled = SaveManager.get_money() < unit_price
		btn.pressed.connect(_on_buy.bind(item_id, unit_price))
	else:
		btn.text = "Vender"
		btn.pressed.connect(_on_sell.bind(item_id, unit_price))
	row.add_child(btn)
	return wrap

func _on_buy(item_id: String, price: int) -> void:
	if not SaveManager.spend_money(price):
		return
	SaveManager.add_item(item_id, 1)
	AudioManager.play_sfx("confirm")
	_refresh()

func _on_sell(item_id: String, price: int) -> void:
	if not SaveManager.remove_item(item_id, 1):
		return
	SaveManager.add_money(price)
	AudioManager.play_sfx("confirm")
	_refresh()
