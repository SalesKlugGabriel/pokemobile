## BattleResolver.gd — Autoload. Fim-de-combate pra batalha em TEMPO REAL
## (Fase 5 do motor novo, 02/09) — porta XP/level-up/loot/Pokédex/sinal de
## quest de BattleManager._end_battle() (linhas 1035-1094) pra fora da
## máquina de turno, chamável direto quando um Pokémon selvagem morre em
## tempo real. Reaproveita BattleManager._get_base_exp() (static, mesma
## fórmula, sem duplicar) e emite EventBus.battle_ended no MESMO formato que
## QuestManager._on_battle_ended() já espera — quest de "derrote 5 Rattata"
## continua funcionando sem tocar QuestManager.gd.
extends Node

## Chamado por WildPokemon._die() quando o selvagem morre em combate real.
## player_save_index: índice no time de quem venceu — 0 é o líder/Follower
## ativo (mesma convenção de TrainerEntity._spawn_follower()).
func resolve_wild_defeat(species_id: int, level: int, species_name: String, player_save_index: int = 0) -> void:
	var new_level := _grant_exp_and_signal(species_id, level, species_name, true, "", player_save_index)
	if new_level == -1:
		return

	SaveManager.record_defeat(species_id)

	var luck_pts : int = SaveManager.get_trainer_stats().get_attribute("sorte")
	var drop : Dictionary = LootTable.new().roll_drop(level, luck_pts)
	if not drop.is_empty():
		SaveManager.add_item(drop.get("id", ""), int(drop.get("quantity", 1)))

## Chamado por WildPokemon._die() quando um Pokémon DE TREINADOR (Fase 7,
## 02/09: `is_trainer_owned=true`) morre em combate real — mesma fórmula de
## XP, mas sem loot nem Pokédex (não é selvagem) e com o nome do treinador no
## sinal (QuestManager já sabe ler "defeat"/"defeat_count" por trainer_name).
func resolve_trainer_pokemon_defeat(species_id: int, level: int, species_name: String, trainer_npc: Node, player_save_index: int = 0) -> void:
	var trainer_name : String = trainer_npc.npc_name if trainer_npc else ""
	_grant_exp_and_signal(species_id, level, species_name, false, trainer_name, player_save_index)

## Devolve o novo nível (ou -1 se o índice do time estava vazio) e já emite
## battle_ended/pokemon_level_up — compartilhado entre selvagem e treinador,
## que só divergem em loot/Pokédex (cada chamador cuida disso por fora).
func _grant_exp_and_signal(species_id: int, level: int, species_name: String, is_wild: bool, trainer_name: String, player_save_index: int) -> int:
	var old_poke : Dictionary = SaveManager.get_pokemon_at(player_save_index)
	if old_poke.is_empty():
		return -1
	var old_level : int = int(old_poke.get("level", 1))

	var base_exp   : int = BattleManager._get_base_exp(species_id)
	var exp_gained : int = maxi(1, roundi(base_exp * level / 7.0))
	var new_level  : int = SaveManager.add_exp_with_share(player_save_index, exp_gained)

	var result_dict := {
		"result":             "win",
		"enemy_species":      species_id,
		"enemy_species_name": species_name,
		"enemy_level":        level,
		"player_won":         true,
		"is_wild":            is_wild,
		"trainer_name":       trainer_name,
	}
	EventBus.battle_ended.emit(result_dict)

	if new_level > old_level:
		EventBus.pokemon_level_up.emit(SaveManager.get_pokemon_at(player_save_index), new_level)

	return new_level
