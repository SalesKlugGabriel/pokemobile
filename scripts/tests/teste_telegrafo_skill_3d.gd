## Regressão do VFX de aviso: apresentação usa anúncio pronto, em metros.
extends SceneTree

const Telegrafo := preload("res://scripts/gameplay_v3/presentation/TelegrafoSkill3D.gd")
const LABORATORIO := "res://scripts/gameplay_v3/Laboratorio3D.gd"
var ok := 0
var fail := 0
var vfx: Node3D

func _conf(condicao: bool, nome: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", nome)
	else:
		fail += 1
		push_error("FALHA: " + nome)

func _initialize() -> void:
	vfx = Telegrafo.new()
	root.add_child(vfx)
	call_deferred("_rodar")

func _rodar() -> void:
	var fonte_do_lab := FileAccess.get_file_as_string(LABORATORIO)
	_conf(fonte_do_lab.contains("var telegrafo_de_skill : TelegrafoSkill3D"),
		"Laboratório declara o VFX sem duplicar telegrafia")
	_conf(fonte_do_lab.contains("_montar_telegrafo_de_skill()") and fonte_do_lab.contains("TelegrafoSkill3D.new()"),
		"Laboratório monta o VFX na abertura")
	var anuncio := {"golpe": "gust", "area_type": "cone", "origem": Vector3(2, 1, 3),
		"direcao": Vector3(0, 0, -1), "alcance": 3.0, "raio": 3.0,
		"largura": 2.0, "resolve_em": Time.get_ticks_msec() / 1000.0 + 5.0,
		"tipo": "Flying"}
	vfx.mostrar(anuncio)
	await process_frame
	_conf(bool(vfx.estado_visual()["ativo"]), "anúncio cria geometria visível")
	_conf(str(vfx.estado_visual()["forma"]) == "cone", "forma vem pronta da regra")
	_conf(vfx.get_node_or_null("AreaDeAviso") != null, "marca recebe nó explícito")
	vfx.cancelar("gust")
	await process_frame
	_conf(not bool(vfx.estado_visual()["ativo"]), "cancelamento remove a marca")
	print("=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail else 0)
