## Integração mínima dos componentes visuais V2. Não testa gosto visual; prova
## que a cena isolada nasce, recebe estado externo e encerra casts por id.
extends SceneTree

var _ok := 0
var _falhas := 0

func _init() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	print("== Gameplay V2: apresentação isolada ==")
	var cena := load("res://scenes/gameplay_v2/ApresentacaoV2.tscn") as PackedScene
	_confirmar(cena != null, "a cena de apresentação carrega")
	if cena == null:
		_finalizar()
		return
	var raiz := cena.instantiate()
	root.add_child(raiz)
	current_scene = raiz
	await process_frame
	await process_frame

	var camera := raiz.get_node_or_null("CameraDeCombate") as CameraDeCombate
	var hud := raiz.get_node_or_null("HudV2") as HudV2
	var tele := raiz.get_node_or_null("TelegraphV2") as TelegraphV2
	_confirmar(camera != null and hud != null and tele != null,
		"câmera, HUD e telegraph nascem juntos")

	if camera != null:
		camera.solicitar_contexto("interior", 10)
		camera.solicitar_contexto("boss", 30)
		_confirmar(camera.contexto_ativo() == "boss", "prioridade de câmera escolhe boss")
		camera.remover_contexto("boss")
		_confirmar(camera.contexto_ativo() == "interior", "remover boss restaura o contexto anterior")

	if hud != null:
		hud.atualizar_stamina(0.0, 100.0, "exaustao_3")
		var estado := hud.get_node("Interface/MargemSuperior/PainelStatus/Status/Folego/Estado") as Label
		_confirmar(estado.text == "EXAUSTÃO III", "exaustão não depende apenas de cor")
		var skills : Array = []
		for i in 8:
			skills.append({"nome": "Skill %d" % (i + 1), "progresso": 1.0})
		hud.atualizar_skills(skills, 8)
		var grade := hud.get_node("Interface/MargemSkills/PainelSkills/Skills/Grade") as GridContainer
		_confirmar(grade.get_child_count() == 8, "HUD preserva os oito slots dinâmicos")
		hud.ajustar_para_largura(430.0)
		_confirmar(grade.columns == 4, "portrait distribui skills em duas linhas")
		var margem_alvo := hud.get_node("Interface/MargemAlvo") as MarginContainer
		_confirmar(is_zero_approx(margem_alvo.anchor_left), "portrait empilha o alvo sob o estado")
		hud.ajustar_para_largura(1280.0)
		_confirmar(grade.columns == 8, "desktop usa uma linha quando há espaço")

	if tele != null:
		tele.limpar()
		for i in 6:
			tele.mostrar_golpe(100 + i, {
				"area_type": ["circle", "ring", "cone", "line", "beam", "target"][i],
				"origem": Vector2(400 + i * 30, 500),
				"direcao": Vector2.RIGHT,
				"duracao": 1.0,
				"hostil": i % 2 == 0,
				"raio": 96.0,
				"raio_interno": 36.0,
				"largura": 72.0,
				"comprimento": 180.0,
				"abertura": deg_to_rad(70.0),
			})
		_confirmar(tele.quantidade_ativa() == 6, "seis geometrias coexistem sem sobrescrever cast_id")
		for i in 6:
			tele.encerrar_golpe(100 + i, "cancelado")
		await create_timer(0.22).timeout
		_confirmar(tele.quantidade_ativa() == 0, "encerramento do gameplay remove cada aviso")

	raiz.queue_free()
	await process_frame
	_finalizar()

func _confirmar(condicao: bool, texto: String) -> void:
	if condicao:
		_ok += 1
		print("  OK   - ", texto)
	else:
		_falhas += 1
		push_error("FALHA - " + texto)

func _finalizar() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [_ok, _falhas])
	quit(0 if _falhas == 0 else 1)
