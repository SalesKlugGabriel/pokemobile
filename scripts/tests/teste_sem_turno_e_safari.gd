## teste_sem_turno_e_safari.gd — Nenhum combate por turno em lugar nenhum, e a
## Zona Safari em tempo real (06/09).
##
## Pedido direto do Gabriel: *"não quero esse modo de batalha em nenhum lugar do
## jogo, 100% player vs npc/Pokémon duelando sem turnos, quem usar a melhor
## combinação de elemento / efeitos / combos vai vencer por pura habilidade"*.
##
## Este arquivo substitui os dois testes que provavam o contrário
## (`teste_fase2_safari` e `teste_fase5_fase7_desligar_turno`, que afirmavam
## "a Safari continua por turno de propósito"). Não foram consertados: foram
## APOSENTADOS, porque o desenho que eles protegiam deixou de existir.
##
## O que se prova aqui é a ausência de uma coisa — e ausência é fácil de testar
## errado. Por isso a conferência é dupla: os ARQUIVOS do motor por turno não
## existem mais, E nenhum caminho vivo do jogo tenta chamá-los.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_sem_turno_e_safari.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: sem turno em lugar nenhum + Safari em tempo real (06/09) ===")

func _process(_delta: float) -> bool:
	_motor_por_turno_nao_existe()
	_ninguem_chama_o_turno()
	_safari_em_tempo_real()
	_item_equipado()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# 1. Os arquivos foram apagados de verdade
# ──────────────────────────────────────────────────────────────────────────
func _motor_por_turno_nao_existe() -> void:
	for caminho in [
		"res://scripts/battle/BattleManager.gd",
		"res://scripts/battle/BattleScene.gd",
		"res://scenes/battle/BattleScene.tscn",
		# O spawner legado ia junto: ele criava PokemonEntity, que era o outro
		# caminho vivo pro turno — e ele estava em Pallet/Rota 1/Viridian, ou
		# seja, no comecinho do jogo.
		"res://scripts/entities/PokemonEntity.gd",
		"res://scenes/entities/PokemonEntity.tscn",
		"res://scripts/world/PokemonSpawner.gd",
	]:
		_assert(not FileAccess.file_exists(caminho),
			"%s não existe mais" % caminho.get_file())

	var proj := FileAccess.get_file_as_string("res://project.godot")
	_assert(not proj.contains("BattleManager="),
		"BattleManager não é mais autoload")

	# Remover o SINAL, não só desconectar: sinal órfão é convite pra alguém
	# religar sem querer (risco nº 1 anotado no plano original do motor).
	var barramento := FileAccess.get_file_as_string("res://scripts/autoloads/EventBus.gd")
	_assert(not barramento.contains("signal wild_encounter_started"),
		"o sinal que abria a tela de turno foi removido do barramento")

# ──────────────────────────────────────────────────────────────────────────
# 2. E nenhum código vivo tenta usá-los
# ──────────────────────────────────────────────────────────────────────────
func _ninguem_chama_o_turno() -> void:
	var suspeitos : Array = []
	for caminho in _listar("res://scripts"):
		if caminho.begins_with("res://scripts/tests"):
			continue
		for linha in FileAccess.get_file_as_string(caminho).split("\n"):
			var l := linha.strip_edges()
			if l.begins_with("#"):
				continue   # comentário citando a história é permitido
			if l.contains("BattleManager.") or l.contains("wild_encounter_started"):
				suspeitos.append("%s: %s" % [caminho.get_file(), l.substr(0, 60)])
	_assert(suspeitos.is_empty(),
		"nenhum código vivo chama o motor por turno (%s)" % str(suspeitos))

	# E nenhuma CENA instancia o que foi apagado.
	var cenas_ruins : Array = []
	for caminho in _listar("res://scenes"):
		if not caminho.ends_with(".tscn"):
			continue
		var texto := FileAccess.get_file_as_string(caminho)
		if texto.contains("BattleScene") or texto.contains("PokemonSpawner") or texto.contains("PokemonEntity.tscn"):
			cenas_ruins.append(caminho.get_file())
	_assert(cenas_ruins.is_empty(),
		"nenhuma cena instancia o motor antigo (%s)" % str(cenas_ruins))

