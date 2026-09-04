## PartyScene.gd — Tela do Time: os Pokémon do jogador com sprite, nível, HP e
## golpes. Abre com Tab, fecha com Tab, Esc ou o X.
##
## Reescrita em 04/09 depois do teste de gameplay. O que estava errado na tela
## antiga, tudo visível numa captura só:
##   - título "PARTY" em inglês, num jogo em português;
##   - os golpes saíam como "? | ?" — o save guarda cada golpe como {id, pp...}
##     e a tela lia a chave "move_id", que não existe. Sempre caía no fallback;
##   - sem sprite: uma linha de texto pra representar o Pokémon;
##   - sem barra de HP, só o número — quem tem 10 anos lê a barra, não a fração;
##   - painel escuro sobre fundo escuro.
extends CanvasLayer

@onready var panel      : PanelContainer = $Panel
@onready var list       : VBoxContainer  = $Panel/Coluna/Scroll/List
@onready var btn_close  : Button         = $Panel/Coluna/Header/BtnClose

var _open : bool = false

## Cor da barra de vida pela proporção — mesma convenção do resto do jogo
## (barra do selvagem no mapa), pra não existirem duas leituras de "está mal".
const COR_HP_ALTO  := Color(0.35, 0.78, 0.32)
const COR_HP_MEDIO := Color(0.92, 0.75, 0.18)
const COR_HP_BAIXO := Color(0.85, 0.26, 0.22)

## Nome dos tipos em português. Fica aqui e não no species.json porque o JSON é
## o dado do jogo (usado por cálculo de dano, tabela de vantagem) — traduzir lá
## quebraria toda comparação de tipo.
const TIPO_PT := {
	"Normal": "Normal", "Fire": "Fogo", "Water": "Água", "Grass": "Planta",
	"Electric": "Elétrico", "Ice": "Gelo", "Fighting": "Lutador",
	"Poison": "Veneno", "Ground": "Terra", "Flying": "Voador",
	"Psychic": "Psíquico", "Bug": "Inseto", "Rock": "Pedra",
	"Ghost": "Fantasma", "Dragon": "Dragão", "Dark": "Sombrio",
	"Steel": "Aço", "Fairy": "Fada",
}

func _ready() -> void:
	panel.hide()
	btn_close.pressed.connect(_close)
	EventBus.party_opened.connect(_open_party)

func _unhandled_input(event: InputEvent) -> void:
	# Esc não aparece aqui de propósito: quem trata "voltar" é o UIStack, pelo
	# menu de Pausa, pra Esc ter o mesmo significado em toda tela do jogo.
	if event.is_action_pressed("menu_team"):
		get_viewport().set_input_as_handled()
		if _open:
			_close()
		else:
			_open_party()

func _open_party() -> void:
	_build_list()
	_open = true
	panel.show()
	get_tree().paused = true
	UIStack.empilhar(self, _close)

func _close() -> void:
	if not _open:
		return
	_open = false
	panel.hide()
	get_tree().paused = false
	UIStack.desempilhar(self)

func _build_list() -> void:
	for child in list.get_children():
		child.queue_free()

	var party : Array = SaveManager.get_team()
	if party.is_empty():
		var lbl := Label.new()
		lbl.text = "Nenhum Pokémon no time ainda."
		list.add_child(lbl)
		return

	for poke in party:
		list.add_child(_montar_card(poke))

func _montar_card(poke: Dictionary) -> Control:
	var species_id : int        = int(poke.get("species_id", 1))
	var species    : Dictionary = GameData.get_species(species_id)
	var apelido    : String     = str(poke.get("nickname", ""))
	var nome       : String     = apelido if apelido != "" else str(species.get("name", "???"))
	var nivel      : int        = int(poke.get("level", 1))
	var hp_cur     : int        = int(poke.get("hp_current", 0))
	var hp_max     : int        = maxi(1, int(poke.get("hp_max", 1)))

	var card := PanelContainer.new()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	card.add_child(linha)

	# ── sprite ────────────────────────────────────────────────────────────────
	linha.add_child(PokemonIcon.criar(species_id, 56, bool(poke.get("shiny", false))))

	# ── coluna de texto ───────────────────────────────────────────────────────
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	linha.add_child(col)

	var topo := Label.new()
	topo.text = "%s   Nv.%d" % [nome, nivel]
	topo.add_theme_font_size_override("font_size", 15)
	col.add_child(topo)

	var tipos : Array = species.get("types", [])
	var tipos_pt : Array[String] = []
	for t in tipos:
		tipos_pt.append(str(TIPO_PT.get(str(t), str(t))))
	if not tipos_pt.is_empty():
		var lbl_tipo := Label.new()
		lbl_tipo.text = " / ".join(tipos_pt)
		lbl_tipo.add_theme_font_size_override("font_size", 11)
		lbl_tipo.add_theme_color_override("font_color", Color(0.72, 0.78, 0.68))
		col.add_child(lbl_tipo)

	# ── barra de HP: a barra é o dado principal, o número é o detalhe ─────────
	var barra := ProgressBar.new()
	barra.max_value = hp_max
	barra.value = hp_cur
	barra.custom_minimum_size = Vector2(0, 14)
	barra.show_percentage = false
	var proporcao := float(hp_cur) / float(hp_max)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = COR_HP_ALTO if proporcao > 0.5 else (
		COR_HP_MEDIO if proporcao > 0.2 else COR_HP_BAIXO)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.12, 0.14, 0.11)
	barra.add_theme_stylebox_override("fill", preenchimento)
	barra.add_theme_stylebox_override("background", fundo)
	col.add_child(barra)

	var lbl_hp := Label.new()
	lbl_hp.text = "HP %d / %d" % [hp_cur, hp_max]
	lbl_hp.add_theme_font_size_override("font_size", 11)
	col.add_child(lbl_hp)

	# ── golpes ────────────────────────────────────────────────────────────────
	# O save guarda cada golpe como {id, pp_current, pp_max} (SaveManager.gd:7).
	# A tela antiga lia "move_id" — chave que não existe — e por isso mostrava
	# "?" pra todo golpe. Aceito as duas chaves pra não depender de qual sistema
	# gravou o Pokémon (captura em tempo real e ensino por item usam caminhos
	# diferentes).
	var nomes : Array[String] = []
	for m in poke.get("moves", []):
		var id_golpe := ""
		if m is Dictionary:
			id_golpe = str(m.get("id", m.get("move_id", "")))
		else:
			id_golpe = str(m)
		if id_golpe.is_empty():
			continue
		var dados : Dictionary = GameData.get_move(id_golpe)
		nomes.append(str(dados.get("name", id_golpe)))
	var lbl_golpes := Label.new()
	lbl_golpes.text = ("Golpes: " + "  ·  ".join(nomes)) if not nomes.is_empty() \
		else "Ainda não sabe nenhum golpe."
	lbl_golpes.add_theme_font_size_override("font_size", 11)
	lbl_golpes.add_theme_color_override("font_color", Color(0.65, 0.7, 0.62))
	col.add_child(lbl_golpes)

	return card
