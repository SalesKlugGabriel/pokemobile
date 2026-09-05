## teste_combate_sensacao.gd — O MVP das Dungeons Elementais (05/09).
##
## Trava as três peças do "o combate responde": campo de visão, sensação de
## impacto e telegraph de área. Nenhuma delas é matemática de dano — são as
## peças que decidem se o jogador CONSEGUE LER a briga. Por isso o que este
## arquivo testa é sempre a mesma pergunta: dá pra ver, dá pra entender, dá pra
## reagir a tempo?
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_combate_sensacao.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: campo de visão, impacto e telegraph (05/09) ===")

func _process(_delta: float) -> bool:
	_camera()
	_telegraph()
	_impacto()
	_ponte_de_feedback()
	_sem_numero_duplicado()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# 1. Campo de visão — a régua de tudo que vem depois
# ──────────────────────────────────────────────────────────────────────────
func _camera() -> void:
	var script_treinador : GDScript = load("res://scripts/entities/TrainerEntity.gd")
	var consts := script_treinador.get_script_constant_map()
	_assert(consts.has("ZOOM_CAMERA"), "o zoom da câmera é uma constante do código, não 77 números soltos")
	var zoom : Vector2 = consts.get("ZOOM_CAMERA", Vector2.ONE)
	_assert(zoom.x < 1.0, "o zoom afasta a câmera (mostra mais mapa que antes)")
	_assert(zoom.x == zoom.y, "o zoom é igual nos dois eixos (sem esticar a arte)")

	# Pixel art só fica nítida se o tile cair num número inteiro de pixels.
	var px_na_tela : float = 128.0 * zoom.x
	_assert(px_na_tela == floor(px_na_tela), "o tile de 128px cai em pixel inteiro na tela (%d px)" % int(px_na_tela))

	# E as cenas têm que concordar com o código: se o .tscn disser outra coisa,
	# o editor mostra um enquadramento e o jogo mostra outro.
	var divergentes : Array = []
	for caminho in _cenas_com_camera("res://scenes"):
		var texto := FileAccess.get_file_as_string(caminho)
		if texto.contains("type=\"Camera2D\"") and not texto.contains("zoom = Vector2(%s, %s)" % [zoom.x, zoom.y]):
			divergentes.append(caminho.get_file())
	_assert(divergentes.is_empty(), "todas as cenas com câmera usam o mesmo zoom do código (%d divergentes)" % divergentes.size())

	# O gerador das 36 cenas de covil também, senão a próxima cena nasce errada.
	var gerador := FileAccess.get_file_as_string("res://tools/gerar_cenas_covis.py")
	_assert(gerador.contains("zoom = Vector2(%s, %s)" % [zoom.x, zoom.y]),
		"o gerador de cenas de covil já nasce com o zoom certo")

func _cenas_com_camera(pasta: String) -> Array:
	var achados : Array = []
	var d := DirAccess.open(pasta)
	if d == null:
		return achados
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var caminho := pasta.path_join(nome)
		if d.current_is_dir():
			achados.append_array(_cenas_com_camera(caminho))
		elif nome.ends_with(".tscn"):
			achados.append(caminho)
		nome = d.get_next()
	d.list_dir_end()
	return achados

