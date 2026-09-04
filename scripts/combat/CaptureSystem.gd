## CaptureSystem.gd — Sistema de captura de Pokémon selvagem (Autoload).
## Gerencia lançamento em arco, cálculo de chance e resultado. Sem class_name
## de propósito — o nome "CaptureSystem" já é o do autoload; declarar
## class_name igual colide ("hides an autoload singleton").
## Após captura: vai pro SaveManager de verdade; emite EventBus.capture_success.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes do spec
# ──────────────────────────────────────────────────────────────────────────────

const POKEBALL_ARC_HEIGHT : float = 240.0  # migração tile128 (03/09): era 60 pro tile de 32px

## Toda pokébola conhecida, da pior chance base pra melhor — usado só por
## pick_best_owned_ball() pra saber o que existe no jogo (não define ordem de
## escolha: cada bola tem sua própria chance calculada pro alvo específico).
const ALL_BALL_IDS : Array[String] = [
	"pokeball", "great_ball", "net_ball", "dusk_ball", "quick_ball",
	"timer_ball", "heal_ball", "premium_pokeball", "ultra_ball", "master_ball",
]

## Onda 1, item 6 (03/09): tabela completa de pokébolas. Achado ao construir
## isto: o dicionário antigo (POKEBALL_MULT) tinha chaves ("superball",
## "masterball" sem underline) que NUNCA batiam com os IDs reais de
## items.json ("great_ball", "master_ball") nem com os valores de lá
## (master_ball é 255.0 em items.json, o dicionário antigo dizia 99.0) — todo
## multiplicador de bola caía sempre no padrão 1.0, silenciosamente. Removido
## de vez: agora o multiplicador vem sempre de items.json (fonte única),
## mesmo campo `catch_rate_mult` que o combate por turno já lê
## (BattleManager._attempt_capture) — os dois engines não podem discordar do
## que uma bola vale.

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

## Referência ao nó de Treinador Stats (injetada externamente ou buscada no grupo)
var trainer_stats : TrainerStats = null

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Conecta ao EventBus para saber quando o Treinador atualiza seus stats
	EventBus.trainer_skill_tree_updated.connect(_refresh_trainer_stats)

func _refresh_trainer_stats() -> void:
	_find_trainer_stats()

func _find_trainer_stats() -> void:
	# Tenta localizar TrainerStats no grupo do player
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("get_trainer_stats"):
			trainer_stats = p.get_trainer_stats()
			return

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

## Lança uma pokébola em arco via Tween e depois tenta a captura.
## target: nó WildPokemon na cena.
func throw_pokeball(target: WildPokemon, pokeball_type: String) -> void:
	if not is_instance_valid(target):
		return

	EventBus.pokeball_thrown.emit(target)

	# Origem: posição do Treinador (ou câmera como fallback)
	var start_pos  := _get_throw_origin()
	var end_pos    := target.global_position
	var peak_pos   := _arc_peak(start_pos, end_pos)

	# Cria sprite temporário da pokébola para animar o arco
	var ball_sprite := Sprite2D.new()
	get_tree().current_scene.add_child(ball_sprite)
	ball_sprite.global_position = start_pos

	var tween := get_tree().create_tween()
	tween.tween_property(ball_sprite, "global_position", peak_pos,  0.25)
	tween.tween_property(ball_sprite, "global_position", end_pos,   0.25)
	tween.tween_callback(func():
		ball_sprite.queue_free()
		var caught := attempt_capture(target, pokeball_type)
		if caught:
			target.queue_free()
		else:
			# Pokébola rebate — target continua na cena
			EventBus.capture_failed.emit(_build_pokemon_data(target))
	)

## Calcula a chance de captura conforme a fórmula do spec.
## master_bonus: pontos de mestre_captura do Treinador (0-8).
func calculate_catch_chance(target: WildPokemon, master_bonus: float, pokeball_type: String = "pokeball") -> float:
	var species_data   : Dictionary = GameData.get_species(target.species_id)
	var catch_rate_raw : int        = species_data.get("catch_rate", 45)

	var catch_base  : float = float(catch_rate_raw) / 255.0
	var hp_bonus    : float = (1.0 - target.get_hp_ratio()) * 0.5
	var master_bns  : float = master_bonus * 0.03
	var ball_mult   : float = ball_multiplier(pokeball_type, target)

	return min((catch_base + hp_bonus + master_bns) * ball_mult, 0.97)

## Multiplicador de UMA bola específica contra UM alvo específico — o mesmo
## `catch_rate_mult` que items.json já expunha pro combate por turno
## (BattleManager._attempt_capture), com o bônus situacional em cima quando a
## condição da bola se cumpre (Onda 1, item 6, 03/09). Bola desconhecida ou
## sem `catch_bonus` cadastrado = só o multiplicador base, sem bônus nenhum.
func ball_multiplier(pokeball_type: String, target: WildPokemon) -> float:
	var item : Dictionary = GameData.get_item(pokeball_type)
	var mult : float = item.get("catch_rate_mult", 1.0)
	if item.is_empty():
		return mult
	match item.get("catch_bonus", ""):
		"water_bug":
			if "Water" in target.types or "Bug" in target.types:
				mult = item.get("catch_bonus_mult", mult)
		"dark_cave":
			if _is_in_dark_cave():
				mult = item.get("catch_bonus_mult", mult)
		"quick_throw":
			if _is_early_in_encounter(target):
				mult = item.get("catch_bonus_mult", mult)
		"battle_length":
			mult = _timer_ball_multiplier(target, item.get("catch_bonus_mult", mult))
	return mult

