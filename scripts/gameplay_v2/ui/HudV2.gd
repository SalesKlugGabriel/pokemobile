## HUD mínima da Gameplay V2. Recebe valores prontos do gameplay e mantém
## apenas estado de apresentação (texto, barras, layout e feedback de toque).
class_name HudV2
extends CanvasLayer

signal skill_solicitada(slot: int)

@onready var painel_status : PanelContainer = $Interface/MargemSuperior/PainelStatus
@onready var margem_superior : MarginContainer = $Interface/MargemSuperior
@onready var nome_treinador : Label = $Interface/MargemSuperior/PainelStatus/Status/VidaTreinador/Nome
@onready var hp_treinador : ProgressBar = $Interface/MargemSuperior/PainelStatus/Status/VidaTreinador/HP
@onready var stamina : ProgressBar = $Interface/MargemSuperior/PainelStatus/Status/Folego/Barra
@onready var estado_stamina : Label = $Interface/MargemSuperior/PainelStatus/Status/Folego/Estado
@onready var nome_pokemon : Label = $Interface/MargemSuperior/PainelStatus/Status/VidaPokemon/Nome
@onready var hp_pokemon : ProgressBar = $Interface/MargemSuperior/PainelStatus/Status/VidaPokemon/HP
@onready var status_pokemon : Label = $Interface/MargemSuperior/PainelStatus/Status/VidaPokemon/Status
@onready var painel_alvo : PanelContainer = $Interface/MargemAlvo/PainelAlvo
@onready var margem_alvo : MarginContainer = $Interface/MargemAlvo
@onready var nome_alvo : Label = $Interface/MargemAlvo/PainelAlvo/Alvo/Nome
@onready var hp_alvo : ProgressBar = $Interface/MargemAlvo/PainelAlvo/Alvo/HP
@onready var detalhe_alvo : Label = $Interface/MargemAlvo/PainelAlvo/Alvo/Detalhe
@onready var ordem : Label = $Interface/Ordem
@onready var grade_skills : GridContainer = $Interface/MargemSkills/PainelSkills/Skills/Grade
@onready var margem_skills : MarginContainer = $Interface/MargemSkills
@onready var ajuda : Label = $Interface/Ajuda

var _botoes : Array[Button] = []
var _barras : Array[ProgressBar] = []
var _capacidade := 4
var _dados_skills : Array = []

func _ready() -> void:
	_criar_slots()
	_colorir_barras()
	get_viewport().size_changed.connect(_ajustar_layout)
	_ajustar_layout()

func aplicar_estado_inicial(snapshot: Dictionary) -> void:
	var t : Dictionary = snapshot.get("treinador", {})
	if not t.is_empty():
		atualizar_vida_treinador(
			int(t.get("vida", t.get("hp", 0))),
			int(t.get("vida_maxima", t.get("hp_max", 1))),
			str(t.get("nome", "TREINADOR")))
	if t.has("stamina"):
		atualizar_stamina(float(t.get("stamina", 0.0)),
			float(t.get("stamina_maxima", 1.0)), str(t.get("stamina_estado", "normal")))
	else:
		var f : Dictionary = snapshot.get("stamina", {})
		if not f.is_empty():
			atualizar_stamina(float(f.get("atual", 0.0)), float(f.get("maximo", 1.0)), str(f.get("estado", "normal")))
	var p : Dictionary = snapshot.get("pokemon", {})
	if not p.is_empty():
		atualizar_pokemon(p)
	else:
		atualizar_pokemon({})
	var alvo : Dictionary = snapshot.get("alvo", {})
	var alvo_id := int(p.get("alvo_id", 0))
	if alvo.is_empty() and alvo_id != 0:
		for candidato in snapshot.get("inimigos", []):
			if candidato is Dictionary and int(candidato.get("id", 0)) == alvo_id:
				alvo = candidato
				break
	atualizar_alvo(alvo)
	var o : Dictionary = snapshot.get("ordem", {})
	var tipo_ordem := str(p.get("ordem", o.get("tipo", "seguir")))
	atualizar_ordem(tipo_ordem, str(o.get("rotulo", alvo.get("nome", ""))))
	var skills : Array = p.get("kit", snapshot.get("skills", []))
	var capacidade := int(p.get("capacidade", snapshot.get("capacidade_skills", max(4, skills.size()))))
	atualizar_skills(skills, capacidade)

func atualizar_vida_treinador(atual: int, maximo: int, nome: String = "TREINADOR") -> void:
	nome_treinador.text = nome.to_upper()
	_definir_barra(hp_treinador, atual, maximo)

