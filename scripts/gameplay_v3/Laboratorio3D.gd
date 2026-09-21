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

## Fase 3: a cena deixou de ser só a régua de FPS e virou o laboratório.
## `medir_fps` liga a medição da Fase 2, que fica disponível pra repetir em
## outro aparelho sem precisar de um build separado.
@export var medir_fps : bool = false

var treinador : TrainerController3D = null
var controle : ControlModeManager = null
var hud_de_combate : HudCombate3D = null

func _ready() -> void:
	_montar_base()
	controle = ControlModeManager.new()
	controle.name = "ControlModeManager"
	add_child(controle)

	if medir_fps:
		_montar_tela()
		_montar_corpos()
		_proximo_degrau()
		return

	_montar_treinador()
	_montar_pokemon()   # precisa do treinador pronto: o 1º do trio o acompanha
	_montar_hud_de_combate()
	_povoar(600)   # vegetação leve, só pra ter referência de movimento no mundo
	_anotar("Laboratório 3D aberto (Fase 3)")

## §16: **três** Pokémon, um por arquétipo implementado — não dezenas.
## O objetivo é provar a arquitetura, e três bastam pra isso.
const TRIO_DE_TESTE : Array[Dictionary] = [
	{"id": 6,   "nivel": 30, "arquetipo": "ground_biped",  "onde": Vector2(14, 22)},
	{"id": 130, "nivel": 30, "arquetipo": "aquatic",       "onde": Vector2(-8, -55)},
	{"id": 18,  "nivel": 30, "arquetipo": "flying",        "onde": Vector2(-22, 18)},
]

var pokemons : Array = []
var companheiro : PokemonInstance3D = null

## A HUD é uma apresentação do Pokémon que está sob controle. Ela não procura
## entidades nem decide estado: o Laboratório, que arbitra a transferência, é a
## única ponte que a vincula e desvincula.
func _montar_hud_de_combate() -> void:
	hud_de_combate = HudCombate3D.new()
	hud_de_combate.name = "HudCombate3D"
	add_child(hud_de_combate)
	hud_de_combate.desvincular_pokemon()
	hud_de_combate.hide()

## Fase 7 — os sinais da transferência. O Codex decide duração, curva e efeito;
## eu digo QUANDO e ENTRE QUEM (mesma fronteira da D-003).
signal transferencia_iniciada(de: String, para: String, alvo_id: int)
signal transferencia_concluida(modo: String)

func _montar_pokemon() -> void:
	for molde in TRIO_DE_TESTE:
		var p := PokemonInstance3D.new()
		add_child(p)
		# Fase 17: o trio do laboratório é do JOGADOR — carrega a escada de
		# capacidade inteira (4 a 8 golpes), não a régua enxuta do selvagem.
		p.montar(int(molde["id"]), int(molde["nivel"]), str(molde["arquetipo"]),
			RegraDeMovePool.CATEGORIA_JOGADOR)
		p.name = "Pokemon_%s" % p.nome_exibido
		var onde : Vector2 = molde["onde"]
		# Nasce SOBRE o terreno. Voador nasce no ar, que é onde ele vive.
		var acima : float = 6.0 if MovementProfile.voa(str(molde["arquetipo"])) else 0.5
		p.global_position = Terreno3D.ponto_em(onde.x, onde.y, acima) if terreno != null \
			else Vector3(onde.x, 2.0, onde.y)
		pokemons.append(p)

	# §6: o primeiro do trio vira o COMPANHEIRO — ele acompanha o treinador
	# pelo mundo. É a peça que a Fase 7 vai transformar em "assumir o controle".
	if not pokemons.is_empty() and treinador != null:
		companheiro = pokemons[0]
		companheiro.acompanha = treinador
		companheiro.derrotado.connect(_ao_cair_o_pokemon)
		companheiro.global_position = Terreno3D.ponto_em(
			treinador.global_position.x + 2.0, treinador.global_position.z + 2.0, 0.5)
		_anotar("%s acompanha o treinador" % companheiro.nome_exibido)

