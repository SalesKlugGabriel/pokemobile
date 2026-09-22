## teste_loot_chega_na_mochila.gd — O saque chega ao jogador (§35, 21/09).
##
## ── Dois buracos, e o segundo é pior ────────────────────────────────────────
##
## **1. `Corpo3D.pegar()` existia e ninguém a chamava.** Conferido por grep: a
## única chamada do repositório estava no laboratório da V2. O loot nascia com o
## corpo, expirava com ele, e **nunca chegava à mochila**. Quinta ocorrência do
## mesmo formato de defeito em um mês.
##
## **2. 🔴 Três dos quatro ids que `RegrasDeCorpo.loot` entregava NÃO EXISTIAM**
## em `data/items/items.json` (215 itens):
##
##     "pocao"             → o id real é "potion"
##     "held_bronze"       → não existe; existem 10 helds tier 1 de verdade
##     "solvente_de_held"  → não existe, e o efeito também não
##
## A regra **tinha teste**, e o teste conferia a **forma** do drop — nunca que o
## id fosse real. Ligar `pegar()` como estava teria posto **itens fantasma no
## save do jogador**: linhas que nenhuma tela desenha e nenhum uso consome. Save
## sujo não se limpa depois.
##
## ── O que este arquivo trava ────────────────────────────────────────────────
##
## A conferência que faltava no mês inteiro: **todo id que o loot pode entregar
## existe no catálogo**. Ela é a única que pega a classe inteira — e é barata.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 19

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

var _quadro : int = 0
var _mundo : Node3D = null
var _corpo : Node3D = null
var _corpo_alpha : Node3D = null

func _initialize() -> void:
	print("== O saque chega na mochila ==")

func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro == 1:
		_montar()
		return false
	if _quadro < 3:
		return false

	_todo_id_existe()
	_a_corrente()
	_o_item_fantasma()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)
	return true

func _montar() -> void:
	var P : GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var C : GDScript = load("res://scripts/gameplay_v3/entidades/Corpo3D.gd")
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var comum = P.nascer(_mundo, 25, 40, Vector3(4, 0, 4))
	var alpha = P.nascer(_mundo, 25, 40, Vector3(8, 0, 4), "",
		RegraDeMovePool.CATEGORIA_PADRAO, true)
	# ⚠️ O sorteio vai NO nascimento: o `_ready` que sorteia o loot dispara
	# dentro do `add_child`, então trocar `sortear` depois chega tarde. Escrevi
	# assim na primeira versão e o teste largou poção numa rodada e nada na
	# seguinte.
	var tudo_dropa := func() -> float: return 0.0
	_corpo = C.nascer(_mundo, comum, 0.5, tudo_dropa)
	_corpo_alpha = C.nascer(_mundo, alpha, 0.5, tudo_dropa)

# ──────────────────────────────────────────────────────────────────────────────

