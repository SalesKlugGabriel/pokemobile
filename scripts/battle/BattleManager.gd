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
# Tradução dos nomes de stat/status usados em moves.json → chaves internas.
# Achado (auditoria de golpes, 2026-08-31): moves.json usa "spd" pra Velocidade
# (ex: agility = "spd_plus2") mas BattlePokemon.stages usa "spd" pra Defesa
# Especial — os dois nomes colidem com sentidos opostos. Aqui "spd" (dado) é
# sempre traduzido pra "spe" (interno).
# ──────────────────────────────────────────────────────────────────────────────
const STAT_NAME_TO_INTERNAL := {
	"atk": "atk", "def": "def", "sp_atk": "spa", "sp_def": "spd",
	"spd": "spe", "acc": "acc", "evasion": "eva",
}

const STATUS_EFFECT_MAP := {
	"burn": BattlePokemon.Status.BURN,
	"poison": BattlePokemon.Status.POISON,
	"bad_poison": BattlePokemon.Status.BAD_POISON,
	"paralysis": BattlePokemon.Status.PARALYSIS,
	"sleep": BattlePokemon.Status.SLEEP,
	"freeze": BattlePokemon.Status.FREEZE,
}

const CURE_MAP := {
	"poison":    [BattlePokemon.Status.POISON, BattlePokemon.Status.BAD_POISON],
	"burn":      [BattlePokemon.Status.BURN],
	"frozen":    [BattlePokemon.Status.FREEZE],
	"sleep":     [BattlePokemon.Status.SLEEP],
	"paralysis": [BattlePokemon.Status.PARALYSIS],
}

# ──────────────────────────────────────────────────────────────────────────────
# Estado da batalha
# ──────────────────────────────────────────────────────────────────────────────
enum BattlePhase { IDLE, STARTING, PLAYER_ACTION, ENEMY_TURN, RESOLVING, CAPTURE, FORCED_SWITCH, ENDING }

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
var _player_seeded     : bool   = false
var _enemy_seeded      : bool   = false

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
	_player_seeded = false
	_enemy_seeded  = false

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
		player_pokemon = BattlePokemon.from_save(poke_save)

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

## Troca de Pokémon — tanto voluntária (botão POKÉMON no menu de ação) quanto
## forçada (o ativo desmaiou e ainda sobra time). `new_index` é o índice no
## time do SaveManager.
func player_switch_pokemon(new_index: int) -> void:
	if phase != BattlePhase.PLAYER_ACTION and phase != BattlePhase.FORCED_SWITCH:
		return
	var team := SaveManager.get_team()
	if new_index < 0 or new_index >= team.size():
		return
	if int(team[new_index].get("hp_current", 0)) <= 0:
		return  # não dá pra mandar um Pokémon desmaiado
	if new_index == _player_save_index:
		return  # já é o ativo

	var was_forced := phase == BattlePhase.FORCED_SWITCH

	# Persiste o HP/PP do Pokémon que está saindo (se ainda não desmaiado —
	# o caso desmaiado já fica com hp_current=0 desde o dano que o derrubou).
	if not was_forced:
		_persist_player_pokemon_to_save()

	_player_save_index = new_index
	player_pokemon = BattlePokemon.from_save(team[new_index])
	battle_scene.show_message("Vai, %s!" % player_pokemon.species_name)
	battle_scene.refresh_player_pokemon(player_pokemon)

	if was_forced:
		phase = BattlePhase.PLAYER_ACTION
		battle_scene.update_hud(player_pokemon, enemy_pokemon)
		battle_scene.show_action_menu()
	else:
		# Troca voluntária consome o turno — o inimigo ainda age.
		_enemy_act()
		_end_of_turn()

