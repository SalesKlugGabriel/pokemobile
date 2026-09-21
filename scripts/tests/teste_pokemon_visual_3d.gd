## Regressão da ponte RFC-010: corpo decide, visual apenas apresenta.
extends SceneTree

var ok := 0
var falhas := 0

func _check(condicao: bool, descricao: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", descricao)
	else:
		falhas += 1
		push_error("FALHA: " + descricao)

func _init() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	# Carregar depois do boot deixa os autoloads disponíveis ao parser da entidade.
	var Entidade: GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var PonteVisual: GDScript = load("res://scripts/gameplay_v3/presentation/PokemonVisual3D.gd")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var rattata = Entidade.nascer(mundo, 19, 20, Vector3.ZERO, "ground_quadruped")
	await process_frame
	await process_frame
	var visual: Node = rattata.find_child("PokemonVisual3D", true, false)
	_check(rattata.tem_modelo, "Rattata usa o GLB em vez do primitivo")
	_check(visual != null, "ponte visual é montada junto do modelo")
	if visual != null:
		_check(visual.tem_animacao(), "GLB com Actions não ativa fallback")
		_check("IDLE" in visual.clipe_atual().to_upper(), "parado toca idle")
		rattata.velocity = Vector3(rattata.velocidade_maxima(), 0.0, 0.0)
		rattata.ultimo_avanco = rattata.velocity
		await process_frame
		_check("RUN" in visual.clipe_atual().to_upper(), "estado público run toca Action de corrida")
		rattata.animacao_visual_solicitada.emit("attack")
		await process_frame
		_check("ATTACK" in visual.clipe_atual().to_upper(), "pedido confirmado toca ataque")
		rattata.animacao_visual_solicitada.emit("hit")
		await process_frame
		_check("HIT" in visual.clipe_atual().to_upper(), "pedido confirmado toca dano")
		rattata.animacao_visual_solicitada.emit("faint")
		await process_frame
		_check("FAINT" in visual.clipe_atual().to_upper(), "pedido confirmado toca queda")

	var sem_asset: Node3D = PonteVisual.new()
	mundo.add_child(sem_asset)
	sem_asset.configurar(rattata, Node3D.new())
	await process_frame
	_check(sem_asset.fallback_ativo(), "Action ausente produz fallback visível")
	_check(sem_asset.get_node_or_null("FallbackAnimacaoVisivel") != null,
		"fallback não falha silenciosamente")
	mundo.queue_free()
	_finish()

func _finish() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