# ──────────────────────────────────────────────────────────────────────────
# 2. Telegraph — é o que separa "difícil" de "injusto"
# ──────────────────────────────────────────────────────────────────────────
func _telegraph() -> void:
	var tg : GDScript = load("res://scripts/combat/TelegraphDeArea.gd")
	var c := tg.get_script_constant_map()
	for chave in ["CARGA", "AVISO", "IMPACTO", "RESCALDO", "ATE_O_DANO"]:
		_assert(c.has(chave), "o telegraph tem a fase %s" % chave)

	var ate : float = c["ATE_O_DANO"]
	_assert(is_equal_approx(ate, float(c["CARGA"]) + float(c["AVISO"])),
		"a janela até o dano é exatamente carga + aviso (sem fase escondida)")
	# Meio segundo não dá pra reagir; três segundos e o combate para de andar.
	_assert(ate >= 0.8 and ate <= 2.0,
		"a janela pra sair de dentro do círculo é jogável: %.2fs" % ate)
	_assert(float(c["IMPACTO"]) < float(c["AVISO"]),
		"o impacto é mais curto que o aviso (o susto não pode durar mais que o alerta)")

	# Cor por tipo: é como o jogador sabe o que vem sem ler o nome do golpe.
	var cores : Dictionary = c["COR_POR_TIPO"]
	for tipo in ["fire", "water", "electric", "ice", "poison", "psychic", "ghost", "rock", "ground", "grass"]:
		_assert(cores.has(tipo), "o tipo %s tem cor própria no chão" % tipo)
	var vistas : Dictionary = {}
	for tipo in ["fire", "water", "electric", "ice", "grass", "poison"]:
		var chave : String = str(cores[tipo])
		_assert(not vistas.has(chave), "a cor de %s não se repete com a de outro tipo" % tipo)
		vistas[chave] = true

	# E TODO golpe de área precisa de uma cor — senão cai no laranja genérico e
	# a leitura por cor deixa de funcionar justo nos golpes que mais importam.
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves/moves.json"))
	var sem_cor : Array = []
	var de_area := 0
	if dados is Dictionary:
		for id in dados:
			var m : Dictionary = dados[id]
			if float(m.get("radius", 0.0)) > 0.0:
				de_area += 1
				# to_lower() de propósito: o JSON grava "Fire", a tabela é
				# minúscula, e foi exatamente aí que a cor se perdia.
				if not cores.has(str(m.get("type", "")).to_lower()):
					sem_cor.append(id)
	_assert(de_area > 0, "existem golpes de área nos dados (%d)" % de_area)
	_assert(sem_cor.is_empty(), "todo golpe de área tem cor de telegraph (%s)" % str(sem_cor))

	# O dano precisa sair DEPOIS do aviso, mirando quem está lá naquele momento
	# — é isso que faz desviar funcionar. Se a busca de alvos acontecer antes da
	# espera, o telegraph vira enfeite.
	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		var i_espera := fonte.find("TelegraphDeArea.ATE_O_DANO")
		var i_alvos := fonte.find("find_targets_in_radius")
		_assert(i_espera > 0 and i_alvos > i_espera,
			"%s procura os alvos SÓ depois da janela do telegraph" % arquivo.get_file())

# ──────────────────────────────────────────────────────────────────────────
# 3. Impacto — o retorno visual de levar/dar pancada
# ──────────────────────────────────────────────────────────────────────────
func _impacto() -> void:
	var fi : GDScript = load("res://scripts/combat/FeedbackDeImpacto.gd")
	var c := fi.get_script_constant_map()
	for chave in ["RECUO_PX", "FLASH_SEG", "TREMOR_MAX_PX", "HITSTOP_SEG", "FRACAO_GOLPE_FORTE"]:
		_assert(c.has(chave), "a camada de impacto define %s" % chave)

	_assert(float(c["HITSTOP_SEG"]) <= 0.12,
		"o hitstop é curto (%.0f ms) — mais que isso o jogo engasga" % (float(c["HITSTOP_SEG"]) * 1000.0))
	_assert(float(c["FLASH_SEG"]) <= 0.2, "o piscar é rápido o bastante pra dois golpes seguidos se separarem")
	var fracao : float = c["FRACAO_GOLPE_FORTE"]
	_assert(fracao > 0.0 and fracao < 1.0,
		"'golpe forte' é uma fração da vida máxima, não um número absoluto de dano")

	# O sinal precisa carregar QUEM bateu — sem isso não dá pra saber pra que
	# lado recuar, e o recuo é o que diz de onde veio o golpe.
	var barramento := FileAccess.get_file_as_string("res://scripts/autoloads/EventBus.gd")
	_assert(barramento.contains("signal damage_dealt(target: Node, amount: int, is_critical: bool, attacker: Node)"),
		"damage_dealt informa quem atacou")
	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd", "res://scripts/entities/TrainerEntity.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("EventBus.damage_dealt.emit(self, amount, false, attacker)"),
			"%s avisa o dano com o atacante junto" % arquivo.get_file())

	# A camada visual não pode encostar na lógica de dano: ela escuta.
	var fonte_fi := FileAccess.get_file_as_string("res://scripts/combat/FeedbackDeImpacto.gd")
	_assert(fonte_fi.contains("EventBus.damage_dealt.connect"),
		"o impacto é um ouvinte do barramento, não uma chamada dentro do combate")
	_assert(not fonte_fi.contains("take_damage("),
		"a camada visual nunca causa nem altera dano")

	var proj := FileAccess.get_file_as_string("res://project.godot")
	_assert(proj.contains("FeedbackDeImpacto="), "a camada de impacto está registrada como autoload")

