## StubBattleScene.gd — dublê de BattleScene pra testes headless de
## BattleManager (sem cena real/UI). Implementa só os métodos que os fluxos
## testados chamam. Usado por teste_fase2_safari.gd.
extends Node

func show_message(msg: String) -> void:
	print("  [msg] %s" % msg)

func show_action_menu() -> void:
	print("  [menu] show_action_menu")

func animate_capture(shakes: int) -> void:
	print("  [capture] shakes=%d" % shakes)

func update_hud(_p, _e) -> void:
	pass

func refresh_player_pokemon(_p) -> void:
	pass

func refresh_enemy_pokemon(_e) -> void:
	pass
