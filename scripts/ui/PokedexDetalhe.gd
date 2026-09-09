## PokedexDetalhe.gd — A ficha de um Pokémon (09/09).
##
## Item 04 da fila. O Gabriel: *"a pokebola está muito fraca, precisa ter uma
## aba de habilidades ensináveis, história do Pokémon, stats, nature,
## evoluções e níveis... também deve exibir os itens que cada Pokémon pode
## dropar"*.
##
## Até aqui a Pokédex era uma lista de 151 linhas com "visto/capturado" e nada
## mais — não havia tela de detalhe nenhuma. Clicar num Pokémon não fazia nada.
##
## As cinco abas, e por que cada uma existe:
##   STATUS   — os números base, e a NATUREZA do exemplar que você capturou
##              (natureza é do indivíduo, não da espécie: só aparece se você tem).
##   GOLPES   — o que ele aprende e em que nível. O `learnsets.json` existe
##              desde sempre e nunca tinha sido mostrado em lugar nenhum.
##   EVOLUÇÃO — a linha inteira, com a condição de cada passo.
##   HISTÓRIA — escrita a partir do DADO REAL da espécie (tipos, altura, onde
##              vive, habilidade), nunca inventada. Um texto que afirma o que
##              o jogo não sabe é mentira bonita.
##   DROPS    — **só aparece se o Pokémon estiver REGISTRADO**. É a regra do
##              otPokemon, e é o que faz registrar a Pokédex valer alguma
##              coisa em vez de ser enfeite de colecionador.
class_name PokedexDetalhe
extends PanelContainer

const ABAS : Array[String] = ["Status", "Golpes", "Evolução", "História", "Drops"]

var _especie : int = 1
var _aba : String = "Status"
var _corpo : VBoxContainer = null
var _titulo : Label = null
var _linha_abas : HBoxContainer = null

static func abrir(pai: Node, species_id: int) -> PokedexDetalhe:
	var d := PokedexDetalhe.new()
	d._especie = species_id
	pai.add_child(d)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.offset_left = 40.0
	d.offset_top = 40.0
	d.offset_right = -40.0
	d.offset_bottom = -40.0
	d._montar()
	return d

func _montar() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	col.add_child(topo)
	topo.add_child(PokemonIcon.criar(_especie, 48))
	_titulo = Label.new()
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_font_size_override("font_size", 20)
	topo.add_child(_titulo)
	var fechar := Button.new()
	fechar.text = "Fechar (Esc)"
	fechar.pressed.connect(_fechar)
	topo.add_child(fechar)

	_linha_abas = HBoxContainer.new()
	_linha_abas.add_theme_constant_override("separation", 6)
	col.add_child(_linha_abas)
	for nome in ABAS:
		var b := Button.new()
		b.text = nome
		b.pressed.connect(func(): _trocar_aba(nome))
		_linha_abas.add_child(b)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(rolagem)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_corpo)

	set_process_unhandled_input(true)
	UIStack.empilhar(self, Callable(self, "_fechar"))
	_atualizar()

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_fechar()

func _fechar() -> void:
	UIStack.desempilhar(self)
	queue_free()

func _trocar_aba(nome: String) -> void:
	_aba = nome
	_atualizar()

func _atualizar() -> void:
	for filho in _corpo.get_children():
		filho.queue_free()
	var dados := GameData.get_species(_especie)
	var capturado := SaveManager.is_caught(_especie)
	_titulo.text = "#%03d  %s   %s" % [_especie, str(dados.get("name", "???")),
		"★ capturado" if capturado else "visto"]

	match _aba:
		"Status": _aba_status(dados)
		"Golpes": _aba_golpes()
		"Evolução": _aba_evolucao(dados)
		"História": _texto(_historia(dados))
		"Drops": _aba_drops(dados, capturado)

# ──────────────────────────────────────────────────────────────────────────
func _aba_status(dados: Dictionary) -> void:
	_texto("Tipos: %s" % ", ".join(dados.get("types", [])))
	_texto("Habilidade: %s" % str(dados.get("ability", "—")))
	var base : Dictionary = dados.get("base_stats", {})
	var rotulos := {"hp": "Vida", "attack": "Ataque", "defense": "Defesa",
		"sp_atk": "Ataque Esp.", "sp_def": "Defesa Esp.", "speed": "Velocidade"}
	for chave in rotulos:
		_barra(str(rotulos[chave]), int(base.get(chave, 0)))

	# NATUREZA é do indivíduo, não da espécie — só existe se o jogador tem um.
	var meu := _meu_exemplar()
	if meu.is_empty():
		_texto("\nNatureza: aparece quando você tiver um deste Pokémon.")
	else:
		_texto("\nSeu exemplar: nível %d · natureza %s" % [
			int(meu.get("level", 1)), str(meu.get("nature", "—"))])

func _aba_golpes() -> void:
	var lista : Array = _learnset()
	if lista.is_empty():
		_texto("Sem golpes cadastrados.")
		return
	_texto("O que ele aprende, e em que nível:")
	for entrada in lista:
		var golpe := GameData.get_move(str(entrada.get("move", "")))
		_texto("  Nv %2d  ·  %s  (%s)" % [int(entrada.get("level", 1)),
			str(golpe.get("name", entrada.get("move", "?"))),
			str(golpe.get("type", "?"))])