func player_cancel_switch() -> void:
	if phase != BattlePhase.PLAYER_ACTION:
		return
	battle_scene.show_action_menu()

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
		if phase == BattlePhase.RESOLVING and not enemy_pokemon.is_fainted():
			_execute_move(enemy_pokemon, player_pokemon, enemy_move)
	else:
		_execute_move(enemy_pokemon, player_pokemon, enemy_move)
		if phase == BattlePhase.RESOLVING and not player_pokemon.is_fainted():
			_execute_move(player_pokemon, enemy_pokemon, player_move)

	if phase == BattlePhase.RESOLVING:
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

	# Hyper Beam etc: precisa recarregar, perde a ação inteira.
	if attacker.must_recharge:
		attacker.must_recharge = false
		battle_scene.show_message("%s precisa recarregar!" % attacker.species_name)
		return

	# Apanhou antes de agir neste turno (Stomp, Bite, Rock Slide...).
	if attacker.flinched:
		attacker.flinched = false
		battle_scene.show_message("%s hesitou e não conseguiu se mexer!" % attacker.species_name)
		return

	# Status que impede agir (sono, congelado, paralisado — com chance).
	if not attacker.can_move():
		var reason := "não pode se mover!"
		match attacker.status:
			BattlePokemon.Status.SLEEP:   reason = "está dormindo."
			BattlePokemon.Status.FREEZE:  reason = "está congelado!"
			BattlePokemon.Status.PARALYSIS: reason = "está paralisado e não consegue se mover!"
		battle_scene.show_message("%s %s" % [attacker.species_name, reason])
		return

	# Confusão — chance de acertar a si mesmo em vez de agir.
	if attacker.is_confused:
		attacker.confuse_turns -= 1
		if attacker.confuse_turns <= 0:
			attacker.is_confused = false
			battle_scene.show_message("%s não está mais confuso!" % attacker.species_name)
		else:
			battle_scene.show_message("%s está confuso!" % attacker.species_name)
		if RNGManager.chance(1.0 / 3.0):
			var self_dmg := _confusion_self_damage(attacker)
			var actual_self := attacker.take_damage(self_dmg)
			battle_scene.show_message("Machucou a si mesmo na confusão!")
			battle_scene.animate_damage(attacker, actual_self)
			if attacker.is_fainted():
				_on_pokemon_fainted(attacker)
			return

	battle_scene.show_message("%s usou %s!" % [attacker.species_name, move_name])

	# Verificar acerto. accuracy=0 no dado é sentinela de "sempre acerta"
	# (usado tanto por golpes que nunca erram — Swift — quanto por moves de
	# status que não miram o oponente, tipo Agility). Antes disso não estava
	# tratado e QUALQUER move com accuracy=0 sempre errava — o oposto do que
	# o dado queria dizer.
	var acc : int = move.get("accuracy", 100)
	if acc > 0 and acc < 100:
		var hit_chance := float(acc) / 100.0 * attacker.accuracy_modifier() / defender.evasion_modifier()
		if not RNGManager.chance(hit_chance):
			battle_scene.show_message("Errou!")
			if move.get("effect", "") == "crash_on_miss":
				var crash := maxi(1, attacker.max_hp / 8)
				var actual_crash := attacker.take_damage(crash)
				battle_scene.show_message("%s se machucou com o próprio impulso!" % attacker.species_name)
				battle_scene.animate_damage(attacker, actual_crash)
				if attacker.is_fainted():
					_on_pokemon_fainted(attacker)
			return

	var category : String = move.get("category", "physical")
	var effect   : String = move.get("effect", "none")

	# Move de status (sem dano)
	if category == "status":
		_apply_status_move(attacker, defender, move)
		return

	# Golpes de dano fixo/especial que não usam a fórmula normal (power=0
	# mas NÃO é "sem efeito" — antes disso o código só via power==0 e saía
	# sem fazer nada, então Investida-K.O./Contra-golpe/Fúria não faziam nada).
	match effect:
		"ohko":
			_execute_ohko(attacker, defender)
			return
		"fixed_damage_20":
			_deal_fixed_damage(attacker, defender, 20)
			return
		"fixed_damage_40":
			_deal_fixed_damage(attacker, defender, 40)
			return
		"halve_hp":
			_deal_fixed_damage(attacker, defender, maxi(1, defender.hp / 2))
			return
		"level_damage":
			_deal_fixed_damage(attacker, defender, attacker.level)
			return
		"random_damage_0_5_to_1_5_level":
			var dmg := maxi(1, roundi(attacker.level * RNGManager.randf_range(0.5, 1.5)))
			_deal_fixed_damage(attacker, defender, dmg)
			return

	var power : int = move.get("power", 0)
	if power == 0:
		return  # move de status raro sem fórmula própria — ainda não modelado

	# Multi-hit (2 a 5 vezes) — Duplo Golpe, Fúria de Areia, etc.
	var hits := 1
	if effect == "multi_hit_2_5":
		hits = _roll_multi_hit_count()

	var total_dealt := 0
	var showed_effectiveness := false
	for _i in hits:
		if defender.is_fainted():
			break
		var damage := _calculate_damage(attacker, defender, move)
		var actual := defender.take_damage(damage)
		total_dealt += actual
		if not showed_effectiveness:
			var effectiveness := _type_effectiveness(move.get("type", "Normal"), defender)
			if effectiveness > 1.5:
				battle_scene.show_message("É super eficaz!")
			elif effectiveness < 0.5 and effectiveness > 0.0:
				battle_scene.show_message("Não é muito eficaz...")
			elif effectiveness == 0.0:
				battle_scene.show_message("Não tem efeito...")
			showed_effectiveness = true
		battle_scene.animate_damage(defender, actual)

	if hits > 1:
		battle_scene.show_message("Acertou %d vez(es)!" % hits)

	if effect == "recharge":
		attacker.must_recharge = true

	# Recuo (o atacante também apanha, proporcional ao dano causado).
	if effect.begins_with("recoil_"):
		var pct := _extract_trailing_number(effect.trim_prefix("recoil_"))
		if pct > 0 and total_dealt > 0:
			var recoil := maxi(1, roundi(total_dealt * pct / 100.0))
			var actual_recoil := attacker.take_damage(recoil)
			battle_scene.show_message("%s foi atingido pelo próprio ataque!" % attacker.species_name)
			battle_scene.animate_damage(attacker, actual_recoil)

	# Dreno (o atacante recupera HP proporcional ao dano causado).
	if effect.begins_with("drain_") and total_dealt > 0:
		var digits := ""
		for c in effect:
			if c.is_valid_int():
				digits += c
			elif digits != "":
				break
		var pct := int(digits) if digits != "" else 50
		var heal_amt := maxi(1, roundi(total_dealt * pct / 100.0))
		if attacker.heal(heal_amt) > 0:
			battle_scene.show_message("%s sugou energia!" % attacker.species_name)

	# Ganhou dinheiro (Pay Day) — só faz sentido pro jogador.
	if effect == "scatter_coins" and attacker == player_pokemon and total_dealt > 0:
		var won := attacker.level * 5
		SaveManager.add_money(won)
		battle_scene.show_message("Espalhou moedas! Ganhou ₽%d!" % won)

	# Efeito secundário por chance (queimadura/paralisia/flinch/confusão/
	# queda de stat) — antes disso, NENHUM golpe de dano aplicava o efeito
	# secundário descrito nos dados (ex: Lança-Chamas nunca queimava).
	if not defender.is_fainted():
		_maybe_apply_secondary_effect(effect, attacker, defender)

	if defender.is_fainted():
		battle_scene.show_message("%s desmaiou!" % defender.species_name)
		_on_pokemon_fainted(defender)

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

	# Habilidade e item segurado (Fase 1 do Diário)
	dmg *= _ability_damage_multiplier(atk, move_type, is_special)
	dmg *= _held_item_damage_multiplier(atk, move_type)

	# Crítico (1/16 chance normal, ~1/4 com Focus Energy — Foco Energético)
	var crit_chance := 0.25 if atk.crit_boost else 0.0625
	if RNGManager.chance(crit_chance):
		dmg *= 1.5
		battle_scene.show_message("Golpe crítico!")

	# Fator aleatório (0.85–1.0)
	dmg *= RNGManager.randf_range(0.85, 1.0)

	return maxi(1, roundi(dmg))

