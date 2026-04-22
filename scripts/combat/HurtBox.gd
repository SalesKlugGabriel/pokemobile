## HurtBox.gd — Área que recebe dano.
## Emite sinal hit(damage, attacker) ao ser atingida.
## Adicione ao grupo "hurtbox" para ser detectada por projéteis e HitBox.
extends Area2D

signal hit(damage: int, attacker: Node)

func _ready() -> void:
	add_to_group("hurtbox")

## Chamado por ProjectileBase ou HitBox ao colidir.
func take_damage(amount: int, attacker: Node = null) -> void:
	hit.emit(amount, attacker)
	# Propaga para o pai se ele implementar take_damage
	var parent := get_parent()
	if parent and parent.has_method("take_damage") and parent != attacker:
		parent.take_damage(amount, attacker)
