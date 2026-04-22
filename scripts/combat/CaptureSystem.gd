## CaptureSystem.gd — Sistema de captura de Pokémon selvagem.
## Singleton/Autoload. Gerencia lançamento em arco, cálculo de chance e resultado.
## Após captura: adiciona ao time (≤6) ou ao PC; emite EventBus.capture_success.
class_name CaptureSystem
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes do spec
# ──────────────────────────────────────────────────────────────────────────────

const POKEBALL_ARC_HEIGHT : float = 60.0

## Multiplicadores de chance de captura por tipo de pokébola
const POKEBALL_MULT : Dictionary = {
	"pokeball":      1.0,
	"superball":     1.5,
	"ultraball":     2.0,
	"masterball":    99.0,   # captura garantida
	"safariball":    1.5,
	"netball":       1.3,
	"diveball":      1.3,
	"nestball":      1.0,
}

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

## Time ativo do Treinador (máximo 6)
var team   : Array[Dictionary] = []
## PC — depósito ilimitado
var pc_box : Array[Dictionary] = []

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
func calculate_catch_chance(
	species_id    : int,
	hp_ratio      : float,
	master_bonus  : float,
	pokeball_type : String = "pokeball"
) -> float:
	var species_data   : Dictionary = GameData.get_species(species_id)
	var catch_rate_raw : int        = species_data.get("catch_rate", 45)

	var catch_base  : float = float(catch_rate_raw) / 255.0
	var hp_bonus    : float = (1.0 - hp_ratio) * 0.5
	var master_bns  : float = master_bonus * 0.03
	var ball_mult   : float = POKEBALL_MULT.get(pokeball_type, 1.0)

	return min((catch_base + hp_bonus + master_bns) * ball_mult, 0.97)

## Tenta capturar o Pokémon. Retorna true se a captura for bem-sucedida.
func attempt_capture(target: WildPokemon, pokeball_type: String) -> bool:
	if not is_instance_valid(target):
		return false

	_find_trainer_stats()
	var master_pts : float = float(trainer_stats.get_master_capture_points()) if trainer_stats else 0.0
	var hp_ratio   : float = target.get_hp_ratio()
	var chance     : float = calculate_catch_chance(target.species_id, hp_ratio, master_pts, pokeball_type)

	if RNGManager.chance(chance):
		var pokemon_data := _build_pokemon_data(target)
		_add_to_team_or_pc(pokemon_data)
		EventBus.capture_success.emit(pokemon_data)
		EventBus.pokemon_caught.emit(pokemon_data) if EventBus.has_signal("pokemon_caught") else null
		return true

	return false

# ──────────────────────────────────────────────────────────────────────────────
# Gestão de time / PC
# ──────────────────────────────────────────────────────────────────────────────

## Adiciona ao time se há vaga (≤6); senão envia ao PC.
func _add_to_team_or_pc(pokemon_data: Dictionary) -> void:
	if team.size() < 6:
		team.append(pokemon_data)
		EventBus.follower_changed.emit(pokemon_data)
	else:
		pc_box.append(pokemon_data)
		push_print("[CaptureSystem] PC: %s enviado ao PC (time cheio)." % pokemon_data.get("name", "?"))

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários internos
# ──────────────────────────────────────────────────────────────────────────────

func _build_pokemon_data(target: WildPokemon) -> Dictionary:
	var species_data : Dictionary = GameData.get_species(target.species_id)
	return {
		"species_id": target.species_id,
		"name":       species_data.get("name", "???"),
		"level":      target.wild_level,
		"hp":         target.current_hp,
		"max_hp":     target.max_hp,
		"is_alpha":   target.is_alpha,
		"types":      species_data.get("types", ["Normal"]),
	}

func _get_throw_origin() -> Vector2:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0].global_position
	return Vector2.ZERO

func _arc_peak(from: Vector2, to: Vector2) -> Vector2:
	var mid := (from + to) * 0.5
	return mid + Vector2(0, -POKEBALL_ARC_HEIGHT)
