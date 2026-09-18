## teste_gameplay_v3_fase16.gd — MT e MO (Fase 16).
##
## ── A pergunta que esta fase tinha que responder ────────────────────────────
##
## As Fases 14 e 15 resolveram travessia por **arquétipo**: quem nada, nada.
## Isso deixou um buraco: se a espécie já decide, **o que sobra pra MO fazer?**
## Portar a MO da V2 sem responder criaria uma MO Surf que ensina um golpe e não
## muda nada no mundo — zero silencioso com nome de item.
##
## A resposta são duas perguntas separadas (§30):
##
##   **capacidade** — o corpo consegue? → arquétipo
##   **permissão**  — o jogador pode?   → a MO
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **"MO = travessia" presumido.** §30 é explícita: *não presumir que faz
##      sempre as duas coisas*. Cortar e Força não abrem passagem nenhuma na V3,
##      e o dado precisa dizer isso em voz alta.
##   2. **Permissão por omissão.** Uma lista vazia que libera tudo não é
##      permissão — é decoração. Falha fechada.
##   3. **Selvagem pedindo carteira.** Exigir MO de um bicho transformaria o
##      mundo num cartório e reprovaria a Fase 11 inteira por regra inventada.
##   4. **MT cobrando nível.** Os 25 níveis (§33) valem pra troca ligada a MO;
##      MT só ensina (§31) e não custa nada.
##   5. **Travessia escrita errada no JSON virando permissão fantasma.**
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _itens : Dictionary = {}
var _aquatico = null

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 16: MT e MO ===")
	_carregar_itens()
	_classificacao()
	_efeitos_declarados()
	_permissoes()
	_as_duas_perguntas()
	_custo()

## Lê `items.json` direto do disco. De propósito: `GameData` é autoload, e
## autoload **não é identificador** num teste `--script` — a lição do
## `RNGManager` (Fase 11) e a do `PonteDeFeedback` (Fase 13), na mesma semana.
func _carregar_itens() -> void:
	var f := FileAccess.open("res://data/items/items.json", FileAccess.READ)
	_conf("items.json abre", f != null)
	if f == null:
		return
	var lido = JSON.parse_string(f.get_as_text())
	_conf("items.json é JSON válido", lido is Dictionary)
	if lido is Dictionary:
		_itens = lido

# ──────────────────────────────────────────────────────────────────────────────

func _classificacao() -> void:
	print("\n-- MT e MO são coisas diferentes --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")

	var mo : Dictionary = _itens.get("hm02", {})
	var mt : Dictionary = _itens.get("tm02", {})
	_conf("as duas existem no dado", not mo.is_empty() and not mt.is_empty())

	_conf("MO é máquina e é MO", R.e_maquina(mo) and R.e_mo("hm02"))
	_conf("MT é máquina e NÃO é MO", R.e_maquina(mt) and R.e_mt(mt) and not R.e_mo("tm02"))
	_conf("uma poção não é máquina nenhuma", not R.e_maquina(_itens.get("potion", {})))

	# §31: MT só ensina; MO ensina e abre a tela de troca.
	_conf("§31: MT só ensina", R.so_ensina(mt))
	_conf("§31: MO NÃO é 'só ensina' — ela abre a troca", not R.so_ensina(mo))

	# Gastar sai do dado, não do prefixo: a MT de ouro é reutilizável.
	_conf("MT comum gasta ao usar", R.gasta_ao_usar(mt))
	_conf("MO não gasta", not R.gasta_ao_usar(mo))
	var ouro : Dictionary = _itens.get("gold_tm01", {})
	if not ouro.is_empty():
		_conf("a MT de OURO não gasta, e isso vem do dado", not R.gasta_ao_usar(ouro),
			"se viesse do prefixo 'tm', esta reprovaria")

func _efeitos_declarados() -> void:
	print("\n-- §30: combate, travessia, ou os dois --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")

	var voar : Dictionary = R.efeitos(_itens.get("hm02", {}))
	_conf("Voar ensina E abre o ar", str(voar["golpe"]) == "fly"
		and str(voar["travessia"]) == R.TRAVESSIA_AR, str(voar))

	var surf : Dictionary = R.efeitos(_itens.get("hm04", {}))
	_conf("Surfar ensina E abre a água", str(surf["golpe"]) == "surf"
		and str(surf["travessia"]) == R.TRAVESSIA_AGUA, str(surf))

	# O ponto inteiro da §30 está nestas duas linhas: são MOs, e não abrem nada.
	for id in ["hm01", "hm03"]:
		var e : Dictionary = R.efeitos(_itens.get(id, {}))
		_conf("%s é MO e abre travessia NENHUMA (§30)" % id,
			str(e["golpe"]) != "" and str(e["travessia"]) == R.TRAVESSIA_NENHUMA,
			"presumir 'MO = travessia' criaria uma promessa falsa: %s" % str(e))

	var mt : Dictionary = _itens.get("tm02", {})
	_conf("MT ensina e não abre travessia",
		R.ensina_golpe(mt) and not R.abre_travessia(mt))

	# Erro de digitação no JSON não pode virar permissão fantasma.
	var torto : Dictionary = {"id": "hm99", "category": "tm_hm",
		"teaches": "cut", "unlocks": "lava"}
	_conf("travessia desconhecida é ignorada, não concedida",
		str(R.efeitos(torto)["travessia"]) == R.TRAVESSIA_NENHUMA)

	# A frase pro jogador precisa citar as duas metades quando as duas existem.
	var frase : String = R.resumo(_itens.get("hm04", {}), "Surfar")
	_conf("o resumo da MO Surf fala do golpe e da água",
		frase.to_lower().contains("surfar") and frase.to_lower().contains("água"), frase)