func atualizar_stamina(atual: float, maximo: float, estado: String) -> void:
	_definir_barra(stamina, atual, maximo)
	var info := _info_de_exaustao(estado)
	estado_stamina.text = str(info["texto"])
	estado_stamina.modulate = info["cor"]
	stamina.tooltip_text = "Stamina %.0f / %.0f — %s" % [atual, maximo, info["texto"]]

func atualizar_pokemon(dados: Dictionary) -> void:
	var ativo := not dados.is_empty() and bool(dados.get("ativo", true))
	nome_pokemon.text = str(dados.get("nome", "SEM POKÉMON")).to_upper()
	_definir_barra(hp_pokemon, int(dados.get("vida", dados.get("hp", 0))),
		int(dados.get("vida_maxima", dados.get("hp_max", 1))))
	hp_pokemon.visible = ativo
	status_pokemon.text = str(dados.get("status", "")).to_upper()
	status_pokemon.visible = ativo and not status_pokemon.text.is_empty() and status_pokemon.text != "NONE"

func atualizar_vida_pokemon(atual: int, maximo: int) -> void:
	_definir_barra(hp_pokemon, atual, maximo)

func atualizar_alvo(dados: Dictionary) -> void:
	var visivel := not dados.is_empty() and bool(dados.get("valido", true))
	painel_alvo.visible = visivel
	if not visivel:
		return
	nome_alvo.text = str(dados.get("nome", "ALVO")).to_upper()
	_definir_barra(hp_alvo, int(dados.get("vida", dados.get("hp", 0))),
		int(dados.get("vida_maxima", dados.get("hp_max", 1))))
	var nivel := int(dados.get("nivel", 0))
	var categoria := str(dados.get("categoria", "SELVAGEM")).to_upper()
	detalhe_alvo.text = "%s  •  NV.%d" % [categoria, nivel] if nivel > 0 else categoria

func atualizar_ordem(tipo: String, rotulo: String = "") -> void:
	var nomes := {
		"atacar": "ATACAR", "ir": "IR ATÉ", "seguir": "SEGUIR",
		"manter": "MANTER POSIÇÃO", "recuar": "RECUAR"
	}
	var texto : String = str(nomes.get(tipo, tipo.to_upper()))
	if not rotulo.is_empty():
		texto += "  ·  " + rotulo
	ordem.text = texto

## Cada entrada pode trazer `nome`, `atalho`, `disponivel` e `progresso` já
## normalizado pelo gameplay (0 acabou de usar; 1 está pronta).
func atualizar_skills(skills: Array, capacidade: int) -> void:
	_dados_skills = skills.duplicate(true)
	_capacidade = clampi(capacidade, 1, _botoes.size())
	for i in _botoes.size():
		var existe := i < _capacidade
		_botoes[i].visible = existe
		_barras[i].visible = existe
		if not existe:
			continue
		var dados : Dictionary = skills[i] if i < skills.size() and skills[i] is Dictionary else {}
		var nome := str(dados.get("nome", ""))
		var atalho := str(dados.get("atalho", i + 1))
		_botoes[i].text = "%s\n%s" % [atalho, nome.to_upper()] if not nome.is_empty() else "%s\nVAZIO" % atalho
		_botoes[i].disabled = nome.is_empty() or not bool(dados.get("disponivel", true))
		_botoes[i].tooltip_text = str(dados.get("descricao", nome))
		_barras[i].value = clampf(float(dados.get("progresso", 1.0)), 0.0, 1.0)
	_ajustar_layout()

func atualizar_recarga(slot: int, progresso: float) -> void:
	if slot < 0 or slot >= _barras.size():
		return
	_barras[slot].value = clampf(progresso, 0.0, 1.0)

func definir_ajuda(texto: String) -> void:
	ajuda.text = texto
	ajuda.visible = not texto.is_empty()

func contexto_feedback() -> Dictionary:
	var visiveis := 0
	var habilitados := 0
	var em_recarga := 0
	for i in _botoes.size():
		if not _botoes[i].visible:
			continue
		visiveis += 1
		if not _botoes[i].disabled:
			habilitados += 1
		if _barras[i].value < 1.0:
			em_recarga += 1
	var tamanho := get_viewport().get_visible_rect().size
	return {
		"viewport": tamanho,
		"orientacao": "portrait" if tamanho.y > tamanho.x else "landscape",
		"layout_compacto": tamanho.x < 900.0,
		"slots_visiveis": visiveis,
		"slots_habilitados": habilitados,
		"slots_em_recarga": em_recarga,
		"ordem": ordem.text,
		"alvo": nome_alvo.text if painel_alvo.visible else "",
	}

