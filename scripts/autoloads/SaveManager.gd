## SaveManager.gd — Gerenciamento completo de save do jogo (Autoload/Singleton)
extends Node

const SAVE_PATH := "user://pokemobile_save.json"

# Pokémon salvo: species_id, nickname, level, exp, ivs, is_shiny,
#                hp_current, hp_max, moves:[{id,pp_current,pp_max}],
#                status, held_item, uuid
var save_data: Dictionary = {
	"trainer": {
		"name": "Ash",
		"hp_current": 100,
		"hp_max": 100,
		"level": 1,
		"exp": 0,
		"money": 3000,
		"skill_tree": {
			"agilidade": 0, "sobrevivencia": 0,
			"afinidade": 0, "mestre_captura": 0, "sorte": 0
		},
		"skill_points_available": 0
	},
	"team": [],   # máx 6 Pokémons (formato acima)
	"pc":   [],   # armazenamento ilimitado
	"inventory": {},
	"quests": {},
	"diaries": [],
	"badges": [],
	"titles": [],
	"pokedex": { "seen": [], "caught": [], "defeated": {} },
	"world": {
		"current_map": "world_map",
		"last_pokemon_center": "world_map",
		"visited_maps": [],
		# Lendários já derrotados SEM captura — o ninho deles fica vazio pro
		# resto da partida (05/09). No save, não em memória: sair do jogo não
		# pode dar outra chance.
		"lendarios_derrotados": [],
		"defeated_alphas": [],
		"alpha_respawn_timers": {},
		"defeated_trainers": []
	},
	"final_choice": "",
	"rng_seed": 0
}

var _save_exists: bool = false

func _ready() -> void:
	_save_exists = FileAccess.file_exists(SAVE_PATH)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.zone_changed.connect(_on_zone_changed)

func _on_map_changed(_from: String, _to: String) -> void:
	if has_save():
		save_game()

func _on_battle_ended(_result: Dictionary) -> void:
	if has_save():
		save_game()

## "world.visited_maps" já existia no schema do save desde sempre, mas nunca
## era escrito nem lido em lugar nenhum — preparado, nunca ligado (mesma
## classe de achado já vista em QuestManager/reach_floor antes de existir
## handler). Usado agora pra saber a quais cidades o jogador já foi, base
## pro Teleporte (Mecânicas, 02/09): entra na lista assim que o jogador PISA
## na zona (não precisa curar no Centro), igual ao Jogo original.
func _on_zone_changed(zone_name: String) -> void:
	var visited: Array = save_data["world"]["visited_maps"]
	if zone_name not in visited:
		visited.append(zone_name)

# ──────────────────────────────────────────────────────────────────────────────
# SAVE / LOAD / DELETE
# ──────────────────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return _save_exists

func save_game() -> void:
	save_data["rng_seed"] = RNGManager.get_seed()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_save_exists = true
	EventBus.game_saved.emit()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveManager] Nenhum save encontrado.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text  := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("[SaveManager] Erro ao parsear save.")
		return false
	save_data = parsed
	RNGManager.set_seed(save_data.get("rng_seed", 0))
	_save_exists = true
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save_exists = false

# ──────────────────────────────────────────────────────────────────────────────
# NEW GAME
# ──────────────────────────────────────────────────────────────────────────────

## Inicializa um novo jogo com nome do treinador e espécie do starter.
func new_game(trainer_name: String, starter_species_id: int) -> void:
	# Reseta estrutura
	save_data["trainer"]["name"]  = trainer_name
	save_data["trainer"]["money"] = 3000
	save_data["team"]      = []
	save_data["pc"]        = []
	save_data["inventory"] = { "pokeball": 5, "potion": 3 }
	save_data["quests"]    = {}
	save_data["diaries"]   = []
	save_data["badges"]    = []
	save_data["titles"]    = []
	save_data["pokedex"]   = { "seen": [], "caught": [], "defeated": {} }
	save_data["world"]["current_map"]          = "world_map"
	save_data["world"]["last_pokemon_center"]  = "world_map"
	save_data["world"]["visited_maps"]         = []
	save_data["world"]["lendarios_derrotados"] = []
	save_data["world"]["defeated_alphas"]      = []
	save_data["world"]["alpha_respawn_timers"] = {}
	save_data["world"]["defeated_trainers"]    = []
	save_data["final_choice"] = ""
	save_data["rng_seed"]     = randi()

	RNGManager.set_seed(save_data["rng_seed"])

	# Cria o Pokémon inicial (level 5)
	var starter := _make_pokemon_data(starter_species_id, 5)
	save_data["team"].append(starter)
	mark_caught(starter_species_id)

	save_game()

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS DE ACESSO — TIME
# ──────────────────────────────────────────────────────────────────────────────

