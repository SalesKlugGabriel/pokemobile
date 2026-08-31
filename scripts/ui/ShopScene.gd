## ShopScene.gd — Loja: compra itens com dinheiro do jogador e vende itens
## do inventário por metade do preço (regra clássica dos jogos Pokémon).
## Pedido do Gabriel (2026-08-31): "loots vendáveis pra conseguir cash e
## comprar itens no shopping". Item de chave ("key") e de campo ("field",
## ex: bicicleta) não entram na loja — não fazem sentido comprados/vendidos.
extends CanvasLayer

signal closed_by_user()

const EXCLUDED_CATEGORIES := ["key", "field"]
const SELL_RATIO := 0.5

@onready var panel        : Panel           = $Panel
@onready var title_label  : Label           = $Panel/Header/Title
@onready var money_label  : Label           = $Panel/Header/MoneyLabel
@onready var close_btn    : Button          = $Panel/Header/CloseBtn
@onready var btn_buy_tab  : Button          = $Panel/TabBar/BtnBuyTab
@onready var btn_sell_tab : Button          = $Panel/TabBar/BtnSellTab
@onready var list         : VBoxContainer   = $Panel/Scroll/List

var _mode : String = "buy"  # "buy" ou "sell"

func _ready() -> void:
	layer = 60
	panel.hide()
	close_btn.pressed.connect(close)
	btn_buy_tab.pressed.connect(func(): _set_mode("buy"))
	btn_sell_tab.pressed.connect(func(): _set_mode("sell"))

func open() -> void:
	_set_mode("buy")
	panel.show()
	AudioManager.play_sfx("menu_open")

func close() -> void:
	panel.hide()
	AudioManager.play_sfx("cancel")
	closed_by_user.emit()

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
		if price <= 0 or item.get("category", "") in EXCLUDED_CATEGORIES:
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
		if price <= 0 or item.get("category", "") in EXCLUDED_CATEGORIES:
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

func _make_row(item_id: String, item: Dictionary, unit_price: int, is_buy: bool, qty: int = -1) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

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
	return row

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
