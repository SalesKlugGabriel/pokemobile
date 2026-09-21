## Regressão da ligação HUD ↔ Laboratório.
## A HUD tem teste funcional próprio; aqui verificamos a ponte no dono da cena.
extends SceneTree

const LABORATORIO := "res://scripts/gameplay_v3/Laboratorio3D.gd"

var ok := 0
var fail := 0

func _conf(condicao: bool, nome: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", nome)
	else:
		fail += 1
		push_error("FALHA: " + nome)

func _initialize() -> void:
	# Carregar a cena em `--script` força entidades que referenciam o autoload
	# GameData como identificador; isso é limitação do runner, não desta ponte.
	var fonte := FileAccess.get_file_as_string(LABORATORIO)
	_conf(not fonte.is_empty(), "fonte do Laboratório existe")
	_conf(fonte.contains("var hud_de_combate : HudCombate3D"),
		"Laboratório declara a HUD, não uma segunda interface")
	_conf(fonte.contains("_montar_hud_de_combate()"), "Laboratório monta a HUD na abertura")
	_conf(fonte.contains("HudCombate3D.new()"), "monta a HUD existente")
	_conf(fonte.contains("hud_de_combate.show()") and fonte.contains("hud_de_combate.vincular_pokemon(companheiro)"),
		"assumir Pokémon torna a HUD visível e a vincula")
	_conf(fonte.contains("hud_de_combate.desvincular_pokemon()") and fonte.contains("hud_de_combate.hide()"),
		"voltar ao treinador desvincula e esconde a HUD")
	print("=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail else 0)
