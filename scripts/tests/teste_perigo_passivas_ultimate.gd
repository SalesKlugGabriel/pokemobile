## teste_perigo_passivas_ultimate.gd — Os dois pedidos pendentes do Gabriel.
##
## 1. Densidade de spawn por lugar, **"Sim, e também mais raro"** → `PerigoDaZona`
## 2. **"as passivas conforme a pokedex informa, a ultimate somente na última
##    evolução"** → `Passivas` e `RegrasDeUltimate`
##
## O teste mais importante é `_menos_encontros_onde_e_perigoso()`: ele trava a
## INVERSÃO. O reflexo de quem mexer nisso depois vai ser "lugar perigoso, mais
## bicho" — e o pedido é o contrário.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _rodou : bool = false

var GameData : Node
var Perigo : GDScript
## As zonas vêm do arquivo, direto. O `GameData` NÃO tem `zones` — foi assim
## que este teste achou um bug de verdade no código do mergulho, que usava
## `GameData.zones` e por isso nunca lia a profundidade certa.
var _zonas : Array = []

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

func _initialize() -> void:
	print("== Perigo por zona, passivas da Pokédex e ultimate ==")

func _process(_d: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	Perigo = load("res://scripts/world/systems/PerigoDaZona.gd")
	_zonas = _carregar_zonas()
	_conf(not _zonas.is_empty(), "zones.json carregou", "%d zonas" % _zonas.size())

	_perigo_sai_do_dado()
	_menos_encontros_onde_e_perigoso()
	_mais_raro_e_mais_forte()
	_passivas_da_pokedex()
	_ultimate_so_na_ultima_evolucao()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
	return true

func _carregar_zonas() -> Array:
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	if f == null:
		return []
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		return (j as Dictionary).get("zones", [])
	return j if j is Array else []

func _zona(id: String) -> Dictionary:
	for z in _zonas:
		if str(z.get("id", "")) == id:
			return z
	return {}

# ──────────────────────────────────────────────────────────────────────────────
# Perigo
# ──────────────────────────────────────────────────────────────────────────────

func _perigo_sai_do_dado() -> void:
	print("-- O perigo vem do próprio zones.json")
	var pallet := _zona("pallet_town")
	_conf(not pallet.is_empty(), "achei a zona de Pallet")
	if pallet.is_empty():
		return

	_conf(Perigo.perigo(pallet) <= 0.05, "Pallet é zona segura",
		"perigo %.2f" % Perigo.perigo(pallet))

	# A zona mais perigosa do jogo, achada pelo dado e não por uma lista.
	var mais_perigosa : Dictionary = {}
	var maior : float = -1.0
	for z in _zonas:
		var p : float = Perigo.perigo(z)
		if p > maior:
			maior = p
			mais_perigosa = z
	_conf(maior > 0.5, "existe zona claramente perigosa no mundo",
		"a maior é %s com %.2f" % [str(mais_perigosa.get("id", "?")), maior])
	print("     mais perigosa: %s — %s"
		% [str(mais_perigosa.get("name", "?")), Perigo.descrever(mais_perigosa)])

	# Não existe segunda lista pra manter em sincronia: subir o nível da zona
	# já sobe o perigo dela.
	var copia : Dictionary = pallet.duplicate(true)
	var tabela : Array = copia["wild_pokemon"]
	for e in tabela:
		e["level_min"] = 50
		e["level_max"] = 55
	_conf(Perigo.perigo(copia) > Perigo.perigo(pallet),
		"subir o nível da zona sobe o perigo dela sozinho (fonte única)")

func _menos_encontros_onde_e_perigoso() -> void:
	print("-- 🔴 A inversão: lugar perigoso tem MENOS encontros")
	var segura := _zona("pallet_town")
	var perigosa : Dictionary = {}
	var maior : float = -1.0
	for z in _zonas:
		var p : float = Perigo.perigo(z)
		if p > maior:
			maior = p
			perigosa = z

	var i_segura : float = Perigo.multiplicador_de_intervalo(segura)
	var i_perigosa : float = Perigo.multiplicador_de_intervalo(perigosa)

	# ESTE é o teste que importa. Quem mexer nisso depois vai ter o reflexo de
	# "lugar perigoso, mais bicho" — e o pedido do Gabriel foi o contrário:
	# "Sim, e também mais raro". Menos encontros, cada um pesando mais.
	_conf(i_perigosa > i_segura,
		"o intervalo entre encontros é MAIOR na zona perigosa",
		"segura ×%.2f, perigosa ×%.2f" % [i_segura, i_perigosa])
	_conf(i_segura <= 1.01, "e a zona segura não é penalizada")

func _mais_raro_e_mais_forte() -> void:
	print("-- O 'mais raro' e o 'mais forte'")
	var segura := _zona("pallet_town")
	var perigosa : Dictionary = {}
	var maior : float = -1.0
	for z in _zonas:
		var p : float = Perigo.perigo(z)
		if p > maior:
			maior = p
			perigosa = z

	_conf(Perigo.chance_de_elite(segura) <= 0.001,
		"zona segura não gera elite")
	_conf(Perigo.chance_de_elite(perigosa) > 0.05,
		"zona perigosa gera elite", "%.0f%%" % (Perigo.chance_de_elite(perigosa) * 100.0))

	# O raro sobe, mas o comum continua sendo o mais provável — a correção
	# comprime a diferença, não inverte a tabela.
	var comum_seguro : float = Perigo.peso_corrigido(30.0, segura)
	var raro_seguro  : float = Perigo.peso_corrigido(5.0, segura)
	var comum_perigo : float = Perigo.peso_corrigido(30.0, perigosa)
	var raro_perigo  : float = Perigo.peso_corrigido(5.0, perigosa)

	_conf(is_equal_approx(comum_seguro, 30.0) and is_equal_approx(raro_seguro, 5.0),
		"em zona segura os pesos são os do arquivo, intocados")
	_conf(raro_perigo / comum_perigo > raro_seguro / comum_seguro,
		"em zona perigosa o raro ganha peso relativo",
		"seguro %.3f, perigoso %.3f" % [raro_seguro / comum_seguro, raro_perigo / comum_perigo])
	_conf(comum_perigo > raro_perigo,
		"mas o comum continua sendo o mais provável (não inverte a tabela)")

	# Elite = topo da faixa + níveis extra.
	var entrada := {"level_min": 10, "level_max": 14}
	var normal_baixo : int = Perigo.nivel_do_encontro(entrada, false, 0.0)
	var normal_alto  : int = Perigo.nivel_do_encontro(entrada, false, 0.99)
	var de_elite     : int = Perigo.nivel_do_encontro(entrada, true, 0.0)
	_conf(normal_baixo >= 10 and normal_alto <= 14,
		"encontro normal fica dentro da faixa da zona",
		"%d a %d" % [normal_baixo, normal_alto])
	_conf(de_elite > normal_alto, "elite nasce acima do topo da faixa",
		"elite %d, topo %d" % [de_elite, normal_alto])

# ──────────────────────────────────────────────────────────────────────────────
# Passivas
# ──────────────────────────────────────────────────────────────────────────────

func _passivas_da_pokedex() -> void:
	print("-- As passivas: 151 de 151")
	var sem : Array = []
	var distintas : Dictionary = {}
	for id in GameData.species.keys():
		var esp : Dictionary = GameData.species[id]
		var h := str(esp.get("ability", ""))
		if h.strip_edges() == "":
			sem.append(str(esp.get("name", id)))
		else:
			distintas[h] = true
	_conf(sem.is_empty(), "toda espécie tem habilidade preenchida",
		"faltam %d: %s" % [sem.size(), ", ".join(sem.slice(0, 5))])
	_conf(distintas.size() >= 40, "e há variedade de verdade",
		"%d habilidades distintas" % distintas.size())

	# Amostras contra a Pokédex — se alguém trocar por engano, reprova.
	for par in [[6, "Blaze"], [25, "Static"], [94, "Levitate"], [143, "Immunity"],
				[150, "Pressure"], [130, "Intimidate"], [95, "Rock Head"]]:
		var esp : Dictionary = GameData.species.get(par[0], GameData.species.get(str(par[0]), {}))
		_conf(str(esp.get("ability", "")) == str(par[1]),
			"#%d tem %s" % [par[0], par[1]],
			"tem '%s'" % str(esp.get("ability", "")))

	# Rattata é a exceção declarada: `Guts` é a segunda habilidade dele, e já
	# estava no arquivo. Trocar pela primeira o deixaria mais fraco sem motivo.
	var rattata : Dictionary = GameData.species.get(19, GameData.species.get("19", {}))
	_conf(str(rattata.get("ability", "")) == "Guts",
		"Rattata mantém Guts (exceção declarada, ver Passivas.gd)")

	print("-- A regra 7: passiva sem efeito precisa DIZER que não tem")
	_conf(Passivas.tem_efeito("Blaze"), "Blaze tem efeito de verdade")
	_conf(not Passivas.tem_efeito("Levitate"), "Levitate ainda não tem")
	_conf(not Passivas.texto_para_tela("Blaze").contains("sem efeito"),
		"a que funciona não leva aviso")
	_conf(Passivas.texto_para_tela("Levitate").contains("sem efeito"),
		"a que não funciona leva o aviso junto do texto",
		Passivas.texto_para_tela("Levitate"))

	# Toda habitação usada no jogo tem descrição — senão a Pokédex mostra
	# "não catalogada" pra um Pokémon real, que é pior que não mostrar nada.
	var sem_descricao : Array = []
	for h in distintas.keys():
		if Passivas.descrever(str(h)).contains("não catalogada"):
			sem_descricao.append(str(h))
	_conf(sem_descricao.is_empty(),
		"toda habilidade em uso tem descrição em português",
		"faltam: %s" % ", ".join(sem_descricao))

# ──────────────────────────────────────────────────────────────────────────────
# Ultimate
# ──────────────────────────────────────────────────────────────────────────────

func _ultimate_so_na_ultima_evolucao() -> void:
	print("-- A ultimate só na última evolução")
	var lista : Array[String] = RegrasDeUltimate.listar(GameData.moves)
	_conf(lista.size() >= 3 and lista.size() <= 10,
		"o corte pega poucos golpes, não a metade do jogo",
		"%d golpes: %s" % [lista.size(), ", ".join(lista)])

	var hyper : Dictionary = GameData.get_move("hyper_beam")
	var tackle : Dictionary = GameData.get_move("tackle")
	_conf(RegrasDeUltimate.e_ultimate(hyper), "Hyper Beam é ultimate")
	_conf(not RegrasDeUltimate.e_ultimate(tackle), "Tackle não é")

	# Charmander (4) evolui; Charizard (6) é o fim da linha.
	_conf(not RegrasDeUltimate.pode_equipar(4, GameData.species),
		"Charmander NÃO pode equipar ultimate")
	_conf(RegrasDeUltimate.pode_equipar(6, GameData.species),
		"Charizard pode")
	_conf(not RegrasDeUltimate.pode_equipar(5, GameData.species),
		"Charmeleon, que é do meio, também não pode")

	# Quem nunca evolui é o fim da própria linha — negar seria punir a espécie
	# por não ter cadeia evolutiva.
	_conf(RegrasDeUltimate.pode_equipar(143, GameData.species),
		"Snorlax, que não evolui, pode equipar")
	_conf(RegrasDeUltimate.pode_equipar(150, GameData.species),
		"Mewtwo pode")

	# A recusa explica o porquê, em português, pra aparecer na tela.
	var r : Dictionary = RegrasDeUltimate.conferir(hyper, 4, GameData.species)
	_conf(not bool(r["pode"]), "a conferência recusa")
	_conf(str(r["motivo"]).contains("última evolução"),
		"e diz o motivo em português", str(r["motivo"]))

	# Golpe comum passa em qualquer um — a regra não pode vazar pro resto.
	_conf(bool(RegrasDeUltimate.conferir(tackle, 4, GameData.species)["pode"]),
		"golpe comum continua liberado pra quem ainda evolui")
