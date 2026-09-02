## CaptureSystem.gd — Sistema de captura de Pokémon selvagem (Autoload).
## Gerencia lançamento em arco, cálculo de chance e resultado. Sem class_name
## de propósito — o nome "CaptureSystem" já é o do autoload; declarar
## class_name igual colide ("hides an autoload singleton").
## Após captura: vai pro SaveManager de verdade; emite EventBus.capture_success.
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
## Pokémon de treinador nunca pode ser capturado.
func attempt_capture(target: WildPokemon, pokeball_type: String) -> bool:
	if not is_instance_valid(target):
		return false
	if target.is_trainer_owned:
		return false

	_find_trainer_stats()
	var master_pts : float = float(trainer_stats.get_master_capture_points()) if trainer_stats else 0.0
	var hp_ratio   : float = target.get_hp_ratio()
	var chance     : float = calculate_catch_chance(target.species_id, hp_ratio, master_pts, pokeball_type)

	if RNGManager.chance(chance):
		var pokemon_data := _build_pokemon_data(target)
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
	return SaveManager.make_caught_data(bp)

func _get_throw_origin() -> Vector2:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0].global_position
	return Vector2.ZERO

func _arc_peak(from: Vector2, to: Vector2) -> Vector2:
	var mid := (from + to) * 0.5
	return mid + Vector2(0, -POKEBALL_ARC_HEIGHT)