## Habilidades com efeito de dano implementado até agora (ver species.json —
## nem toda espécie tem "ability" ainda, e nem toda ability tem efeito aqui;
## as sem efeito ficam só como dado/flavor até alguém pedir a mecânica delas).
func _ability_damage_multiplier(atk: BattlePokemon, move_type: String, is_special: bool) -> float:
	var low_hp := atk.hp <= atk.max_hp / 3.0
	match atk.ability:
		"Overgrow":
			if move_type == "Grass" and low_hp:
				return 1.5
		"Blaze":
			if move_type == "Fire" and low_hp:
				return 1.5
		"Torrent":
			if move_type == "Water" and low_hp:
				return 1.5
		"Guts":
			if atk.status != BattlePokemon.Status.NONE and not is_special:
				return 1.5
	return 1.0

## Item segurado do tipo "held" em items.json (boost_type/boost_mult) — ex:
## Charcoal aumenta golpes de Fogo. Vazio ou item sem esse formato = sem efeito.
func _held_item_damage_multiplier(atk: BattlePokemon, move_type: String) -> float:
	if atk.held_item.is_empty():
		return 1.0
	var item : Dictionary = GameData.get_item(atk.held_item)
	if item.get("category", "") == "held" and item.get("boost_type", "") == move_type:
		return float(item.get("boost_mult", 1.0))
	return 1.0

