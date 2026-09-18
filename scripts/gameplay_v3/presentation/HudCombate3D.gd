## HudCombate3D — apresentação incremental do Pokémon controlado na V3.
##
## Este componente não calcula dano, capacidade, duração de cooldown, tipos ou
## raridade. Ele recebe um `PokemonInstance3D` já montado e só apresenta seu
## estado público. Enquanto a V3 não expõe sinal de progresso de recarga, a HUD
## consulta o estado em baixa frequência e usa uma barra binária
## pronto/recarregando — nunca cria um percentual a partir de cooldown bruto.
class_name HudCombate3D
extends CanvasLayer

const MovePool = preload("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")
const INTERVALO_ATUALIZACAO := 0.10

var _pokemon: Node = null
var _event_bus: Node = null
var _tempo: float = 0.0
var _assinatura_kit := ""
var _slots: Array[Dictionary] = []

var _raiz: Control
var _nome: Label
var _vida: ProgressBar
var _vida_texto: Label
var _alpha: Label
var _basico: Label
var _aviso: Label
var _grade: GridContainer

func _ready() -> void:
	_montar()
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.connect("skill_anunciada", _ao_anunciar_skill)
		_event_bus.connect("skill_cancelada", _ao_cancelar_skill)
		_event_bus.connect("golpe_resolvido", _ao_resolver_golpe)
	get_viewport().size_changed.connect(_ajustar_layout)
	_ajustar_layout()

func _exit_tree() -> void:
	if is_instance_valid(_event_bus):
		if _event_bus.is_connected("skill_anunciada", _ao_anunciar_skill):
			_event_bus.disconnect("skill_anunciada", _ao_anunciar_skill)
		if _event_bus.is_connected("skill_cancelada", _ao_cancelar_skill):
			_event_bus.disconnect("skill_cancelada", _ao_cancelar_skill)
		if _event_bus.is_connected("golpe_resolvido", _ao_resolver_golpe):
			_event_bus.disconnect("golpe_resolvido", _ao_resolver_golpe)
	_pokemon = null
	_event_bus = null

## Porta pública de integração. A cena dona decide qual Pokémon o jogador
## controla; a HUD não procura nós a cada frame nem escolhe um por espécie.
func vincular_pokemon(pokemon: Node) -> void:
	_pokemon = pokemon
	_assinatura_kit = ""
	if _nome == null:
		call_deferred("_atualizar", true)
	else:
		_atualizar(true)

func desvincular_pokemon() -> void:
	_pokemon = null
	_assinatura_kit = ""
	_nome.text = "SEM POKÉMON ATIVO"
	_vida.value = 0.0
	_vida_texto.text = ""
	_alpha.hide()
	_basico.text = "BÁSICO"
	for slot in _slots:
		slot["container"].hide()

func estado_visual() -> Dictionary:
	var recarregando := 0
	for slot in _slots:
		if bool(slot.get("recarregando", false)):
			recarregando += 1
	return {
		"slots": _slots.size(),
		"recarregando": recarregando,
		"alpha_visivel": _alpha.visible,
		"pokemon": _nome.text,
	}

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo < INTERVALO_ATUALIZACAO:
		return
	_tempo = 0.0
	_atualizar()

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Interface"
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	painel.position = Vector2(18, 18)
	painel.custom_minimum_size = Vector2(300, 102)
	painel.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.04, 0.07, 0.88), 10))
	_raiz.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	painel.add_child(coluna)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 18)
	coluna.add_child(_nome)
	_alpha = Label.new()
	_alpha.text = "ALPHA · NÃO CAPTURÁVEL"
	_alpha.modulate = Color(1.0, 0.72, 0.22)
	_alpha.add_theme_font_size_override("font_size", 12)
	coluna.add_child(_alpha)
	_vida = ProgressBar.new()
	_vida.max_value = 1.0
	_vida.show_percentage = false
	_vida.custom_minimum_size = Vector2(276, 14)
	_estilizar_barra(_vida, Color(0.22, 0.82, 0.48))
	coluna.add_child(_vida)
	_vida_texto = Label.new()
	_vida_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vida_texto.add_theme_font_size_override("font_size", 12)
	coluna.add_child(_vida_texto)

	_basico = Label.new()
	_basico.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_basico.position = Vector2(-178, 20)
	_basico.size = Vector2(160, 30)
	_basico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_basico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_basico.add_theme_stylebox_override("normal", _caixa(Color(0.07, 0.20, 0.34, 0.88), 8))
	_raiz.add_child(_basico)

	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.position = Vector2(-170, 18)
	_aviso.size = Vector2(340, 34)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.add_theme_stylebox_override("normal", _caixa(Color(0.28, 0.09, 0.05, 0.90), 8))
	_aviso.hide()
	_raiz.add_child(_aviso)

	var fundo_skills := PanelContainer.new()
	fundo_skills.name = "PainelSkills"
	fundo_skills.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fundo_skills.position = Vector2(-208, -158)
	fundo_skills.size = Vector2(416, 140)
	fundo_skills.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.04, 0.07, 0.90), 10))
	_raiz.add_child(fundo_skills)
	_grade = GridContainer.new()
	_grade.add_theme_constant_override("h_separation", 8)
	_grade.add_theme_constant_override("v_separation", 8)
	fundo_skills.add_child(_grade)

