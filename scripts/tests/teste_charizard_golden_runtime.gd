## Executado no projeto de ensaio antes da promoção e no projeto real depois.
extends SceneTree

var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var Entidade: GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var charizard = Entidade.nascer(mundo, 6, 30, Vector3(0, 2, 0), "ground_biped")
	await process_frame
	await process_frame
	_conferir(charizard.tem_modelo, "Charizard nasce com GLB, sem fallback primitivo")
	var suporte := charizard.get_node_or_null("Modelo") as Node3D
	_conferir(suporte != null and is_zero_approx(suporte.rotation_degrees.x),
		"modelo entra sem remendo de eixo")
	_conferir(suporte != null and bool(ValidadorDeModelo.conferir(suporte, 6)["ok"]),
		"canônico importado mantém escala de 1,70 m e pés no chão")
	var visual: PokemonVisual3D = charizard.find_child("PokemonVisual3D", true, false)
	_conferir(visual != null and visual.tem_animacao() and not visual.fallback_ativo(),
		"PokemonVisual3D conecta ao AnimationPlayer sem fallback")
	if visual != null:
		_conferir("IDLE" in visual.clipe_atual().to_upper(), "parado usa IDLE")
		charizard.velocity = Vector3(charizard.velocidade_maxima(), 0, 0)
		charizard.ultimo_avanco = charizard.velocity
		await process_frame
		_conferir("RUN" in visual.clipe_atual().to_upper(), "corrida usa RUN, não WALK")
		charizard.animacao_visual_solicitada.emit("attack")
		await process_frame
		_conferir("ATTACK" in visual.clipe_atual().to_upper(), "ataque usa Action existente")
		charizard.animacao_visual_solicitada.emit("hit")
		await process_frame
		_conferir("HIT" in visual.clipe_atual().to_upper(), "dano usa Action existente")
		charizard.animacao_visual_solicitada.emit("faint")
		await process_frame
		_conferir("FAINT" in visual.clipe_atual().to_upper(), "queda usa Action existente")
	mundo.queue_free()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)


func _conferir(condicao: bool, mensagem: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", mensagem)
	else:
		falhas += 1
		push_error("FALHA: " + mensagem)
