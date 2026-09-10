## teste_pokedex_evolucao_null.gd — 10/09, achado pelo feedback real do
## Gabriel: "está bugada a pokedex, mostrando coisas que não tem nada a ver".
## species.json guarda `evolution_to: null` pra quem não evolui mais — e
## `int(null)` é ERRO DE EXECUÇÃO no Godot (silencioso, não trava o jogo),
## não vira 0 sozinho. A aba Evolução do Wartortle pulava de Blastoise (que
## não evolui) direto pra Ivysaur/Venusaur (linha evolutiva de Bulbasaur,
## sem relação nenhuma), com "(false false)" no lugar do nível.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: aba Evolução da Pokédex não vaza pra outra linha (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# Wartortle (#008) — Squirtle(7) → Wartortle(8) → Blastoise(9, forma final).
	var d := PokedexDetalhe.abrir(root, 8)
	d._trocar_aba("Evolução")

	var textos : Array[String] = []
	for filho in d._corpo.get_children():
		if filho is Label:
			textos.append(filho.text)
	var tudo := "\n".join(textos)

	_assert(tudo.contains("Squirtle"), "mostra Squirtle (início da linha)")
	_assert(tudo.contains("Wartortle"), "mostra Wartortle (você está aqui)")
	_assert(tudo.contains("Blastoise"), "mostra Blastoise (forma final)")
	_assert(not tudo.contains("Ivysaur"), "NÃO vaza pra Ivysaur (outra linha evolutiva inteira)")
	_assert(not tudo.contains("Venusaur"), "NÃO vaza pra Venusaur (idem)")
	_assert(not tudo.contains("false"), "nenhuma linha mostra 'false' no lugar do nível/condição")

	d._fechar()

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
