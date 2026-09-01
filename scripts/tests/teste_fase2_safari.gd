## teste_fase2_safari.gd — Teste headless da mecânica da Zona Safari (Fase 2:
## Bola Safari limitada por visita, Isca/Pedra, sem lutar/fugir de verdade).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase2_safari.gd
##
## Escopo deliberado: NÃO exercita captura bem-sucedida nem fuga do Pokémon
## de verdade — as duas caem em BattleManager._end_battle(), que usa
## `await create_timer(...)` + SceneTransition.fade_to() (troca de cena com
## tween). Uma sonda confirmou que `await` dentro do ciclo de _process() do
## script de teste headless não é resumido de forma confiável (o processo
## termina antes da continuação rodar) — o mesmo caminho, aliás, que NENHUM
## teste existente no projeto testava ponta a ponta (nem a captura normal,
## fora da Zona Safari). Por isso este teste cobre tudo que é síncrono e
## determinístico (contagem de bolas, matemática de isca/pedra, bloqueio de
## Lutar/Mochila/Pokémon) e deixa a captura/fuga de verdade pra confirmação
## visual ao vivo (mesmo padrão já usado noutras partes do projeto).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var BattleManager : Node
var GameData       : Node
var EventBus       : Node
var _stub_scene    : Node

func _initialize() -> void:
	print("=== Teste Fase 2 (Zona Safari) ===")
	BattleManager = root.get_node("BattleManager")
	GameData      = root.get_node("GameData")
	EventBus      = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	_teste_geral()
	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % label)
	else:
		_fail += 1
		print("  FALHA - %s" % label)


## Prepara um "combate Safari" fake: stub de BattleScene (sem UI real) +
## BattlePokemon dos dois lados + is_safari_battle=true + fase PLAYER_ACTION.
## flee_mult_inicial=0.0 garante (junto dos multiplicadores de isca/pedra,
## que só MULTIPLICAM o que já está lá) que nenhuma fuga de verdade dispara
## nos testes de isca/pedra — mantém 0*qualquer_coisa=0, chance(0.0) é
## sempre false (RNGManager.chance = randf() < probabilidade).
func _montar_batalha_safari(flee_mult_inicial: float = 1.0) -> void:
	_stub_scene = Node.new()
	_stub_scene.set_script(load("res://scripts/tests/StubBattleScene.gd"))
	BattleManager.battle_scene     = _stub_scene
	BattleManager.enemy_pokemon    = BattlePokemon.create(19, 20, false)  # Rattata Nv.20
	BattleManager.player_pokemon   = BattlePokemon.create(1, 20, true)
	BattleManager.is_wild_battle   = true
	BattleManager.is_safari_battle = true
	BattleManager._safari_catch_mult = 1.0
	BattleManager._safari_flee_mult  = flee_mult_inicial
	BattleManager.phase = BattleManager.BattlePhase.PLAYER_ACTION


