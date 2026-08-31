## teste_fase1_pokemon.gd — Teste headless da Fase 1 (Nature, Ability, Held
## Item ativo em batalha, Bestiary com contagem de derrotas).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase1_pokemon.gd
extends SceneTree

var _ok   := 0
var _fail := 0
var _rodou := false

var SaveManager   : Node
var GameData      : Node
var BattleManager  : Node

func _initialize() -> void:
	print("=== Teste Fase 1 (Pokémon de verdade) ===")
	SaveManager   = root.get_node("SaveManager")
	GameData      = root.get_node("GameData")
	BattleManager = root.get_node("BattleManager")

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

func _teste_geral() -> void:
	# ---- 1. Nature ----
	_assert(GameData.get_nature_multiplier("adamant", "atk") == 1.1,
		"Adamant sobe 'atk' em 10%")
	_assert(GameData.get_nature_multiplier("adamant", "spa") == 0.9,
		"Adamant desce 'spa' em 10%")
	_assert(GameData.get_nature_multiplier("adamant", "def") == 1.0,
		"Adamant não mexe em 'def'")
	_assert(GameData.get_nature_multiplier("hardy", "atk") == 1.0,
		"Hardy é neutra (boost==cut) mesmo sendo 'atk' nas duas pontas")
	var nat = GameData.roll_random_nature()
	_assert(GameData.NATURES.has(nat), "roll_random_nature() sempre devolve uma nature válida (%s)" % nat)

	# ---- 2. Ability por espécie ----
	_assert(GameData.get_species(4).get("ability", "") == "Blaze",
		"Charmander (id 4) tem ability 'Blaze' cadastrada")
	_assert(GameData.get_species(1).get("ability", "") == "Overgrow",
		"Bulbasaur (id 1) tem ability 'Overgrow' cadastrada")
	_assert(GameData.get_species(150).get("ability", "") == "",
		"espécie sem ability cadastrada (Mewtwo, id 150) devolve vazio, sem quebrar")

	# ---- 3. BattlePokemon.create() pega ability/nature da espécie ----
	var charmander = BattlePokemon.create(4, 50, false)
	_assert(charmander.ability == "Blaze", "BattlePokemon criado carrega a ability da espécie")
	_assert(GameData.NATURES.has(charmander.nature), "BattlePokemon criado sorteia uma nature válida")
	_assert(charmander.held_item == "", "Pokémon selvagem criado não tem item segurado")

	# ---- 4. Multiplicador de dano por ability (Blaze: +50% Fogo com HP <= 1/3) ----
	charmander.hp = charmander.max_hp  # HP cheio: Blaze não deveria ativar
	_assert(BattleManager._ability_damage_multiplier(charmander, "Fire", false) == 1.0,
		"Blaze não ativa com HP cheio")
	charmander.hp = int(charmander.max_hp * 0.3)  # abaixo de 1/3
	_assert(BattleManager._ability_damage_multiplier(charmander, "Fire", false) == 1.5,
		"Blaze dá +50% em golpe de Fogo com HP <= 1/3")
	_assert(BattleManager._ability_damage_multiplier(charmander, "Water", false) == 1.0,
		"Blaze não afeta golpe de tipo diferente (Água)")

	# ---- 5. Guts (status + físico) ----
	var rattata = BattlePokemon.create(19, 30, false)
	_assert(rattata.ability == "Guts", "Rattata (id 19) tem ability 'Guts'")
	rattata.status = BattlePokemon.Status.BURN
	_assert(BattleManager._ability_damage_multiplier(rattata, "Normal", false) == 1.5,
		"Guts dá +50% em golpe físico quando statusado")
	_assert(BattleManager._ability_damage_multiplier(rattata, "Normal", true) == 1.0,
		"Guts não afeta golpe especial")

	# ---- 6. Item segurado ----
	var equipado = BattlePokemon.create(4, 50, false)
	equipado.held_item = "charcoal"
	_assert(BattleManager._held_item_damage_multiplier(equipado, "Fire") == 1.2,
		"Charcoal dá +20% em golpe de Fogo")
	_assert(BattleManager._held_item_damage_multiplier(equipado, "Water") == 1.0,
		"Charcoal não afeta golpe de tipo diferente")

	# ---- 7. from_save() carrega nature/ability/held_item do save ----
	var poke_save := {
		"species_id": 4, "level": 50, "nature": "adamant", "held_item": "charcoal",
		"ivs": {"hp":31,"atk":31,"def":31,"spa":31,"spd":31,"spe":31},
		"evs": {"hp":0,"atk":0,"def":0,"spa":0,"spd":0,"spe":0},
		"hp_current": 100, "moves": [],
	}
	var do_save = BattlePokemon.from_save(poke_save)
	_assert(do_save.nature == "adamant", "from_save() carrega a nature salva")
	_assert(do_save.held_item == "charcoal", "from_save() carrega o item segurado salvo")
	_assert(do_save.ability == "Blaze", "from_save() também resolve a ability pela espécie")
	var atk_neutro := (2.0 * 52 + 31) * 50.0 / 100.0 + 5.0  # base atk Charmander=52
	_assert(do_save.attack == int(floor(atk_neutro * 1.1)),
		"nature Adamant (+10%% atk) foi aplicada no stat calculado (%d)" % do_save.attack)

	# ---- 8. Equipar/desequipar item (SaveManager) ----
	SaveManager.new_game("TesteFase1", 4)
	SaveManager.add_item("charcoal", 1)
	_assert(SaveManager.get_inventory().get("charcoal", 0) == 1, "charcoal está no inventário")
	var equipou = SaveManager.equip_held_item(0, "charcoal")
	_assert(equipou, "equip_held_item() funciona com item disponível")
	_assert(SaveManager.get_pokemon_at(0).get("held_item", "") == "charcoal",
		"o Pokémon do time ficou com o item equipado")
	_assert(SaveManager.get_inventory().get("charcoal", 0) == 0,
		"o item saiu do inventário ao equipar")
	var removido = SaveManager.unequip_held_item(0)
	_assert(removido == "charcoal", "unequip_held_item() devolve o item que estava equipado")
	_assert(SaveManager.get_pokemon_at(0).get("held_item", "") == "",
		"o Pokémon ficou sem item depois de desequipar")
	_assert(SaveManager.get_inventory().get("charcoal", 0) == 1,
		"o item voltou pro inventário ao desequipar")
	var sem_item = SaveManager.equip_held_item(0, "master_ball")
	_assert(not sem_item, "equip_held_item() falha se o item não está no inventário")

	# ---- 9. Bestiary (contagem de derrota) ----
	_assert(SaveManager.get_defeat_count(19) == 0, "Rattata começa com 0 derrotas registradas")
	SaveManager.record_defeat(19)
	SaveManager.record_defeat(19)
	_assert(SaveManager.get_defeat_count(19) == 2, "2 chamadas de record_defeat somam 2")
	_assert(SaveManager.is_seen(19), "record_defeat também marca a espécie como vista na Pokédex")

	SaveManager.save_game()
	SaveManager.load_game()
	_assert(SaveManager.get_defeat_count(19) == 2,
		"contagem de derrota sobrevive a salvar/recarregar")
	_assert(SaveManager.get_pokemon_at(0).get("held_item", "") == "",
		"held_item do time sobrevive a salvar/recarregar (vazio, como ficou)")
