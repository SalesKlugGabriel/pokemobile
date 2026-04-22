## HitBox.gd — Área de ataque que detecta HurtBoxes e aplica dano.
## Configura damage e attacker antes de ativar o monitoramento.
extends Area2D

## Dano a aplicar ao colidir
var damage   : int  = 0
## Nó que possui este HitBox (para evitar auto-hit)
var attacker : Node = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# HitBox começa inativo; o dono o habilita durante um swing/skill
	monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	# Evita acertar o próprio dono
	if area.get_parent() == attacker:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage, attacker)

## Ativa o HitBox por uma duração (em segundos) e depois desativa.
func activate(duration: float) -> void:
	monitoring = true
	await get_tree().create_timer(duration).timeout
	monitoring = false
