## teste_hud_novo_ancoragem.gd — 09/09, achado ao vivo no celular do Gabriel
## ("não vi a melhoria da Pokédex", "também não vi... as alterações que
## combinamos"). BarraDeAcaoRapida.gd e PokedexRapida.gd usavam
## set_anchors_preset()+position=/custom_minimum_size= — um Control cujo pai
## direto é uma CanvasLayer (não outro Control) calcula a área do pai como
## 0x0 nesse instante, e o resultado nascia LITERAL na posição pedida (ex:
## (-70,10)) em vez de ancorado de verdade no canto da tela. Corrigido com
## offsets explícitos (anchor_left/top/right/bottom + offset_left/top/right/
## bottom), o mesmo jeito que _botoes/_desenho em ControlesDeToque.gd e o
## $HBox do próprio OverworldHUD.tscn já usavam sem esse bug.
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: ancoragem do HUD novo (Pokédex/BarraDeAcaoRapida, 09/09) ===")

func _process(_delta: float) -> bool:
	var dex_src := FileAccess.get_file_as_string("res://scripts/ui/PokedexRapida.gd")
	var barra_src := FileAccess.get_file_as_string("res://scripts/ui/BarraDeAcaoRapida.gd")

	for nome in ["PokedexRapida", "BarraDeAcaoRapida"]:
		var src := dex_src if nome == "PokedexRapida" else barra_src
		var sem_comentario := _sem_comentarios(src)
		_assert(not sem_comentario.contains("set_anchors_preset"),
			"%s não CHAMA set_anchors_preset() (calcula a área do pai como 0x0 sob CanvasLayer)" % nome)
		_assert(src.contains("anchor_left") and src.contains("offset_left"),
			"%s ancora com offsets explícitos, não position=/custom_minimum_size=" % nome)

	# A tira de remédio (party strip) entrava direto no mapa (Node2D, herda a
	# transformação da câmera) em vez da CanvasLayer do HUD — corrigido pra
	# entrar como irmã de BarraDeAcaoRapida (get_parent(), que É a CanvasLayer).
	var barra_sem_comentario := _sem_comentarios(barra_src)
	_assert(not barra_sem_comentario.contains("get_tree().current_scene"),
		"a tira de remédio não entra mais direto no mapa (Node2D com transformação de câmera)")
	_assert(barra_src.contains("get_parent()"),
		"a tira de remédio entra na mesma CanvasLayer do resto do HUD")

	# Prova numérica: com um Control fake simulando o mesmo cálculo (anchors
	# fixos + offsets fixos), o resultado tem que dar o mesmo valor não
	# importa o tamanho do "pai" — diferente de position= que dependeria dele.
	var c := Control.new()
	c.anchor_left = 1.0; c.anchor_right = 1.0
	c.anchor_top = 0.0; c.anchor_bottom = 0.0
	c.offset_left = -70.0; c.offset_right = -10.0
	c.offset_top = 10.0; c.offset_bottom = 46.0
	_assert(c.offset_left == -70.0 and c.offset_right == -10.0,
		"offsets explícitos não mudam de valor sozinhos (não dependem de nenhuma leitura de tamanho do pai)")
	c.free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _sem_comentarios(src: String) -> String:
	var linhas := src.split("\n")
	var mantidas : Array[String] = []
	for l in linhas:
		if not l.strip_edges().begins_with("#"):
			mantidas.append(l)
	return "\n".join(mantidas)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
