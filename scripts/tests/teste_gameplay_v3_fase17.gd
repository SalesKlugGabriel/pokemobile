## teste_gameplay_v3_fase17.gd — Move Pool (Fase 17).
##
## ── O que esta fase encontrou ───────────────────────────────────────────────
##
## 🔴 **Nenhum Pokémon da V3 tinha golpe.** `PokemonInstance3D.kit` nascia `[]` e
## o único `.kit =` do repositório inteiro estava dentro de um teste. As teclas
## existiam, `UsoDeSkill` existia, o aviso e a área existiam — e apertar Q no
## jogo não fazia absolutamente nada, sem erro nenhum.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Voltar ao kit vazio.** A primeira conferência do mundo é a mais
##      importante do arquivo: um bicho que nasce tem golpe.
##   2. **A escada do `KitDeCombate` virar enfeite.** Charmander < Charmeleon <
##      Charizard em repertório foi um pedido literal do Gabriel; com 4 teclas
##      cravadas, metade do kit de um Charizard seria inalcançável em silêncio.
##   3. **MT equipando sozinha** (§31). Aprender é lembrar; equipar é decidir.
##   4. **Pool virar teto.** Conhecer não tem limite; carregar tem.
##   5. **Selvagem com kit de jogador.** São duas réguas diferentes, e escolher
##      a errada por descuido é o tipo de erro que só aparece jogando.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _especies : Dictionary = {}
var _golpes : Dictionary = {}
var _learnsets : Dictionary = {}
var _itens : Dictionary = {}

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 17: Move Pool ===")
	_carregar()
	_camada_conhecidos()
	_camada_equipados()
	_a_escada()
	_camada_ativos()
	_maquinas()

## Tudo direto do disco: autoload **não é identificador** num teste `--script`
## — a lição do `RNGManager` (Fase 11) e a do `PonteDeFeedback` (Fase 13).
func _carregar() -> void:
	# 🔴 O nome aqui é o da PROPRIEDADE, com underscore. Escrevi "especies" na
	# primeira versão e os quatro arquivos carregaram e foram jogados fora sem
	# um erro sequer — `set()` num nome que não existe não reclama. O sintoma
	# foi 11 conferências reprovando longe daqui.
	for par in [["res://data/pokemon/species.json", "_especies"],
			["res://data/moves/moves.json", "_golpes"],
			["res://data/pokemon/learnsets.json", "_learnsets"],
			["res://data/items/items.json", "_itens"]]:
		var f := FileAccess.open(str(par[0]), FileAccess.READ)
		_conf("%s abre" % str(par[0]).get_file(), f != null)
		if f == null:
			continue
		var lido = JSON.parse_string(f.get_as_text())
		_conf("%s é JSON válido" % str(par[0]).get_file(), lido is Dictionary)
		if lido is Dictionary:
			set(str(par[1]), lido)

func _learnset(id: int) -> Array:
	var l = _learnsets.get(str(id), [])
	return l if l is Array else []

# ──────────────────────────────────────────────────────────────────────────────
# 1. Conhecidos — sem teto
# ──────────────────────────────────────────────────────────────────────────────

