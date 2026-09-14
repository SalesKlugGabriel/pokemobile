## Laboratorio3D.gd — Fase 2: a cena 3D experimental, e a medição que decide.
##
## ── Por que esta cena existe antes de qualquer gameplay ─────────────────────
##
## A auditoria achou o fato que governa o pivô inteiro: o renderer deste projeto
## é **`gl_compatibility`**, escolhido pra o jogo rodar no navegador. Ele
## desenha 3D, mas sem SDFGI, sem compute e com sombras limitadas — enquanto a
## §24 do pedido fala em vegetação densa estilo ARK.
##
## Descobrir que não aguenta **com uma floresta pronta** custaria semanas.
## Descobrir com uma cena vazia custa uma tarde. Então a Fase 2 é a medição.
##
## ── O que ela mede ──────────────────────────────────────────────────────────
##
## Três degraus, sempre no MESMO navegador e na mesma resolução:
##
##   1. base     — chão, luz e câmera. O piso do que o renderer custa.
##   2. vegetação— MultiMesh com N instâncias. É o teste de verdade: é assim que
##                 árvore e grama vão existir (§42), nunca como Node por planta.
##   3. entidades— corpos com física, no lugar de Pokémon e treinador.
##
## O número sai pelo `JavaScriptBridge` pra a página, e quem lê é o Playwright.
## **FPS alegado a partir de teste headless não vale** — headless não renderiza,
## e esse foi um erro que eu já quase cometi neste projeto.
extends Node3D

## Quantas instâncias em cada degrau de vegetação. Os saltos são grandes de
## propósito: o que interessa é onde a curva quebra, não a precisão no meio.
const DEGRAUS : Array[int] = [0, 500, 2000, 8000, 20000]

## Segundos medindo cada degrau. Os primeiros quadros depois de criar geometria
## são sempre ruins (compilação de shader, upload); descartar o começo é o que
## separa medir o estado estável de medir o susto.
const SEGUNDOS_POR_DEGRAU : float = 3.0
const SEGUNDOS_DESCARTADOS : float = 1.0

## Corpos com física, pra o custo não ser só de desenho.
const CORPOS_FISICOS : int = 40

var _degrau : int = -1
var _tempo : float = 0.0
var _quadros : int = 0
var _resultados : Array = []
var _multimesh : MultiMeshInstance3D = null
var _terminou : bool = false
var _tela : Label = null

func _ready() -> void:
	_montar_tela()
	_montar_base()
	_montar_corpos()
	_proximo_degrau()

## A medição precisa ser LEGÍVEL no aparelho de quem mede. A primeira versão só
## imprimia no console e entregava o resultado a `window.__v3` — inútil pra
## alguém abrindo no celular. Número que o medidor não consegue ler não é
## medição, é log.
func _montar_tela() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 100
	add_child(camada)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(fundo)

	_tela = Label.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tela.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tela.add_theme_font_size_override("font_size", 34)
	_tela.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camada.add_child(_tela)
	_escrever("Medindo...\n\nDeixe a tela ligada.\nLeva cerca de 15 segundos.")

func _escrever(texto: String) -> void:
	if _tela != null:
		_tela.text = texto

# ──────────────────────────────────────────────────────────────────────────────
# A cena
# ──────────────────────────────────────────────────────────────────────────────

func _montar_base() -> void:
	# Chão. Um plano grande basta: o que se quer medir é o renderer, não o
	# terreno — terreno de verdade é a Fase 4.
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	chao.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.35, 0.22)
	chao.material_override = mat
	add_child(chao)

	var corpo_do_chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200, 1, 200)
	forma.shape = caixa
	forma.position = Vector3(0, -0.5, 0)
	corpo_do_chao.add_child(forma)
	add_child(corpo_do_chao)

	# Sol. Sombra LIGADA de propósito: sombra é justamente o que o
	# `gl_compatibility` faz de forma limitada, então medir sem ela seria medir
	# um caso que o jogo não vai ter.
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	add_child(sol)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	ambiente.environment = env
	add_child(ambiente)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 6, 18)
	camera.rotation_degrees = Vector3(-12, 0, 0)
	camera.current = true
	add_child(camera)

	_multimesh = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var arbusto := BoxMesh.new()
	arbusto.size = Vector3(0.6, 1.8, 0.6)
	mm.mesh = arbusto
	_multimesh.multimesh = mm
	var mat_veg := StandardMaterial3D.new()
	mat_veg.albedo_color = Color(0.2, 0.45, 0.18)
	_multimesh.material_override = mat_veg
	add_child(_multimesh)