## 🔴 A conferência que pega a classe inteira: varre a régua de loot em toda
## combinação plausível e exige que **cada id exista** no catálogo.
func _todo_id_existe() -> void:
	print("\n-- Todo id que o loot entrega existe no catálogo --")

	var jogo := root.get_node_or_null("GameData")
	_conf("o catálogo de itens está carregado",
		jogo != null and jogo.items.size() > 50,
		str(jogo.items.size()) if jogo != null else "sem GameData")
	if jogo == null:
		return

	var helds : Array = _corpo._helds_do_catalogo()
	print("   helds tier 1 no catálogo: ", helds.size())
	_conf("existem helds tier 1 pra sortear", helds.size() > 0)

	var faltando : Array = []
	var vistos : Dictionary = {}
	var testes : int = 0
	# Varre nível, Alpha ou não, sorte, e o sorteio inteiro em passos finos: é a
	# única forma de alcançar os três ramos de drop.
	for nivel in [1, 25, 50, 75, 100]:
		for alpha in [false, true]:
			for sorte in [0, 50, 999]:
				var passo : float = 0.0
				while passo < 1.0:
					var drop : Array = RegrasDeCorpo.loot(
						nivel, alpha, sorte,
						[passo, passo, passo], helds)
					testes += 1
					for it in drop:
						var id : String = str(it.get("item", ""))
						vistos[id] = true
						if not jogo.items.has(id) and not (id in faltando):
							faltando.append(id)
					passo += 0.01

	print("   ", testes, " combinações · ", vistos.size(), " ids distintos entregues")
	_conf("o varrimento alcançou os ramos de drop", vistos.size() >= 2,
		str(vistos.keys()))
	_conf("TODO id entregue existe no catálogo", faltando.is_empty(),
		"ids fantasma: " + ", ".join(faltando)
			+ " — guardar isso põe lixo no save do jogador")

	# E a prova de que a régua PEGA o defeito: o id antigo não existe mesmo.
	_conf("a régua detectaria o id antigo ('pocao')",
		not jogo.items.has("pocao"),
		"'pocao' passou a existir? então a correção de 21/09 virou desnecessária")
	_conf("e 'potion', que é o certo, existe", jogo.items.has("potion"))
	_conf("todo held sorteado é held de verdade",
		helds.all(func(h): return str(jogo.items[h].get("category", "")) == "held"))
	# Ordem estável: sem isto o sorteio daria item diferente a cada execução.
	var de_novo : Array = _corpo._helds_do_catalogo()
	_conf("a lista de helds é estável entre chamadas", helds == de_novo,
		"Dictionary.keys() não promete ordem — sem ordenar, o drop deixa de ser "
		+ "determinístico")

# ──────────────────────────────────────────────────────────────────────────────

func _a_corrente() -> void:
	print("\n-- A corrente: do chão pra mochila --")

	var save := root.get_node_or_null("SaveManager")
	_conf("SaveManager disponível", save != null)
	if save == null:
		return

	# ⚠️ Em memória e restaurado no fim: o save do Gabriel não é bancada.
	var antes : Dictionary = save.save_data.duplicate(true)
	save.save_data["inventory"] = {}

	var loot : Array = _corpo.estado()["loot"]
	print("   o corpo largou: ", str(loot))
	_conf("o corpo largou algo com o sorteio favorável", loot.size() > 0,
		"nível 40 com sorteio 0,0 deveria dropar poção")

	var r : Dictionary = _corpo.pegar(0)
	_conf("pegar devolve o item", str(r.get("item", "")) != "", str(r))
	_conf("e diz que guardou", bool(r.get("guardado", false)), str(r))
	_conf("o item está na mochila DE VERDADE",
		int(save.save_data["inventory"].get(str(r["item"]), 0)) >= 1,
		str(save.save_data["inventory"]))
	# §35: um item por vez. Pegar o índice 0 tira só ele.
	_conf("o chão ficou com um item menos",
		_corpo.estado()["loot"].size() == loot.size() - 1)
	_conf("índice inválido não faz nada", _corpo.pegar(99).is_empty())

	save.save_data = antes

# ──────────────────────────────────────────────────────────────────────────────

func _o_item_fantasma() -> void:
	print("\n-- A trava contra o item fantasma --")

	var save := root.get_node_or_null("SaveManager")
	if save == null:
		_conf("(pulado — sem save)", false)
		return
	var antes : Dictionary = save.save_data.duplicate(true)
	save.save_data["inventory"] = {}

	# Forço um id inexistente no chão, como se a régua tivesse errado de novo.
	_corpo_alpha.dados["loot"] = [{"item": "item_que_nao_existe", "qtd": 1}]
	var r : Dictionary = _corpo_alpha.pegar(0)
	_conf("id inexistente NÃO é guardado", not bool(r.get("guardado", false)),
		str(r))
	_conf("e o motivo diz qual id era",
		str(r.get("motivo", "")).contains("item_que_nao_existe"),
		str(r.get("motivo", "")))
	_conf("a mochila continua limpa", save.save_data["inventory"].is_empty(),
		str(save.save_data["inventory"]) + " — lixo em save não se limpa depois")

	save.save_data = antes
	_conf("o save do Gabriel foi restaurado",
		save.save_data["inventory"].size() == antes["inventory"].size())
