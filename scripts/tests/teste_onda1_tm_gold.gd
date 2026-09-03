## teste_onda1_tm_gold.gd — Teste headless de MT Ouro (uso infinito) vs MT
## comum (uso único) — Onda 1, item 7 do roteiro geral, 03/09. Também trava a
## correção de um bug achado no caminho: MO (HM) nunca deveria se gastar,
## mas vinha sendo consumida igual MT comum. Roda com:
## godot4 --headless --script res://scripts/tests/teste_onda1_tm_gold.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node
var GameData    : Node

func _initialize() -> void:
	print("=== Teste Onda 1 (MT Ouro vs MT comum + correção de MO) ===")
	SaveManager = root.get_node("SaveManager")
	GameData    = root.get_node("GameData")

## Reproduz exatamente a decisão de PauseMenu._teach_and_finish(): ensina o
## golpe e só remove o item do inventário se single_use != false.
func _teach_like_pause_menu(team_index: int, item_id: String, slot: int) -> bool:
	var item : Dictionary = GameData.get_item(item_id)
	var move_id : String = item.get("teaches", "")
	var aprendeu : bool = SaveManager.learn_move(team_index, move_id, slot)
	if aprendeu and item.get("single_use", true):
		SaveManager.remove_item(item_id, 1)
	return aprendeu

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Dados em items.json ----
	for n in range(1, 13):
		var tm_id := "tm%02d" % n
		_assert(GameData.get_item(tm_id).get("single_use", null) == true, "%s é single_use=true (comum)" % tm_id)
		var gold_id := "gold_tm%02d" % n
		var gold_item : Dictionary = GameData.get_item(gold_id)
		_assert(not gold_item.is_empty(), "%s existe" % gold_id)
		_assert(gold_item.get("single_use", null) == false, "%s é single_use=false (infinito)" % gold_id)
		_assert(gold_item.get("teaches", "") == GameData.get_item(tm_id).get("teaches", ""),
			"%s ensina o MESMO golpe que %s" % [gold_id, tm_id])
		_assert(int(gold_item.get("price", 0)) == int(GameData.get_item(tm_id).get("price", 0)) * 3,
			"%s custa 3x o preço de %s" % [gold_id, tm_id])
	for hm_id in ["hm01", "hm02", "hm03"]:
		_assert(GameData.get_item(hm_id).get("single_use", null) == false,
			"%s (MO) é single_use=false — correção do bug achado (MOs vinham se gastando)" % hm_id)

	# ---- Mecânica de verdade: MT comum se gasta, MT Ouro não, MO não ----
	SaveManager.new_game("TesteTMOuro", 1)
	# new_game() só dá 1 Pokémon inicial — adiciona um segundo pra testar que
	# a MESMA MT Ouro/MO ensina o golpe em dois Pokémon diferentes sem
	# precisar de uma segunda cópia (o ponto inteiro do "uso infinito").
	var bp := BattlePokemon.create(4, 5, false)  # Charmander
	SaveManager.add_pokemon(SaveManager.make_caught_data(bp))
	var team : Array = SaveManager.get_team()
	_assert(team.size() == 2, "time agora tem 2 Pokémon (starter + o adicionado pro teste)")

	# MT comum (tm02, Terremoto): ensina e SOME do inventário
	SaveManager.add_item("tm02", 1)
	_assert(SaveManager.has_item("tm02", 1), "tm02 está no inventário antes de usar")
	_assert(_teach_like_pause_menu(0, "tm02", 0), "ensinar Terremoto com tm02 funciona")
	_assert(not SaveManager.has_item("tm02", 1), "tm02 (comum) SOME do inventário depois de usar")

	# MT Ouro (gold_tm02, Terremoto): ensina pra 2 Pokémon diferentes com a MESMA cópia
	SaveManager.add_item("gold_tm02", 1)
	_assert(_teach_like_pause_menu(0, "gold_tm02", 0), "ensinar Terremoto de novo com gold_tm02 funciona")
	_assert(SaveManager.has_item("gold_tm02", 1), "gold_tm02 CONTINUA no inventário depois de usar (uso infinito)")
	_assert(_teach_like_pause_menu(1, "gold_tm02", 0), "a MESMA gold_tm02 ensina um SEGUNDO Pokémon, sem comprar outra")
	_assert(SaveManager.has_item("gold_tm02", 1), "gold_tm02 ainda no inventário depois do segundo uso")

	# MO (hm01, Cortar): ensina e NÃO some — correção do bug achado
	SaveManager.add_item("hm01", 1)
	_assert(_teach_like_pause_menu(0, "hm01", 1), "ensinar Cortar com hm01 funciona")
	_assert(SaveManager.has_item("hm01", 1), "hm01 (MO) NÃO some do inventário depois de usar (bug corrigido)")
	_assert(_teach_like_pause_menu(1, "hm01", 1), "a MESMA hm01 ensina um segundo Pokémon também")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
