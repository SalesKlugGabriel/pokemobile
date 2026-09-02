## ProjectileBase.gd — Script base para projéteis de skills.
## Estende Area2D. Move em linha reta; ao colidir com HurtBox aplica dano.
## Cooldown gerenciado pelo lançador, não pelo projétil.
class_name ProjectileBase
extends Area2D

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

@export var speed     : float  = 400.0
@export var damage    : int    = 10
@export var move_type : String = "Normal"

## Se true, atravessa múltiplos alvos antes de se destruir
@export var pierce    : bool   = false

## Bônus de dano externo (ex: afinidade do Treinador, passa-se ao criar o projétil)
@export var damage_bonus : float = 0.0

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

## Direção normalizada de movimento (definida ao spawnar)
var direction  : Vector2 = Vector2.RIGHT

## Quem lançou este projétil (para evitar auto-hit)
var owner_node : Node = null

## Alvos já atingidos (para pierce)
var _hit_nodes : Array[Node] = []

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Conecta ao sinal de sobreposição de área
	area_entered.connect(_on_area_entered)
	# Auto-destrói após 4 segundos para evitar vazamento
	var timeout := get_tree().create_timer(4.0)
	timeout.timeout.connect(queue_free)

# ──────────────────────────────────────────────────────────────────────────────
# Configuração pós-spawn
# ──────────────────────────────────────────────────────────────────────────────

## Configura o projétil após instanciação.
## dir: direção normalizada. lançador: nó que disparou (para evitar auto-hit).
func setup(dir: Vector2, launcher: Node, bonus: float = 0.0) -> void:
	direction    = dir.normalized()
	owner_node   = launcher
	damage_bonus = bonus
	# Rotaciona sprite para a direção do movimento
	rotation = dir.angle()

# ──────────────────────────────────────────────────────────────────────────────
# Movimento
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

# ──────────────────────────────────────────────────────────────────────────────
# Colisão com HurtBox
# ──────────────────────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	# Ignora se não for HurtBox ou se já atingiu este alvo (pierce)
	if not area.is_in_group("hurtbox"):
		return

	var target_node : Node = area.get_parent()

	# Não acerta quem lançou
	if target_node == owner_node:
		return

	# Pierce: não acerta o mesmo nó duas vezes
	if pierce and target_node in _hit_nodes:
		return

	_apply_hit(area, target_node)

func _apply_hit(hurtbox: Area2D, target_node: Node) -> void:
	# Calcula dano considerando tipo e stats do defensor (se disponível)
	var final_damage := damage
	if target_node.has_method("get_combat_stats"):
		var defender_stats : Dictionary = target_node.get_combat_stats()
		var move_data := {
			"power":        damage,
			"type":         move_type,
			"damage_bonus": damage_bonus,
		}
		var attacker_stats := { "atk": 50, "level": 1 }   # fallback; lançador deve sobrescrever
		if owner_node and owner_node.has_method("get_combat_stats"):
			attacker_stats = owner_node.get_combat_stats()
		final_damage = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)

	# Aplica dano via método padronizado
	if hurtbox.has_method("take_damage"):
		hurtbox.take_damage(final_damage, owner_node)
	elif target_node.has_method("take_damage"):
		target_node.take_damage(final_damage, owner_node)

	if pierce:
		_hit_nodes.append(target_node)
	else:
		queue_free()
