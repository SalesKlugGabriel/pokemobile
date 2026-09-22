## Pidgeot canônico pelo mesmo carregamento de Pokémon do jogo.
extends SceneTree

var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var Entidade: GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var pidgeot = Entidade.nascer(mundo, 18, 30, Vector3(0, 2, 0), "flying")
	await process_frame
	await process_frame
	_conferir(pidgeot.tem_modelo, "Pidgeot carrega GLB sem fallback")
	var suporte := pidgeot.get_node_or_null("Modelo") as Node3D
	_conferir(suporte != null and bool(ValidadorDeModelo.conferir(suporte, 18)["ok"]),
		"escala e origem do canônico válidas")
	var visual: PokemonVisual3D = pidgeot.find_child("PokemonVisual3D", true, false)
	_conferir(visual != null and visual.tem_animacao() and not visual.fallback_ativo(),
		"ponte visual conectada sem fallback")
	if visual != null:
		_conferir("FLY" in visual.clipe_atual().to_upper(),
			"arquétipo aéreo usa FLY mesmo sem deslocamento")
		pidgeot.animacao_visual_solicitada.emit("attack")
		await process_frame
		_conferir("ATTACK" in visual.clipe_atual().to_upper(), "ataque usa Action")
		pidgeot.animacao_visual_solicitada.emit("hit")
		await process_frame
		_conferir("HIT" in visual.clipe_atual().to_upper(), "dano usa Action")
		pidgeot.animacao_visual_solicitada.emit("faint")
		await process_frame
		_conferir("FAINT" in visual.clipe_atual().to_upper(), "desmaio usa Action")
	mundo.queue_free()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas else 0)


func _conferir(condicao: bool, descricao: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", descricao)
	else:
		falhas += 1
		push_error("FALHA: " + descricao)