func _type_effectiveness(move_type: String, defender: BattlePokemon) -> float:
	var species  := GameData.get_species(defender.species_id)
	var def_types: Array = species.get("types", ["Normal"])
	var mult     : float = 1.0
	var chart    : Dictionary = TYPE_CHART.get(move_type, {})
	for dt in def_types:
		mult *= chart.get(dt, 1.0)
	return mult

func _deal_fixed_damage(attacker: BattlePokemon, defender: BattlePokemon, amount: int) -> void:
	var actual := defender.take_damage(maxi(1, amount))
	battle_scene.animate_damage(defender, actual)
	if defender.is_fainted():
		battle_scene.show_message("%s desmaiou!" % defender.species_name)
		_on_pokemon_fainted(defender)

func _execute_ohko(attacker: BattlePokemon, defender: BattlePokemon) -> void:
	# Simplificado: só funciona se o atacante não for de nível menor que o
	# alvo (regra clássica), chance = accuracy do golpe (já checada como
	# acerto normal antes de chegar aqui não se aplica — o "acerto" de OHKO
	# É essa checagem de nível, então refazemos aqui).
	if attacker.level < defender.level:
		battle_scene.show_message("Não teve efeito!")
		return
	_deal_fixed_damage(attacker, defender, defender.hp)

func _roll_multi_hit_count() -> int:
	# Probabilidades clássicas: 2 e 3 acertos são bem mais comuns que 4 e 5.
	var roll := RNGManager.randf()
	if roll < 0.375:
		return 2
	elif roll < 0.75:
		return 3
	elif roll < 0.875:
		return 4
	return 5

func _confusion_self_damage(attacker: BattlePokemon) -> int:
	# Golpe físico típico (potência 40) contra si mesmo, sem STAB/tipo.
	var a := attacker.effective_attack(false)
	var d := attacker.effective_defense(false)
	var dmg : float = (2.0 * attacker.level / 5.0 + 2.0) * 40 * float(a) / float(d) / 50.0 + 2.0
	return maxi(1, roundi(dmg))