func get_trainer() -> Dictionary:
	return save_data["trainer"]

func get_team() -> Array:
	return save_data["team"]

func get_pokemon_at(index: int) -> Dictionary:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return {}
	return team[index]

func get_visited_maps() -> Array:
	return save_data["world"]["visited_maps"]

## True se algum Pokémon do time já sabe o golpe E é do tipo exigido — pedido
## do Gabriel (02/09): Surfar exige um Pokémon de tipo Água que saiba "surf"
## (não vale ensinar a MT11 num Pikachu e sair nadando), Voar exige um de
## tipo Voador que saiba "fly". O golpe é ensinado via MT/MO na Mochila
## (PauseMenu._teach_and_finish grava em team[i].moves); nenhum dos dois
## precisa desse Pokémon estar líder do time, só fazer parte dele.
func team_has_move_of_type(move_id: String, required_type: String) -> bool:
	for poke in save_data["team"]:
		var sabe_o_golpe := false
		for move in poke.get("moves", []):
			if move.get("id", "") == move_id:
				sabe_o_golpe = true
				break
		if not sabe_o_golpe:
			continue
		var types : Array = GameData.get_species(int(poke.get("species_id", 0))).get("types", [])
		for t in types:
			if String(t).capitalize() == required_type.capitalize():
				return true
	return false

## True se o time tem algum Pokémon cujo species_id está na lista dada —
## base da Montaria (Tauros/Dodrio/Rhyhorn/etc., 02/09): não é golpe
## nenhum, é só ter o bicho no time, igual o próprio Gabriel descreveu.
func team_has_any_species(species_ids: Array) -> bool:
	for poke in save_data["team"]:
		if int(poke.get("species_id", 0)) in species_ids:
			return true
	return false

func get_starter_species() -> int:
	var team: Array = save_data["team"]
	if team.is_empty():
		return 1
	return int(team[0].get("species_id", 1))

func get_starter_level() -> int:
	var team: Array = save_data["team"]
	if team.is_empty():
		return 5
	return int(team[0].get("level", 5))

## Atualiza dados de um Pokémon do time após batalha (HP, PP, status, exp).
func update_team_pokemon(index: int, data: Dictionary) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	team[index] = data

## Dá EXP ao Pokémon no índice; retorna nível após (pode ter subido).
func add_exp_to_pokemon(index: int, exp_gained: int) -> int:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return 0
	var poke: Dictionary = team[index]
	poke["exp"] = int(poke.get("exp", 0)) + exp_gained
	# Level up loop (medium-fast: n³)
	while true:
		var lv  : int = int(poke.get("level", 1))
		if lv >= 100:
			break
		var needed : int = (lv + 1) * (lv + 1) * (lv + 1)
		if int(poke["exp"]) >= needed:
			poke["level"] = lv + 1
			# Recalcula hp_max e hp_current proporcional
			var old_max : int = int(poke.get("hp_max", 1))
			var new_max : int = _calc_hp(
				GameData.get_species(int(poke["species_id"])).get("base_stats", {}).get("hp", 45),
				int(poke.get("ivs", {}).get("hp", 15)),
				poke["level"]
			)
			var ratio := float(int(poke.get("hp_current", old_max))) / float(old_max)
			poke["hp_max"]     = new_max
			poke["hp_current"] = maxi(1, roundi(new_max * ratio))
		else:
			break
	team[index] = poke
	# Verificar evolução
	_check_evolution(index)
	return int(poke["level"])

