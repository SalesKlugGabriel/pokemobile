## EventBus.gd — Sistema de sinais global (Autoload/Singleton)
## Todos os sistemas emitem e escutam sinais por aqui para desacoplar dependências.
extends Node

# --- TREINADOR ---
signal trainer_hp_changed(current: int, maximum: int)
signal trainer_level_up(new_level: int)
signal trainer_exp_gained(amount: int)
signal trainer_died()
signal trainer_skill_tree_updated()
## Marcha de locomoção mudou (02/09) — "walk"/"bike"/"mount"/"surf"/"fly".
## Emitido só quando muda de verdade (TrainerEntity._emit_mode_if_changed),
## não a cada frame. HUD usa pra mostrar um indicador (sprite ainda não muda
## de aparência por marcha, isso cobre o feedback visual por ora).
signal movement_mode_changed(mode: String)

# --- POKÉMON FOLLOWER ---
signal follower_changed(pokemon_data: Dictionary)
signal follower_hp_changed(current: int, maximum: int)
signal follower_fainted(pokemon_data: Dictionary)
signal follower_skill_used(slot: int, move_id: String)
signal follower_skill_cooldown_updated(slot: int, progress: float)

# --- POKÉMON SELVAGEM ---
signal wild_pokemon_spawned(pokemon: Node)
signal wild_pokemon_died(pokemon: Node, loot: Array)
signal wild_pokemon_fainted(pokemon: Node)
signal wild_encounter_started(pokemon: Node)   # overworld: pokémon alcança jogador

# --- CAPTURA ---
signal pokeball_thrown(target: Node)
signal capture_success(pokemon_data: Dictionary)
signal capture_failed(pokemon_data: Dictionary)

# --- COMBATE ---
signal damage_dealt(target: Node, amount: int, is_critical: bool)
signal status_applied(target: Node, status_id: String)
signal battle_started()
signal battle_ended(result: Dictionary)

# --- ITENS E LOOT ---
signal item_picked_up(item_id: String, quantity: int)
signal item_used(item_id: String, target: Node)
signal tm_taught(pokemon_data: Dictionary, move_id: String, slot: int)

# --- PROGRESSÃO ---
signal pokemon_level_up(pokemon_data: Dictionary, new_level: int)

# --- QUESTS ---
signal quest_started(quest_id: String)
signal quest_objective_updated(quest_id: String, objective_index: int, current: int, required: int)
signal quest_completed(quest_id: String)

# --- MUNDO ---
signal map_changed(from_map: String, to_map: String)
signal pokemon_center_visited(map_id: String)
signal game_saved()
signal game_over()
signal player_tile_entered(tile: Vector2i)
## Andar alcançado dentro de uma estrutura de múltiplos andares (torre, caverna
## profunda...). structure_id bate com o "target" de objetivos reach_floor/
## traverse_floors em quests.json (ex: "pokemon_tower", "cerulean_cave").
## Emitido por FloorMap quando a cena declara floor_number > 0.
signal floor_reached(structure_id: String, floor: int)

# --- UI ---
signal dialogue_started(npc_id: String, lines: Array)   # diálogo com linhas carregadas
signal dialogue_ended()
signal dialog_started(npc: Node)                         # NPC começou interação (antes de carregar linhas)
signal dialog_ended()                                    # alias semântico de dialogue_ended
signal npc_dialog_requested(npc: Node, dialog_id: String)
signal hud_toggle_map(visible: bool)
signal pokedex_opened()
signal party_opened()
signal pokemon_evolved(from_id: int, into_id: int)
signal zone_changed(zone_name: String)