# ──────────────────────────────────────────────────────────────────────────
# 3. A Safari virou tempo real — a mecânica foi PORTADA, não jogada fora
# ──────────────────────────────────────────────────────────────────────────
func _safari_em_tempo_real() -> void:
	_assert(RegrasSafari.e_safari("safari_zone"), "a zona é reconhecida")
	_assert(not RegrasSafari.e_safari("world_map"), "e o resto do mundo não é")

	# A regra que DEFINE a Safari em qualquer Pokémon: aqui não se luta.
	_assert(not RegrasSafari.pode_lutar("safari_zone"), "na Safari não se luta")
	_assert(RegrasSafari.pode_lutar("world_map"), "fora dela, luta-se normalmente")
	var follower := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(follower.contains("RegrasSafari.pode_lutar("),
		"e o seu Pokémon obedece a isso antes de usar qualquer golpe")
	var selvagem := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(selvagem.contains("_tick_safari("),
		"o selvagem também não ataca lá — ele só decide se vai embora")

	# 30 bolas por visita, e cada visita repõe.
	RegrasSafari.bolas = 3
	RegrasSafari.ao_entrar_na_zona()
	_assert(RegrasSafari.bolas == RegrasSafari.BOLAS_POR_VISITA,
		"cada visita repõe as %d Bolas Safari" % RegrasSafari.BOLAS_POR_VISITA)
	_assert(RegrasSafari.gastar_bola(), "gastar uma bola funciona")
	_assert(RegrasSafari.bolas == RegrasSafari.BOLAS_POR_VISITA - 1, "e a conta baixa")
	RegrasSafari.bolas = 0
	_assert(not RegrasSafari.gastar_bola(), "sem bola, não dá pra tentar")
	_assert(not RegrasSafari.tem_bola(), "e o jogo sabe disso")

	# Isca e pedra: a troca que substitui "lutar" num lugar onde não se luta.
	var alvo := Node.new()
	RegrasSafari.ao_entrar_na_zona()
	var fuga_base := RegrasSafari.chance_de_fuga(alvo)
	RegrasSafari.jogar_isca(alvo)
	_assert(RegrasSafari.chance_de_fuga(alvo) < fuga_base,
		"a isca acalma: ele foge menos")
	_assert(RegrasSafari.mult_captura(alvo) < 1.0,
		"e em troca fica mais difícil de capturar")
	RegrasSafari.ao_entrar_na_zona()
	RegrasSafari.jogar_pedra(alvo)
	_assert(RegrasSafari.chance_de_fuga(alvo) > fuga_base,
		"a pedra irrita: ele foge mais")
	_assert(RegrasSafari.mult_captura(alvo) > 1.0,
		"e em troca fica mais fácil de capturar")

	# Teto: jogar dez pedras não pode virar captura garantida.
	for _i in 20:
		RegrasSafari.jogar_pedra(alvo)
	_assert(RegrasSafari.mult_captura(alvo) <= RegrasSafari.MULT_MAX,
		"empilhar pedra tem teto (%.2f)" % RegrasSafari.mult_captura(alvo))
	_assert(RegrasSafari.chance_de_fuga(alvo) <= 1.0, "e a fuga nunca passa de 100%")
	RegrasSafari.esquecer(alvo)
	_assert(RegrasSafari.mult_captura(alvo) == 1.0,
		"quando o Pokémon sai de cena, os multiplicadores dele somem junto")
	alvo.free()

	# A captura na Safari usa as bolas da visita, não a mochila normal.
	var captura := FileAccess.get_file_as_string("res://scripts/combat/CaptureSystem.gd")
	_assert(captura.contains("RegrasSafari.gastar_bola()"),
		"capturar na Safari gasta uma Bola Safari")
	_assert(captura.contains("RegrasSafari.mult_captura("),
		"e a chance leva em conta a isca/pedra que você jogou")

	# As duas ações precisam existir como tecla, senão a mecânica não é jogável.
	var proj := FileAccess.get_file_as_string("res://project.godot")
	_assert(proj.contains("safari_isca="), "existe tecla pra isca")
	_assert(proj.contains("safari_pedra="), "existe tecla pra pedra")
	var treinador := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(treinador.contains("_acao_safari("), "e o jogador de fato as usa")

# ──────────────────────────────────────────────────────────────────────────
# 4. O que quase se perdeu junto com o motor apagado
# ──────────────────────────────────────────────────────────────────────────
## Apagar o combate por turno quase levou junto uma mecânica que não tinha nada
## a ver com turno: o item equipado dava +20% de dano do tipo dele, e essa regra
## só existia lá dentro. Ou seja, equipar item nunca fez nada no combate de
## verdade. Achado ao consertar um teste que citava a função apagada.
func _item_equipado() -> void:
	var itens = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	var algum := ""
	if itens is Dictionary:
		for id in itens:
			if str(itens[id].get("category", "")) == "held":
				algum = id
				break
	_assert(algum != "", "existem itens equipáveis no jogo (%s)" % algum)

	var calc := FileAccess.get_file_as_string("res://scripts/combat/DamageCalculator.gd")
	_assert(calc.contains("multiplicador_de_item_equipado("),
		"o bônus do item equipado vive no cálculo de dano em tempo real")
	var follower := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(follower.contains("\"held_item\": _item_equipado()"),
		"e o seu Pokémon informa o item que está segurando ao atacar")

	if algum != "":
		var dados : Dictionary = itens[algum]
		var tipo : String = str(dados.get("boost_type", ""))
		_assert(DamageCalculator.multiplicador_de_item_equipado(algum, tipo) > 1.0,
			"segurando %s, golpe de %s bate mais forte" % [algum, tipo])
		_assert(DamageCalculator.multiplicador_de_item_equipado(algum, "TipoQueNaoExiste") == 1.0,
			"e golpe de outro tipo não ganha nada")
		_assert(DamageCalculator.multiplicador_de_item_equipado("", tipo) == 1.0,
			"sem item equipado, nenhum bônus")

func _listar(pasta: String) -> Array:
	var achados : Array = []
	var d := DirAccess.open(pasta)
	if d == null:
		return achados
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var caminho := pasta.path_join(nome)
		if d.current_is_dir():
			achados.append_array(_listar(caminho))
		elif nome.ends_with(".gd") or nome.ends_with(".tscn"):
			achados.append(caminho)
		nome = d.get_next()
	d.list_dir_end()
	return achados

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
