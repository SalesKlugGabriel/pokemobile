## teste_gameplay_v3_fase21.gd — Captura em 3D (Fase 21).
##
## ── O que esta fase é, e o que ela NÃO é ────────────────────────────────────
##
## Não é regra nova. `RegrasDeCorpo` já tinha a captura inteira e provada desde
## a V2 — chance por espécie, peso do nível, Ball, shiny, lendário, teto de 95%,
## tentativa única, janela de 10 a 15 s. A RFC da V3 lista `Corpo` entre os
## sistemas **adaptados**: *"a regra fica e a interface muda"*.
##
## O que é novo é **a bola atravessando o espaço**, que em 2D não existia: lá a
## captura era um clique num cadáver que já estava na tela.
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **A regra reimplementada.** Se alguém recalcular chance aqui em vez de
##      chamar `RegrasDeCorpo`, as duas divergem. O teste compara.
##   2. **O Alpha capturável.** A §30 diz que ele é obstáculo, não troféu — e a
##      Fase 18 já decidiu isso; a bola não pode furar a decisão.
##   3. **A segunda tentativa.** §28: uma por corpo. Insistir não é opção.
##   4. **A bola instantânea.** Resolver o acerto no mesmo quadro apagaria o
##      tempo entre decidir e saber, que é a mecânica inteira.
##   5. **A bola que acerta o mapa todo.** Sem alcance, o jogador limparia o
##      mundo de longe e a §28 deixaria de existir.
##   6. **A gravidade inventada.** Uma bola que cai diferente do mundo é o tipo
##      de coisa que ninguém nomeia e todo mundo sente como estranho.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 47

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

## ⚠️ `_initialize`, não `_init`: os autoloads só entram na árvore depois, e
## qualquer script do jogo que cite `GameData` não compila antes disso. Foi a
## quinta vez que essa armadilha apareceu (19/09) — agora está na disciplina.
## ⚠️ Três quadros, e cada um existe por um motivo medido:
##
##   0 (`_initialize`) — só o que é classe pura. **Nada de cena**: um nó
##     adicionado aqui ainda **não está na árvore**, e `global_position` devolve
##     `(0,0,0)` com um erro no console que se perde. Medido nesta fase.
##   1 — monta a cena. Agora `root` está viva de verdade.
##   2 — confere. O `_ready` de cada nó só disparou agora, então é só aqui que
##     `add_to_group` já aconteceu.
##
## As duas armadilhas estão na disciplina de teste do `QUADRO`, e eu caí nas
## duas mesmo tendo lido — por isso o comentário fica no topo do arquivo.
var _quadro : int = 0

func _initialize() -> void:
	print("== Fase 21: captura em 3D ==")
	_arremesso()
	_a_regra_nao_foi_reescrita()

func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro == 1:
		_montar_cena()
		return false
	if _quadro < 3:
		return false

	_o_corpo()
	_a_bola_no_ar()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# 1. A balística
# ──────────────────────────────────────────────────────────────────────────────