static func _extract_trailing_number(s: String) -> int:
	var digits := ""
	for c in s:
		if c.is_valid_int():
			digits += c
	return int(digits) if digits != "" else 0

func _on_pokemon_fainted(fainted: BattlePokemon) -> void:
	if fainted == enemy_pokemon:
		_handle_enemy_fainted()
	else:
		_handle_player_fainted()

## O Pokémon inimigo desmaiou — se for treinador com mais time, manda o
## próximo; senão a batalha acabou (vitória).
func _handle_enemy_fainted() -> void:
	if not is_wild_battle and trainer_team_idx + 1 < trainer_team_data.size():
		trainer_team_idx += 1
		_enemy_seeded = false
		var nxt : Dictionary = trainer_team_data[trainer_team_idx]
		enemy_pokemon = BattlePokemon.create(int(nxt.get("species_id", 16)), int(nxt.get("level", 5)), false)
		battle_scene.show_message("O adversário enviou %s!" % enemy_pokemon.species_name)
		battle_scene.refresh_enemy_pokemon(enemy_pokemon)
		return
	_end_battle("win")

## O Pokémon do jogador desmaiou — se sobrar time vivo, abre a troca
## obrigatória; senão a batalha acabou (derrota). Antes disso, QUALQUER
## desmaio do ativo encerrava a batalha na hora, mesmo com o time cheio de
## Pokémon saudáveis esperando no banco.
func _handle_player_fainted() -> void:
	_persist_player_pokemon_to_save()
	var team := SaveManager.get_team()
	for i in team.size():
		if i != _player_save_index and int(team[i].get("hp_current", 0)) > 0:
			phase = BattlePhase.FORCED_SWITCH
			battle_scene.show_switch_menu(true)
			return
	_end_battle("lose")

# ──────────────────────────────────────────────────────────────────────────────
# Moves de status / efeitos
# ──────────────────────────────────────────────────────────────────────────────
func _apply_status_move(atk: BattlePokemon, def: BattlePokemon, move: Dictionary) -> void:
	var effect : String = move.get("effect", "none")
	_apply_single_effect(effect, atk, def, 100)
	battle_scene.update_hud(player_pokemon, enemy_pokemon)
	if def.is_fainted():
		battle_scene.show_message("%s desmaiou!" % def.species_name)
		_on_pokemon_fainted(def)

## Efeito secundário de um golpe de dano (queimadura/paralisia/flinch/
## confusão/queda de stat com chance %). Chamado depois do dano já ter sido
## aplicado.
func _maybe_apply_secondary_effect(effect: String, atk: BattlePokemon, def: BattlePokemon) -> void:
	if effect == "none" or effect == "":
		return
	if effect.begins_with("recoil_") or effect.begins_with("drain_") or effect == "scatter_coins" \
			or effect == "multi_hit_2_5" or effect == "recharge" or effect == "crash_on_miss":
		return  # já tratados antes de chegar aqui
	_apply_single_effect(effect, atk, def, -1)
	battle_scene.update_hud(player_pokemon, enemy_pokemon)