func _atualizar(forcar_kit: bool = false) -> void:
	if not is_instance_valid(_pokemon):
		if _pokemon != null:
			desvincular_pokemon()
		return
	var nome := str(_pokemon.get("nome_exibido"))
	var nivel := int(_pokemon.get("nivel"))
	_nome.text = "%s  ·  NV.%d" % [nome.to_upper(), nivel]
	var atual := int(_pokemon.get("vida"))
	var maximo: int = max(1, int(_pokemon.get("vida_maxima")))
	_vida.value = clampf(float(atual) / float(maximo), 0.0, 1.0)
	_vida_texto.text = "%d / %d" % [atual, maximo]
	_alpha.visible = bool(_pokemon.get("alpha"))
	_basico.text = "BÁSICO · PRONTO" if bool(_pokemon.call("basico_pronto")) else "BÁSICO · RECARGANDO"
	_basico.modulate = Color(0.55, 0.88, 1.0) if bool(_pokemon.call("basico_pronto")) else Color(1.0, 0.68, 0.28)

	var kit: Array = _pokemon.get("kit")
	var assinatura: String = "|".join(PackedStringArray(kit.map(func(id): return str(id))))
	if forcar_kit or assinatura != _assinatura_kit:
		_assinatura_kit = assinatura
		_reconstruir_slots(kit)
	_atualizar_recargas()

func _reconstruir_slots(kit: Array) -> void:
	for antigo in _slots:
		antigo["container"].queue_free()
	_slots.clear()
	for indice in kit.size():
		var container := VBoxContainer.new()
		container.custom_minimum_size = Vector2(94, 52)
		_grade.add_child(container)
		var botao := Button.new()
		botao.custom_minimum_size = Vector2(94, 43)
		botao.focus_mode = Control.FOCUS_NONE
		var golpe: Dictionary = _pokemon.call("golpe_do_slot", indice)
		var nome := str(golpe.get("name", kit[indice])).to_upper()
		botao.text = "%s\n%s" % [MovePool.tecla_do_slot(indice).to_upper(), nome]
		botao.tooltip_text = str(golpe.get("description", nome))
		botao.pressed.connect(_ao_pressionar_skill.bind(indice))
		container.add_child(botao)
		var barra := ProgressBar.new()
		barra.custom_minimum_size = Vector2(94, 5)
		barra.max_value = 1.0
		barra.value = 1.0
		barra.show_percentage = false
		_estilizar_barra(barra, Color(0.38, 0.72, 1.0))
		container.add_child(barra)
		_slots.append({"container": container, "button": botao, "bar": barra, "slot": indice, "recarregando": false})
	_ajustar_layout()

func _atualizar_recargas() -> void:
	for slot in _slots:
		var indice: int = int(slot["slot"])
		var esfriando: bool = float(_pokemon.call("skill_esfriando", indice)) > 0.0
		var barra: ProgressBar = slot["bar"]
		barra.value = 0.0 if esfriando else 1.0
		barra.modulate = Color(1.0, 0.65, 0.28) if esfriando else Color.WHITE
		slot["button"].disabled = esfriando
		slot["recarregando"] = esfriando

func _ao_pressionar_skill(indice: int) -> void:
	if not is_instance_valid(_pokemon):
		return
	var resposta: Dictionary = _pokemon.call("usar_skill", indice)
	if resposta.has("recusado"):
		_mostrar_aviso(str(resposta["recusado"]))

func _ao_anunciar_skill(anuncio: Dictionary) -> void:
	_mostrar_aviso("AVISO · %s" % str(anuncio.get("nome", anuncio.get("golpe", "GOLPE"))).to_upper())

func _ao_cancelar_skill(_golpe: String) -> void:
	_aviso.hide()

func _ao_resolver_golpe(relatorio: Dictionary) -> void:
	var frase := str(relatorio.get("frase", ""))
	if not frase.is_empty():
		_mostrar_aviso(frase.to_upper())

func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.show()

func _ajustar_layout() -> void:
	if _grade == null:
		return
	var largura := get_viewport().get_visible_rect().size.x
	_grade.columns = max(1, min(_slots.size(), 4 if largura < 900.0 else 8))

func _estilizar_barra(barra: ProgressBar, cor: Color) -> void:
	barra.add_theme_stylebox_override("background", _caixa(Color(0.01, 0.015, 0.03, 0.88), 3))
	barra.add_theme_stylebox_override("fill", _caixa(cor, 3))

func _caixa(cor: Color, raio: int) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = cor
	caixa.corner_radius_top_left = raio
	caixa.corner_radius_top_right = raio
	caixa.corner_radius_bottom_left = raio
	caixa.corner_radius_bottom_right = raio
	caixa.content_margin_left = 10.0
	caixa.content_margin_right = 10.0
	caixa.content_margin_top = 6.0
	caixa.content_margin_bottom = 6.0
	return caixa
