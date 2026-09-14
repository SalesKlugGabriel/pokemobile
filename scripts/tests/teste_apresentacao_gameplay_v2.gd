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
	await _testar_laboratorio_integrado()
	_finalizar()

func _testar_laboratorio_integrado() -> void:
	print("-- Integração com o Laboratório real --")
	var cena := load("res://scenes/gameplay_v2/Laboratorio.tscn") as PackedScene
	_confirmar(cena != null, "a cena real do Laboratório carrega com a apresentação")
	if cena == null:
		return
	var lab := cena.instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame

	var camera := lab.get_node_or_null("CameraDeCombate") as CameraDeCombate
	var hud := lab.get_node_or_null("HudV2") as HudV2
	var tele := lab.get_node_or_null("TelegraphV2") as TelegraphV2
	var integracao := lab.get_node_or_null("IntegracaoVisualV2") as IntegracaoVisualV2
	_confirmar(camera != null and hud != null and tele != null and integracao != null,
		"Laboratório nasce com câmera, HUD, telegraph e integração")
	var cameras := lab.find_children("*", "Camera2D", true, false)
	_confirmar(cameras.size() == 1, "a câmera provisória não duplica a câmera integrada")
	if hud == null or camera == null or tele == null:
		lab.queue_free()
		await process_frame
		return

	var snapshot : Dictionary = lab.estado()
	var treinador : Dictionary = snapshot.get("treinador", {})
	var pokemon : Dictionary = snapshot.get("pokemon", {})
	var hp_treinador := hud.get_node("Interface/MargemSuperior/PainelStatus/Status/VidaTreinador/HP") as ProgressBar
	var nome_pokemon := hud.get_node("Interface/MargemSuperior/PainelStatus/Status/VidaPokemon/Nome") as Label
	var grade := hud.get_node("Interface/MargemSkills/PainelSkills/Skills/Grade") as GridContainer
	_confirmar(int(hp_treinador.value) == int(treinador.get("vida", -1)),
		"HUD nasce da vida numérica do Laboratório")
	_confirmar(nome_pokemon.text == str(pokemon.get("nome", "")).to_upper(),
		"HUD nasce com o Pokémon ativo real")
	_confirmar(grade.get_child_count() == 8 and int(pokemon.get("capacidade", 0)) == 4,
		"HUD mantém oito slots e mostra a capacidade recebida")

	lab.treinador.stamina_mudou.emit(20.0, 100.0, "exaustao_2")
	var estado_stamina := hud.get_node("Interface/MargemSuperior/PainelStatus/Status/Folego/Estado") as Label
	_confirmar(estado_stamina.text == "EXAUSTÃO II", "sinal real de stamina atualiza a HUD")

	lab.contexto_de_camera.emit("boss", 30)
	_confirmar(camera.contexto_ativo() == "boss", "contexto real do Laboratório atualiza a câmera")

	var inimigos : Array = root.get_tree().get_nodes_in_group("selvagem_v2")
	if not inimigos.is_empty():
		var alvo : Node = inimigos[0]
		_confirmar(lab.ordenar("atacar", {"alvo": alvo}), "ordem real é aceita pela fachada")
		await process_frame
		var painel_alvo := hud.get_node("Interface/MargemAlvo/PainelAlvo") as PanelContainer
		var nome_alvo := hud.get_node("Interface/MargemAlvo/PainelAlvo/Alvo/Nome") as Label
		_confirmar(painel_alvo.visible and nome_alvo.text == str(alvo.nome_exibido).to_upper(),
			"ordem e alvo reais aparecem na HUD")

	tele.limpar()
	var dados_cast := {
		"area_type": "ring", "origem": Vector2(900, 700), "direcao": Vector2.RIGHT,
		"duracao": 0.0, "hostil": true, "raio": 180.0, "fracao_vazia": 0.6,
	}
	lab.pokemon.golpe_telegrafado.emit(900, dados_cast)
	_confirmar(tele.quantidade_ativa() == 0, "golpe instantâneo não cria aviso visual falso")
	dados_cast["duracao"] = 1.0
	lab.pokemon.golpe_telegrafado.emit(901, dados_cast)
	_confirmar(tele.quantidade_ativa() == 1, "cast real chega ao renderer por sinal")
	lab.pokemon.telegrafia_encerrada.emit(901, "interrompido")
	await create_timer(0.22).timeout
	_confirmar(tele.quantidade_ativa() == 0, "interrupção real remove o aviso pelo cast_id")

	var trocou : bool = lab.proximo_pokemon()
	await process_frame
	_confirmar(trocou and nome_pokemon.text == str(lab.pokemon.nome_exibido).to_upper(),
		"troca real reconecta HUD e câmera ao novo Pokémon")

	lab.queue_free()
	await process_frame

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