func _arremesso() -> void:
	print("\n-- O arremesso --")

	var g : float = Locomocao3D.GRAVIDADE
	var v : Vector3 = RegraDeArremesso.velocidade_inicial(Vector3.FORWARD)

	_conf("a bola sai subindo", v.y > 0.0, str(v))
	_conf("e sai pra frente", v.z < 0.0, str(v))
	_conf("com a velocidade declarada",
		is_equal_approx(v.length(), RegraDeArremesso.VELOCIDADE),
		"%.3f" % v.length())

	# Mirar pro chão não pode cuspir a bola no próprio pé: a direção é achatada
	# e a subida vem da INCLINACAO. É o mesmo princípio de `base_do_movimento`.
	var pra_baixo : Vector3 = RegraDeArremesso.velocidade_inicial(
		Vector3(0.0, -0.9, -0.1).normalized())
	_conf("mirar pro chão ainda arremessa pra frente e pra cima",
		pra_baixo.y > 0.0 and pra_baixo.z < 0.0, str(pra_baixo))
	# E mirar reto pra cima não pode devolver zero (bola na própria cabeça).
	var pro_ceu : Vector3 = RegraDeArremesso.velocidade_inicial(Vector3.UP)
	_conf("mirar reto pro céu não devolve zero",
		pro_ceu.length() > 1.0, str(pro_ceu))

	var t : float = RegraDeArremesso.tempo_de_voo(v, g)
	var d : float = RegraDeArremesso.alcance(v, g)
	print("   tempo de voo ", "%.3f" % t, " s · alcance plano ", "%.2f" % d, " m")
	# A bola tem de ser VISÍVEL no ar: resolver em 2 quadros seria o mesmo que
	# resolver na hora, e apagaria a decisão da §28.
	_conf("o voo dura o bastante pra ser visto", t > 0.15, ("%.3f" % t) + " s")
	_conf("e não vira um lob lento", t < 2.0, ("%.3f" % t) + " s")
	# 🔴 A conferência que pegou o defeito: o alcance que a mira ACEITA tem de
	# ser alcançável pelo braço. Eram 18 m declarados contra 7,26 m de
	# balística — a bola cairia no meio do caminho e pareceria bug de mira.
	# Agora o alcance é derivado, então não há o que divergir.
	var alc : float = RegraDeArremesso.alcance_maximo(g)
	print("   alcance aceito pela mira: ", "%.2f" % alc, " m")
	_conf("a mira nunca aceita mais longe do que o braço joga", alc <= d,
		("%.2f" % alc) + " aceito contra " + ("%.2f" % d) + " de balística")
	_conf("e o alcance aceito não é irrisório", alc > 8.0, "%.2f" % alc)

	# A trajetória é arco de verdade: sobe, e volta.
	var meio : Vector3 = RegraDeArremesso.posicao_em(Vector3.ZERO, v, t * 0.5, g)
	var fim : Vector3 = RegraDeArremesso.posicao_em(Vector3.ZERO, v, t, g)
	_conf("no meio do voo a bola está no alto", meio.y > 0.0, str(meio.y))
	_conf("e volta à altura de saída no fim", absf(fim.y) < 0.01, str(fim.y))
	_conf("no instante zero ela está na mão",
		RegraDeArremesso.posicao_em(Vector3.ONE, v, 0.0, g).is_equal_approx(
			Vector3.ONE))

	# Alcance: a trava que obriga a aproximação.
	_conf("perto dá pra arremessar",
		bool(RegraDeArremesso.no_alcance(Vector3.ZERO, Vector3(0, 0, 5))["pode"]))
	_conf("longe não dá",
		not bool(RegraDeArremesso.no_alcance(
			Vector3.ZERO, Vector3(0, 0, 200))["pode"]))
	# A borda: logo além do alcance derivado já recusa.
	_conf("logo além do alcance já recusa",
		not bool(RegraDeArremesso.no_alcance(Vector3.ZERO,
			Vector3(0, 0, RegraDeArremesso.alcance_maximo() + 0.5))["pode"]))
	_conf("e a recusa explica em português",
		str(RegraDeArremesso.no_alcance(
			Vector3.ZERO, Vector3(0, 0, 200))["motivo"]).length() > 10)

	# Acerto: o alvo grande é um alvo maior, de verdade.
	var perto := Vector3(0, 0, 1.0)
	_conf("acerta o que está colado",
		RegraDeArremesso.acertou(Vector3.ZERO, perto))
	var fora := Vector3(0, 0, 2.5)
	_conf("erra o que está fora do raio",
		not RegraDeArremesso.acertou(Vector3.ZERO, fora))
	_conf("mas acerta um alvo GRANDE na mesma distância",
		RegraDeArremesso.acertou(Vector3.ZERO, fora, 2.0),
		"o raio do alvo não está sendo somado — um Onix seria atravessado")

# ──────────────────────────────────────────────────────────────────────────────
# 2. O corpo
# ──────────────────────────────────────────────────────────────────────────────

var _mundo : Node3D = null
var _comum : Node3D = null
var _alpha : Node3D = null
var _corpo : Node3D = null
var _corpo_alpha : Node3D = null
var _outro : Node3D = null
var _corpo2 : Node3D = null
var _bicho_bola : Node3D = null
var _corpo_bola : Node3D = null
var _bola : Node3D = null

## Onde cada coisa estava NO INSTANTE em que nasceu. O Pokémon continua caindo
## sob gravidade depois disso, então comparar o corpo com onde ele está dois
## quadros depois reprovaria código correto — foi o que aconteceu aqui.
var _onde_o_comum_caiu : Vector3 = Vector3.ZERO
const ORIGEM_DO_ARREMESSO : Vector3 = Vector3(0.0, 1.4, 0.0)

