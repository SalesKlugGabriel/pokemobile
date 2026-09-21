## Regressão da apresentação de impacto V3. Roda isolada, sem combate real.
extends SceneTree

var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var laboratorio := FileAccess.get_file_as_string("res://scripts/gameplay_v3/Laboratorio3D.gd")
	_conferir(laboratorio.contains("var impacto_de_golpe : ImpactoDeGolpe3D"),
		"Laboratório declara o VFX de impacto")
	_conferir(laboratorio.contains("_montar_impacto_de_golpe()"),
		"Laboratório monta o VFX de impacto")
	var Classe: GDScript = load("res://scripts/gameplay_v3/presentation/ImpactoDeGolpe3D.gd")
	var efeito: Node3D = Classe.new()
	root.add_child(efeito)
	await process_frame
	_conferir(efeito.estado_visual()["ativos"] == 0, "começa sem impactos")

	efeito.mostrar({
		"golpe": "flamethrower", "destino": Vector3(3.0, 1.2, -4.0),
		"tipo": "Fire", "efetividade": "muito_forte", "fracao_da_vida": 0.42,
	})
	await process_frame
	var estado: Dictionary = efeito.estado_visual()
	_conferir(estado["ativos"] == 1, "relatório válido cria um impacto")
	var impacto: Node3D = efeito.get_child(0)
	_conferir(impacto.position.is_equal_approx(Vector3(3.0, 1.2, -4.0)),
		"o impacto usa o destino fornecido pelo relatório")
	_conferir(impacto.get_child_count() == 2, "o pulso tem dois anéis visuais")

	# Saturar prova que spam de combate não cria efeitos sem limite.
	for indice in 16:
		efeito.mostrar({"destino": Vector3(indice, 0.0, 0.0)})
	_conferir(efeito.estado_visual()["ativos"] == 12, "limita efeitos simultâneos")
	efeito.mostrar({"tipo": "Fire"})
	_conferir(efeito.estado_visual()["ativos"] == 12, "relatório sem destino é ignorado")
	efeito.queue_free()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)


func _conferir(condicao: bool, mensagem: String) -> void:
	if condicao:
		ok += 1
		print("  OK  %s" % mensagem)
	else:
		falhas += 1
		push_error("FALHA: %s" % mensagem)