func _permissoes() -> void:
	print("\n-- a mochila concede, ninguém guarda --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")

	_conf("mochila vazia não concede nada", R.permissoes_de([], _itens).is_empty())
	_conf("só a MO de Voar concede só o ar",
		R.permissoes_de(["hm02"], _itens) == [R.TRAVESSIA_AR])
	_conf("Voar + Surfar concedem os dois",
		R.permissoes_de(["hm02", "hm04"], _itens).size() == 2)
	_conf("Cortar e Força não concedem nada",
		R.permissoes_de(["hm01", "hm03"], _itens).is_empty(),
		"é a §30 chegando até a mochila")

	# A mochila da V2 é {id: quantidade} — aceitar os dois formatos evita que o
	# chamador converta (e converta errado).
	_conf("formato {id: quantidade} funciona igual",
		R.permissoes_de({"hm04": 1}, _itens) == [R.TRAVESSIA_AGUA])
	_conf("quantidade zero não concede", R.permissoes_de({"hm04": 0}, _itens).is_empty())
	_conf("item que não existe no catálogo é ignorado",
		R.permissoes_de(["nao_existe"], _itens).is_empty())

func _as_duas_perguntas() -> void:
	print("\n-- capacidade E permissão --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")
	var T = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")

	# Capacidade faltando: nem a MO resolve.
	var terrestre_com_mo : Dictionary = R.pode_atravessar(
		"ground_biped", T.AGUA_PROFUNDA, [R.TRAVESSIA_AGUA])
	_conf("terrestre COM a MO ainda não atravessa", not bool(terrestre_com_mo["pode"]))
	_conf("e o motivo fala do Pokémon, não da MO",
		str(terrestre_com_mo["motivo"]).to_lower().contains("nada"),
		str(terrestre_com_mo["motivo"]))

	# Permissão faltando: nem a capacidade resolve.
	var aquatico_sem : Dictionary = R.pode_atravessar("aquatic", T.AGUA_PROFUNDA, [])
	_conf("aquático SEM a MO não atravessa (falha fechada)", not bool(aquatico_sem["pode"]))
	_conf("e o motivo fala da permissão, não do Pokémon",
		not str(aquatico_sem["motivo"]).to_lower().contains("não nada"),
		str(aquatico_sem["motivo"]))

	_conf("aquático COM a MO atravessa",
		bool(R.pode_atravessar("aquatic", T.AGUA_PROFUNDA, [R.TRAVESSIA_AGUA])["pode"]))

	# Água rasa nunca precisa de permissão — a parede na beira da praia continua
	# derrubada (Fase 14).
	_conf("água rasa não exige MO nenhuma",
		bool(R.pode_atravessar("ground_biped", T.AGUA_RASA, [])["pode"]))
	_conf("terra firme idem",
		bool(R.pode_atravessar("ground_biped", T.TERRA, [])["pode"]))

	# Quem voa não está NA água: passar por cima não é atravessar.
	_conf("o voador passa por cima sem a MO de Surfar",
		bool(R.pode_atravessar("flying", T.AGUA_PROFUNDA, [])["pode"]))

	# Decolar tem duas recusas diferentes, e elas não podem virar a mesma frase.
	var sem_asa : Dictionary = R.pode_decolar("ground_biped", {}, [R.TRAVESSIA_AR])
	var sem_mo : Dictionary = R.pode_decolar("flying", {}, [])
	var proibido : Dictionary = R.pode_decolar("flying", {"voo": T.VOO_PROIBIDO},
		[R.TRAVESSIA_AR])
	_conf("quem não voa não decola", not bool(sem_asa["pode"]))
	_conf("quem voa sem a MO não decola", not bool(sem_mo["pode"]))
	_conf("zona proibida barra mesmo com a MO", not bool(proibido["pode"]))
	_conf("as três recusas têm frases diferentes",
		str(sem_asa["motivo"]) != str(sem_mo["motivo"])
		and str(sem_mo["motivo"]) != str(proibido["motivo"]),
		"recusa sem motivo distinto é o jogador sem saber o que fazer")
	_conf("com asa, MO e zona livre, decola",
		bool(R.pode_decolar("flying", {}, [R.TRAVESSIA_AR])["pode"]))

