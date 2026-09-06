## teste_sem_turno_e_captura.gd — Combate puro em todo lugar, e captura só
## depois de vencer (06/09).
##
## Duas regras do Gabriel, no mesmo dia, e a segunda completa a primeira:
##
##   1. *"não quero esse modo de batalha em nenhum lugar do jogo, 100% player vs
##      npc/Pokémon duelando sem turnos"* — o motor por turno foi apagado.
##   2. *"Safari também vai ser combate puro. No jogo inteiro a captura deve
##      acontecer depois de derrotar o Pokémon selvagem, aparecer uma sprite do
##      Pokémon derrotado desmaiado e então usar a pokebola"*.
##
## A segunda regra muda o significado da captura: ela deixa de ser "acertar uma
## bola num bicho que corre" e vira o **prêmio de ter vencido a luta**. E resolve
## sozinha uma contradição que existia com os lendários — antes, derrotar
## GASTAVA a chance de capturar; agora derrotar é o caminho até ela.
##
## Este arquivo já passou por duas gerações: nasceu provando que a Safari tinha
## regra própria (isca/pedra/bolas limitadas, portadas do turno) e foi reescrito
## quando o Gabriel disse que lá também é combate puro. O que ele prova agora é
## que **não existe exceção em lugar nenhum**.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_sem_turno_e_captura.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: combate puro em todo lugar + captura só após derrota (06/09) ===")

func _process(_delta: float) -> bool:
	_motor_por_turno_nao_existe()
	_ninguem_chama_o_turno()
	_safari_sem_regra_propria()
	_captura_exige_derrota()
	_item_equipado()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# 1. Os arquivos do motor por turno foram apagados de verdade
# ──────────────────────────────────────────────────────────────────────────
func _motor_por_turno_nao_existe() -> void:
	for caminho in [
		"res://scripts/battle/BattleManager.gd",
		"res://scripts/battle/BattleScene.gd",
		"res://scenes/battle/BattleScene.tscn",
		# O spawner legado ia junto: ele criava PokemonEntity, que era o outro
		# caminho vivo pro turno — e estava em Pallet/Rota 1/Viridian, ou seja,
		# no comecinho do jogo.
		"res://scripts/entities/PokemonEntity.gd",
		"res://scenes/entities/PokemonEntity.tscn",
		"res://scripts/world/PokemonSpawner.gd",
	]:
		_assert(not FileAccess.file_exists(caminho), "%s não existe mais" % caminho.get_file())

	var proj := FileAccess.get_file_as_string("res://project.godot")
	_assert(not proj.contains("BattleManager="), "BattleManager não é mais autoload")

	# Remover o SINAL, não só desconectar: sinal órfão é convite pra alguém
	# religar sem querer.
	var barramento := FileAccess.get_file_as_string("res://scripts/autoloads/EventBus.gd")
	_assert(not barramento.contains("signal wild_encounter_started"),
		"o sinal que abria a tela de turno foi removido do barramento")

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
	_assert(suspeitos.is_empty(), "nenhum código vivo chama o motor por turno (%s)" % str(suspeitos))

	var cenas_ruins : Array = []
	for caminho in _listar("res://scenes"):
		if not caminho.ends_with(".tscn"):
			continue
		var texto := FileAccess.get_file_as_string(caminho)
		if texto.contains("BattleScene") or texto.contains("PokemonSpawner") or texto.contains("PokemonEntity.tscn"):
			cenas_ruins.append(caminho.get_file())
	_assert(cenas_ruins.is_empty(), "nenhuma cena instancia o motor antigo (%s)" % str(cenas_ruins))

# ──────────────────────────────────────────────────────────────────────────
# 2. A Safari não tem mais NENHUMA regra própria
# ──────────────────────────────────────────────────────────────────────────
## Ela chegou a ter (isca, pedra, 30 bolas por visita, ninguém ataca) — portadas
## do motor por turno algumas horas antes. O Gabriel então disse que lá também é
## combate puro, e a exceção inteira foi apagada. Este bloco existe pra ela não
## voltar de fininho: um lugar do mapa com regra de combate própria é
## exatamente o que ele não quer.
func _safari_sem_regra_propria() -> void:
	_assert(not FileAccess.file_exists("res://scripts/world/systems/RegrasSafari.gd"),
		"o arquivo de regras da Safari não existe mais")

	var vivos : Array = []
	for caminho in _listar("res://scripts"):
		if caminho.begins_with("res://scripts/tests"):
			continue
		for linha in FileAccess.get_file_as_string(caminho).split("\n"):
			var l := linha.strip_edges()
			if l.begins_with("#") or l.begins_with("##"):
				continue
			if l.contains("RegrasSafari") or l.contains("safari_isca") or l.contains("safari_pedra"):
				vivos.append("%s: %s" % [caminho.get_file(), l.substr(0, 50)])
	_assert(vivos.is_empty(), "nenhum código trata a Safari como caso especial (%s)" % str(vivos))

	var proj := FileAccess.get_file_as_string("res://project.godot")
	_assert(not proj.contains("safari_isca=") and not proj.contains("safari_pedra="),
		"as teclas de isca/pedra saíram do mapa de input")

	# E o combate lá funciona igual: nem o seu Pokémon nem o selvagem consultam
	# a zona antes de atacar.
	var follower := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(not follower.contains("pode_lutar("), "seu Pokémon ataca na Safari como em qualquer lugar")
	var selvagem := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(not selvagem.contains("_tick_safari("), "e o selvagem também luta lá")

