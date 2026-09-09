## teste_reacoes_follower.gd — Reações visuais do Follower (09/09), item da
## lista de imersão pedida pelo Gabriel: "reações do Pokémon seguidor".
## Confere por texto-fonte (igual outros testes de UI/visual deste projeto)
## porque o efeito em si (tween de cor/escala) só se julga jogando — o que
## dá pra travar automaticamente é que o CÓDIGO existe e está no lugar certo.
extends SceneTree

var _fail := 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   - ", msg)
	else:
		_fail += 1
		print("  FALHA - ", msg)

func _init() -> void:
	print("=== Teste: reações visuais do Follower (09/09) ===")

	var f := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")

	# HP crítico: tingimento que liga E desliga (não é só um flash).
	_assert(f.contains("_atualizar_reacao_de_hp"), "existe reação de HP baixo")
	_assert(f.contains("FRACAO_HP_PREOCUPADO"), "com um limite declarado (não um número solto no meio do código)")
	var i_dano := f.find("func take_damage")
	var i_reacao := f.find("_atualizar_reacao_de_hp()", i_dano)
	_assert(i_dano > 0 and i_reacao > i_dano, "chamada de dentro de take_damage — reage a QUALQUER dano, não só um caso")
	_assert(f.contains("preocupado_agora == _preocupado") and f.contains("return"),
		"e não refaz o tween se o estado não mudou (senão pisca a cada tique de dano)")

	# Level up: só reage ao PRÓPRIO Pokémon, não a qualquer um do time.
	_assert(f.contains("_on_pokemon_level_up"), "existe reação de level up")
	_assert(f.contains("pokemon_species_id"), "e confere se é o mesmo Pokémon antes de reagir")
	_assert(f.contains('AudioManager.play_sfx("level_up")'), "com som (o jogo já tinha o arquivo, só ninguém usava aqui)")

	# A cura também reavalia o tingimento — senão um Pokémon curado ficaria
	# com a cor de "pouca vida" até o próximo dano.
	var cura := FileAccess.get_file_as_string("res://scripts/systems/CuraDeCampo.gd")
	_assert(cura.contains("_atualizar_reacao_de_hp"),
		"curar reavalia o tingimento (não só desmaiar/não-desmaiar)")

	print("=== Resultado: %d ok, %d falhas ===" % [8 - _fail, _fail])
	quit(1 if _fail > 0 else 0)