## Verifica e aplica evolução por level.
## Estrutura evolutions.json: {"species_id": N, "evolves_to": M, "condition": {"type": "level"|"stone", "value": L|item_id}}
func _check_evolution(index: int) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	var poke : Dictionary = team[index]
	var species_id    := int(poke.get("species_id", 0))
	var current_level : int = int(poke.get("level", 1))

	var evo : Dictionary = GameData.get_evolution(species_id)
	if evo.is_empty():
		return
	var condition : Dictionary = evo.get("condition", {})
	if condition.get("type", "") != "level":
		return
	if current_level < int(condition.get("value", 999)):
		return

	_apply_evolution(index, int(evo.get("evolves_to", species_id)))
	_check_evolution(index)  # cadeia de evolução

## Tenta evoluir o Pokémon no índice usando uma pedra (Fire Stone etc — item
## com category "stone"). Retorna true se evoluiu (e consome a pedra fora
## daqui, quem chamar decide). Achado: `evolutions.json` já tinha as 13
## evoluções por pedra mapeadas (bate exato com o Gen 1 de verdade), só
## nunca tinha sido ligado a nada — `_check_evolution` só olhava "level".
func try_evolve_with_stone(index: int, stone_item_id: String) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var species_id := int(team[index].get("species_id", 0))
	var evo : Dictionary = GameData.get_evolution(species_id)
	if evo.is_empty():
		return false
	var condition : Dictionary = evo.get("condition", {})
	if condition.get("type", "") != "stone" or String(condition.get("value", "")) != stone_item_id:
		return false
	_apply_evolution(index, int(evo.get("evolves_to", species_id)))
	return true

func _apply_evolution(index: int, new_id: int) -> void:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return
	var poke : Dictionary = team[index]
	var old_id : int = int(poke.get("species_id", 0))
	var current_level : int = int(poke.get("level", 1))
	var new_species := GameData.get_species(new_id)
	if new_species.is_empty():
		return
	poke["species_id"]   = new_id
	poke["species_name"] = new_species.get("name", "???")
	var new_max := _calc_hp(
		new_species.get("base_stats", {}).get("hp", 45),
		int(poke.get("ivs", {}).get("hp", 15)),
		current_level
	)
	var ratio := float(int(poke.get("hp_current", 1))) / float(maxi(1, int(poke.get("hp_max", 1))))
	poke["hp_max"]     = new_max
	poke["hp_current"] = maxi(1, roundi(new_max * ratio))
	team[index] = poke
	EventBus.pokemon_evolved.emit(old_id, new_id)

## Ensina um move num slot (0-3) do Pokémon no índice — usado por TM/HM.
## `slot_index` = -1 significa "primeiro slot vazio" (só funciona se tiver
## menos de 4 moves); com moveset cheio, quem chamar precisa escolher o slot.
func learn_move(index: int, move_id: String, slot_index: int = -1) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var move_data := GameData.get_move(move_id)
	if move_data.is_empty():
		return false
	var poke : Dictionary = team[index]
	var moves : Array = poke.get("moves", [])
	var new_move := {
		"id": move_id,
		"pp_current": int(move_data.get("pp", 10)),
		"pp_max": int(move_data.get("pp", 10)),
	}
	if slot_index < 0:
		if moves.size() >= 4:
			return false
		moves.append(new_move)
	else:
		if slot_index >= moves.size():
			return false
		moves[slot_index] = new_move
	poke["moves"] = moves
	team[index] = poke
	return true

## Equipa um item segurado no Pokémon do índice, tirando do inventário. Se ele
## já segurava outro item, esse item volta pro inventário (troca, não perde).
## Retorna false se o item não existe no inventário.
func equip_held_item(index: int, item_id: String) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	if not has_item(item_id, 1):
		return false
	var poke : Dictionary = team[index]
	var old_item : String = str(poke.get("held_item", ""))
	remove_item(item_id, 1)
	if not old_item.is_empty():
		add_item(old_item, 1)
	poke["held_item"] = item_id
	team[index] = poke
	return true

## Tira o item segurado do Pokémon do índice, devolvendo pro inventário.
## Retorna o item_id removido ("" se ele não segurava nada).
func unequip_held_item(index: int) -> String:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return ""
	var poke : Dictionary = team[index]
	var item_id : String = str(poke.get("held_item", ""))
	if item_id.is_empty():
		return ""
	add_item(item_id, 1)
	poke["held_item"] = ""
	team[index] = poke
	return item_id

