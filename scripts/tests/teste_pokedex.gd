## teste_pokedex.gd — A Pokédex que serve pra alguma coisa (09/09).
##
## O Gabriel: *"a pokebola está muito fraca, precisa ter uma aba de habilidades
## ensináveis, história do Pokémon, stats, nature, evoluções e níveis... também
## deve exibir os itens que cada Pokémon pode dropar"*.
##
## Até aqui a Pokédex era uma lista de 151 linhas com "visto/capturado" e nada
## mais — **clicar num Pokémon não fazia nada**. Não existia tela de detalhe.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_pokedex.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _process(_delta: float) -> bool:
	print("=== Teste: a ficha da Pokédex (09/09) ===")
	var ficha := FileAccess.get_file_as_string("res://scripts/ui/PokedexDetalhe.gd")
	var lista := FileAccess.get_file_as_string("res://scripts/ui/PokedexScene.gd")

	# ── 1. Dá pra chegar na ficha ──────────────────────────────────────────
	_assert(lista.contains("PokedexDetalhe.abrir("),
		"clicar num Pokémon abre a ficha — antes não fazia nada")
	_assert(lista.contains("if is_seen:"),
		"e só quem já foi visto tem ficha (abrir um '???' entregaria a surpresa)")

	# ── 2. As cinco abas que ele pediu ─────────────────────────────────────
	var script : GDScript = load("res://scripts/ui/PokedexDetalhe.gd")
	var abas : Array = script.get_script_constant_map().get("ABAS", [])
	for esperada in ["Status", "Golpes", "Evolução", "História", "Drops"]:
		_assert(esperada in abas, "existe a aba '%s'" % esperada)

	# ── 3. Cada aba mostra o que foi pedido ────────────────────────────────
	_assert(ficha.contains("base_stats"), "Status mostra os status base")
	_assert(ficha.contains("nature"), "e a natureza do exemplar capturado")
	_assert(ficha.contains("_meu_exemplar()"),
		"natureza vem do SEU Pokémon — natureza é do indivíduo, não da espécie")
	_assert(ficha.contains("learnsets.json"),
		"Golpes lê o learnsets.json (que existia e nunca tinha sido mostrado)")
	_assert(ficha.contains("evolution_condition"),
		"Evolução mostra a condição de cada passo")
	_assert(ficha.contains("_quem_evolui_para("),
		"e a linha inteira, não só daqui pra frente")

	# ── 4. A história não inventa fato ─────────────────────────────────────
	_assert(ficha.contains("catch_rate") and ficha.contains("biomes"),
		"a história é montada a partir do dado real da espécie")
	_assert(ficha.contains("nunca inventada") or ficha.contains("nunca afirma"),
		"e isso está escrito no arquivo, pra ninguém 'melhorar' o texto depois")

	# ── 5. A regra do otPokemon: drops só pra quem registrou ───────────────
	var i_drops := ficha.find("func _aba_drops")
	var i_trava := ficha.find("if not capturado:", i_drops)
	var i_lista := ficha.find("dados.get(\"drops\"", i_drops)
	_assert(i_drops > 0 and i_trava > i_drops and i_lista > i_trava,
		"os drops só aparecem depois de capturar — é o que faz registrar valer a pena")
	_assert(ficha.contains("vende por"),
		"e a ficha diz por quanto cada drop vende (o loot só vira economia se o jogador souber o preço)")

	# ── 6. Visto e capturado são coisas diferentes na tela ─────────────────
	_assert(lista.contains("CAPTURADO") and lista.contains("VISTO"),
		"visto e capturado têm marcação separada, como ele pediu")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
