## teste_tudo_compila.gd — Todo arquivo .gd do jogo tem que COMPILAR (05/09).
##
## Este arquivo nasceu de um erro meu, e existe pra ele não se repetir.
##
## Ao ligar o telegraph de área, criei uma classe nova (`TelegraphDeArea`) e a
## usei em WildPokemon.gd/FollowerPokemon.gd. Um `class_name` novo só passa a
## existir depois que o Godot reescaneia o projeto — até lá, os dois arquivos
## mais importantes do combate NÃO COMPILAVAM. E a suíte inteira passou: "70
## arquivos, 0 com falha". Passou porque cada teste roda a sua própria árvore e
## só reprova nas próprias conferências; um arquivo que nem carrega não reprova
## nada — ele simplesmente não participa.
##
## É a mesma família do erro de ler a suíte com `grep FALHOU` em vez do código
## de saída: a conferência existia, só não era capaz de ver o problema. Aqui a
## pergunta é a mais simples possível, e por isso ela pega o que os outros
## testes não pegam — o jogo inteiro ainda é código válido?
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_tudo_compila.gd
extends SceneTree

var _ok := 0
var _fail := 0

## `res://scripts/tests` fica de fora de propósito: teste é `extends SceneTree`
## e carregar um aqui dispararia o teste dentro do teste.
const IGNORAR : Array[String] = ["res://scripts/tests"]

func _initialize() -> void:
	print("=== Teste: todo .gd do jogo compila (05/09) ===")

func _process(_delta: float) -> bool:
	var arquivos := _listar("res://scripts")
	_assert(arquivos.size() > 50, "achei os arquivos do jogo pra conferir (%d)" % arquivos.size())

	# `load()` NÃO devolve null num arquivo quebrado — devolve o script mesmo
	# assim, e por isso a primeira versão deste teste passava com dois arquivos
	# de combate sem compilar. Quem denuncia é `can_instantiate()`, que só é
	# verdadeiro quando o Godot conseguiu de fato montar a classe. Descoberto
	# quebrando um arquivo de propósito pra ver o teste reprovar — e ele não
	# reprovou.
	var quebrados : Array = []
	for caminho in arquivos:
		var s = ResourceLoader.load(caminho, "Script", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not (s as Script).can_instantiate():
			quebrados.append(caminho.replace("res://", ""))
	_assert(quebrados.is_empty(),
		"nenhum arquivo com erro de sintaxe/identificador (%d quebrados: %s)" % [quebrados.size(), ", ".join(quebrados)])

	# Um `class_name` só é enxergado por outros arquivos depois que o cache
	# global é reescrito. Este é o passo que eu tinha esquecido — e sem ele o
	# jogo publicado sobe quebrado mesmo com todos os testes verdes.
	var cache := FileAccess.get_file_as_string("res://.godot/global_script_class_cache.cfg")
	var faltando : Array = []
	for caminho in arquivos:
		var texto := FileAccess.get_file_as_string(caminho)
		for linha in texto.split("\n"):
			var l := linha.strip_edges()
			if l.begins_with("class_name "):
				var nome := l.substr(11).split(" ")[0].strip_edges()
				if not cache.contains("&\"%s\"" % nome):
					faltando.append(nome)
				break
	_assert(faltando.is_empty(),
		"todo class_name está no cache global do Godot (%s)" % ("nenhum faltando" if faltando.is_empty() else ", ".join(faltando)))

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _listar(pasta: String) -> Array:
	var achados : Array = []
	for ignorado in IGNORAR:
		if pasta.begins_with(ignorado):
			return achados
	var d := DirAccess.open(pasta)
	if d == null:
		return achados
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var caminho := pasta.path_join(nome)
		if d.current_is_dir():
			achados.append_array(_listar(caminho))
		elif nome.ends_with(".gd"):
			achados.append(caminho)
		nome = d.get_next()
	d.list_dir_end()
	return achados

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