# ──────────────────────────────────────────────────────────────────────────
# 3. A regra nova: derrotar primeiro, capturar depois
# ──────────────────────────────────────────────────────────────────────────
func _captura_exige_derrota() -> void:
	var selvagem := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(selvagem.contains("func esta_desmaiado()"),
		"o selvagem sabe dizer se está desmaiado")
	_assert(selvagem.contains("func _ficar_desmaiado()"),
		"e derrotá-lo o deixa desmaiado em vez de apagá-lo")

	# O corpo tem que FICAR na cena: se sumisse, não haveria em que jogar a bola.
	var i_desmaia := selvagem.find("_ficar_desmaiado()")
	var i_free := selvagem.find("queue_free()", selvagem.find("func _die()"))
	_assert(i_desmaia > 0, "o caminho de derrota chama o desmaio")
	_assert(selvagem.contains("if is_trainer_owned:\n\t\tqueue_free()\n\telse:\n\t\t_ficar_desmaiado()"),
		"só o Pokémon de treinador some ao cair — o selvagem fica caído no chão")

	# Leitura na tela: sem arte nova, deitar e apagar a cor é o que diz "caiu".
	_assert(selvagem.contains("sprite.rotation"), "o sprite deita quando desmaia")
	_assert(selvagem.contains("sprite.modulate = Color(0.65"), "e perde a cor")
	_assert(selvagem.contains("Jogue uma Pokébola"),
		"e o jogo diz o que fazer em seguida, em vez de deixar adivinhar")

	# O corpo tem prazo — senão o mapa vira um cemitério de Pokémon capturáveis.
	_assert(selvagem.contains("SEGUNDOS_DESMAIADO"), "o corpo desaparece depois de um tempo")
	var script_selvagem : GDScript = load("res://scripts/entities/WildPokemon.gd")
	var consts := script_selvagem.get_script_constant_map()
	var prazo : float = float(consts.get("SEGUNDOS_DESMAIADO", 0.0))
	_assert(prazo >= 10.0 and prazo <= 60.0,
		"e o prazo é jogável: %.0fs (dá tempo de chegar perto e tentar mais de uma vez)" % prazo)

	# A trava de verdade, no sistema de captura.
	var captura := FileAccess.get_file_as_string("res://scripts/combat/CaptureSystem.gd")
	_assert(captura.contains("esta_desmaiado()"),
		"a captura confere se o Pokémon foi derrotado")
	var i_trava := captura.find("esta_desmaiado()")
	var i_salva := captura.find("SaveManager.add_pokemon(")
	_assert(i_trava > 0 and i_salva > i_trava,
		"e a trava vem ANTES de guardar o Pokémon — não adianta conferir depois")

	# A bola mira o corpo caído, não o bicho de pé mais próximo.
	var treinador := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(treinador.contains("_corpo_desmaiado_perto()"),
		"a Pokébola procura o corpo caído mais perto")
	_assert(treinador.contains("Derrote-o primeiro"),
		"e explica o motivo quando há um selvagem de pé por perto")

	# Lendário: derrotar deixou de gastar a chance. O que gasta é o corpo
	# expirar sem captura — que é a leitura certa da regra nova.
	_assert(not selvagem.contains("NinhoLendario.marcar_derrotado(species_id)\n\t\t\tRecompensasDeCovil"),
		"derrotar o lendário não gasta mais a chance da partida")
	var i_expira := selvagem.find("Time.get_ticks_msec() < _desmaiado_ate_msec")
	var i_marca := selvagem.find("NinhoLendario.marcar_derrotado(")
	_assert(i_expira > 0 and i_marca > i_expira,
		"o lendário só se perde se o corpo dele expirar sem ser capturado")

# ──────────────────────────────────────────────────────────────────────────
# 4. O que quase se perdeu junto com o motor apagado
# ──────────────────────────────────────────────────────────────────────────
## O item equipado dava +20% de dano do tipo dele, e essa regra só existia
## dentro do combate por turno. Ou seja: equipar item nunca fez efeito nenhum no
## combate de verdade. Achado ao consertar um teste que citava a função apagada.
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
		var tipo : String = str(itens[algum].get("boost_type", ""))
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