## §11 + §12: o treinador nasce, e o árbitro de input é quem lhe dá o controle.
## Nunca o contrário — o controlador não se auto-ativa.
func _montar_treinador() -> void:
	treinador = TrainerController3D.new()
	treinador.name = "TrainerController3D"
	# Nasce sobre o terreno, e não a uma altura chutada: `ponto_em` lê a mesma
	# função de altura que gerou a malha, então nunca nasce dentro do chão nem
	# caindo de 10 metros.
	treinador.position = Terreno3D.ponto_em(0.0, 30.0, 1.0) if terreno != null \
		else Vector3(0, 2, 0)
	add_child(treinador)
	controle.registrar(ControlModeManager.WORLD, treinador)
	controle.trocar_para(ControlModeManager.WORLD)

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

var terreno : Terreno3D = null

func _montar_base() -> void:
	# Fase 4: terreno de verdade, com altura, encosta, praia e água (§23, §26).
	# O chão plano da Fase 2 era pra medir o renderer; ele aprovava qualquer
	# controlador, porque não havia o que subir nem onde escorregar.
	if medir_fps:
		# A medição precisa do MESMO chão de antes pra os números serem
		# comparáveis com os de 14/09. Terreno novo mudaria a régua no meio.
		_montar_chao_plano()
	else:
		terreno = Terreno3D.new()
		terreno.name = "Terreno"
		add_child(terreno)

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

## O chão plano da Fase 2. Existe só pra a medição de FPS continuar comparável
## com a de 14/09 — trocar a cena da régua invalidaria a comparação.
func _montar_chao_plano() -> void:
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	chao.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.35, 0.22)
	chao.material_override = mat
	add_child(chao)

	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200, 1, 200)
	forma.shape = caixa
	forma.position = Vector3(0, -0.5, 0)
	corpo.add_child(forma)
	add_child(corpo)

## (Fase 3) Colina e degraus de caixa. Substituídos pelo `Terreno3D` — ficam
## porque o teste da Fase 3 ainda prova a regra de inclinação com eles.
func _montar_relevo() -> void:
	var relevo := StaticBody3D.new()
	relevo.name = "Relevo"
	add_child(relevo)

	# Uma rampa subível (~25°) e uma parede íngreme (~70°) lado a lado: é o par
	# que prova a regra do ângulo máximo — uma o treinador sobe, a outra não.
	for dados in [
			{"pos": Vector3(8, 0, -6), "tam": Vector3(10, 4, 10), "rot": -25.0},
			{"pos": Vector3(-10, 0, -6), "tam": Vector3(8, 6, 8), "rot": -70.0},
			# Degraus baixos (0,3 m): o `floor_snap_length` do corpo sobe isso
			# sozinho. Degrau de 0,8 m é PAREDE pra uma cápsula — o Godot 4 não
			# tem step-climb automático, e fingir que tem seria esconder um
			# problema que a Fase 4 precisa resolver de verdade.
			{"pos": Vector3(0, 0.15, -14), "tam": Vector3(6, 0.3, 6), "rot": 0.0},
			{"pos": Vector3(0, 0.45, -20), "tam": Vector3(6, 0.3, 6), "rot": 0.0},
		]:
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = dados["tam"]
		forma.shape = caixa
		forma.position = dados["pos"]
		forma.rotation_degrees.x = dados["rot"]
		relevo.add_child(forma)

		var vis := MeshInstance3D.new()
		var malha := BoxMesh.new()
		malha.size = dados["tam"]
		vis.mesh = malha
		vis.position = dados["pos"]
		vis.rotation_degrees.x = dados["rot"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.4, 0.33)
		vis.material_override = mat
		relevo.add_child(vis)

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
	# 🔴 Sem esta linha o laço de medição roda mesmo com `medir_fps` desligado —
	# e pior, com `_degrau = -1`. Em GDScript índice negativo conta do fim, então
	# `DEGRAUS[-1]` devolvia 20000 e o teste da Fase 3 imprimia uma medição de
	# 20 mil plantas que nunca aconteceu. Zero silencioso com número convincente,
	# que é a pior espécie.
	if not medir_fps or _terminou:
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


