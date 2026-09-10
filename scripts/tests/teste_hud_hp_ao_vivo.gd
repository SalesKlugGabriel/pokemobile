## teste_hud_hp_ao_vivo.gd — 10/09, achado pelo feedback real do Gabriel:
## "meu pokemon morre no primeiro ataque que recebe, e a barra de vida
## continua cheia no mostrador". FollowerPokemon.take_damage() sempre emitiu
## EventBus.follower_hp_changed — mas o único listener em todo o jogo era o
## TutorialManager (aviso de "use uma poção"). O HUD só redesenhava a barra
## via _refresh(), disparado por game_saved, que lê hp_current do SAVE —
## e o save não é escrito a cada golpe. A barra congelava no valor de antes
## da luta começar, inclusive quando o Pokémon desmaiava de verdade.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false
var EventBus : Node

func _initialize() -> void:
	print("=== Teste: barra de HP do HUD reage ao vivo (10/09) ===")
	EventBus = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var hud_scene : PackedScene = load("res://scenes/ui/OverworldHUD.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	# Dano ao vivo — o caminho que faltava.
	EventBus.follower_hp_changed.emit(40, 100)
	_assert(hud.bar_hp.value == 40.0, "follower_hp_changed atualiza a barra na hora, sem precisar salvar")
	_assert(hud.bar_hp.modulate == Color(1.0, 0.85, 0.1), "40/100 (40%) fica amarelo — abaixo de 50%, acima de 25%")

	# Um hit que mata de vez (o caso exato do relato: "morre no primeiro
	# ataque"): a barra tem que ir a ZERO, não ficar parada em cheia.
	EventBus.follower_hp_changed.emit(0, 100)
	_assert(hud.bar_hp.value == 0.0, "HP a 0 (desmaiou) zera a barra de verdade")
	_assert(hud.bar_hp.modulate == Color(0.9, 0.15, 0.15), "0% fica vermelho")

	# Cura de campo (outro caminho que já emitia o sinal) também reflete.
	EventBus.follower_hp_changed.emit(85, 100)
	_assert(hud.bar_hp.value == 85.0, "curar em campo também atualiza a barra na hora")
	_assert(hud.bar_hp.modulate == Color(0.2, 0.85, 0.2), "85% fica verde")

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
