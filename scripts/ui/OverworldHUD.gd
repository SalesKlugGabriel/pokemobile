## OverworldHUD.gd — HUD do overworld: dinheiro, HP do lead e nome da zona.
extends CanvasLayer

@onready var label_money : Label = $HBox/LabelMoney
@onready var label_lead  : Label = $HBox/LabelLead
@onready var bar_hp      : ProgressBar = $HBox/BarHP
@onready var label_zone  : Label = $ZoneLabel
@onready var label_mode  : Label = $ModePanel/LabelMode
@onready var mode_panel  : PanelContainer = $ModePanel
@onready var btn_fly     : Button = $BtnFly

var _zone_names : Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# Skills visíveis + tocáveis no HUD (Fase 9 do motor de combate em tempo
# real, 02/09) — pedido do Gabriel: "skills visiveis ou atreladas a botões
# de ação". Cada slot é um Button de verdade (funciona em tela sensível ao
# toque, não só teclado — o atalho de tecla continua funcionando igual,
# rebindável agora via KeybindManager, ver skill_1-4 em REBINDABLE_ACTIONS)
# com o nome do golpe, e uma barrinha fina de cooldown embaixo.
# EventBus.follower_skill_cooldown_updated já era emitido desde a Fase 0.5,
# só nunca tinha ninguém escutando. Construído em código (não editando o
# .tscn) pra reduzir risco de mexer numa cena que já tem vários nós à mão.
# ──────────────────────────────────────────────────────────────────────────────
const SKILL_BTN_SIZE : Vector2 = Vector2(52, 30)
const SKILL_BAR_SIZE : Vector2 = Vector2(52, 5)
var _skill_bars    : Array[ProgressBar] = []
var _skill_buttons : Array[Button]      = []

func _build_skill_cooldown_bars() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	for i in 4:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)

		var btn := Button.new()
		btn.custom_minimum_size = SKILL_BTN_SIZE
		btn.text = "—"
		btn.disabled = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_skill_button_pressed.bind(i))
		col.add_child(btn)
		_skill_buttons.append(btn)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = SKILL_BAR_SIZE
		bar.max_value = 1.0
		bar.value = 1.0
		bar.show_percentage = false
		bar.modulate = Color(0.4, 0.8, 1.0)
		col.add_child(bar)
		_skill_bars.append(bar)

	# Ancora e centraliza SÓ DEPOIS de todos os filhos existirem — chamar
	# set_anchors_preset() antes (com o row ainda vazio, tamanho 0x0) calcula
	# o offset errado e os botões nascem fora da tela (achado ao testar no
	# navegador: nada aparecia). PRESET_MODE_KEEP_SIZE preserva o tamanho já
	# calculado pelo HBoxContainer em vez de zerar de novo.
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	# PRESET_CENTER_BOTTOM deixa a BORDA DE CIMA do row exatamente na borda
	# inferior da tela (todo o row fica pra fora, corte confirmado ao testar
	# no navegador) — sobe a altura inteira do row + uma margem, não só um
	# empurrãozinho.
	row.position -= Vector2(0, SKILL_BTN_SIZE.y + SKILL_BAR_SIZE.y + 2.0 + 20.0)

## Toque/clique no botão dispara a skill igual apertar a tecla — mesmo
## caminho (FollowerPokemon.use_skill), então cooldown/alvo/área funcionam
## idêntico às duas formas de acionar.
func _on_skill_button_pressed(slot: int) -> void:
	var follower := get_tree().get_first_node_in_group("follower_pokemon")
	if follower and follower.has_method("use_skill"):
		follower.use_skill(slot)