func _camada_conhecidos() -> void:
	print("\n-- conhecer não tem limite --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")

	var charizard := _learnset(6)
	_conf("o learnset do Charizard existe", charizard.size() > 0)

	var cedo : Array = R.conhecidos(charizard, 5)
	var tarde : Array = R.conhecidos(charizard, 100)
	_conf("nível alto sabe mais que nível baixo", tarde.size() > cedo.size(),
		"%d vs %d" % [cedo.size(), tarde.size()])
	_conf("o que ele sabia cedo, continua sabendo",
		cedo.all(func(m): return m in tarde))

	# O ponto da camada: o pool ignora a capacidade de propósito.
	_conf("o pool PASSA da capacidade de slots, e isso é certo",
		tarde.size() > 8, "conhecer %d golpes com 8 slots é o esperado" % tarde.size())

	# Nível filtra aqui dentro, não só em quem chamou — a classe não confia
	# num pré-filtro que pode não ter acontecido.
	#
	# ⚠️ A conferência certa é "todo golpe do pool tem ALGUMA entrada até o
	# nível", não "nenhuma entrada acima dele". O mesmo golpe aparece em dois
	# níveis no dado real — `ember` está no 1 e no 9 do Charizard — e a primeira
	# versão desta linha reprovou o código por isso, estando o código certo.
	var sem_direito := false
	for mid in cedo:
		var tem := false
		for e in charizard:
			if str(e.get("move", "")) == mid and int(e.get("level", 0)) <= 5:
				tem = true
		if not tem:
			sem_direito = true
	_conf("nada que ele ainda não teria direito entra no pool", not sem_direito)

	_conf("nenhum repetido", cedo.size() == _sem_repetir(cedo).size())

	# §31: o que a máquina ensinou entra no pool.
	var com_mt : Array = R.conhecidos(charizard, 5, ["surf"])
	_conf("o golpe ensinado entra no pool", "surf" in com_mt)
	_conf("e entra por ÚLTIMO — é o mais novo que ele sabe",
		str(com_mt[com_mt.size() - 1]) == "surf")
	_conf("ensinar duas vezes não duplica",
		R.conhecidos(charizard, 5, ["surf", "surf"]).count("surf") == 1)

	var r1 : Dictionary = R.aprender(["ember"], "surf")
	_conf("aprender diz que é novo", bool(r1["novo"]) and "surf" in r1["conhecidos"])
	var r2 : Dictionary = R.aprender(["ember", "surf"], "surf")
	_conf("aprender de novo diz que NÃO é novo", not bool(r2["novo"]))
	_conf("e não duplica", (r2["conhecidos"] as Array).count("surf") == 1)
	_conf("aprender golpe vazio não faz nada",
		not bool((R.aprender(["ember"], "") as Dictionary)["novo"]))

func _sem_repetir(lista: Array) -> Array:
	var fora : Array = []
	for x in lista:
		if not (x in fora):
			fora.append(x)
	return fora

# ──────────────────────────────────────────────────────────────────────────────
# 2. Equipados — o teto certo
# ──────────────────────────────────────────────────────────────────────────────

func _camada_equipados() -> void:
	print("\n-- carregar tem limite, e são dois limites diferentes --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")
	var K = load("res://scripts/combat/KitDeCombate.gd")

	var slots_jog : int = R.slots(6, 100, _especies, R.CATEGORIA_JOGADOR)
	var slots_selv : int = R.slots(6, 100, _especies, "comum")
	_conf("jogador usa a escada de capacidade",
		slots_jog == K.capacidade(6, 100, _especies), "%d" % slots_jog)
	_conf("selvagem usa a régua de selvagem",
		slots_selv == K.slots_de_selvagem(6, 100, "comum", _especies), "%d" % slots_selv)
	_conf("e as duas réguas NÃO dão o mesmo número",
		slots_jog != slots_selv, "%d vs %d — se fossem iguais, a categoria seria decorativa"
			% [slots_jog, slots_selv])

	var pool : Dictionary = R.montar_pool(6, 100, _learnset(6), _golpes,
		_especies.get("6", {}).get("types", ["Fire"]), _especies, R.CATEGORIA_JOGADOR)
	_conf("o kit cabe nos slots", (pool["equipados"] as Array).size() <= int(pool["slots"]))
	_conf("o kit não é vazio", (pool["equipados"] as Array).size() > 0)
	_conf("todo equipado é conhecido",
		(pool["equipados"] as Array).all(func(m): return m in pool["conhecidos"]),
		"equipar o que não se sabe é como o kit deixa de significar algo")
	_conf("nenhum equipado repetido",
		(pool["equipados"] as Array).size() == _sem_repetir(pool["equipados"]).size())

	# A rede de segurança do `KitDeCombate` continua valendo através daqui.
	var com_dano := false
	for mid in pool["equipados"]:
		if int((_golpes.get(str(mid), {}) as Dictionary).get("power", 0)) > 0:
			com_dano = true
	_conf("sempre ao menos um golpe que tira vida", com_dano)

	# Um Pokémon de nível 1 não abre o jogo com o kit cheio (faixa ofensiva).
	var novato : Dictionary = R.montar_pool(4, 5, _learnset(4), _golpes,
		["Fire"], _especies, R.CATEGORIA_JOGADOR)
	_conf("nível 5 não abre o jogo com 4+ botões",
		(novato["equipados"] as Array).size() <= 3,
		"levou %d" % (novato["equipados"] as Array).size())

	# Learnset inexistente: a rede de socorro entra, e ele não fica sem nada.
	var vazio : Dictionary = R.montar_pool(6, 50, [], _golpes, ["Fire"],
		_especies, R.CATEGORIA_JOGADOR)
	_conf("sem learnset nenhum, ainda sai com o golpe básico do tipo",
		(vazio["equipados"] as Array).size() >= 1, str(vazio["equipados"]))