## Aplica um efeito descrito em moves.json. `default_chance` é usado quando o
## nome do efeito não traz uma chance embutida (-1 = só aplica se o nome
## trouxer uma chance explícita, usado nos efeitos secundários de golpes de
## dano — sem isso, TODO golpe de dano com efeito viraria garantido).
func _apply_single_effect(effect: String, atk: BattlePokemon, def: BattlePokemon, default_chance: int) -> void:
	# 1) Mudança de stat: "<stat>_plus<1|2>" ou "<stat>_minus<1|2>[_<chance>]"
	var stat_change := _parse_stat_change(effect)
	if not stat_change.is_empty():
		var chance : int = _resolve_chance(int(stat_change["chance"]), default_chance)
		if chance <= 0 or not RNGManager.chance(chance / 100.0):
			return
		var target : BattlePokemon = atk if stat_change["delta"] > 0 else def
		_change_stage(target, stat_change["stat"], stat_change["delta"])
		return

	# 2) Confusão (própria, separada do enum Status — pode coexistir com ele)
	if effect == "confuse" or effect.begins_with("confuse_"):
		var raw : int = -1 if effect == "confuse" else _extract_trailing_number(effect)
		var chance := _resolve_chance(raw, default_chance)
		if chance <= 0 or not RNGManager.chance(chance / 100.0):
			return
		if not def.is_confused and not def.is_fainted():
			def.is_confused   = true
			def.confuse_turns = RNGManager.randi_range(2, 5)
			battle_scene.show_message("%s ficou confuso!" % def.species_name)
		return

	# 3) Flinch (só faz sentido como efeito secundário — golpe puro de flinch não existe)
	if effect.begins_with("flinch_"):
		var chance := _extract_trailing_number(effect)
		if chance > 0 and RNGManager.chance(chance / 100.0):
			def.flinched = true
		return

	# 4) Condição de status (queima/veneno/paralisia/sono/congela)
	for key in STATUS_EFFECT_MAP.keys():
		if effect == key or effect.begins_with(key + "_"):
			var raw : int = -1 if effect == key else _extract_trailing_number(effect)
			var chance := _resolve_chance(raw, default_chance)
			if chance <= 0 or not RNGManager.chance(chance / 100.0):
				return
			if def.apply_status(STATUS_EFFECT_MAP[key]):
				battle_scene.show_message("%s foi afetado(a)!" % def.species_name)
			return

	# 5) Efeitos únicos que não seguem um padrão de nome
	match effect:
		"heal_half":
			var healed := atk.heal(atk.max_hp / 2)
			if healed > 0:
				battle_scene.show_message("%s recuperou HP!" % atk.species_name)
		"heal_full_and_sleep_2":
			atk.heal(atk.max_hp)
			atk.status = BattlePokemon.Status.NONE  # Descanso sobrescreve qualquer status anterior
			atk.apply_status(BattlePokemon.Status.SLEEP)
			atk.sleep_turns = 2
			battle_scene.show_message("%s dormiu e recuperou toda a energia!" % atk.species_name)
		"crit_rate_up":
			atk.crit_boost = true
			battle_scene.show_message("%s está se concentrando!" % atk.species_name)
		"leech_seed":
			if def == enemy_pokemon:
				_enemy_seeded = true
			else:
				_player_seeded = true
			def.is_seeded = true
			battle_scene.show_message("%s foi semeado(a)!" % def.species_name)
		"reset_all_stats":
			for stat in atk.stages.keys():
				atk.stages[stat] = 0
			for stat in def.stages.keys():
				def.stages[stat] = 0
			atk.is_confused = false
			def.is_confused = false
			battle_scene.show_message("Todas as mudanças de status sumiram!")
		_:
			pass  # efeito ainda não modelado (bide, substitute, disable, trap,
			      # counter, mimic, metronome, telas de defesa, etc.) — o golpe
			      # só mostra "usou X!" por enquanto, sem crashar.

## `raw` é a chance embutida no nome do efeito (-1 se o nome não trouxe
## nenhuma). `fallback` é 100 quando é um move de status puro (efeito
## garantido) ou -1 quando é o efeito secundário de um golpe de dano (sem
## chance explícita no nome, não deveria acontecer nos dados — não aplica).
func _resolve_chance(raw: int, fallback: int) -> int:
	if raw >= 0:
		return raw
	if fallback >= 0:
		return fallback
	return 0