## Monta tudo num quadro; confere no seguinte.
##
## ⚠️ `load()`, e não o identificador `PokemonInstance3D`. Instanciar a entidade
## pelo nome da classe **trava** um teste `--script` — conferido com `git stash`
## que isso já era verdade antes desta fase. É por isso que todo teste do
## projeto faz assim; eu tentei o caminho curto primeiro.
func _montar_cena() -> void:
	var P : GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var C : GDScript = load("res://scripts/gameplay_v3/entidades/Corpo3D.gd")
	var B : GDScript = load("res://scripts/gameplay_v3/entidades/PokebolaLancada3D.gd")

	_mundo = Node3D.new()
	root.add_child(_mundo)

	_comum = P.nascer(_mundo, 25, 12, Vector3(3, 0, 3))
	_alpha = P.nascer(_mundo, 25, 12, Vector3(9, 0, 3),
		"", RegraDeMovePool.CATEGORIA_PADRAO, true)
	_onde_o_comum_caiu = _comum.global_position
	_corpo = C.nascer(_mundo, _comum, 0.5)
	_corpo.sortear = func() -> float: return 0.0
	_corpo_alpha = C.nascer(_mundo, _alpha, 0.5)
	_corpo_alpha.sortear = func() -> float: return 0.0
	_outro = P.nascer(_mundo, 25, 12, Vector3(-4, 0, 0))
	_corpo2 = C.nascer(_mundo, _outro, 0.5)
	_corpo2.sortear = func() -> float: return 0.999

	_bicho_bola = P.nascer(_mundo, 25, 12, Vector3(0, 0, -6))
	_corpo_bola = C.nascer(_mundo, _bicho_bola, 0.5)
	_corpo_bola.sortear = func() -> float: return 0.0
	_bola = B.lancar(_mundo, ORIGEM_DO_ARREMESSO, Vector3.FORWARD, _corpo_bola)

func _o_corpo() -> void:
	print("\n-- O corpo que fica --")
	var comum := _comum
	var alpha := _alpha
	var corpo := _corpo
	var corpo_alpha := _corpo_alpha
	var outro := _outro
	var corpo2 := _corpo2

	# Um comum e um Alpha. O Alpha é o caso que a §30 protege.
	_conf("o comum é capturável", comum.capturavel)
	_conf("o Alpha NÃO é", not alpha.capturavel,
		"a Fase 18 decidiu isso; a bola não pode furar")

	_conf("o corpo nasce onde o Pokémon caiu",
		corpo.global_position.is_equal_approx(_onde_o_comum_caiu),
		str(corpo.global_position) + " x " + str(_onde_o_comum_caiu))
	# E ele NÃO acompanha o corpo do bicho depois disso: quem caiu segue caindo
	# sob gravidade, e o cadáver fica onde ficou.
	_conf("e fica parado enquanto o bicho continua caindo",
		absf(corpo.global_position.y - comum.global_position.y) > 0.0001
			or is_equal_approx(comum.global_position.y, _onde_o_comum_caiu.y),
		"o corpo está colado no bicho")
	_conf("e entra no grupo que o treinador procura",
		corpo.is_in_group("corpo_v3"))

	var est : Dictionary = corpo.estado()
	_conf("a janela é a de sempre (10 a 15 s)",
		float(est["segundos_restantes"]) >= RegrasDeCorpo.DURACAO_MIN
			and float(est["segundos_restantes"]) <= RegrasDeCorpo.DURACAO_MAX,
		str(est["segundos_restantes"]))
	# §28: a chance é escondida. Expor viraria planilha.
	_conf("o estado NÃO revela a chance de captura",
		not est.has("chance"), str(est.keys()))
	_conf("o raio de alvo acompanha o tamanho do bicho",
		float(est["raio_de_alvo"]) > 0.0, str(est["raio_de_alvo"]))

	# O Alpha deixa corpo, mas o corpo recusa a tentativa.
	var r_alpha : Dictionary = corpo_alpha.tentar_capturar("masterball")
	_conf("nem a Master Ball captura um Alpha", not bool(r_alpha["pegou"]),
		str(r_alpha))
	_conf("e a recusa não gasta a bola", not bool(r_alpha["gastou"]),
		"recusar gastando é punir o jogador por uma regra que ele não podia saber")

	# A tentativa única (§28).
	var r1 : Dictionary = corpo.tentar_capturar("pokeball")
	_conf("o sorteio favorável captura", bool(r1["pegou"]), str(r1))
	_conf("e devolve espécie e nível pra quem for guardar",
		int(r1.get("species_id", 0)) == 25 and int(r1.get("nivel", 0)) == 12)

	# Um segundo corpo, agora com sorteio que sempre falha.
	var f1 : Dictionary = corpo2.tentar_capturar("pokeball")
	_conf("o sorteio ruim falha", not bool(f1["pegou"]))
	_conf("e a falha explica sem revelar a conta",
		str(f1["motivo"]).length() > 5 and not str(f1["motivo"]).contains("%"),
		str(f1["motivo"]))


# ──────────────────────────────────────────────────────────────────────────────
# 3. A bola no ar
# ──────────────────────────────────────────────────────────────────────────────