# ──────────────────────────────────────────────────────────────────────────────
# 3. A escada — o pedido do Gabriel, medido
# ──────────────────────────────────────────────────────────────────────────────

func _a_escada() -> void:
	print("\n-- a escada: evoluir muda COMO se joga --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")

	# *"um charmander lvl 100 em vez de 4 skills > 6 skills, um charmeleon 7,
	#   um charizard 8"* — a frase literal, virada em medição.
	var esperado := {4: 6, 5: 7, 6: 8}
	for id in esperado:
		_conf("Lv.100 #%d carrega %d slots" % [id, esperado[id]],
			R.slots(id, 100, _especies, R.CATEGORIA_JOGADOR) == int(esperado[id]),
			"deu %d" % R.slots(id, 100, _especies, R.CATEGORIA_JOGADOR))

	# E a escada só vale a pena se o teclado alcançar o topo dela.
	_conf("o teclado alcança os 8", R.TECLAS_DE_SKILL >= int(esperado[6]),
		"se alcançasse 4, metade do kit de um Charizard seria enfeite")

	# O Magikarp: o caso que a escada resolve sem regra especial.
	var karp : Dictionary = R.montar_pool(129, 100, _learnset(129), _golpes,
		["Water"], _especies, R.CATEGORIA_JOGADOR)
	var gyara : Dictionary = R.montar_pool(130, 100, _learnset(130), _golpes,
		["Water", "Flying"], _especies, R.CATEGORIA_JOGADOR)
	_conf("Magikarp Lv.100 não enche os slots que tem",
		(karp["equipados"] as Array).size() < int(karp["slots"]),
		"%d de %d — o learnset dele é que é curto, não a regra"
			% [(karp["equipados"] as Array).size(), int(karp["slots"])])
	_conf("e Gyarados leva mais golpes que Magikarp",
		(gyara["equipados"] as Array).size() > (karp["equipados"] as Array).size(),
		"%d vs %d" % [(gyara["equipados"] as Array).size(),
			(karp["equipados"] as Array).size()])

# ──────────────────────────────────────────────────────────────────────────────
# 4. Ativos — o que a mão alcança
# ──────────────────────────────────────────────────────────────────────────────

func _camada_ativos() -> void:
	print("\n-- ativo é o que tem tecla --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")

	_conf("kit pequeno: todo mundo tem tecla",
		(R.ativos(["a", "b"]) as Array).size() == 2)
	_conf("kit do tamanho do teclado: cabe inteiro",
		(R.ativos(["1","2","3","4","5","6","7","8"]) as Array).size() == 8)
	_conf("kit maior que o teclado é CORTADO, num lugar só",
		(R.ativos(["1","2","3","4","5","6","7","8","9","10"]) as Array).size()
			== R.TECLAS_DE_SKILL)
	_conf("e o corte preserva a ordem",
		str((R.ativos(["1","2","3"]) as Array)[0]) == "1")

	_conf("slot 0 é a primeira tecla", R.tecla_do_slot(0) == "skill_1")
	_conf("slot 7 é a última", R.tecla_do_slot(7) == "skill_8")
	_conf("fora do teclado não devolve tecla nenhuma",
		R.tecla_do_slot(8) == "" and R.tecla_do_slot(-1) == "",
		"devolver 'skill_9' faria a entidade perguntar por uma ação que não existe")

# ──────────────────────────────────────────────────────────────────────────────
# 5. §31 — MT ensina e NÃO equipa
# ──────────────────────────────────────────────────────────────────────────────

