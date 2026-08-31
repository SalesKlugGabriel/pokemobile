## BattleManager.gd — Autoload que orquestra toda a lógica de batalha.
## Recebe wild_encounter_started → cria BattlePokemon para ambos os lados →
## transita para BattleScene → processa turnos → retorna ao mundo.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const BATTLE_SCENE_PATH := "res://scenes/battle/BattleScene.tscn"

## Cena do mundo ativa antes de entrar na batalha (para retorno correto)
var _prev_world_scene : String = "res://scenes/world/maps/WorldMap.tscn"

# Tabela de efetividade de tipos
const TYPE_CHART : Dictionary = {
	"Normal":   {"Rock":0.5,"Ghost":0.0,"Steel":0.5},
	"Fire":     {"Fire":0.5,"Water":0.5,"Grass":2.0,"Ice":2.0,"Bug":2.0,"Rock":0.5,"Dragon":0.5,"Steel":2.0},
	"Water":    {"Fire":2.0,"Water":0.5,"Grass":0.5,"Ground":2.0,"Rock":2.0,"Dragon":0.5},
	"Electric": {"Water":2.0,"Electric":0.5,"Grass":0.5,"Ground":0.0,"Flying":2.0,"Dragon":0.5},
	"Grass":    {"Fire":0.5,"Water":2.0,"Grass":0.5,"Poison":0.5,"Ground":2.0,"Flying":0.5,"Bug":0.5,"Rock":2.0,"Dragon":0.5,"Steel":0.5},
	"Ice":      {"Water":0.5,"Grass":2.0,"Ice":0.5,"Ground":2.0,"Flying":2.0,"Dragon":2.0,"Steel":0.5},
	"Fighting": {"Normal":2.0,"Ice":2.0,"Poison":0.5,"Flying":0.5,"Psychic":0.5,"Bug":0.5,"Rock":2.0,"Ghost":0.0,"Dark":2.0,"Steel":2.0,"Fairy":0.5},
	"Poison":   {"Grass":2.0,"Poison":0.5,"Ground":0.5,"Rock":0.5,"Ghost":0.5,"Steel":0.0,"Fairy":2.0},
	"Ground":   {"Fire":2.0,"Electric":2.0,"Grass":0.5,"Poison":2.0,"Flying":0.0,"Bug":0.5,"Rock":2.0,"Steel":2.0},
	"Flying":   {"Electric":0.5,"Grass":2.0,"Fighting":2.0,"Bug":2.0,"Rock":0.5,"Steel":0.5},
	"Psychic":  {"Fighting":2.0,"Poison":2.0,"Psychic":0.5,"Dark":0.0,"Steel":0.5},
	"Bug":      {"Fire":0.5,"Grass":2.0,"Fighting":0.5,"Flying":0.5,"Psychic":2.0,"Ghost":0.5,"Dark":2.0,"Steel":0.5,"Fairy":0.5},
	"Rock":     {"Fire":2.0,"Ice":2.0,"Fighting":0.5,"Ground":0.5,"Flying":2.0,"Bug":2.0,"Steel":0.5},
	"Ghost":    {"Normal":0.0,"Psychic":2.0,"Ghost":2.0,"Dark":0.5},
	"Dragon":   {"Dragon":2.0,"Steel":0.5,"Fairy":0.0},
	"Dark":     {"Fighting":0.5,"Psychic":2.0,"Ghost":2.0,"Dark":0.5,"Fairy":0.5},
	"Steel":    {"Fire":0.5,"Water":0.5,"Electric":0.5,"Ice":2.0,"Rock":2.0,"Steel":0.5,"Fairy":2.0},
	"Fairy":    {"Fire":0.5,"Fighting":2.0,"Poison":0.5,"Dragon":2.0,"Dark":2.0,"Steel":0.5},
}

# ──────────────────────────────────────────────────────────────────────────────
# Estado da batalha
# ──────────────────────────────────────────────────────────────────────────────
enum BattlePhase { IDLE, STARTING, PLAYER_ACTION, ENEMY_TURN, RESOLVING, CAPTURE, ENDING }