# ──────────────────────────────────────────────────────────────────────────────
# Fase 7 — a transferência de controle (§17)
# ──────────────────────────────────────────────────────────────────────────────
#
# O coração da fantasia: *"quando a batalha começa, eu assumo o controle do meu
# Pokémon"*. O desenho, com as alternativas consideradas, está em
# `docs/COMBAT_FIRST_PERSON.md`.

## Assumir o Pokémon. Devolve {"ok", "motivo"} — motivo em português, porque é
## ele que aparece na tela.
## Fase 16: o que o jogador tem permissão de atravessar aqui.
##
## ── 19/09: ligado à mochila DE VERDADE ──────────────────────────────────────
##
## Até hoje isto devolvia uma mochila de teste cravada. Agora lê
## `SaveManager.save_data["inventory"]`, que é a mochila real da V2 — a mesma
## que o jogador enche jogando.
##
## 🔴 **E o comentário que estava aqui apontava a chave ERRADA.** Ele dizia
## `save_data["items"]`; a chave real é **`"inventory"`**. Ligar pelo que estava
## escrito teria lido um dicionário vazio — e `permissoes_de({}, catalogo)`
## devolve `[]`, que é *falha fechada*. O jogador perderia Surf e Voar **sem
## nenhum erro**: as travessias simplesmente parariam de funcionar, e o motivo
## na tela seria "você não tem a MO", que é uma frase perfeitamente plausível.
## É o zero silencioso de novo, e desta vez estava escrito num comentário
## esperando alguém confiar nele.
##
## ── Por que ainda existe uma mochila de teste ───────────────────────────────
##
## Porque o laboratório precisa andar **sem save nenhum**: em headless, e na
## primeira vez que alguém abre a cena sem ter jogado. A regra é explícita —
## havendo save, ele manda; não havendo, a bancada concede as duas e **declara
## que está concedendo**, em vez de deixar a permissão valer por omissão.
const MOCHILA_DE_TESTE : Array[String] = ["hm02", "hm04"]

## De onde a última leitura de permissão veio. Existe pra o teste e a tela
## poderem perguntar "isto é a mochila do jogador ou a da bancada?" — sem isso,
## uma bancada concedendo tudo é indistinguível de um save que concede tudo.
var origem_das_permissoes : String = "bancada"

func permissoes_do_jogador() -> Array:
	var catalogo : Dictionary = {}
	var dados := get_node_or_null("/root/GameData")
	if dados != null:
		catalogo = dados.items
	if catalogo.is_empty():
		# Sem catálogo carregado (teste headless), a bancada ainda precisa andar.
		origem_das_permissoes = "bancada (sem catálogo)"
		return [RegraDeMaquina.TRAVESSIA_AGUA, RegraDeMaquina.TRAVESSIA_AR]

	# ⚠️ `get_node_or_null`, nunca o identificador `SaveManager` — autoload não
	# é identificador em teste `--script`, e citá-lo aqui faria o arquivo
	# inteiro parar de compilar num teste. A lição de quatro fases seguidas.
	var save := get_node_or_null("/root/SaveManager")
	if save != null and save.save_data is Dictionary:
		var mochila = save.save_data.get("inventory", {})
		# Mochila vazia é caso legítimo (jogador no começo), e aí a resposta
		# certa é `[]` — nenhuma travessia. Não caio na bancada aqui, senão um
		# save de verdade seria silenciosamente promovido a tudo liberado.
		if mochila is Dictionary or mochila is Array:
			origem_das_permissoes = "mochila do jogador"
			return RegraDeMaquina.permissoes_de(mochila, catalogo)

	origem_das_permissoes = "bancada (sem save)"
	return RegraDeMaquina.permissoes_de(MOCHILA_DE_TESTE, catalogo)