func _parse_stat_change(effect: String) -> Dictionary:
	for stat_key in STAT_NAME_TO_INTERNAL.keys():
		for dir_word in ["plus", "minus"]:
			var prefix := "%s_%s" % [stat_key, dir_word]
			if not effect.begins_with(prefix):
				continue
			var rest := effect.substr(prefix.length())
			if rest.length() == 0 or (rest[0] != "1" and rest[0] != "2"):
				continue
			var magnitude := int(rest[0])
			var remainder := rest.substr(1)
			var chance := -1
			if remainder.begins_with("_"):
				chance = int(remainder.substr(1))
			elif remainder != "":
				continue
			return {
				"stat": STAT_NAME_TO_INTERNAL[stat_key],
				"delta": magnitude if dir_word == "plus" else -magnitude,
				"chance": chance,
			}
	return {}

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
## Achado (auditoria de 2026-08-31): esta função lia `item.get("effect")`,
## mas items.json não tem esse campo — usa `heal_hp`/`cures`/`revive_hp`/
## `restore_pp` diretamente. Ou seja, usar QUALQUER item em batalha (Poção
## incluída) nunca fazia nada além de gastar o item. Reescrito pra ler o
## formato real dos dados.
func _apply_item(item_id: String, target: BattlePokemon) -> void:
	var item := GameData.get_item(item_id)
	var item_name : String = item.get("name", item_id)
	battle_scene.show_message("Usou %s!" % item_name)

	if item.has("heal_hp") and not target.is_fainted():
		var amount : int = int(item["heal_hp"])
		var healed : int = target.heal(target.max_hp) if amount < 0 else target.heal(amount)
		if healed > 0:
			battle_scene.show_message("%s recuperou %d HP!" % [target.species_name, healed])

	if item.has("revive_hp") and target.is_fainted():
		var ratio : float = float(item["revive_hp"])
		target.hp = target.max_hp if ratio < 0 else maxi(1, roundi(target.max_hp * ratio))
		battle_scene.show_message("%s foi revivido(a)!" % target.species_name)

	if item.has("cures"):
		var cures : Array = item["cures"]
		var should_cure := false
		if "all" in cures:
			should_cure = true
		else:
			for cure_key in cures:
				if target.status in CURE_MAP.get(cure_key, []):
					should_cure = true
					break
		if should_cure and target.status != BattlePokemon.Status.NONE:
			target.status = BattlePokemon.Status.NONE
			battle_scene.show_message("%s foi curado(a)!" % target.species_name)

	if item.get("heal_status", false) and target.status != BattlePokemon.Status.NONE:
		target.status = BattlePokemon.Status.NONE

	if item.has("restore_pp"):
		var amt : int = int(item["restore_pp"])
		for m in target.moves:
			var pp_max : int = int(m.get("pp", 10))
			m["pp_current"] = pp_max if amt < 0 else mini(pp_max, int(m.get("pp_current", 0)) + amt)

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
			_on_pokemon_fainted(player_pokemon)
			return

	if e_dmg > 0:
		battle_scene.show_message("%s sofreu dano!" % enemy_pokemon.species_name)
		battle_scene.animate_damage(enemy_pokemon, e_dmg)
		if enemy_pokemon.is_fainted():
			battle_scene.show_message("%s desmaiou!" % enemy_pokemon.species_name)
			_on_pokemon_fainted(enemy_pokemon)
			return

	# Leech Seed — drena de quem está semeado pra quem semeou.
	if _player_seeded and player_pokemon.is_seeded and not player_pokemon.is_fainted():
		var drain := maxi(1, player_pokemon.max_hp / 16)
		var actual := player_pokemon.take_damage(drain)
		enemy_pokemon.heal(actual)
		battle_scene.show_message("%s teve energia sugada pela semente!" % player_pokemon.species_name)
		battle_scene.animate_damage(player_pokemon, actual)
		if player_pokemon.is_fainted():
			battle_scene.show_message("%s desmaiou!" % player_pokemon.species_name)
			_on_pokemon_fainted(player_pokemon)
			return

	if _enemy_seeded and enemy_pokemon.is_seeded and not enemy_pokemon.is_fainted():
		var drain2 := maxi(1, enemy_pokemon.max_hp / 16)
		var actual2 := enemy_pokemon.take_damage(drain2)
		player_pokemon.heal(actual2)
		battle_scene.show_message("%s teve energia sugada pela semente!" % enemy_pokemon.species_name)
		battle_scene.animate_damage(enemy_pokemon, actual2)
		if enemy_pokemon.is_fainted():
			battle_scene.show_message("%s desmaiou!" % enemy_pokemon.species_name)
			_on_pokemon_fainted(enemy_pokemon)
			return

	battle_scene.update_hud(player_pokemon, enemy_pokemon)
	phase = BattlePhase.PLAYER_ACTION
	battle_scene.show_action_menu()