var phase          : BattlePhase   = BattlePhase.IDLE
var player_pokemon : BattlePokemon = null
var enemy_pokemon  : BattlePokemon = null
var is_wild_battle : bool          = true
var wild_entity    : Node          = null   # PokemonEntity ou WildPokemon

## Referência à cena de batalha ativa
var battle_scene   : Node          = null

## Dados de batalha de treinador
var trainer_npc       : Node          = null   # NpcEntity que iniciou a batalha
var trainer_team_data : Array         = []     # team do treinador: [{species_id, level}]
var trainer_team_idx  : int           = 0      # índice atual no time do treinador

## Ação pendente do jogador
var _player_move_index : int    = -1
var _player_item_id    : String = ""
var _player_action     : String = ""   # "fight", "item", "run", "switch"
var _player_save_index : int    = 0    # índice no time do SaveManager

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	EventBus.wild_encounter_started.connect(_on_wild_encounter_started)

# ──────────────────────────────────────────────────────────────────────────────
# Entrada na batalha
# ──────────────────────────────────────────────────────────────────────────────
func _on_wild_encounter_started(pokemon_entity: Node) -> void:
	if phase != BattlePhase.IDLE:
		return

	# Guarda cena atual para retornar após a batalha
	if get_tree().current_scene:
		_prev_world_scene = get_tree().current_scene.scene_file_path

	wild_entity    = pokemon_entity
	is_wild_battle = true
	phase          = BattlePhase.STARTING

	# Monta BattlePokemon do inimigo e registra no pokédex
	enemy_pokemon = BattlePokemon.create(
		pokemon_entity.species_id,
		pokemon_entity.level,
		false
	)
	SaveManager.mark_seen(pokemon_entity.species_id)

	# Monta BattlePokemon do jogador a partir do save (team[0])
	_player_save_index = 0
	var poke_save := SaveManager.get_pokemon_at(_player_save_index)
	if poke_save.is_empty():
		# Fallback: sem save → Bulbasaur L5
		player_pokemon = BattlePokemon.create(1, 5, true)
	else:
		var move_ids: Array = []
		for m in poke_save.get("moves", []):
			move_ids.append(m.get("id", ""))
		player_pokemon = BattlePokemon.create(
			int(poke_save.get("species_id", 1)),
			int(poke_save.get("level", 5)),
			true,
			poke_save.get("ivs", {}),
			move_ids
		)
		# Restaura HP atual e PP dos moves do save
		player_pokemon.hp = int(poke_save.get("hp_current", player_pokemon.max_hp))
		var saved_moves: Array = poke_save.get("moves", [])
		for i in mini(saved_moves.size(), player_pokemon.moves.size()):
			player_pokemon.moves[i]["pp_current"] = int(saved_moves[i].get("pp_current",
				player_pokemon.moves[i].get("pp_current", 0)))

	EventBus.battle_started.emit()
	SceneTransition.fade_to(BATTLE_SCENE_PATH)

## Chamado pela BattleScene quando estiver pronta para iniciar
func on_battle_scene_ready(scene: Node) -> void:
	battle_scene = scene
	phase        = BattlePhase.PLAYER_ACTION
	AudioManager.play_bgm("battle")
	battle_scene.show_battle_start(player_pokemon, enemy_pokemon)

# ──────────────────────────────────────────────────────────────────────────────
# Ações do jogador (chamadas pela BattleScene via UI)
# ──────────────────────────────────────────────────────────────────────────────
func player_select_move(move_index: int) -> void:
	if phase != BattlePhase.PLAYER_ACTION:
		return
	_player_action     = "fight"
	_player_move_index = move_index
	_resolve_turn()

func player_use_item(item_id: String, target: BattlePokemon) -> void:
	if phase != BattlePhase.PLAYER_ACTION:
		return
	_player_action  = "item"
	_player_item_id = item_id
	_apply_item(item_id, target)
	# Usar item consome o turno mas inimigo ainda age
	_enemy_act()
	_end_of_turn()

func player_try_run() -> void:
	if phase != BattlePhase.PLAYER_ACTION:
		return
	if not is_wild_battle:
		battle_scene.show_message("Não dá pra fugir de batalhas de treinador!")
		return
	# Fórmula de fuga: sempre funciona contra selvagens por enquanto
	_end_battle("run")