func assumir_pokemon() -> Dictionary:
	var pode : Dictionary = Transferencia.pode_assumir(companheiro, controle.modo)
	if not bool(pode["pode"]):
		return {"ok": false, "motivo": str(pode["motivo"])}

	var estado : Dictionary = Transferencia.ao_assumir(
		treinador, companheiro, treinador.camera.yaw())
	transferencia_iniciada.emit(ControlModeManager.WORLD, ControlModeManager.COMBAT,
		int(estado["pokemon_id"]))

	# A ORDEM importa: o Pokémon precisa estar registrado ANTES de virar o modo,
	# senão existe um quadro sem dono nenhum do input.
	controle.registrar(ControlModeManager.COMBAT, companheiro)
	companheiro.assumir_controle(float(estado["yaw_herdado"]), permissoes_do_jogador())
	controle.trocar_para(ControlModeManager.COMBAT)

	if bool(estado["zerar_intencao_do_treinador"]):
		treinador.soltar_movimento()
		treinador.intencao = Vector2.ZERO
	if treinador.camera != null and treinador.camera.camera != null:
		treinador.camera.camera.current = false

	_anotar("assumiu %s" % companheiro.nome_exibido)
	if hud_de_combate != null:
		hud_de_combate.show()
		hud_de_combate.vincular_pokemon(companheiro)
	transferencia_concluida.emit(ControlModeManager.COMBAT)
	return {"ok": true, "motivo": ""}

## Voltar a ser o treinador. A câmera dele HERDA o ângulo do Pokémon: a luta
## gira o jogador, e devolvê-lo virado pra trás é desorientação gratuita.
func voltar_ao_treinador() -> Dictionary:
	if controle.modo != ControlModeManager.COMBAT:
		return {"ok": false, "motivo": "Você já é o treinador."}

	var yaw : float = 0.0
	if companheiro != null and is_instance_valid(companheiro) and companheiro.camera != null:
		yaw = companheiro.camera.yaw()
	var estado : Dictionary = Transferencia.ao_voltar(yaw)
	transferencia_iniciada.emit(ControlModeManager.COMBAT, ControlModeManager.WORLD,
		treinador.get_instance_id())

	controle.trocar_para(ControlModeManager.WORLD)
	if companheiro != null and is_instance_valid(companheiro):
		companheiro.devolver_controle(
			treinador if bool(estado["voltar_a_acompanhar"]) else null)
	treinador.camera.definir_yaw(float(estado["yaw_herdado"]))
	if treinador.camera.camera != null:
		treinador.camera.camera.current = true

	_anotar("voltou a ser o treinador")
	if hud_de_combate != null:
		hud_de_combate.desvincular_pokemon()
		hud_de_combate.hide()
	transferencia_concluida.emit(ControlModeManager.WORLD)
	return {"ok": true, "motivo": ""}

## §4: o Pokémon caiu. O controle volta **automaticamente** — não é escolha do
## jogador, é consequência, e é o que dá peso a andar sem ninguém fora da ball.
func _ao_cair_o_pokemon(_quem: Node) -> void:
	if controle.modo != ControlModeManager.COMBAT:
		return
	if not Transferencia.deve_devolver_controle(true, false):
		return
	_anotar("o Pokémon caiu — o treinador está exposto")
	voltar_ao_treinador()

## Autoload não é identificador garantido quando a cena é carregada por um
## teste `--script`. A ponte segue opcional para a bancada, sem inventar uma
## mensagem nem falhar o Laboratório por causa da camada de feedback.
func _anotar(texto: String) -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.call("anotar", texto)

# ──────────────────────────────────────────────────────────────────────────────
# Entrada
# ──────────────────────────────────────────────────────────────────────────────

func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.is_echo()):
		return
	# T de "trocar de corpo": a fantasia inteira numa tecla.
	if (evento as InputEventKey).keycode == KEY_T:
		if controle.modo == ControlModeManager.WORLD:
			assumir_pokemon()
		else:
			voltar_ao_treinador()