## Corpos com física caindo e colidindo — o custo que Pokémon e treinador vão
## ter, sem depender de nenhum deles existir ainda.
func _montar_corpos() -> void:
	for i in CORPOS_FISICOS:
		var c := CharacterBody3D.new()
		var forma := CollisionShape3D.new()
		var capsula := CapsuleShape3D.new()
		capsula.radius = 0.4
		capsula.height = 1.6
		forma.shape = capsula
		c.add_child(forma)
		var vis := MeshInstance3D.new()
		var malha := CapsuleMesh.new()
		malha.radius = 0.4
		malha.height = 1.6
		vis.mesh = malha
		c.add_child(vis)
		c.position = Vector3(randf_range(-30, 30), 2.0, randf_range(-30, 30))
		add_child(c)

func _povoar(quantos: int) -> void:
	var mm : MultiMesh = _multimesh.multimesh
	mm.instance_count = quantos
	for i in quantos:
		var t := Transform3D()
		# Escala e rotação variáveis: a §24 proíbe vegetação em grade, e medir
		# com tudo idêntico mediria um caso que o jogo não vai ter.
		t = t.scaled(Vector3.ONE * randf_range(0.7, 1.6))
		t = t.rotated(Vector3.UP, randf_range(0.0, TAU))
		t.origin = Vector3(randf_range(-60, 60), 0.9, randf_range(-60, 60))
		mm.set_instance_transform(i, t)

# ──────────────────────────────────────────────────────────────────────────────
# A medição
# ──────────────────────────────────────────────────────────────────────────────

func _proximo_degrau() -> void:
	_degrau += 1
	if _degrau >= DEGRAUS.size():
		_encerrar()
		return
	_povoar(DEGRAUS[_degrau])
	_tempo = 0.0
	_quadros = 0

func _process(delta: float) -> void:
	if _terminou:
		return
	_tempo += delta
	if _tempo <= SEGUNDOS_DESCARTADOS:
		return   # aquecimento: shader compilando, geometria subindo
	_quadros += 1
	if _tempo < SEGUNDOS_POR_DEGRAU:
		return

	var medido : float = float(_quadros) / (SEGUNDOS_POR_DEGRAU - SEGUNDOS_DESCARTADOS)
	_resultados.append({
		"instancias": DEGRAUS[_degrau],
		"fps": snappedf(medido, 0.1),
		"corpos": CORPOS_FISICOS,
	})
	print("[V3] %d instâncias -> %.1f FPS" % [DEGRAUS[_degrau], medido])
	_mostrar_parcial()
	_proximo_degrau()

func _mostrar_parcial() -> void:
	var linhas : Array[String] = ["Medindo... (%d de %d)" % [_resultados.size(), DEGRAUS.size()], ""]
	for r in _resultados:
		linhas.append("%6d plantas   %5.1f FPS" % [int(r["instancias"]), float(r["fps"])])
	_escrever("\n".join(linhas))

func _encerrar() -> void:
	_terminou = true
	var relatorio := {
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"tela": "%dx%d" % [get_viewport().get_visible_rect().size.x,
						   get_viewport().get_visible_rect().size.y],
		"degraus": _resultados,
	}
	print("[V3] RELATORIO " + JSON.stringify(relatorio))

	var linhas : Array[String] = ["RESULTADO", ""]
	var pior : float = 9999.0
	for r in _resultados:
		linhas.append("%6d plantas   %5.1f FPS" % [int(r["instancias"]), float(r["fps"])])
		pior = minf(pior, float(r["fps"]))
	linhas.append("")
	linhas.append("renderer: %s" % str(relatorio["renderer"]))
	linhas.append("tela: %s" % str(relatorio["tela"]))
	linhas.append("")
	# A leitura pronta, pra não depender de quem olha saber interpretar.
	if pior >= 50.0:
		linhas.append("✅ AGUENTA — 3D é viável neste aparelho")
	elif pior >= 30.0:
		linhas.append("⚠️ NO LIMITE — dá, mas com vegetação contida")
	else:
		linhas.append("🔴 NÃO AGUENTA — precisamos rever renderer ou escopo")
	linhas.append("")
	linhas.append("Mande um print pro Claude.")
	_escrever("\n".join(linhas))
	# No navegador, entrega o resultado à página — é de lá que o Playwright lê.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__v3 = %s;" % JSON.stringify(relatorio), true)