func player_throw_pokeball(ball_item_id: String) -> void:
	if phase != BattlePhase.PLAYER_ACTION:
		return
	if not is_wild_battle:
		battle_scene.show_message("Não dá pra capturar Pokémon de treinadores!")
		return
	if not SaveManager.remove_item(ball_item_id):
		battle_scene.show_message("Sem Pokébola!")
		battle_scene.show_action_menu()
		return
	phase = BattlePhase.CAPTURE
	_attempt_capture(ball_item_id)

# ──────────────────────────────────────────────────────────────────────────────
# Resolução de turno
# ──────────────────────────────────────────────────────────────────────────────
func _resolve_turn() -> void:
	phase = BattlePhase.RESOLVING

	var player_move := player_pokemon.use_move(_player_move_index)
	var enemy_move  := _pick_enemy_move()

	# Determinar ordem: priority > speed
	var player_prio : int = player_move.get("priority", 0)
	var enemy_prio  : int = enemy_move.get("priority", 0)
	var player_first: bool

	if player_prio != enemy_prio:
		player_first = player_prio > enemy_prio
	else:
		player_first = player_pokemon.effective_speed() >= enemy_pokemon.effective_speed()

	if player_first:
		_execute_move(player_pokemon, enemy_pokemon, player_move)
		if not enemy_pokemon.is_fainted():
			_execute_move(enemy_pokemon, player_pokemon, enemy_move)
	else:
		_execute_move(enemy_pokemon, player_pokemon, enemy_move)
		if not player_pokemon.is_fainted():
			_execute_move(player_pokemon, enemy_pokemon, player_move)

	_end_of_turn()

func _pick_enemy_move() -> Dictionary:
	var usable := enemy_pokemon.get_usable_moves()
	if usable.is_empty():
		return GameData.get_move("struggle")
	return RNGManager.pick(usable)

func _enemy_act() -> void:
	var enemy_move := _pick_enemy_move()
	_execute_move(enemy_pokemon, player_pokemon, enemy_move)

# ──────────────────────────────────────────────────────────────────────────────
# Execução de move
# ──────────────────────────────────────────────────────────────────────────────
func _execute_move(attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary) -> void:
	if move.is_empty():
		return

	var move_name : String = move.get("name", "???")

	# Verificar se pode agir (status)
	if not attacker.can_move():
		battle_scene.show_message("%s não pode se mover!" % attacker.species_name)
		return

	battle_scene.show_message("%s usou %s!" % [attacker.species_name, move_name])

	# Verificar acerto
	var acc : int = move.get("accuracy", 100)
	if acc < 100:
		var hit_chance := float(acc) / 100.0 * attacker.accuracy_modifier() / defender.evasion_modifier()
		if not RNGManager.chance(hit_chance):
			battle_scene.show_message("Errou!")
			return

	var category : String = move.get("category", "physical")

	# Move de status
	if category == "status":
		_apply_status_move(attacker, defender, move)
		return

	# Calcular dano
	var power : int = move.get("power", 0)
	if power == 0:
		return

	var damage := _calculate_damage(attacker, defender, move)
	var actual := defender.take_damage(damage)

	# Efetividade
	var effectiveness := _type_effectiveness(move.get("type","Normal"), defender)
	if effectiveness > 1.5:
		battle_scene.show_message("É super eficaz!")
	elif effectiveness < 0.5 and effectiveness > 0.0:
		battle_scene.show_message("Não é muito eficaz...")
	elif effectiveness == 0.0:
		battle_scene.show_message("Não tem efeito...")

	battle_scene.animate_damage(defender, actual)

	if defender.is_fainted():
		battle_scene.show_message("%s desmaiou!" % defender.species_name)
		if defender == enemy_pokemon:
			_end_battle("win")
		else:
			_end_battle("lose")