## Cura todo o time: HP e PP restaurados, status removido. Salva o jogo.
func heal_team() -> void:
	for poke in save_data["team"]:
		poke["hp_current"] = int(poke.get("hp_max", 1))
		poke["status"] = "none"
		for move in poke.get("moves", []):
			move["pp_current"] = int(move.get("pp_max", 35))
	save_game()

## Adiciona Pokémon ao time (ou PC se cheio). Retorna "team" ou "pc".
func add_pokemon(pokemon_data: Dictionary) -> String:
	var team: Array = save_data["team"]
	if team.size() < 6:
		team.append(pokemon_data)
		return "team"
	else:
		save_data["pc"].append(pokemon_data)
		return "pc"

## Alias de add_pokemon — nome que o QuestManager usa pra presente de missão
## (mesmo destino: time se tiver vaga, senão PC).
func add_pokemon_to_party(pokemon_data: Dictionary) -> String:
	return add_pokemon(pokemon_data)

## Presente de missão dado por NOME de espécie (quests.json guarda
## {"id":"eevee","level":30} — mais legível que species_id cru). Achado ao
## fechar a lore da Fratura (03/09): QuestManager._give_rewards() passava
## esse dict CRU direto pra add_pokemon(), sem NENHUMA conversão — o
## "Pokémon" resultante não tinha species_id/ivs/moves/hp_max, um registro
## quebrado que nunca teria funcionado em batalha nem exibido certo em tela
## nenhuma. Reaproveita o MESMO _make_pokemon_data() que já cria o inicial
## do jogo, pra nunca ter um segundo jeito (divergente) de montar Pokémon.
func gift_pokemon_by_name(species_name: String, level: int) -> String:
	var species_id := GameData.get_species_id_by_name(species_name)
	if species_id <= 0:
		push_warning("SaveManager.gift_pokemon_by_name: espécie '%s' não encontrada" % species_name)
		return ""
	return add_pokemon(_make_pokemon_data(species_id, maxi(1, level)))

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — INVENTÁRIO
# ──────────────────────────────────────────────────────────────────────────────

func get_inventory() -> Dictionary:
	return save_data["inventory"]

func add_item(item_id: String, quantity: int = 1) -> void:
	var inv: Dictionary = save_data["inventory"]
	inv[item_id] = int(inv.get(item_id, 0)) + quantity

func remove_item(item_id: String, quantity: int = 1) -> bool:
	var inv: Dictionary = save_data["inventory"]
	if int(inv.get(item_id, 0)) < quantity:
		return false
	inv[item_id] = int(inv[item_id]) - quantity
	if int(inv[item_id]) == 0:
		inv.erase(item_id)
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return int(save_data["inventory"].get(item_id, 0)) >= quantity

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — DINHEIRO
# ──────────────────────────────────────────────────────────────────────────────
## Achado: OverworldHUD.gd já chamava SaveManager.get_money() desde antes desta
## função existir de verdade — era a causa do erro "a number is required" que
## aparecia sozinho toda vez que o HUD do mundo atualizava.
func get_money() -> int:
	return int(save_data["trainer"].get("money", 0))

func add_money(amount: int) -> void:
	save_data["trainer"]["money"] = get_money() + maxi(0, amount)

## Retorna true se conseguiu pagar (tinha dinheiro suficiente).
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_money() < amount:
		return false
	save_data["trainer"]["money"] = get_money() - amount
	return true

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — POKÉDEX
# ──────────────────────────────────────────────────────────────────────────────

func get_pokedex() -> Dictionary:
	return save_data.get("pokedex", { "seen": [], "caught": [] })

