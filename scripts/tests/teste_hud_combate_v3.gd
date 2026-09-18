## Smoke test da HUD V3 sem autoloads, fórmulas ou cena oficial.
extends SceneTree

const Hud = preload("res://scripts/gameplay_v3/presentation/HudCombate3D.gd")

class PokemonFake extends Node:
	var nome_exibido := "Charizard"
	var nivel := 36
	var vida := 120
	var vida_maxima := 150
	var alpha := true
	var kit: Array = ["flamethrower", "slash", "fly", "dragon_claw", "scary_face"]
	func basico_pronto() -> bool: return true
	func skill_esfriando(indice: int) -> float: return 2.0 if indice == 1 else 0.0
	func golpe_do_slot(indice: int) -> Dictionary:
		return {"id": kit[indice], "name": "Golpe %d" % (indice + 1), "description": "Teste"}
	func usar_skill(_indice: int) -> Dictionary: return {"recusado": "teste"}

var ok := 0
var fail := 0
var _hud: CanvasLayer

func _conf(cond: bool, nome: String) -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s" % nome)

func _initialize() -> void:
	_hud = Hud.new()
	root.add_child(_hud)
	var pokemon := PokemonFake.new()
	root.add_child(pokemon)
	_hud.vincular_pokemon(pokemon)
	call_deferred("_conferir")

func _conferir() -> void:
	var estado: Dictionary = _hud.estado_visual()
	_conf(int(estado["slots"]) == 5, "renderiza a quantidade real de skills")
	_conf(int(estado["recarregando"]) == 1, "recarga vira estado indeterminado")
	_conf(bool(estado["alpha_visivel"]), "Alpha recebe indicador visual")
	_conf(str(estado["pokemon"]).contains("CHARIZARD"), "nome e nível chegam do runtime")
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