# ──────────────────────────────────────────────────────────────────────────────
# Captura (4.5)
# ──────────────────────────────────────────────────────────────────────────────
func _attempt_capture(ball_item_id: String) -> void:
	var ball     := GameData.get_item(ball_item_id)
	var ball_mult: float = float(ball.get("catch_rate_mult", 1))

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
	# player_won/is_wild/enemy_species_name/enemy_level: adicionados pro QuestManager
	# poder reconhecer o resultado sem reimplementar a lógica de vitória aqui.
	var result_dict := {
		"result":             result,
		"enemy_species":      enemy_pokemon.species_id   if enemy_pokemon else 0,
		"enemy_species_name": enemy_pokemon.species_name  if enemy_pokemon else "",
		"enemy_level":        enemy_pokemon.level         if enemy_pokemon else 0,
		"player_won":         result == "win",
		"is_wild":            is_wild_battle,
		"trainer_name":       trainer_npc.npc_name if (not is_wild_battle and trainer_npc) else "",
	}

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
				# Bestiary (Fase 1 do Diário) — só selvagem conta como "presença
				# registrada"; treinador é outra pessoa lutando, não a espécie.
				if is_wild_battle:
					SaveManager.record_defeat(enemy_pokemon.species_id)
				if new_level > old_level:
					AudioManager.play_sfx("level_up")
					battle_scene.show_message("%s subiu para o Nível %d!" % [player_pokemon.species_name, new_level])
				# Loot (Lote 9) — só em batalha selvagem.
				if is_wild_battle and enemy_pokemon:
					var drop : Dictionary = LootTable.new().roll_drop(enemy_pokemon.level, 0)
					if not drop.is_empty():
						var item_data := GameData.get_item(drop.get("id", ""))
						var qty : int = int(drop.get("quantity", 1))
						SaveManager.add_item(drop.get("id", ""), qty)
						battle_scene.show_message("Você encontrou %dx %s!" % [qty, item_data.get("name", drop.get("id", ""))])
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
	_return_to_world(result)

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
		if poke.get("hp_current", 0) > 0:
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
	_player_seeded    = false
	_enemy_seeded     = false
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

func _return_to_world(result: String = "") -> void:
	# Marca treinador como derrotado
	if not is_wild_battle and trainer_npc:
		trainer_npc.trainer_defeated = true
		trainer_npc._set_state(trainer_npc.State.IDLE if trainer_npc.patrol_route.is_empty() else trainer_npc.State.PATROL_MOVE)

	# Achado: o Pokémon selvagem do mapa nunca era removido depois da batalha
	# (só a cópia de dados usada na luta era descartada) — vencer ou capturar
	# deixava o mesmo selvagem plantado no mapa, pronto pra "reaparecer" e
	# começar outra batalha de novo. "run"/"lose" mantêm ele no mapa de
	# propósito (o jogador só fugiu, não venceu nem capturou).
	if is_wild_battle and (result == "win" or result == "capture") and is_instance_valid(wild_entity):
		wild_entity.queue_free()

	player_pokemon    = null
	enemy_pokemon     = null
	wild_entity       = null
	trainer_npc       = null
	trainer_team_data = []
	trainer_team_idx  = 0
	phase             = BattlePhase.IDLE
	battle_scene      = null
	SceneTransition.fade_to(_prev_world_scene)