func _maquinas() -> void:
	print("\n-- §31: aprender é lembrar, equipar é decidir --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")
	var M = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")

	var mt : Dictionary = _itens.get("tm02", {})
	_conf("a MT existe no dado", not mt.is_empty())
	if mt.is_empty():
		return
	var golpe := str(M.efeitos(mt).get("golpe", ""))
	_conf("a MT ensina um golpe de verdade", not golpe.is_empty())

	var antes : Dictionary = R.montar_pool(6, 50, _learnset(6), _golpes,
		["Fire", "Flying"], _especies, R.CATEGORIA_JOGADOR)
	var depois : Dictionary = R.montar_pool(6, 50, _learnset(6), _golpes,
		["Fire", "Flying"], _especies, R.CATEGORIA_JOGADOR, [golpe])

	_conf("depois da MT ele SABE o golpe", golpe in depois["conhecidos"])
	_conf("o pool cresceu exatamente 1",
		(depois["conhecidos"] as Array).size() - (antes["conhecidos"] as Array).size()
			== (0 if golpe in antes["conhecidos"] else 1))
	_conf("a capacidade NÃO mudou — MT não dá slot",
		int(depois["slots"]) == int(antes["slots"]))

# ──────────────────────────────────────────────────────────────────────────────
# Com corpo de verdade: o achado desta fase, travado
# ──────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			_no_mundo()
		5:
			_terminar()
			return true
	return false

func _no_mundo() -> void:
	print("\n-- no mundo, com corpo --")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	mundo.add_child(Ter.new())
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMovePool.gd")

	# 🔴 A conferência que define esta fase. Antes dela, isto reprovava.
	var meu = P.nascer(mundo, 6, 50, Vector3(0, 2, 0), "ground_biped",
		R.CATEGORIA_JOGADOR)
	_conf("um Pokémon que nasce TEM golpe", (meu.kit as Array).size() > 0,
		"era exatamente isto que estava vazio no jogo inteiro")
	_conf("e sabe mais do que carrega",
		(meu.conhecidos as Array).size() >= (meu.kit as Array).size())
	_conf("o slot 0 devolve dados de golpe de verdade",
		not (meu.golpe_do_slot(0) as Dictionary).is_empty())
	_conf("um slot além do kit devolve vazio, não erro",
		(meu.golpe_do_slot(99) as Dictionary).is_empty())

	# A categoria é o que separa as duas réguas — com o MESMO bicho.
	var selvagem = P.nascer(mundo, 6, 50, Vector3(20, 2, 20), "ground_biped")
	_conf("o selvagem carrega menos que o do jogador",
		(selvagem.kit as Array).size() < (meu.kit as Array).size(),
		"jogador %d, selvagem %d" % [(meu.kit as Array).size(),
			(selvagem.kit as Array).size()])
	_conf("mas o selvagem também não fica sem nada",
		(selvagem.kit as Array).size() > 0)

	# §31 com corpo: a MT deposita no pool e o kit ativo não se mexe.
	var kit_antes : int = (meu.kit as Array).size()
	var sabia_antes : int = (meu.conhecidos as Array).size()
	var r : Dictionary = meu.aprender_de_maquina(_itens.get("tm02", {}))
	_conf("usar a MT ensinou", not str(r["golpe"]).is_empty())
	_conf("e o kit ATIVO não mudou sozinho (§31)",
		(meu.kit as Array).size() == kit_antes,
		"se a MT equipasse sozinha, ela decidiria pelo jogador")
	_conf("mas o pool cresceu",
		(meu.conhecidos as Array).size() > sabia_antes or not bool(r["novo"]))

	# Uma máquina que não ensina nada não inventa golpe.
	var nada : Dictionary = meu.aprender_de_maquina({})
	_conf("máquina vazia não ensina nada", str(nada["golpe"]) == ""
		and not bool(nada["novo"]))

## 🔴 A guarda da Fase 16, que nasceu de um teste que abortou no meio e **saiu
## com sucesso**. Teste que some é teste que reprova.
const CONFERENCIAS_ESPERADAS : int = 59

func _terminar() -> void:
	var total : int = ok + fail
	if total < CONFERENCIAS_ESPERADAS:
		fail += 1
		print("  FALHOU  só %d de %d conferências rodaram — alguma abortou calada"
			% [total, CONFERENCIAS_ESPERADAS])
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