# ──────────────────────────────────────────────────────────────────────────────
# Cálculo de dano (Gen 3+ formula)
# ──────────────────────────────────────────────────────────────────────────────
func _calculate_damage(atk: BattlePokemon, def: BattlePokemon, move: Dictionary) -> int:
	var power    : int    = move.get("power", 40)
	var category : String = move.get("category", "physical")
	var is_special := category == "special"

	var a : int = atk.effective_attack(is_special)
	var d : int = def.effective_defense(is_special)

	# Base damage
	var dmg : float = (2.0 * atk.level / 5.0 + 2.0) * power * float(a) / float(d) / 50.0 + 2.0

	# STAB
	var move_type    : String = move.get("type", "Normal")
	var species_data : Dictionary = GameData.get_species(atk.species_id)
	var atk_types    : Array  = species_data.get("types", [])
	if move_type in atk_types:
		dmg *= 1.5

	# Efetividade de tipo
	dmg *= _type_effectiveness(move_type, def)

	# Crítico (1/16 chance, 1.5x dano)
	if RNGManager.chance(0.0625):
		dmg *= 1.5
		battle_scene.show_message("Golpe crítico!")

	# Fator aleatório (0.85–1.0)
	dmg *= RNGManager.randf_range(0.85, 1.0)

	return maxi(1, roundi(dmg))

func _type_effectiveness(move_type: String, defender: BattlePokemon) -> float:
	var species  := GameData.get_species(defender.species_id)
	var def_types: Array = species.get("types", ["Normal"])
	var mult     : float = 1.0
	var chart    : Dictionary = TYPE_CHART.get(move_type, {})
	for dt in def_types:
		mult *= chart.get(dt, 1.0)
	return mult

# ──────────────────────────────────────────────────────────────────────────────
# Moves de status
# ──────────────────────────────────────────────────────────────────────────────
func _apply_status_move(atk: BattlePokemon, def: BattlePokemon, move: Dictionary) -> void:
	var effect : String = move.get("effect", "none")
	match effect:
		"burn":           def.apply_status(BattlePokemon.Status.BURN)
		"poison":         def.apply_status(BattlePokemon.Status.POISON)
		"bad_poison":     def.apply_status(BattlePokemon.Status.BAD_POISON)
		"paralyze":       def.apply_status(BattlePokemon.Status.PARALYSIS)
		"sleep":          def.apply_status(BattlePokemon.Status.SLEEP)
		"atk_up_1":       _change_stage(atk, "atk", 1)
		"def_up_1":       _change_stage(atk, "def", 1)
		"spa_up_1":       _change_stage(atk, "spa", 1)
		"spd_up_1":       _change_stage(atk, "spd", 1)
		"spe_up_1":       _change_stage(atk, "spe", 1)
		"atk_down_1":     _change_stage(def, "atk", -1)
		"def_down_1":     _change_stage(def, "def", -1)
		"spe_down_1":     _change_stage(def, "spe", -1)
		"acc_down_1":     _change_stage(def, "acc", -1)
		"heal_half":
			var healed := atk.heal(atk.max_hp / 2)
			battle_scene.show_message("%s recuperou HP!" % atk.species_name)
	battle_scene.update_hud(player_pokemon, enemy_pokemon)

func _change_stage(target: BattlePokemon, stat: String, delta: int) -> void:
	var old : int = target.stages[stat]
	target.stages[stat] = clampi(old + delta, -6, 6)
	var diff : int = target.stages[stat] - old
	if diff > 0:
		battle_scene.show_message("%s de %s subiu!" % [stat.to_upper(), target.species_name])
	elif diff < 0:
		battle_scene.show_message("%s de %s caiu!" % [stat.to_upper(), target.species_name])
	else:
		battle_scene.show_message("Não pode mais mudar!")

# ──────────────────────────────────────────────────────────────────────────────
# Itens
# ──────────────────────────────────────────────────────────────────────────────
func _apply_item(item_id: String, target: BattlePokemon) -> void:
	var item := GameData.get_item(item_id)
	var effect : String = item.get("effect", "none")
	match effect:
		"heal_20":   target.heal(20)
		"heal_50":   target.heal(50)
		"heal_200":  target.heal(200)
		"heal_full": target.heal(target.max_hp)
		"cure_status": target.status = BattlePokemon.Status.NONE
	battle_scene.show_message("Usou %s!" % item.get("name", item_id))
	battle_scene.update_hud(player_pokemon, enemy_pokemon)