func _a_bola_no_ar() -> void:
	print("\n-- A bola no ar --")

	var corpo := _corpo_bola
	var bola := _bola
	print("   bola em ", bola.global_position, " · corpo em ",
		corpo.global_position, " · raio do alvo ", "%.2f" % corpo.raio_de_alvo)
	_conf("a bola nasce com a gravidade DO MUNDO",
		is_equal_approx(bola.gravidade, Locomocao3D.GRAVIDADE),
		str(bola.gravidade) + " x " + str(Locomocao3D.GRAVIDADE))
	_conf("a bola nasce na altura da mão, não no chão",
		bola.position.y > 1.0, str(bola.position.y),
	)
	_conf("e entra no grupo dela", bola.is_in_group("pokebola_v3"))
	# ⚠️ A bola NÃO pode ter resolvido ainda. Resolver no quadro do arremesso
	# apagaria o tempo entre decidir e saber, que é a mecânica da §28.
	_conf("a bola não resolve no quadro do arremesso",
		not bool(RegraDeArremesso.acertou(bola.global_position,
			corpo.global_position, corpo.raio_de_alvo)),
		"a bola nasceu já em cima do alvo")

	# O voo, simulado pela regra pura (headless não roda física).
	# ⚠️ A simulação parte de ONDE A BOLA SAIU, não de onde ela já está: quando
	# esta conferência roda, dois quadros de física já a moveram, e recomeçar a
	# balística dali com a velocidade INICIAL descreveria um arremesso que
	# nunca aconteceu. Foi o meu erro na primeira versão.
	var v : Vector3 = bola.velocidade
	var acertou_em : float = -1.0
	var t : float = 0.0
	while t <= RegraDeArremesso.VIDA_MAXIMA:
		var p : Vector3 = RegraDeArremesso.posicao_em(
			ORIGEM_DO_ARREMESSO, v, t, bola.gravidade)
		if RegraDeArremesso.acertou(p, corpo.global_position, corpo.raio_de_alvo):
			acertou_em = t
			break
		t += 0.016
	print("   acertou em ", "%.3f" % acertou_em, " s de voo")
	_conf("a bola mirada no corpo chega nele", acertou_em > 0.0,
		"nunca acertou — o arco passa por cima do corpo no chão")
	_conf("e leva tempo visível pra chegar", acertou_em > 0.1,
		("%.3f" % acertou_em) + " s")

	_mundo.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# 4. A regra não foi reescrita
# ──────────────────────────────────────────────────────────────────────────────

func _a_regra_nao_foi_reescrita() -> void:
	print("\n-- A regra da V2, intocada --")

	# A prova de que a Fase 21 não recalcula nada: o corpo em 3D e a regra pura
	# têm de dar a MESMA resposta pros mesmos dados. Se alguém reimplementar
	# chance aqui, isto diverge.
	var dados : Dictionary = {
		"catch_rate": 190, "nivel": 12, "capturavel": true,
		"tentativa_usada": false, "restante": 12.0,
		"shiny": false, "lendario": false, "nome": "Pikachu",
	}
	var c : float = RegrasDeCorpo.chance(190, 12, "pokeball")
	print("   chance de referência: ", "%.4f" % c)
	_conf("a chance está entre o piso e o teto declarados",
		c >= RegrasDeCorpo.CHANCE_MINIMA and c <= RegrasDeCorpo.CHANCE_MAXIMA,
		"%.4f" % c)
	_conf("uma Ball melhor sobe a chance",
		RegrasDeCorpo.chance(190, 12, "ultraball") > c)
	_conf("a Master Ball ignora tudo",
		is_equal_approx(RegrasDeCorpo.chance(3, 100, "masterball"), 1.0))
	_conf("nível alto é mais difícil",
		RegrasDeCorpo.chance(190, 90, "pokeball") < c)

	# E o caminho de recusa continua sendo o da V2, não uma cópia.
	dados["tentativa_usada"] = true
	_conf("já tentou = recusa, pela regra da V2",
		not bool(RegrasDeCorpo.pode_tentar(dados)["pode"]))

	# 🔴 A conferência que impede a duplicação silenciosa: o arquivo da Fase 21
	# não pode conter a fórmula. Se aparecer aritmética de chance aqui, alguém
	# copiou em vez de chamar.
	var fonte : String = FileAccess.get_file_as_string(
		"res://scripts/gameplay_v3/entidades/Corpo3D.gd")
	_conf("Corpo3D chama RegrasDeCorpo", fonte.contains("RegrasDeCorpo.tentar"))
	_conf("e NÃO tem fórmula de chance própria",
		not fonte.contains("CHANCE_MAXIMA") and not fonte.contains("catch_rate / "),
		"apareceu conta de chance no Corpo3D — a regra foi copiada")

	var fonte_bola : String = FileAccess.get_file_as_string(
		"res://scripts/gameplay_v3/entidades/PokebolaLancada3D.gd")
	_conf("a bola não decide captura, só entrega",
		not fonte_bola.contains("RegrasDeCorpo.chance"),
		"a bola está calculando chance — ela só deveria avisar o corpo")