func _aba_evolucao(dados: Dictionary) -> void:
	var atual := _especie
	# Volta até o começo da linha pra mostrar a cadeia inteira, não só daqui
	# pra frente — quem abre um Charizard quer ver que ele vem do Charmander.
	var inicio := atual
	for _i in 5:
		var anterior := _quem_evolui_para(inicio)
		if anterior <= 0:
			break
		inicio = anterior
	var passo := inicio
	var linhas := 0
	while passo > 0 and linhas < 5:
		var d := GameData.get_species(passo)
		var marca : String = "  ← você está aqui" if passo == _especie else ""
		_texto("%s%s" % [str(d.get("name", "?")), marca])
		var seguinte : int = int(d.get("evolution_to", 0))
		if seguinte <= 0:
			break
		var cond : Dictionary = d.get("evolution_condition", {})
		var como := "nível %d" % int(cond.get("value", 0)) if str(cond.get("type", "")) == "level" \
			else str(cond.get("type", "?")) + " " + str(cond.get("value", ""))
		_texto("      ↓  (%s)" % como)
		passo = seguinte
		linhas += 1
	if linhas == 0:
		_texto("Este Pokémon não evolui.")

## 🔴 A regra do otPokemon: a lista de drops só aparece pra quem já REGISTROU o
## Pokémon. É o que transforma registrar a Pokédex em recompensa — antes,
## capturar marcava um X numa lista e não mudava nada no jogo.
func _aba_drops(dados: Dictionary, capturado: bool) -> void:
	if not capturado:
		_texto("Capture este Pokémon para descobrir o que ele deixa cair.")
		return
	var drops : Array = dados.get("drops", [])
	if drops.is_empty():
		_texto("Não deixa nada.")
		return
	for d in drops:
		var item := GameData.get_item(str(d.get("id", "")))
		var chance : float = float(d.get("chance", 0.0)) * 100.0
		var preco : int = int(item.get("price", 0))
		var valor : String = ""  if preco <= 0 else "  ·  vende por %d" % int(preco / 2)
		_texto("  %s  —  %.1f%%%s" % [str(item.get("name", d.get("id", "?"))), chance, valor])

# ──────────────────────────────────────────────────────────────────────────
## História montada a partir do dado REAL da espécie. Nenhuma frase afirma algo
## que o jogo não sabe — texto de Pokédex é lugar clássico pra inventar fato, e
## um fato inventado aqui vira contradição com a mecânica depois.
func _historia(dados: Dictionary) -> String:
	var nome := str(dados.get("name", "?"))
	var tipos : Array = dados.get("types", [])
	var altura := _altura()
	var biomas : Array = dados.get("biomes", [])
	var partes : Array = []

	partes.append("%s é um Pokémon do tipo %s." % [nome, " e ".join(tipos)])
	if altura > 0.0:
		var porte := "pequeno" if altura < 1.0 else ("médio" if altura < 2.0 else "grande")
		partes.append("Mede cerca de %.1f m — porte %s." % [altura, porte])
	if not biomas.is_empty():
		partes.append("Costuma ser encontrado em: %s." % ", ".join(biomas))
	var hab := str(dados.get("ability", ""))
	if hab != "":
		partes.append("Sua habilidade natural é %s." % hab)
	if int(dados.get("evolution_to", 0)) > 0:
		var cond : Dictionary = dados.get("evolution_condition", {})
		if str(cond.get("type", "")) == "level":
			partes.append("Ainda vai evoluir: acontece por volta do nível %d." % int(cond.get("value", 0)))
		else:
			partes.append("Ainda vai evoluir.")
	else:
		partes.append("Está na forma final da sua linha evolutiva.")
	var captura := int(dados.get("catch_rate", 45))
	if captura <= 10:
		partes.append("É raríssimo, e resiste muito à Pokébola.")
	elif captura >= 150:
		partes.append("É comum, e relativamente fácil de capturar.")
	return "\n".join(partes)

func _altura() -> float:
	var arq := FileAccess.get_file_as_string("res://data/pokemon/heights.json")
	var d = JSON.parse_string(arq)
	if d is Dictionary:
		return float(d.get(str(_especie), 0.0))
	return 0.0

func _learnset() -> Array:
	var arq := FileAccess.get_file_as_string("res://data/pokemon/learnsets.json")
	var d = JSON.parse_string(arq)
	if d is Dictionary and d.has(str(_especie)):
		return d[str(_especie)]
	return []

func _quem_evolui_para(destino: int) -> int:
	for id in range(1, 152):
		var d := GameData.get_species(id)
		if int(d.get("evolution_to", 0)) == destino:
			return id
	return 0

func _meu_exemplar() -> Dictionary:
	for poke in SaveManager.get_team():
		if int(poke.get("species_id", -1)) == _especie:
			return poke
	return {}

func _texto(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_child(l)

func _barra(rotulo: String, valor: int) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = rotulo
	l.custom_minimum_size = Vector2(110, 0)
	linha.add_child(l)
	var barra := ProgressBar.new()
	barra.max_value = 180.0
	barra.value = valor
	barra.custom_minimum_size = Vector2(220, 16)
	barra.show_percentage = false
	linha.add_child(barra)
	var n := Label.new()
	n.text = str(valor)
	linha.add_child(n)
	_corpo.add_child(linha)