# ──────────────────────────────────────────────────────────────────────────────
# Fim de turno
# ──────────────────────────────────────────────────────────────────────────────
func _end_of_turn() -> void:
	if player_pokemon.is_fainted() or enemy_pokemon.is_fainted():
		return

	# Dano de status
	var p_dmg := player_pokemon.tick_status()
	var e_dmg := enemy_pokemon.tick_status()

	if p_dmg > 0:
		battle_scene.show_message("%s sofreu dano de %s!" % [player_pokemon.species_name, player_pokemon.status_name()])
		battle_scene.animate_damage(player_pokemon, p_dmg)
		if player_pokemon.is_fainted():
			battle_scene.show_message("%s desmaiou!" % player_pokemon.species_name)
			_end_battle("lose")
			return

	if e_dmg > 0:
		battle_scene.show_message("%s sofreu dano!" % enemy_pokemon.species_name)
		battle_scene.animate_damage(enemy_pokemon, e_dmg)
		if enemy_pokemon.is_fainted():
			battle_scene.show_message("%s desmaiou!" % enemy_pokemon.species_name)
			_end_battle("win")
			return

	battle_scene.update_hud(player_pokemon, enemy_pokemon)
	phase = BattlePhase.PLAYER_ACTION
	battle_scene.show_action_menu()

# ──────────────────────────────────────────────────────────────────────────────
# Captura (4.5)
# ──────────────────────────────────────────────────────────────────────────────
func _attempt_capture(ball_item_id: String) -> void:
	var ball     := GameData.get_item(ball_item_id)
	var ball_mult: float = float(ball.get("catch_rate_multiplier", 1))

	var species  := GameData.get_species(enemy_pokemon.species_id)
	var base_rate: int = species.get("capture_rate", 45)

	# Fórmula moderna: a = (3 * max_hp - 2 * hp) * rate * ball_mult / (3 * max_hp)
	var a : float = (3.0 * enemy_pokemon.max_hp - 2.0 * enemy_pokemon.hp) \
			* base_rate * ball_mult / (3.0 * enemy_pokemon.max_hp)

	# Status bonus
	match enemy_pokemon.status:
		BattlePokemon.Status.SLEEP, BattlePokemon.Status.FREEZE:
			a *= 2.5
		BattlePokemon.Status.BURN, BattlePokemon.Status.POISON, \
		BattlePokemon.Status.BAD_POISON, BattlePokemon.Status.PARALYSIS:
			a *= 1.5

	a = clampf(a, 0.0, 255.0)

	# Shake checks: 4 sucessivos → capturado
	# b = 65536 / (255 / a)^0.1875 ; cada shake: random 0-65535 < b → sucesso
	var b : float = 65536.0 / pow(255.0 / maxf(1.0, a), 0.1875)
	var shakes    := 0
	for _i in 4:
		if RNGManager.randi_range(0, 65535) < roundi(b):
			shakes += 1
		else:
			break

	battle_scene.animate_capture(shakes)

	if shakes == 4:
		_capture_success()
	else:
		battle_scene.show_message("Oh não! O Pokémon escapou!")
		phase = BattlePhase.PLAYER_ACTION
		battle_scene.show_action_menu()
		# Inimigo age após fuga frustrada
		_enemy_act()
		_end_of_turn()

func _capture_success() -> void:
	AudioManager.play_sfx("catch_success")
	var pokemon_data := SaveManager.make_caught_data(enemy_pokemon)
	var slot := SaveManager.add_pokemon(pokemon_data)
	SaveManager.mark_caught(enemy_pokemon.species_id)
	var msg := "%s foi capturado!" % enemy_pokemon.species_name
	if slot == "pc":
		msg += "\n(Time cheio — foi para o PC)"
	battle_scene.show_message(msg)
	EventBus.capture_success.emit(pokemon_data)
	_end_battle("capture")