## Bola Rápida (Quick Ball): bônus máximo se arremessada ANTES do selvagem
## notar o Treinador, ou nos primeiros instantes depois disso — mesma ideia
## do jogo real ("primeiro turno"), adaptada pro tempo real (usa o mesmo
## TURN_SECONDS de StatusEffectController, pra não inventar um segundo
## "tamanho de turno" diferente no mesmo motor).
func _is_early_in_encounter(target: WildPokemon) -> bool:
	if target.engaged_at_msec == -1:
		return true
	var elapsed_sec : float = float(Time.get_ticks_msec() - target.engaged_at_msec) / 1000.0
	return elapsed_sec < StatusEffectController.TURN_SECONDS

## Bola Tempo (Timer Ball): cresce com o tempo de combate, até o teto da
## própria bola (item.catch_bonus_mult) — mesma curva do jogo real (~+0.3x
## por "turno"). Selvagem que nunca "engajou" (capturado furtivamente, fora
## de combate) não tem tempo de batalha nenhum: fica no mínimo (1.0x).
func _timer_ball_multiplier(target: WildPokemon, cap_mult: float) -> float:
	if target.engaged_at_msec == -1:
		return 1.0
	var elapsed_turns : float = float(Time.get_ticks_msec() - target.engaged_at_msec) / 1000.0 / StatusEffectController.TURN_SECONDS
	return clampf(1.0 + elapsed_turns * 0.3, 1.0, cap_mult)

## Bola do Anoitecer (Dusk Ball): bônus em caverna escura (FloorMap.dark_cave
## — Rock Tunnel etc). O jogo não tem ciclo dia/noite (o outro gatilho
## clássico dessa bola), então só a metade "caverna" existe aqui.
func _is_in_dark_cave() -> bool:
	var scene := get_tree().current_scene
	return scene is FloorMap and scene.dark_cave

## Dado o alvo atual, escolhe a bola que o Treinador possui com a MAIOR
## chance de captura calculada pra ele — substitui a lista fixa antiga
## (BALL_PRIORITY em TrainerEntity.gd), que já nascia quebrada (IDs sem
## underline não batiam com o save) e não fazia sentido nenhum com bolas
## situacionais (uma Net Ball não é "melhor" que Ultra Ball em geral, só
## contra Água/Inseto). "" = nenhuma bola no inventário.
func pick_best_owned_ball(target: WildPokemon) -> String:
	_find_trainer_stats()
	var master_pts : float = float(trainer_stats.get_master_capture_points()) if trainer_stats else 0.0
	var best_id     : String = ""
	var best_chance : float  = -1.0
	for ball_id in ALL_BALL_IDS:
		if not SaveManager.has_item(ball_id, 1):
			continue
		var chance := calculate_catch_chance(target, master_pts, ball_id)
		if chance > best_chance:
			best_chance = chance
			best_id     = ball_id
	return best_id

## Tenta capturar o Pokémon. Retorna true se a captura for bem-sucedida.
## Pokémon de treinador nunca pode ser capturado.
func attempt_capture(target: WildPokemon, pokeball_type: String) -> bool:
	if not is_instance_valid(target):
		return false
	if target.is_trainer_owned:
		return false

	_find_trainer_stats()
	var master_pts : float = float(trainer_stats.get_master_capture_points()) if trainer_stats else 0.0
	var chance     : float = calculate_catch_chance(target, master_pts, pokeball_type)

	if RNGManager.chance(chance):
		var pokemon_data := _build_pokemon_data(target)
		# Bola de Cura (Heal Ball): sem bônus de captura, mas cura tudo do
		# Pokémon capturado — sobrescreve o que _build_pokemon_data() já
		# tinha montado (HP/status reais do momento da captura).
		if GameData.get_item(pokeball_type).get("heals_on_catch", false):
			pokemon_data["hp_current"] = pokemon_data.get("hp_max", 1)
			pokemon_data["status"]     = "none"
		SaveManager.add_pokemon(pokemon_data)
		SaveManager.mark_caught(target.species_id)
		EventBus.capture_success.emit(pokemon_data)
		return true

	return false

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários internos
# ──────────────────────────────────────────────────────────────────────────────

## Achado ao ligar isto (Fase 6, 02/09): a versão antiga gravava o Pokémon
## capturado em `team`/`pc_box` LOCAIS deste próprio autoload, nunca no save
## de verdade — a captura "funcionava" visualmente mas o Pokémon sumia ao
## recarregar. Corrigido reaproveitando o MESMO caminho que o combate por
## turno já usa: BattlePokemon.create() gera IVs/nature/moveset novos de
## verdade (WildPokemon não rola isso, é uma aproximação simplificada do
## motor em tempo real), e SaveManager.make_caught_data() já sabe montar o
## formato de save completo a partir disso.
func _build_pokemon_data(target: WildPokemon) -> Dictionary:
	var bp := BattlePokemon.create(target.species_id, target.wild_level, false)
	bp.hp = mini(target.current_hp, bp.max_hp)
	# O sorteio de shiny já aconteceu quando o selvagem nasceu no mapa
	# (WildPokemon._load_species(), 1/4096) — aqui só persiste o resultado
	# de verdade no Pokémon capturado, senão a captura "esquecia" o shiny.
	bp.is_shiny = target.is_shiny
	return SaveManager.make_caught_data(bp)

func _get_throw_origin() -> Vector2:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0].global_position
	return Vector2.ZERO

func _arc_peak(from: Vector2, to: Vector2) -> Vector2:
	var mid := (from + to) * 0.5
	return mid + Vector2(0, -POKEBALL_ARC_HEIGHT)