# ──────────────────────────────────────────────────────────────────────────
# 4. Ponte de feedback — o Gabriel joga e me manda o recado de dentro do jogo
# ──────────────────────────────────────────────────────────────────────────
func _ponte_de_feedback() -> void:
	var ponte : GDScript = load("res://scripts/autoloads/PonteDeFeedback.gd")
	var c := ponte.get_script_constant_map()
	_assert(c.has("URL_FEEDBACK"), "a ponte sabe pra onde mandar o recado")
	var url : String = c["URL_FEEDBACK"]
	_assert(url.begins_with("https://"), "o recado vai por HTTPS")
	_assert(url.contains("/editor/api/feedback"),
		"usa o serviço que já estava no ar — sem container, domínio ou porta nova")
	_assert(str(c.get("ARQUIVO_FILA", "")).begins_with("user://"),
		"o recado que não conseguiu sair fica guardado em disco, não só na memória")

	var fonte := FileAccess.get_file_as_string("res://scripts/autoloads/PonteDeFeedback.gd")
	# A ordem importa: se a print for tirada depois de abrir o painel, eu recebo
	# a foto do painel em vez da foto do problema.
	var i_print := fonte.find("_print_atual = await _capturar_print()")
	var i_abre := fonte.find("_painel.visible = true")
	_assert(i_print > 0 and i_abre > i_print, "a print é tirada ANTES do painel aparecer")
	_assert(fonte.contains("_fila.pop_front()"),
		"o recado só sai da fila depois que o servidor confirmou")
	# Contexto automático: é o dado que ele nunca ia digitar e que é o que me
	# faz achar o problema.
	for campo in ["mapa", "tile", "fps", "pokemon"]:
		_assert(fonte.contains("\"%s\"" % campo), "o recado leva o contexto '%s' automaticamente" % campo)
	_assert(FileAccess.get_file_as_string("res://project.godot").contains("PonteDeFeedback="),
		"a ponte está registrada como autoload")

# ──────────────────────────────────────────────────────────────────────────
# 5. Um dano, um número
# ──────────────────────────────────────────────────────────────────────────
## Ao ligar a camada de impacto, o número de dano passou a sair dela — e os
## lugares que já imprimiam "Golpe -12" viraram duplicata na tela. Este teste
## existe pra isso não voltar: o NOME do golpe sai de quem bate, o NÚMERO sai
## de quem apanha, e nunca os dois juntos.
func _sem_numero_duplicado() -> void:
	for arquivo in ["res://scripts/entities/WildPokemon.gd", "res://scripts/entities/FollowerPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		var duplicados := 0
		for linha in fonte.split("\n"):
			if linha.contains("FloatingText.show_text") and linha.contains("-%d") and not linha.contains("status_label"):
				duplicados += 1
		_assert(duplicados == 0,
			"%s não imprime o dano por fora da camada de impacto (%d linhas)" % [arquivo.get_file(), duplicados])

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