# ──────────────────────────────────────────────────────────────────────────────
# Fim de batalha
# ──────────────────────────────────────────────────────────────────────────────
func _end_battle(result: String) -> void:
	phase = BattlePhase.ENDING
	var result_dict := { "result": result, "enemy_species": enemy_pokemon.species_id if enemy_pokemon else 0 }

	match result:
		"win":
			# EXP ganha = base_exp * enemy_level / 7 (simplificado)
			if enemy_pokemon and player_pokemon:
				var base_exp  : int = _get_base_exp(enemy_pokemon.species_id)
				var exp_gained: int = maxi(1, roundi(base_exp * enemy_pokemon.level / 7.0))
				var old_level : int = player_pokemon.level
				var new_level : int = SaveManager.add_exp_to_pokemon(_player_save_index, exp_gained)
				battle_scene.show_message("Você venceu!")
				battle_scene.show_message("%s ganhou %d EXP!" % [player_pokemon.species_name, exp_gained])
				if new_level > old_level:
					AudioManager.play_sfx("level_up")
					battle_scene.show_message("%s subiu para o Nível %d!" % [player_pokemon.species_name, new_level])
		"lose":
			battle_scene.show_message("Você perdeu...")
			# Verifica se todo o time está fainted → game over
			if _is_full_blackout():
				EventBus.game_over.emit()
		"run":
			battle_scene.show_message("Fugiu com segurança!")
		"capture":
			pass  # mensagem já exibida em _capture_success

	# Persiste HP e PP do Pokémon do jogador no save
	_persist_player_pokemon_to_save()

	EventBus.battle_ended.emit(result_dict)
	await get_tree().create_timer(2.0).timeout
	_return_to_world()

## Salva HP e PP atuais do Pokémon do jogador de volta ao save.
func _persist_player_pokemon_to_save() -> void:
	if player_pokemon == null:
		return
	var poke_save := SaveManager.get_pokemon_at(_player_save_index)
	if poke_save.is_empty():
		return
	poke_save["hp_current"] = player_pokemon.hp
	# Atualiza PP de cada move
	for i in player_pokemon.moves.size():
		if i < poke_save["moves"].size():
			poke_save["moves"][i]["pp_current"] = player_pokemon.moves[i].get("pp_current", 0)
	SaveManager.update_team_pokemon(_player_save_index, poke_save)
	SaveManager.save_game()

## Retorna base_exp aproximado para uma espécie (sem campo no JSON, usa fórmula simples).
static func _get_base_exp(species_id: int) -> int:
	# Aproximação: espécies iniciais têm ~64, evoluções ~100-200
	# Fórmula: 50 + species_id * 0.8 (cap 250)
	return mini(250, 50 + roundi(species_id * 0.8))

func _is_full_blackout() -> bool:
	var team := SaveManager.get_team()
	for poke in team:
		if poke.get("current_hp", 0) > 0:
			return false
	return true

## Inicia batalha contra treinador (NpcEntity com is_trainer=true).
func start_trainer_battle(npc: Node) -> void:
	if phase != BattlePhase.IDLE:
		return
	trainer_npc       = npc
	trainer_team_data = npc.trainer_team
	trainer_team_idx  = 0
	is_wild_battle    = false
	phase             = BattlePhase.STARTING

	# Primeiro Pokémon do treinador
	var first : Dictionary = trainer_team_data[0] if not trainer_team_data.is_empty() else {"species_id": 16, "level": 5}
	enemy_pokemon = BattlePokemon.create(int(first.get("species_id", 16)), int(first.get("level", 5)), false)

	# Pokémon do jogador (mesmo que batalha selvagem)
	_player_save_index = 0
	var poke_save := SaveManager.get_pokemon_at(_player_save_index)
	if poke_save.is_empty():
		push_warning("BattleManager: jogador sem Pokémon")
		phase = BattlePhase.IDLE
		return

	player_pokemon = BattlePokemon.from_save(poke_save)
	AudioManager.play_bgm("battle_trainer")
	SceneTransition.fade_to(BATTLE_SCENE_PATH)

func _return_to_world() -> void:
	# Marca treinador como derrotado
	if not is_wild_battle and trainer_npc:
		trainer_npc.trainer_defeated = true
		trainer_npc._set_state(trainer_npc.State.IDLE if trainer_npc.patrol_route.is_empty() else trainer_npc.State.PATROL_MOVE)

	player_pokemon    = null
	enemy_pokemon     = null
	wild_entity       = null
	trainer_npc       = null
	trainer_team_data = []
	trainer_team_idx  = 0
	phase             = BattlePhase.IDLE
	battle_scene      = null
	SceneTransition.fade_to(_prev_world_scene)