func _custo() -> void:
	print("\n-- §33: os 25 níveis são da MO, não de toda troca --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")
	var K = load("res://scripts/combat/TrocaDeKit.gd")

	_conf("MO custa níveis", R.custa_niveis(_itens.get("hm02", {})))
	_conf("MT não custa nada", not R.custa_niveis(_itens.get("tm02", {})))
	_conf("o custo NÃO é redeclarado aqui — vem de TrocaDeKit",
		R.custo_em_niveis() == K.CUSTO_EM_NIVEIS,
		"duas fontes pro mesmo número é como elas passam a discordar")
	_conf("e continua configurável", K.CUSTO_EM_NIVEIS > 0)

# ──────────────────────────────────────────────────────────────────────────────
# Com corpo de verdade: o selvagem não pede carteira
# ──────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> bool:
	_quadros += 1
	match _quadros:
		1:
			_montar()
		5:
			_no_mundo()
		9:
			_terminar()
			return true
	return false

func _montar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	mundo.add_child(Ter.new())
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_aquatico = P.nascer(mundo, 130, 30, _ponto_seco(), "aquatic")

func _ponto_seco() -> Vector3:
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	for x in range(0, 200, 7):
		for z in range(0, 200, 7):
			if Ter.superficie_em(float(x), float(z)) == RegraDeTravessia.TERRA:
				return Vector3(float(x), Ter.altura_em(float(x), float(z)), float(z))
	return Vector3.ZERO

func _ponto_fundo() -> Vector3:
	var Ter = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	for x in range(0, 200, 5):
		for z in range(0, 200, 5):
			if Ter.superficie_em(float(x), float(z)) == RegraDeTravessia.AGUA_PROFUNDA:
				return Vector3(float(x), 1.0, float(z))
	return Vector3.ZERO

func _no_mundo() -> void:
	print("\n-- no terreno de verdade --")
	var fundo := _ponto_fundo()
	_conf("o terreno tem água profunda pra testar", fundo != Vector3.ZERO)
	if fundo == Vector3.ZERO or _aquatico == null:
		return

	# 1. Selvagem: nunca é perguntado pela MO. Se esta reprovar, a Fase 11
	#    inteira passa a depender de um item que selvagem não carrega.
	_aquatico.controlado_pelo_jogador = false
	_aquatico.permissoes = []
	_aquatico.global_position = fundo
	_aquatico._tick_travessia(0.016)
	_conf("o selvagem aquático FICA na água, sem MO nenhuma",
		Vector2(_aquatico.global_position.x - fundo.x,
				_aquatico.global_position.z - fundo.z).length() < 0.01,
		"pedir carteira a um bicho é regra inventada")

	# 2. Jogador sem a MO: devolvido. Precisa de um lugar seco conhecido pra
	#    onde voltar — senão o recuo não acontece (achado da Fase 14).
	_aquatico.global_position = _ponto_seco()
	_aquatico.controlado_pelo_jogador = true
	_aquatico.permissoes = []
	_aquatico._tick_travessia(0.016)
	_aquatico.global_position = fundo
	_aquatico._tick_travessia(0.016)
	_conf("o jogador SEM a MO é devolvido da água funda",
		Vector2(_aquatico.global_position.x - fundo.x,
				_aquatico.global_position.z - fundo.z).length() > 0.5)
	_conf("e ouve por quê",
		_aquatico.por_que_nao_atravessa(RegraDeTravessia.AGUA_PROFUNDA).length() > 10,
		_aquatico.por_que_nao_atravessa(RegraDeTravessia.AGUA_PROFUNDA))

	# 3. Mesmo corpo, mesma água, com a MO: fica.
	_aquatico.permissoes = [RegraDeMaquina.TRAVESSIA_AGUA]
	_aquatico.global_position = fundo
	_aquatico._tick_travessia(0.016)
	_conf("o jogador COM a MO fica na água funda",
		Vector2(_aquatico.global_position.x - fundo.x,
				_aquatico.global_position.z - fundo.z).length() < 0.01,
		"mesmo corpo, mesma água — só a permissão mudou")

	# 4. A permissão é do JOGADOR: sai com ele.
	_aquatico.devolver_controle()
	_conf("devolver o controle devolve a permissão junto",
		_aquatico.permissoes.is_empty())

## 🔴 **Achado ao escrever esta fase, e ele vale pra suíte inteira.**
##
## Um erro de execução no meio do teste (`Invalid set index`) abortou `_no_mundo`
## calado: as conferências que faltavam simplesmente não rodaram, e o arquivo
## **saiu com sucesso** — 43 OK, 0 falhas, e um terço do teste nunca aconteceu.
##
## É a mesma família do `RNGManager` da Fase 11: o erro aparece na saída e não
## reprova nada. Contar as conferências fecha essa porta — teste que some é
## teste que reprova.
const CONFERENCIAS_ESPERADAS : int = 48

func _terminar() -> void:
	var total : int = ok + fail
	if total < CONFERENCIAS_ESPERADAS:
		fail += 1
		print("  FALHOU  só %d de %d conferências rodaram — alguma abortou calada"
			% [total, CONFERENCIAS_ESPERADAS])
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