func mark_seen(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if species_id not in dex["seen"]:
		dex["seen"].append(species_id)

func mark_caught(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if species_id not in dex["seen"]:
		dex["seen"].append(species_id)
	if species_id not in dex["caught"]:
		dex["caught"].append(species_id)

func is_seen(species_id: int) -> bool:
	return species_id in save_data["pokedex"]["seen"]

func is_caught(species_id: int) -> bool:
	return species_id in save_data["pokedex"]["caught"]

## Bestiary — quantas vezes essa espécie já foi derrotada em batalha selvagem
## (não conta treinador, não é "quem venceu de quem", é presença registrada).
func record_defeat(species_id: int) -> void:
	var dex: Dictionary = save_data["pokedex"]
	if not dex.has("defeated"):
		dex["defeated"] = {}
	var key := str(species_id)
	dex["defeated"][key] = int(dex["defeated"].get(key, 0)) + 1
	mark_seen(species_id)

func get_defeat_count(species_id: int) -> int:
	var dex: Dictionary = save_data.get("pokedex", {})
	return int(dex.get("defeated", {}).get(str(species_id), 0))

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — INSÍGNIAS E TÍTULOS
# ──────────────────────────────────────────────────────────────────────────────

func get_badges() -> Array:
	return save_data["badges"]

func award_badge(badge_id: String) -> void:
	if badge_id.is_empty() or badge_id in save_data["badges"]:
		return
	save_data["badges"].append(badge_id)
	save_game()

func has_badge(badge_id: String) -> bool:
	return badge_id in save_data["badges"]

func get_titles() -> Array:
	return save_data.get("titles", [])

func unlock_title(title: String) -> void:
	if title.is_empty() or title in save_data["titles"]:
		return
	save_data["titles"].append(title)
	save_game()

func has_title(title: String) -> bool:
	return title in save_data.get("titles", [])

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — TREINADORES DERROTADOS (03/09, revisão de lore/balanceamento)
# ──────────────────────────────────────────────────────────────────────────────
## Achado grave ao planejar uma economia de nível de verdade: `trainer_
## defeated` (NpcEntity.gd) era uma variável só em memória, nunca salva —
## toda troca de mapa recria a cena (e o NPC) do zero, resetando pra false.
## Isso deixava QUALQUER treinador do jogo (líderes de ginásio, Elite Four,
## Campeão inclusive) re-lutável infinitas vezes só saindo e voltando na
## sala — o suficiente pra farmar Lance em loop e zerar qualquer meta de
## horas de jogo. `trainer_id` vem de NpcEntity._trainer_save_id()
## (map_id + nome do nó, sempre único, sem precisar editar nenhuma cena).
func mark_trainer_defeated(trainer_id: String) -> void:
	if trainer_id.is_empty() or trainer_id in save_data["world"]["defeated_trainers"]:
		return
	save_data["world"]["defeated_trainers"].append(trainer_id)
	save_game()

func is_trainer_defeated(trainer_id: String) -> bool:
	return trainer_id in save_data["world"].get("defeated_trainers", [])

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — "BOOSTAR" POKÉMON: vitaminas (EVs) e Doce Raro (03/09)
# ──────────────────────────────────────────────────────────────────────────────
## items.json usa nomes de stat em inglês por extenso ("attack","sp_atk"...)
## nos vitamin — mas o dicionário `evs` de cada Pokémon usa as chaves curtas
## já padronizadas no resto do jogo (mesma classe de bug já corrigida
## outras vezes neste projeto: "attack" vs "atk"). Traduz aqui, uma vez só.
const EV_STAT_KEY_MAP : Dictionary = {
	"hp": "hp", "attack": "atk", "defense": "def",
	"speed": "spe", "sp_atk": "spa", "sp_def": "spd",
}
const EV_CAP_PER_STAT : int = 252   # mesmo teto por stat do jogo real

## Achado: os itens de categoria "vitamin" (HP Up, Protein, Ferro, Carbos,
## Cálcio — e o Zinco que faltava, adicionado junto) já existiam com os
## campos `ev_stat`/`ev_amount`, e cada Pokémon já tinha um dicionário
## `evs` de verdade (lido no cálculo de stat, `BattlePokemon.gd`) — só
## NUNCA existia nenhum código que de fato incrementasse esse dicionário.
## Usar uma vitamina não fazia literalmente nada, em lugar nenhum do jogo.
func apply_ev_vitamin(index: int, ev_stat_raw: String, amount: int) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var key : String = EV_STAT_KEY_MAP.get(ev_stat_raw, "")
	if key.is_empty():
		return false
	var poke : Dictionary = team[index]
	var evs : Dictionary = poke.get("evs", {})
	var atual : int = int(evs.get(key, 0))
	if atual >= EV_CAP_PER_STAT:
		return false
	evs[key] = mini(EV_CAP_PER_STAT, atual + amount)
	poke["evs"] = evs
	team[index] = poke
	save_game()
	return true

## Doce Raro: sobe exatamente 1 nível, reaproveitando o MESMO cálculo de EXP
## cumulativo (n³) de add_exp_to_pokemon() — sem fórmula duplicada. Também
## era um item de categoria "vitamin" (`effect:"level_up"`) nunca lido em
## lugar nenhum, igual as outras vitaminas.
func use_rare_candy(index: int) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var poke : Dictionary = team[index]
	var lv : int = int(poke.get("level", 1))
	if lv >= 100:
		return false
	var needed : int = (lv + 1) * (lv + 1) * (lv + 1)
	var faltando : int = needed - int(poke.get("exp", 0))
	add_exp_to_pokemon(index, maxi(1, faltando))
	return true

## Repartidor de EXP (03/09) — achado ao revisar a lore/balanceamento: só o
## Pokémon no índice 0 (o líder/ativo) jamais ganhava EXP de batalha nenhuma;
## upar o time inteiro exigia trocar de líder e repetir a mesma luta várias
## vezes. Possuir "exp_share" faz o resto do time (vivo, HP > 0) ganhar a
## MESMA quantia de EXP do vencedor, sem dividir — decisão de simplicidade,
## igual jogo moderno, não a versão antiga que divide entre os dois. Devolve
## o novo nível de quem lutou (`active_index`), igual add_exp_to_pokemon().
func add_exp_with_share(active_index: int, exp_gained: int) -> int:
	var new_level : int = add_exp_to_pokemon(active_index, exp_gained)
	if has_item("exp_share", 1):
		var team: Array = save_data["team"]
		for i in team.size():
			if i == active_index:
				continue
			if int(team[i].get("hp_current", 0)) > 0:
				add_exp_to_pokemon(i, exp_gained)
	return new_level

## PP Up (03/09) — mesma classe de item "vitamina" que só existia no jogo
## como conceito, nunca lido em código nenhum. Cada uso soma 1/5 do PP BASE
## do golpe (não do PP já aumentado — evita crescimento composto/infinito),
## até 3 usos por golpe (teto de +60% sobre o base), igual jogo real.
func apply_pp_up(index: int, move_slot: int) -> bool:
	var team: Array = save_data["team"]
	if index < 0 or index >= team.size():
		return false
	var poke  : Dictionary = team[index]
	var moves : Array      = poke.get("moves", [])
	if move_slot < 0 or move_slot >= moves.size():
		return false
	var move_entry : Dictionary = moves[move_slot]
	var base_pp : int = int(GameData.get_move(str(move_entry.get("id", ""))).get("pp", 10))
	var incremento : int = maxi(1, base_pp / 5)
	var teto : int = base_pp + incremento * 3
	var atual_max : int = int(move_entry.get("pp_max", base_pp))
	if atual_max >= teto:
		return false
	var novo_max : int = mini(teto, atual_max + incremento)
	var ganho    : int = novo_max - atual_max
	move_entry["pp_max"]     = novo_max
	move_entry["pp_current"] = int(move_entry.get("pp_current", atual_max)) + ganho
	moves[move_slot] = move_entry
	poke["moves"] = moves
	team[index] = poke
	save_game()
	return true

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — DIÁRIOS (lore da Fratura) e A ESCOLHA FINAL (MAIN-11, 03/09)
# ──────────────────────────────────────────────────────────────────────────────
## As 6 páginas de diário (diario_1..6) já eram dadas como recompensa de
## MAIN-02..07, mas o campo `save_data["diaries"]` que existia pra rastrear
## quais o jogador já tem nunca era escrito em lugar nenhum — puro
## reaproveitamento de um campo que já estava certo, só esquecido.
func add_diary(diary_id: String) -> void:
	if diary_id.is_empty() or diary_id in save_data["diaries"]:
		return
	save_data["diaries"].append(diary_id)
	save_game()

func get_diaries() -> Array:
	return save_data.get("diaries", [])

## Resolve MAIN-11 ("A Escolha") de verdade — a ramificação narrativa da
## Fratura nunca tinha handler nenhum no motor (tipo de objetivo "choice" e
## chave de recompensa "world_state" eram só texto morto em quests.json).
## "seal_fracture": fecha a Fratura pra sempre — Mewtwo, sendo uma criatura
## nascida da energia dela, se desfaz junto (removido da coleção do
## jogador, mesmo que já tenha sido capturado). "capture_mewtwo": o jogador
## fica com o Mewtwo, a Fratura continua aberta. Os dois títulos são
## mutuamente exclusivos por design — refletem escolhas opostas, não dá
## pra ganhar os dois na mesma partida.
func resolve_main11_choice(option: String) -> void:
	save_data["final_choice"] = option
	if option == "seal_fracture":
		_remove_first_pokemon_by_species(150)
		unlock_title("guardiao_da_fratura")
	elif option == "capture_mewtwo":
		unlock_title("domador_de_mewtwo")
	save_game()

func get_final_choice() -> String:
	return save_data.get("final_choice", "")

func _remove_first_pokemon_by_species(species_id: int) -> void:
	var team : Array = save_data["team"]
	for i in team.size():
		if int(team[i].get("species_id", -1)) == species_id:
			team.remove_at(i)
			return
	var pc : Array = save_data["pc"]
	for i in pc.size():
		if int(pc[i].get("species_id", -1)) == species_id:
			pc.remove_at(i)
			return

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — QUESTS (progresso persistido; QuestManager é o dono da lógica)
# ──────────────────────────────────────────────────────────────────────────────

## Salva o progresso de UMA quest. `completed=true` some da lista de ativas.
func save_quest_progress(quest_id: String, progress: Array, completed: bool) -> void:
	save_data["quests"][quest_id] = { "progress": progress.duplicate(), "completed": completed }
	save_game()

## Devolve o dicionário inteiro quest_id → {progress, completed}, pro QuestManager
## reconstruir o próprio estado (ativas/completas) ao carregar o jogo.
func get_all_quest_progress() -> Dictionary:
	return save_data.get("quests", {})

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — XP E SKILL TREE DO TREINADOR
# ──────────────────────────────────────────────────────────────────────────────

## Ganha XP de treinador e sobe de nível (mesma curva cúbica do Pokémon, por
## consistência — nível n exige exp total (n+1)³). Cada nível dá 1 ponto de
## skill; XP de quest também pode dar ponto de bônus direto via add_skill_points.
func add_trainer_exp(amount: int) -> void:
	if amount <= 0:
		return
	var t: Dictionary = save_data["trainer"]
	t["exp"] = int(t.get("exp", 0)) + amount
	EventBus.trainer_exp_gained.emit(amount)
	var leveled := false
	while true:
		var lv: int = int(t.get("level", 1))
		if lv >= 100:
			break
		var needed: int = (lv + 1) * (lv + 1) * (lv + 1)
		if int(t["exp"]) >= needed:
			t["level"] = lv + 1
			leveled = true
		else:
			break
	if leveled:
		EventBus.trainer_level_up.emit(int(t["level"]))
	save_game()

## Constrói um TrainerStats (calculadora) a partir do save atual — sem cache,
## sempre fresco. Fonte de verdade é save_data; TrainerStats só faz a conta.
func get_trainer_stats() -> TrainerStats:
	var t: Dictionary = save_data["trainer"]
	var skill_tree: Dictionary = t.get("skill_tree", {})
	var spent := 0
	for v in skill_tree.values():
		spent += int(v)
	var ts := TrainerStats.new()
	ts.deserialize({
		"trainer_level": int(t.get("level", 1)),
		"points":        skill_tree,
		"spent_total":   spent,
		"bonus_points":  int(t.get("skill_points_available", 0)),
	})
	return ts

## Pontos de bônus concedidos fora do nível (recompensa de quest/task), somados
## aos pontos normais de nível na hora de calcular quanto dá pra gastar.
func add_skill_points(n: int) -> void:
	if n <= 0:
		return
	var t: Dictionary = save_data["trainer"]
	t["skill_points_available"] = int(t.get("skill_points_available", 0)) + n
	save_game()
	EventBus.trainer_skill_tree_updated.emit()

## Gasta 1 ponto no atributo indicado. Retorna false se não há ponto disponível
## ou o atributo já está no máximo (TrainerStats.MAX_POINTS).
func spend_skill_point(attribute: String) -> bool:
	var ts := get_trainer_stats()
	if not ts.add_point(attribute):
		return false
	save_data["trainer"]["skill_tree"] = ts.serialize()["points"]
	save_game()
	return true

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS — MUNDO
# ──────────────────────────────────────────────────────────────────────────────

func get_world() -> Dictionary:
	return save_data["world"]

func get_quest_state(quest_id: String) -> Dictionary:
	return save_data["quests"].get(quest_id, {})

# ──────────────────────────────────────────────────────────────────────────────
# UTILITÁRIOS INTERNOS
# ──────────────────────────────────────────────────────────────────────────────

## Gera UUID simples para identificar Pokémon no save.
static func _make_uuid() -> String:
	return "%08x-%04x-%04x" % [randi(), randi() % 65536, randi() % 65536]

## Calcula HP máximo (fórmula Gen 3+).
static func _calc_hp(base: int, iv: int, level: int) -> int:
	return int((2 * base + iv) * level / 100) + level + 10

## Calcula stat (fórmula Gen 3+, sem nature para simplificar).
static func _calc_stat(base: int, iv: int, level: int) -> int:
	return int((2 * base + iv) * level / 100) + 5

## Cria dicionário completo de dados de um Pokémon novo (nível dado).
func _make_pokemon_data(species_id: int, level: int) -> Dictionary:
	var species := GameData.get_species(species_id)
	var bs : Dictionary = species.get("base_stats", {})
	var ivs     := {
		"hp":  RNGManager.randi_range(0, 31),
		"atk": RNGManager.randi_range(0, 31),
		"def": RNGManager.randi_range(0, 31),
		"spa": RNGManager.randi_range(0, 31),
		"spd": RNGManager.randi_range(0, 31),
		"spe": RNGManager.randi_range(0, 31),
	}
	var hp_max := _calc_hp(int(bs.get("hp", 45)), int(ivs["hp"]), level)

	# Auto-seleciona até 4 moves aprendidos até este nível
	var learnset : Array = GameData.get_learnable_moves(species_id, level)
	var available : Array = []
	for entry in learnset:
		available.append(entry["move"])
	if available.size() > 4:
		available = available.slice(available.size() - 4)
	var moves : Array = []
	for move_id in available:
		var move_data := GameData.get_move(move_id)
		moves.append({
			"id":         move_id,
			"pp_current": int(move_data.get("pp", 35)),
			"pp_max":     int(move_data.get("pp", 35))
		})

	return {
		"uuid":       _make_uuid(),
		"species_id": species_id,
		"nickname":   "",
		"level":      level,
		"exp":        level * level * level,  # início exato do nível
		"ivs":        ivs,
		"evs":        { "hp":0, "atk":0, "def":0, "spa":0, "spd":0, "spe":0 },
		"nature":     GameData.roll_random_nature(),
		"is_shiny":   false,
		"hp_current": hp_max,
		"hp_max":     hp_max,
		"moves":      moves,
		"status":     "none",
		"held_item":  ""
	}

## Cria dados de Pokémon capturado a partir de um BattlePokemon.
func make_caught_data(bp) -> Dictionary:
	var moves : Array = []
	for move in bp.moves:
		moves.append({
			"id":         move.get("id", ""),
			"pp_current": int(move.get("pp_current", 0)),
			"pp_max":     int(move.get("pp_max", 35))
		})
	var species := GameData.get_species(bp.species_id)
	var bs : Dictionary = species.get("base_stats", {})
	return {
		"uuid":       _make_uuid(),
		"species_id": bp.species_id,
		"nickname":   "",
		"level":      bp.level,
		"exp":        bp.level * bp.level * bp.level,
		"ivs":        bp.ivs,
		"evs":        { "hp":0, "atk":0, "def":0, "spa":0, "spd":0, "spe":0 },
		"nature":     bp.nature,
		"is_shiny":   bp.is_shiny,
		"hp_current": bp.hp,
		"hp_max":     bp.max_hp,
		"moves":      moves,
		"status":     "none",
		"held_item":  ""
	}
