## teste_controles_de_toque.gd — O jogo tem que ser jogável no celular (09/09).
##
## O Gabriel não conseguia nem começar o jogo no telefone. Eram DOIS problemas,
## e as conferências abaixo existem pra nenhum dos dois voltar:
##
##   1. O jogo desenhava numa faixa 16:9 com tarja preta e usava ~40% da tela.
##   2. O toque não virava comando. Três tentativas erradas depois, o que
##      resolveu foi instrumentar o jogo pra ele DIZER o que recebia: o motor
##      recebia o clique da ponte, e o que faltava era o jogo fazer algo com
##      ele numa tela sem mundo (título, nome, diálogo).
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_controles_de_toque.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: o jogo no celular (09/09) ===")

func _process(_delta: float) -> bool:
	var proj := FileAccess.get_file_as_string("res://project.godot")

	# 1. A tela inteira, sem tarja.
	_assert(proj.contains('window/stretch/aspect="expand"'),
		"o jogo preenche a tela do celular (aspect 'expand', não 'keep')")
	_assert(not proj.contains('window/stretch/aspect="keep"'),
		"e a proporção travada que causava a tarja preta não voltou")

	# 2. A ponte de toque, e o script de export que a injeta.
	var exportador := FileAccess.get_file_as_string("res://tools/exportar_web.sh")
	_assert(exportador.contains("__ponteDeToque"), "existe a ponte que converte toque em clique")
	_assert(exportador.contains("touchAction"), "e ela desliga o sequestro do toque pelo navegador")
	_assert(exportador.contains("versao.txt"),
		"o export carimba a versão — sem isso não dá pra saber se o navegador vê o build novo")

	var toque := FileAccess.get_file_as_string("res://scripts/ui/ControlesDeToque.gd")

	# 3. O que resolveu: toque em tela sem mundo vale como confirmar.
	var i_sem_camera := toque.find("if mundo == null:")
	var i_interact := toque.find("_injetar_pulso(\"interact\")", i_sem_camera)
	_assert(i_sem_camera > 0 and i_interact > i_sem_camera,
		"tocar numa tela de UI (sem câmera) vale como confirmar")

	# 4. O pedido do Gabriel: joystick invisível e ação por toque único.
	var script_toque : GDScript = load("res://scripts/ui/ControlesDeToque.gd")
	var c := script_toque.get_script_constant_map()
	_assert(c.has("LADO_DIREITO") and bool(c["LADO_DIREITO"]),
		"o joystick fica no lado direito, como ele pediu")
	_assert(float(c.get("FRACAO_ALTURA", 0.0)) >= 0.4,
		"e ocupa a metade de baixo da tela")
	_assert(toque.contains("_pintar_eixo"),
		"o eixo é invisível até o dedo encostar (nasce onde ele tocou)")
	var i_caido := toque.find("var caido = _mais_perto")
	var i_vivo := toque.find("var vivo = _mais_perto")
	_assert(i_caido > 0 and i_vivo > i_caido,
		"tocar num Pokémon CAÍDO ganha do vivo — é nele que a bola funciona")
	_assert(toque.contains("_injetar_pulso(\"pokeball\")"), "tocar no caído joga a Pokébola")
	_assert(toque.contains("_injetar_pulso(\"skill_1\")"), "tocar no vivo ataca")

	# 5. Emoji não: a fonte do jogo não tem glifo e saía quadradinho.
	_assert(toque.contains('["BAG", "menu_bag"]'), "os atalhos usam texto, não emoji")
	var ponte := FileAccess.get_file_as_string("res://scripts/autoloads/PonteDeFeedback.gd")
	_assert(ponte.contains('_botao.text = "FB"'), "o botão de recado também")

	# 6. Teclado: o Godot web não levanta o do celular num campo de texto.
	_assert(ponte.contains("_usar_caixa_nativa()"),
		"o recado usa a caixa nativa do navegador no celular")
	var novo_jogo := FileAccess.get_file_as_string("res://scripts/ui/NewGameFlow.gd")
	_assert(novo_jogo.contains("_celular_no_navegador()"),
		"e o campo de nome também — senão o jogador trava sem escrever o próprio nome")

	# 7. O espião fica desligado, mas fica.
	_assert(toque.contains("const ESPIAO : bool = false"),
		"o espião de eventos está desligado (mas continua no arquivo, foi ele que resolveu)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
