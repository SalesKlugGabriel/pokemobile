## AreaTargeting.gd — Busca de alvos num raio (golpe de área), Fase 4 do motor
## de combate em tempo real (02/09). Antes desta fase não existia NENHUM
## código de dano em área no projeto — FollowerPokemon/WildPokemon só sabiam
## bater num único current_target/target.
class_name AreaTargeting
extends RefCounted

## Retorna todo nó do(s) grupo(s) indicado(s) dentro de radius de origin.
## groups: um StringName ou um Array de StringName (pra golpe de área que
## precisa acertar mais de um grupo de inimigos, ex: WildPokemon mirando
## Follower + Treinador ao mesmo tempo).
## exclude: nós que nunca devem entrar no resultado (ex: o próprio atacante).
static func find_targets_in_radius(origin: Vector2, radius: float, groups, exclude: Array = []) -> Array:
	var group_list : Array = groups if groups is Array else [groups]
	var loop := Engine.get_main_loop()
	var result : Array = []
	for group in group_list:
		for node in loop.get_nodes_in_group(group):
			if node in exclude or node in result:
				continue
			if not (node is Node2D):
				continue
			if node.global_position.distance_to(origin) <= radius:
				result.append(node)
	return result