## Atualiza nome/estado dos 4 botões quando o Follower muda (troca de líder,
## captura nova, etc.) — pokemon_data.moves já vem pronto de
## FollowerPokemon._build_pokemon_data(), não precisa reconsultar nada.
func _on_follower_changed(pokemon_data: Dictionary) -> void:
	var moves : Array = pokemon_data.get("moves", [])
	for i in _skill_buttons.size():
		var move_id : String = str(moves[i]) if i < moves.size() else ""
		if move_id.is_empty():
			_skill_buttons[i].text = "—"
			_skill_buttons[i].disabled = true
		else:
			var move_data : Dictionary = GameData.get_move(move_id)
			var nome : String = str(move_data.get("name", move_id))
			_skill_buttons[i].text = nome.substr(0, 9)
			_skill_buttons[i].disabled = false

## Textos e cor por marcha — sprite do jogador ainda não muda de aparência
## por marcha (pendente, ver docs/customizacao-personagem.md), então isso é
## o feedback visual real por enquanto. "walk" fica sem indicador (é o
## padrão, não precisa avisar).
## Sem emoji de propósito — a fonte padrão do projeto não tem cobertura
## garantida pra esses glyphs (achado ao revisar: só ₽ era usado até aqui,
## que é BMP; emoji de bike/cavalo/onda são fora do BMP, risco de "tofu").
const MODE_INFO := {
	"bike":  {"text": "BICICLETA", "color": Color(0.55, 0.85, 1.0)},
	"mount": {"text": "MONTARIA",  "color": Color(0.95, 0.75, 0.3)},
	"surf":  {"text": "SURFANDO",  "color": Color(0.3, 0.7, 1.0)},
	"fly":   {"text": "VOANDO",    "color": Color(0.85, 0.85, 1.0)},
}

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
	EventBus.movement_mode_changed.connect(_on_movement_mode_changed)
	EventBus.follower_skill_cooldown_updated.connect(_on_skill_cooldown_updated)
	EventBus.follower_changed.connect(_on_follower_changed)
	btn_fly.pressed.connect(_on_btn_fly_pressed)
	mode_panel.hide()
	_build_skill_cooldown_bars()
	_refresh()

## progress: 0.0 (acabou de usar) → 1.0 (pronta de novo). Emitido só enquanto
## a skill está recarregando (FollowerPokemon._tick_cooldowns()) — por isso a
## barra já nasce cheia (pronta) e só "esvazia e enche" quando usada.
func _on_skill_cooldown_updated(slot: int, progress: float) -> void:
	if slot < 0 or slot >= _skill_bars.size():
		return
	var bar := _skill_bars[slot]
	bar.value = progress
	bar.modulate = Color(0.4, 0.8, 1.0) if progress >= 1.0 else Color(1.0, 0.6, 0.2)

func _refresh() -> void:
	if not SaveManager.has_save():
		hide()
		return
	show()
	label_money.text = "₽%d" % SaveManager.get_money()
	# "Teleporte" (golpe, tipo Psíquico) — corrigido 02/09 (sessão seguinte):
	# era Voador/"fly" até aqui, mas isso é a mecânica de movimento (Voar,
	# ver TrainerEntity.gd), não teleporte.
	btn_fly.visible = SaveManager.team_has_move_of_type("teleport", "Psychic")
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

## Feedback de qual marcha está ativa (Bicicleta/Montaria/Surfando/Voando) —
## sprite do jogador ainda não muda de aparência por marcha, isso cobre o
## "o jogador precisa perceber que mudou" por enquanto. "walk" (a pé) some
## o indicador, é o padrão e não precisa avisar.
func _on_movement_mode_changed(mode: String) -> void:
	if not MODE_INFO.has(mode):
		mode_panel.hide()
		return
	var info : Dictionary = MODE_INFO[mode]
	label_mode.text = info["text"]
	label_mode.modulate = info["color"]
	mode_panel.show()

## Botão "Teleporte" da HUD — abre o seletor de destino direto, sem passar
## pelo menu de pausa inteiro (pedido do Gabriel: acesso às funções sem
## pausar pra navegar menu). PauseMenu.gd é quem sabe as cidades/warp de
## verdade — reaproveitado via grupo, não duplicado aqui.
func _on_btn_fly_pressed() -> void:
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("open_fly_picker_direct"):
		pause_menu.open_fly_picker_direct()

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
