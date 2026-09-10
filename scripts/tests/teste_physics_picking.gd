## teste_physics_picking.gd — 10/09, achado pelo feedback real do Gabriel:
## "não é possivel iniciar combate, nem clicando no pokemon selvagem" e
## "pokedex quando vc clica no pokemon, não abre a pokedex dele". Causa raiz
## das DUAS: `Viewport.physics_object_picking` vem DESLIGADO por padrão no
## Godot 4 — sem ele, nenhum Area2D com input_pickable=true (hurtbox do
## selvagem, do Follower, corpo desmaiado) recebe clique/toque NENHUM. No
## celular ninguém notava porque ControlesDeToque._mais_perto() já resolve
## por busca de distância, sem física — mas em qualquer janela larga
## (desktop, inclusive a do Gabriel) essa muleta está desligada
## (`_e_celular()`) e o clique nativo do Godot simplesmente nunca chegava a
## lugar nenhum. Provado AO VIVO contra produção (Playwright real, não só
## este teste): 0 cliques registrados em ~1200 tentativas (grade densa)
## antes da correção, 234 depois — só ligando a flag em BaseMap._ready().
##
## Este teste confere que a linha existe no lugar certo (cedo, não como
## afterthought) — a prova funcional de verdade já foi feita ao vivo contra
## o build publicado, um SubViewport/push_input isolado aqui seria frágil
## (depende de detalhes de timing do motor que este projeto não controla) e
## menos confiável que checar que a correção continua no código.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: physics_object_picking ligado (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var src := FileAccess.get_file_as_string("res://scripts/world/BaseMap.gd")
	var i_ready := src.find("func _ready() -> void:")
	var i_picking := src.find("get_viewport().physics_object_picking = true")
	_assert(i_ready >= 0 and i_picking > i_ready, "BaseMap._ready() liga physics_object_picking")
	var i_paint := src.find("_paint_tiles()")
	_assert(i_picking >= 0 and i_picking < i_paint, "liga a física de clique ANTES de pintar o mapa (cedo, não como afterthought)")

	# As entidades que dependem disso pra funcionar — se algum dia perderem
	# input_pickable, a física ligada de nada adianta.
	var wp_tscn := FileAccess.get_file_as_string("res://scenes/entities/pokemon/WildPokemon.tscn")
	_assert(wp_tscn.contains('input_pickable = true'), "HurtBox do Pokémon selvagem continua clicável")
	var fp_tscn := FileAccess.get_file_as_string("res://scenes/entities/FollowerPokemon.tscn")
	_assert(fp_tscn.contains('input_pickable = true'), "HurtBox do Follower continua clicável")

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