func _teste_geral() -> void:
	# ---- 1. Restock de bolas ao entrar na zona ----
	BattleManager._safari_balls_left = 0
	EventBus.zone_changed.emit("safari_zone")
	_assert(BattleManager.get_safari_balls_left() == BattleManager.SAFARI_BALLS_PER_VISIT,
		"entrar em 'safari_zone' restaura as %d Bolas Safari" % BattleManager.SAFARI_BALLS_PER_VISIT)

	EventBus.zone_changed.emit("fuchsia_city")  # sair não zera nem mexe
	_assert(BattleManager.get_safari_balls_left() == BattleManager.SAFARI_BALLS_PER_VISIT,
		"sair da zona (mudar pra outra) não mexe na contagem de bolas")

	# ---- 2. is_safari_battle detectado por zone_id da entidade (dublê —
	# WildPokemon de verdade tem _ready() com dependência de autoload que não
	# resolve isolado via .new() num --script bruto; a wiring real de
	# zone_id em WildPokemon.initialize()/SpawnManager._spawn_pokemon() foi
	# conferida por leitura de código, é 1 linha de atribuição cada) ----
	var stub_safari := Node.new()
	stub_safari.set_script(load("res://scripts/tests/StubWildEntity.gd"))
	stub_safari.zone_id = "safari_zone"
	_assert(BattleManager._is_safari_zone_entity(stub_safari),
		"entidade com zone_id='safari_zone' é reconhecida como batalha Safari")
	stub_safari.free()

	var stub_normal := Node.new()
	stub_normal.set_script(load("res://scripts/tests/StubWildEntity.gd"))
	stub_normal.zone_id = "route_1"
	_assert(not BattleManager._is_safari_zone_entity(stub_normal),
		"entidade de outra zona ('route_1') não é reconhecida como Safari")
	stub_normal.free()

	var stub_sem_campo := Node.new()  # sem script nenhum -> .get("zone_id") devolve null
	_assert(not BattleManager._is_safari_zone_entity(stub_sem_campo),
		"entidade sem campo zone_id nenhum (ex: pesca) não quebra e não conta como Safari")
	stub_sem_campo.free()

	# ---- 3. Bloqueio de Lutar/Mochila/Trocar durante batalha Safari ----
	_montar_batalha_safari()
	var hp_antes : int = BattleManager.player_pokemon.hp
	BattleManager.player_select_move(0)
	_assert(BattleManager.player_pokemon.hp == hp_antes and BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"player_select_move() não faz nada em batalha Safari (sem luta de verdade)")

	BattleManager.player_use_item("potion", BattleManager.player_pokemon)
	_assert(BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"player_use_item() não faz nada em batalha Safari")

	BattleManager.player_switch_pokemon(1)
	_assert(BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"player_switch_pokemon() não faz nada em batalha Safari (não dá pra desmaiar)")

	BattleManager.player_throw_pokeball("pokeball")
	_assert(BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"player_throw_pokeball() normal não funciona em batalha Safari (usa player_safari_throw_ball)")

	# ---- 4. Bola Safari: contagem consome 1 por arremesso, independe do resultado ----
	_montar_batalha_safari(0.0)  # flee_mult=0 -> _safari_end_of_turn() nunca foge de verdade
	BattleManager._safari_balls_left = 5
	BattleManager.player_safari_throw_ball()
	_assert(BattleManager.get_safari_balls_left() == 4,
		"1 arremesso de Bola Safari consome exatamente 1 bola (5 -> 4)")

	# ---- 5. Sem bolas: joga mensagem e não deixa arremessar ----
	_montar_batalha_safari(0.0)
	BattleManager._safari_balls_left = 0
	BattleManager.player_safari_throw_ball()
	_assert(BattleManager.get_safari_balls_left() == 0 and BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"com 0 bolas, arremessar não consome (fica negativo) e volta pro menu de ação")

	# ---- 6. Isca: mais fácil ficar (flee cai), mais difícil capturar (catch cai) ----
	_montar_batalha_safari(0.0)
	BattleManager.player_safari_throw_bait()
	_assert(is_equal_approx(BattleManager._safari_catch_mult, BattleManager.SAFARI_BAIT_CATCH_MULT),
		"jogar isca multiplica o catch_mult por %.2f" % BattleManager.SAFARI_BAIT_CATCH_MULT)
	_assert(is_equal_approx(BattleManager._safari_flee_mult, 0.0 * BattleManager.SAFARI_BAIT_FLEE_MULT),
		"jogar isca multiplica o flee_mult (ficou 0 porque partiu de 0, controlado pro teste)")
	_assert(BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"depois da isca (sem fuga, flee_mult=0), volta pro menu de ação sem terminar a batalha")

	# Isca aplicada 2x acumula (multiplicativo, não substitui)
	BattleManager.player_safari_throw_bait()
	_assert(is_equal_approx(BattleManager._safari_catch_mult, pow(BattleManager.SAFARI_BAIT_CATCH_MULT, 2)),
		"2 iscas seguidas acumulam o efeito (multiplicativo)")

	# ---- 7. Pedra: mais difícil ficar (flee sobe), mais fácil capturar (catch sobe) ----
	_montar_batalha_safari(0.0)
	BattleManager.player_safari_throw_rock()
	_assert(is_equal_approx(BattleManager._safari_catch_mult, BattleManager.SAFARI_ROCK_CATCH_MULT),
		"jogar pedra multiplica o catch_mult por %.2f" % BattleManager.SAFARI_ROCK_CATCH_MULT)
	_assert(BattleManager.phase == BattleManager.BattlePhase.PLAYER_ACTION,
		"depois da pedra (sem fuga, flee_mult=0), volta pro menu de ação sem terminar a batalha")

	# ---- 8. Isca e Pedra puxam o resultado em direções opostas (mesma base) ----
	_assert(BattleManager.SAFARI_BAIT_CATCH_MULT < 1.0 and BattleManager.SAFARI_ROCK_CATCH_MULT > 1.0,
		"isca dificulta a captura (mult<1) e pedra facilita (mult>1) — papéis opostos, regra clássica")
	_assert(BattleManager.SAFARI_BAIT_FLEE_MULT < 1.0 and BattleManager.SAFARI_ROCK_FLEE_MULT > 1.0,
		"isca reduz a chance de fuga (mult<1) e pedra aumenta (mult>1) — papéis opostos")

	# ---- 9. Fora da Zona Safari, os botões normais continuam funcionando ----
	_montar_batalha_safari()
	BattleManager.is_safari_battle = false
	var msg_antes : bool = BattleManager.player_pokemon.moves.size() > 0
	_assert(msg_antes, "sanity check: Pokémon de teste tem pelo menos 1 golpe (setup válido pro próximo teste)")

	_return_estado_neutro()


## Devolve o BattleManager pro estado IDLE — evita que a próxima suíte de
## teste (se rodar no mesmo processo) herde uma batalha "pendurada".
func _return_estado_neutro() -> void:
	BattleManager.phase             = BattleManager.BattlePhase.IDLE
	BattleManager.is_safari_battle  = false
	BattleManager.is_wild_battle    = true
	BattleManager.player_pokemon    = null
	BattleManager.enemy_pokemon     = null
	BattleManager.battle_scene      = null