func _criar_slots() -> void:
	for i in 8:
		var coluna := VBoxContainer.new()
		coluna.custom_minimum_size = Vector2(96, 58)
		coluna.add_theme_constant_override("separation", 3)
		grade_skills.add_child(coluna)

		var botao := Button.new()
		botao.custom_minimum_size = Vector2(96, 48)
		botao.add_theme_font_size_override("font_size", 12)
		botao.focus_mode = Control.FOCUS_NONE
		botao.pressed.connect(_ao_pressionar_skill.bind(i))
		coluna.add_child(botao)
		_botoes.append(botao)

		var barra := ProgressBar.new()
		barra.custom_minimum_size = Vector2(96, 5)
		barra.max_value = 1.0
		barra.value = 1.0
		barra.show_percentage = false
		coluna.add_child(barra)
		_barras.append(barra)

func _ao_pressionar_skill(slot: int) -> void:
	skill_solicitada.emit(slot)

func _ajustar_layout() -> void:
	if not is_instance_valid(grade_skills):
		return
	ajustar_para_largura(get_viewport().get_visible_rect().size.x)

## Entrada pública também usada por testes e por containers que renderizam a
## HUD num SubViewport. A decisão continua sendo largura disponível, não device.
func ajustar_para_largura(largura: float) -> void:
	var compacto := largura < 900.0
	grade_skills.columns = min(_capacidade, 4 if compacto else 8)
	ajuda.visible = largura >= 700.0 and not ajuda.text.is_empty()
	if compacto:
		margem_superior.offset_right = -12.0
		margem_alvo.anchor_left = 0.0
		margem_alvo.anchor_right = 0.0
		margem_alvo.offset_left = 16.0
		margem_alvo.offset_top = 154.0
		margem_alvo.offset_right = minf(largura - 16.0, 420.0)
		margem_alvo.offset_bottom = 252.0
		ordem.offset_left = 16.0
		ordem.offset_top = 262.0
		ordem.offset_right = -16.0
		ordem.offset_bottom = 296.0
		margem_skills.offset_top = -176.0
	else:
		margem_superior.offset_right = -16.0
		margem_alvo.anchor_left = 1.0
		margem_alvo.anchor_right = 1.0
		margem_alvo.offset_left = -312.0
		margem_alvo.offset_top = 20.0
		margem_alvo.offset_right = -20.0
		margem_alvo.offset_bottom = 126.0
		ordem.offset_left = 480.0
		ordem.offset_top = 18.0
		ordem.offset_right = -480.0
		ordem.offset_bottom = 52.0
		margem_skills.offset_top = -164.0
	if largura < 560.0:
		painel_status.custom_minimum_size.x = minf(340.0, largura - 24.0)
	else:
		painel_status.custom_minimum_size.x = 430.0

func _colorir_barras() -> void:
	_definir_cor_barra(hp_treinador, Color("45c978"))
	_definir_cor_barra(stamina, Color("35d4c5"))
	_definir_cor_barra(hp_pokemon, Color("e6b94f"))
	_definir_cor_barra(hp_alvo, Color("ee6554"))

func _definir_cor_barra(barra: ProgressBar, cor: Color) -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.015, 0.025, 0.04, 0.82)
	fundo.corner_radius_top_left = 3
	fundo.corner_radius_top_right = 3
	fundo.corner_radius_bottom_left = 3
	fundo.corner_radius_bottom_right = 3
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = cor
	preenchimento.corner_radius_top_left = 3
	preenchimento.corner_radius_top_right = 3
	preenchimento.corner_radius_bottom_left = 3
	preenchimento.corner_radius_bottom_right = 3
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", preenchimento)

func _definir_barra(barra: ProgressBar, atual: float, maximo: float) -> void:
	barra.max_value = maxf(1.0, maximo)
	barra.value = clampf(atual, 0.0, barra.max_value)
	barra.tooltip_text = "%.0f / %.0f" % [atual, maximo]

func _info_de_exaustao(estado: String) -> Dictionary:
	match estado:
		"exaustao_1":
			return {"texto": "EXAUSTÃO I", "cor": Color(1.0, 0.82, 0.36)}
		"exaustao_2":
			return {"texto": "EXAUSTÃO II", "cor": Color(1.0, 0.55, 0.24)}
		"exaustao_3":
			return {"texto": "EXAUSTÃO III", "cor": Color(1.0, 0.28, 0.20)}
		_:
			return {"texto": "PRONTO", "cor": Color(0.48, 0.92, 0.72)}
