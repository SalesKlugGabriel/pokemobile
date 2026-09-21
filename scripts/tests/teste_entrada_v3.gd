## Regressão da rota inicial V3: não depende de save nem abre o mundo real.
extends SceneTree

const CENA := "res://scenes/gameplay_v3/EntradaV3.tscn"
const DESTINO := "res://scenes/gameplay_v3/Laboratorio3D.tscn"
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
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == CENA,
		"projeto inicia pela entrada V3")
	_check(ResourceLoader.exists(CENA), "cena de entrada V3 existe")
	_check(ResourceLoader.exists(DESTINO), "destino do mundo 3D existe")
	var empacotada := load(CENA) as PackedScene
	_check(empacotada != null, "entrada V3 carrega como PackedScene")
	if empacotada != null:
		var entrada := empacotada.instantiate() as Control
		root.add_child(entrada)
		# Em execução por `--script`, o _ready da cena acrescentada pode rodar
		# somente no quadro seguinte ao add_child. Aguardar dois evita medir a
		# árvore antes de a interface ter sido montada.
		await process_frame
		await process_frame
		var botao := entrada.find_child("EntrarMundo3D", true, false) as Button
		_check(botao != null, "botão de entrada 3D é montado")
		if botao != null:
			_check(botao.text == "ENTRAR NO MUNDO 3D", "ação principal é explícita")
			_check(botao.custom_minimum_size.y >= 48.0, "alvo de toque tem altura acessível")
		_check(entrada.find_child("StatusV3", true, false) != null, "estado do laboratório é declarado")
		entrada.queue_free()
	_finish()

func _finish() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
