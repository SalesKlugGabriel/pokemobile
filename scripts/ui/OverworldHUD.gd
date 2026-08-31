## OverworldHUD.gd — HUD do overworld: dinheiro, HP do lead e nome da zona.
extends CanvasLayer

@onready var label_money : Label = $HBox/LabelMoney
@onready var label_lead  : Label = $HBox/LabelLead
@onready var bar_hp      : ProgressBar = $HBox/BarHP
@onready var label_zone  : Label = $ZoneLabel

var _zone_names : Dictionary = {}

func _load_zone_names() -> void:
	var path := "res://data/world/zones.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var data = json.get_data()
	if data is Dictionary and data.has("zones"):
		for zone in data["zones"]:
			if zone.has("id") and zone.has("name"):
				_zone_names[zone["id"]] = zone["name"]
	_zone_names["pokemon_center"] = "Centro Pokémon"
	_zone_names["world_map"] = ""

func _ready() -> void:
	_load_zone_names()
	EventBus.game_saved.connect(_refresh)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.zone_changed.connect(_on_zone_changed)
	_refresh()

func _refresh() -> void:
	if not SaveManager.has_save():
		hide()
		return
	show()
	label_money.text = "₽%d" % SaveManager.get_money()
	var lead := SaveManager.get_pokemon_at(0)
	if lead.is_empty():
		label_lead.text = ""
		bar_hp.value = 0
		return
	var species_name : String = GameData.get_species(int(lead.get("species_id", 1))).get("name", "???")
	var nickname     : String = lead.get("nickname", "")
	var display_name : String = nickname if nickname != "" else species_name
	var hp_cur : int = lead.get("hp_current", 0)
	var hp_max : int = lead.get("hp_max", 1)
	label_lead.text  = "%s  Lv.%d" % [display_name, lead.get("level", 1)]
	bar_hp.max_value = hp_max
	bar_hp.value     = hp_cur
	# Coloração da barra por HP%
	var pct : float = float(hp_cur) / float(hp_max)
	if pct > 0.5:
		bar_hp.modulate = Color(0.2, 0.85, 0.2)
	elif pct > 0.25:
		bar_hp.modulate = Color(1.0, 0.85, 0.1)
	else:
		bar_hp.modulate = Color(0.9, 0.15, 0.15)

func _on_battle_ended(_result) -> void:
	_refresh()

func _on_zone_changed(zone_name: String) -> void:
	if not label_zone:
		return
	var display : String = _zone_names.get(zone_name, zone_name)
	if display.is_empty():
		label_zone.hide()
		return
	label_zone.text = display
	label_zone.show()
	# Fade out após 3 segundos
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label_zone, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		label_zone.modulate.a = 1.0
		label_zone.hide()
	)
