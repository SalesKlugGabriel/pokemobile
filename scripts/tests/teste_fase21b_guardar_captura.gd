## teste_fase21b_guardar_captura.gd — A captura chega no save (21/09).
##
## ── O buraco ────────────────────────────────────────────────────────────────
##
## A Fase 21 fez a bola voar, acertar e o corpo decidir. E aí a corrente parava:
## `PokebolaLancada3D.resolveu` era emitido e **ninguém escutava** — conferido
## por grep, nenhum arquivo fora da própria bola se conectava. O jogador
## capturava e o Pokémon **evaporava**.
##
## Quarta vez no mês que a peça existe, não dá erro e não faz nada (kit vazio na
## 17, Alpha que nunca nascia na 18, tecla `pokeball` sem leitor na 21). Já não
## é acidente — é o formato de defeito deste projeto, e é o que esta suíte
## precisa saber caçar.
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **O sinal sem ouvinte**, de novo — a conferência é feita no código, não
##      na minha memória de ter ligado.
##   2. **A conta refeita.** Montar o Pokémon, escolher time/PC e marcar a
##      Pokédex já existem desde a V1; reimplementar qualquer um seria criar uma
##      segunda verdade.
##   3. **A mensagem que esconde o time cheio.** "Foi pro PC" e "entrou no time"
##      são coisas diferentes pra quem joga.
##   4. **O save corrompido por captura inválida.** `species_id` 0 viraria um
##      Pokémon inexistente no time — pior que perder a captura.
##   5. **O crash sem save.** No laboratório não há partida; a captura tem de
##      degradar dizendo isso, não estourar.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 25

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("== Fase 21b: a captura chega no save ==")
	_a_regra()
	_a_corrente_esta_ligada()
	_no_save_de_verdade()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)

# ──────────────────────────────────────────────────────────────────────────────

func _a_regra() -> void:
	print("\n-- A regra pura --")
	var R : GDScript = load(
		"res://scripts/gameplay_v3/pokemon/RegraDeGuardarCaptura.gd")
	_conf("a regra carrega", R != null)

	# O que merece ir pro save.
	_conf("captura boa é guardada",
		bool(R.deve_guardar({"pegou": true, "species_id": 25, "nivel": 12})["guardar"]))
	_conf("falha não é guardada",
		not bool(R.deve_guardar({"pegou": false})["guardar"]))
	# Falha fechada: id 0 viraria um Pokémon inexistente no time do jogador.
	_conf("espécie inválida é recusada",
		not bool(R.deve_guardar({"pegou": true, "species_id": 0, "nivel": 5})["guardar"]))
	_conf("nível inválido é recusado",
		not bool(R.deve_guardar({"pegou": true, "species_id": 25, "nivel": 0})["guardar"]))
	_conf("e a recusa diz o motivo",
		str(R.deve_guardar({"pegou": true, "species_id": 0, "nivel": 5})["motivo"]).length() > 5)

	# A mensagem muda com o destino — é o que revela o time cheio.
	var no_time : String = R.mensagem(R.TIME, "Pikachu")
	var no_pc : String = R.mensagem(R.PC, "Pikachu")
	print("   time: ", no_time)
	print("   pc:   ", no_pc)
	_conf("as duas mensagens são diferentes", no_time != no_pc)
	_conf("a do PC avisa que o time está cheio",
		no_pc.to_lower().contains("cheio") and no_pc.contains("PC"))
	_conf("as duas dizem o nome do Pokémon",
		no_time.contains("Pikachu") and no_pc.contains("Pikachu"))

	var rel : Dictionary = R.relatorio(25, 12, "Pikachu", R.PC)
	_conf("o relatório marca que foi pro PC", bool(rel["foi_pro_pc"]))
	_conf("e traz a mensagem pronta pra HUD", str(rel["mensagem"]).length() > 10)
	_conf("o relatório do time NÃO marca PC",
		not bool(R.relatorio(25, 12, "Pikachu", R.TIME)["foi_pro_pc"]))

func _a_corrente_esta_ligada() -> void:
	print("\n-- A corrente: o sinal tem ouvinte --")

	# 🔴 Esta é a conferência que faltava no mês inteiro. Ela lê o CÓDIGO, e não
	# a minha memória de ter ligado — um `connect` que some num refatoramento
	# não daria erro nenhum.
	var t : String = FileAccess.get_file_as_string(
		"res://scripts/gameplay_v3/entidades/TrainerController3D.gd")
	_conf("o treinador se conecta ao `resolveu` da bola",
		t.contains("resolveu.connect"),
		"o sinal voltou a não ter ouvinte — a captura evapora de novo")
	_conf("e expõe um sinal próprio pra HUD", t.contains("signal capturou"))
	_conf("usa o add_pokemon que já existe", t.contains("add_pokemon("),
		"reimplementar a escolha time/PC criaria uma segunda verdade")
	_conf("usa o _make_pokemon_data que já existe",
		t.contains("_make_pokemon_data("))
	_conf("marca a Pokédex", t.contains("mark_caught("))
	_conf("e salva", t.contains("save_game()"))
	# A lição de cinco fases: autoload nunca por identificador.
	_conf("alcança o save por caminho, não pelo identificador",
		t.contains('get_node_or_null("/root/SaveManager")'),
		"citar o autoload direto faz o arquivo não compilar em teste --script")

func _no_save_de_verdade() -> void:
	print("\n-- Contra o save de verdade --")

	var save := root.get_node_or_null("SaveManager")
	if save == null:
		_conf("SaveManager está disponível", false, "autoload ausente")
		_conf("(pulado)", false)
		return
	_conf("SaveManager está disponível", true)

	# ⚠️ Em memória, e restaurado no fim: o save do Gabriel não é bancada de
	# teste. A lição de 26/08 no viabil-app vale igual aqui.
	var antes : Dictionary = save.save_data.duplicate(true)
	save.save_data["team"] = []
	save.save_data["pc"] = []

	var dados : Dictionary = save._make_pokemon_data(25, 12)
	_conf("o Pokémon montado tem a espécie e o nível pedidos",
		int(dados.get("species_id", 0)) == 25 and int(dados.get("level", 0)) == 12,
		str(dados.get("species_id")) + " lv " + str(dados.get("level")))

	var destino : String = str(save.add_pokemon(dados))
	_conf("com o time vazio, ele entra no TIME", destino == "team", destino)

	# Enche o time e confirma que o sétimo vai pro PC — e que a mensagem muda
	# junto, que é o ponto da regra.
	for _i in 6:
		save.add_pokemon(save._make_pokemon_data(25, 5))
	var destino2 : String = str(save.add_pokemon(save._make_pokemon_data(25, 5)))
	_conf("com o time cheio, o próximo vai pro PC", destino2 == "pc", destino2)

	var R : GDScript = load(
		"res://scripts/gameplay_v3/pokemon/RegraDeGuardarCaptura.gd")
	_conf("e a mensagem acompanha o destino REAL",
		R.mensagem(destino2, "Pikachu").to_lower().contains("cheio"),
		"o texto ficaria dizendo 'entrou no time' com o bicho no PC")

	save.save_data = antes
	_conf("o save do Gabriel foi restaurado",
		save.save_data["team"].size() == antes["team"].size())
