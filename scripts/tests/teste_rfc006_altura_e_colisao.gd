## teste_rfc006_altura_e_colisao.gd — A revisão de gameplay que a RFC-006 pediu.
##
## ── Por que este arquivo existe ─────────────────────────────────────────────
##
## O Codex mediu a divergência **do lado dele**: `Terreno3D.altura_em(x,z)`
## diferia da malha de colisão em até **1,7922 m** em 6.400 centros de célula, e
## implementou a opção A (a API pública interpola os mesmos dois triângulos que
## a colisão usa). A RFC diz, com todas as letras, que o contrato **não está
## aceito** até eu revisar a regressão de movimento e spawn.
##
## Revisar lendo o diff não é revisar. O que este arquivo faz é medir o que a
## divergência significava **em gameplay**, e provar que agora não significa
## mais:
##
##   1. **Nascer.** `SpawnerSelvagem3D` põe `ponto.y = altura_em(...)` e solta o
##      corpo ali. Se a consulta discorda da colisão, o bicho nasce enterrado
##      (a física o expulsa pra cima no quadro seguinte — e a Fase 11 provou que
##      expulsão de corpo carrega quem estiver por perto) ou pairando (cai, e o
##      primeiro quadro de vida dele é uma queda).
##   2. **Andar.** O `_tick_travessia` e o `RegraDeAcompanhar` perguntam a
##      altura pra decidir profundidade de água, teto de voo e onde o seguidor
##      pousa. Errar 1,79 m em água rasa (que começa a −1,5 m) troca "praia" por
##      "submerso" — inverte a regra da Fase 14.
##   3. **A superfície.** `superficie_em` também passou a ler a altura
##      interpolada. Se areia/terra/água mudassem de lugar, som de passo e cor
##      passariam a discordar do que o corpo pisa.
##
## ⚠️ A régua aqui é a malha de verdade: os vértices são recalculados com a
## MESMA aritmética do `_gerar()` e o ponto é comparado contra o triângulo em
## que ele cai. Comparar `altura_em` com `altura_em` provaria nada.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 20

## A tolerância que eu declaro como gameplay, e a razão dela está no relatório:
## 1 cm é menor que qualquer passo, qualquer degrau e qualquer folga de cápsula
## deste jogo. Acima disso alguém flutua ou afunda visivelmente.
const TOLERANCIA_M : float = 0.01

## O limite de chão **deste jogo**, não o padrão do Godot.
##
## ⚠️ Escrevi 45° aqui primeiro, por ser o `floor_max_angle` padrão da engine —
## e estava errado: `TrainerController3D` e `PokemonInstance3D` os dois atribuem
## `Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA`, que é **46°**. Medir contra o padrão
## da engine seria medir um jogo que não é este. Lido da fonte, nunca copiado.
static func limite_de_chao_graus() -> float:
	var Loc : GDScript = load("res://scripts/gameplay_v3/movimento/Locomocao3D.gd")
	return rad_to_deg(Loc.ANGULO_MAXIMO_DE_SUBIDA)

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

# ──────────────────────────────────────────────────────────────────────────────
# A malha de verdade, reconstruída à mão
# ──────────────────────────────────────────────────────────────────────────────

## A altura da SUPERFÍCIE DE COLISÃO num ponto, calculada sem passar por
## `altura_em`. É a régua independente: reconstrói a célula de 2 m, amostra os
## quatro cantos pela função analítica (que é o que `_gerar` entrega ao
## `ArrayMesh` e ao `TrimeshShape3D`) e resolve o plano do triângulo A-B-C ou
## A-C-D em que o ponto cai — por geometria de plano, não pelas baricêntricas
## que o código sob teste usa.
func _altura_da_malha(x: float, z: float, Ter: GDScript) -> float:
	var passo : float = Ter.PASSO
	var x0 : float = -Ter.LARGURA * 0.5
	var z0 : float = -Ter.PROFUNDIDADE * 0.5
	var coluna : int = int(floor((x - x0) / passo))
	var linha : int = int(floor((z - z0) / passo))
	var xa : float = x0 + coluna * passo
	var za : float = z0 + linha * passo
	var xb : float = xa + passo
	var zb : float = za + passo

	# Os quatro cantos, pela mesma fonte que gera os vértices.
	var a := Vector3(xa, Ter._altura_analitica_em(xa, za), za)
	var b := Vector3(xb, Ter._altura_analitica_em(xb, za), za)
	var c := Vector3(xb, Ter._altura_analitica_em(xb, zb), zb)
	var d := Vector3(xa, Ter._altura_analitica_em(xa, zb), zb)

	var u : float = (x - xa) / passo
	var v : float = (z - za) / passo
	if v <= u:
		return _y_no_plano(a, b, c, x, z)
	return _y_no_plano(a, c, d, x, z)

## Onde o plano de três pontos cruza a vertical que passa por (x, z).
func _y_no_plano(p1: Vector3, p2: Vector3, p3: Vector3, x: float, z: float) -> float:
	var n : Vector3 = (p2 - p1).cross(p3 - p1)
	if absf(n.y) < 0.000001:
		return p1.y
	return p1.y - (n.x * (x - p1.x) + n.z * (z - p1.z)) / n.y

# ──────────────────────────────────────────────────────────────────────────────

func _init() -> void:
	print("== RFC-006: altura consultada x superfície de colisão ==")

	# ⚠️ Autoload não é identificador em teste `--script` — a lição de três
	# fases seguidas. `Terreno3D` é `class_name`, não autoload, mas carrego por
	# `load` mesmo assim porque preciso do `_altura_analitica_em`, que é
	# privado: chamá-lo por identificador direto seria acesso a membro privado
	# de outra classe, e o que eu quero é justamente medir a fonte dos vértices.
	var Ter : GDScript = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	_conf("Terreno3D carrega", Ter != null)

	_medir_divergencia(Ter)
	_medir_nascimento(Ter)
	_medir_travessia(Ter)
	_medir_relevo(Ter)
	_medir_fora_do_retangulo(Ter)

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	# A guarda de contagem (a lição da Fase 16): um arquivo que aborta no meio
	# sai com sucesso e some da conta. Silêncio deixou de ser aprovação.
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)

# ──────────────────────────────────────────────────────────────────────────────
# 1. A divergência em si
# ──────────────────────────────────────────────────────────────────────────────

func _medir_divergencia(Ter: GDScript) -> void:
	print("\n-- A divergência, medida contra o plano do triângulo --")

	# Uma varredura densa e DESALINHADA da grade: 0,37 m não é divisor de 2 m,
	# então os pontos caem no meio das células, nas duas metades, e nunca em
	# cima de um vértice — que é exatamente onde as duas fórmulas concordariam
	# de graça e a medição não provaria nada.
	var pior : float = 0.0
	var pior_em := Vector2.ZERO
	var acima_de_um_cm : int = 0
	var amostras : int = 0
	var x : float = -70.0
	while x <= 70.0:
		var z : float = -70.0
		while z <= 70.0:
			var consultada : float = Ter.altura_em(x, z)
			var real : float = _altura_da_malha(x, z, Ter)
			var erro : float = absf(consultada - real)
			if erro > pior:
				pior = erro
				pior_em = Vector2(x, z)
			if erro > TOLERANCIA_M:
				acima_de_um_cm += 1
			amostras += 1
			z += 0.37
		x += 0.37

	print("   amostras=", amostras, "  pior=", "%.6f" % pior, " m em ", pior_em)
	_conf("varredura cobre as duas metades da célula", amostras > 30000,
		str(amostras) + " amostras")
	_conf("altura consultada = superfície de colisão (≤ 1 cm)",
		pior <= TOLERANCIA_M, "pior erro " + ("%.6f" % pior) + " m")
	_conf("nenhum ponto acima de 1 cm", acima_de_um_cm == 0,
		str(acima_de_um_cm) + " pontos fora")

	# A prova de que a régua PEGA divergência: a fonte analítica contínua — o
	# que a API devolvia antes da RFC-006 — tem de reprovar nesta mesma medida.
	# Sem isto, "erro 0,000000" poderia ser um teste que não mede nada.
	var pior_analitica : float = 0.0
	var xx : float = -70.0
	while xx <= 70.0:
		var zz : float = -70.0
		while zz <= 70.0:
			pior_analitica = maxf(pior_analitica,
				absf(Ter._altura_analitica_em(xx, zz) - _altura_da_malha(xx, zz, Ter)))
			zz += 0.37
		xx += 0.37
	print("   a fonte ANALÍTICA erraria até ", "%.4f" % pior_analitica, " m")
	_conf("a régua detecta a divergência antiga", pior_analitica > 0.10,
		"analítica erra só " + ("%.4f" % pior_analitica) + " m — régua cega")

# ──────────────────────────────────────────────────────────────────────────────
# 2. Nascer
# ──────────────────────────────────────────────────────────────────────────────

func _medir_nascimento(Ter: GDScript) -> void:
	print("\n-- Nascer: o Y que o spawner escreve x o chão que existe ali --")

	# O anel de spawn da Fase 11 é de 12 a 28 m em volta do jogador. Reproduzo
	# a geometria dele sem instanciar o spawner: o que está sob teste é o chão,
	# não o sorteio.
	var enterrados : int = 0
	var pairando : int = 0
	var pior : float = 0.0
	for i in 720:
		var ang : float = float(i) * TAU / 720.0
		var raio : float = 12.0 + fmod(float(i) * 0.7, 16.0)
		var px : float = cos(ang) * raio
		var pz : float = sin(ang) * raio
		var y_escrito : float = Ter.altura_em(px, pz)
		var y_real : float = _altura_da_malha(px, pz, Ter)
		var d : float = y_escrito - y_real
		pior = maxf(pior, absf(d))
		if d < -TOLERANCIA_M:
			enterrados += 1
		elif d > TOLERANCIA_M:
			pairando += 1

	print("   720 pontos de anel · pior desvio ", "%.6f" % pior, " m")
	_conf("nenhum nascimento enterrado", enterrados == 0, str(enterrados) + " enterrados")
	_conf("nenhum nascimento pairando", pairando == 0, str(pairando) + " pairando")
	_conf("desvio de nascimento dentro da tolerância", pior <= TOLERANCIA_M,
		("%.6f" % pior) + " m")

# ──────────────────────────────────────────────────────────────────────────────
# 3. Andar: a travessia lê a mesma altura
# ──────────────────────────────────────────────────────────────────────────────

func _medir_travessia(Ter: GDScript) -> void:
	print("\n-- Andar: profundidade de água e superfície --")

	# A Fase 14 classifica profundidade por faixas de altura. Se a altura muda,
	# a classificação pode mudar de faixa — e é isso que troca "praia" por
	# "submerso". Mede-se quantos pontos TROCARIAM de classe se alguém ainda
	# lesse a fonte analítica.
	var Trav : GDScript = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	_conf("RegraDeTravessia carrega", Trav != null)

	var trocariam : int = 0
	var conferidos : int = 0
	var x : float = -60.0
	while x <= 60.0:
		var z : float = -60.0
		while z <= 60.0:
			var pela_api : String = Trav.profundidade_em(Ter.altura_em(x, z))
			var pela_malha : String = Trav.profundidade_em(_altura_da_malha(x, z, Ter))
			if pela_api != pela_malha:
				trocariam += 1
			conferidos += 1
			z += 1.13
		x += 1.13

	print("   ", conferidos, " pontos · ", trocariam, " trocariam de profundidade")
	_conf("profundidade da água concorda com a colisão", trocariam == 0,
		str(trocariam) + " pontos discordam")

	# A superfície (cor, som de passo) passou a ler a altura interpolada. Ela
	# tem de concordar com o que o corpo pisa, senão anda-se na areia ouvindo
	# água.
	var sup_trocam : int = 0
	var xx : float = -60.0
	while xx <= 60.0:
		var zz : float = -60.0
		while zz <= 60.0:
			if Ter.superficie_em(xx, zz) != _superficie_da_malha(xx, zz, Ter):
				sup_trocam += 1
			zz += 1.13
		xx += 1.13
	_conf("superfície concorda com a colisão", sup_trocam == 0,
		str(sup_trocam) + " pontos discordam")

## A superfície derivada da altura de COLISÃO, pelas mesmas faixas que
## `superficie_em` usa. Reimplementada aqui de propósito: se eu chamasse
## `superficie_em`, estaria comparando a função com ela mesma.
func _superficie_da_malha(x: float, z: float, Ter: GDScript) -> String:
	var y : float = _altura_da_malha(x, z, Ter)
	if y <= Ter.AGUA_RASA_ATE:
		return "agua_profunda"
	if y < Ter.NIVEL_DO_MAR:
		return "agua_rasa"
	if y < Ter.FIM_DA_AREIA:
		return "areia"
	if y > 12.0:
		return "rocha"
	return "terra"

# ──────────────────────────────────────────────────────────────────────────────
# 4. O relevo que a resolução de 2 m consegue representar
# ──────────────────────────────────────────────────────────────────────────────

func _medir_relevo(Ter: GDScript) -> void:
	print("\n-- Relevo: o que 2 m de passo representa (pergunta 2 da RFC) --")

	# O degrau máximo entre vértices vizinhos é o que decide se uma falésia é
	# "subível" ou vira parede. Mede-se pra eu poder responder com número, e
	# não com opinião, qual resolução o gameplay precisa.
	var limite : float = limite_de_chao_graus()
	var maior_degrau : float = 0.0
	var maior_inclinacao : float = 0.0
	var celulas : int = 0
	var ingremes : int = 0
	var passo : float = Ter.PASSO
	var x : float = -78.0
	while x <= 78.0:
		var z : float = -78.0
		while z <= 78.0:
			var h : float = Ter._altura_analitica_em(x, z)
			var dx : float = absf(Ter._altura_analitica_em(x + passo, z) - h)
			var dz : float = absf(Ter._altura_analitica_em(x, z + passo) - h)
			var d : float = maxf(dx, dz)
			var graus : float = rad_to_deg(atan(d / passo))
			maior_degrau = maxf(maior_degrau, d)
			maior_inclinacao = maxf(maior_inclinacao, graus)
			if graus >= limite:
				ingremes += 1
			celulas += 1
			z += passo
		x += passo

	print("   maior degrau entre vértices vizinhos: ", "%.4f" % maior_degrau, " m")
	print("   maior inclinação de célula:           ", "%.2f" % maior_inclinacao, "°")
	print("   células acima de ", "%.0f" % limite, "°: ", ingremes, " de ", celulas,
		"  (", "%.2f" % (100.0 * float(ingremes) / float(celulas)), "%)")
	_conf("o terreno tem relevo de verdade", maior_degrau > 0.2,
		"degrau máximo " + ("%.4f" % maior_degrau) + " m — terreno é uma mesa")

	# 🔴 ACHADO, e ele é meu, não do Codex: o laboratório TEM parede.
	#
	# `floor_max_angle` padrão do Godot é 45°: acima disso o `move_and_slide`
	# para de tratar a face como chão e o corpo escorrega por ela. Este teste
	# não finge que isso não existe — ele **fixa a existência** da parede, pra
	# que a regra que falta (recusar ponto íngreme antes de `nascer()`, a
	# pergunta 4 da RFC-006) tenha um alvo medido e não uma suposição.
	#
	# Enquanto essa regra não existir, nascer numa dessas células é um bicho
	# que desliza no primeiro quadro de vida. A RFC-006 **não** autoriza criar
	# máscara de spawn, então isto fica registrado, não corrigido aqui.
	_conf("o laboratório tem células mais íngremes que o limite de chão",
		ingremes > 0,
		"nenhuma célula passa de " + ("%.0f" % limite)
			+ "° — o achado sumiu, revisar a medição")
	_conf("a parede é minoria, não o terreno inteiro",
		float(ingremes) / float(celulas) < 0.25,
		("%.2f" % (100.0 * float(ingremes) / float(celulas))) + "% do mapa é parede")

# ──────────────────────────────────────────────────────────────────────────────
# 5. Fora do retângulo físico não existe colisão — e a API diz isso
# ──────────────────────────────────────────────────────────────────────────────

func _medir_fora_do_retangulo(Ter: GDScript) -> void:
	print("\n-- Fora do laboratório: a API mantém a fonte analítica --")

	var meia_l : float = Ter.LARGURA * 0.5
	var fora : float = meia_l + 25.0
	_conf("fora do retângulo devolve a fonte analítica",
		is_equal_approx(Ter.altura_em(fora, 0.0), Ter._altura_analitica_em(fora, 0.0)))
	_conf("dentro do retângulo NÃO devolve a fonte analítica",
		not is_equal_approx(Ter.altura_em(1.0, 1.0), Ter._altura_analitica_em(1.0, 1.0)),
		"as duas coincidem em (1,1) — a interpolação não está agindo")

	# A borda é o ponto onde os dois regimes se encontram. Um salto ali seria um
	# degrau invisível na fronteira do laboratório: o corpo andaria e afundaria.
	var na_borda : float = Ter.altura_em(meia_l, 0.0)
	var logo_fora : float = Ter.altura_em(meia_l + 0.001, 0.0)
	_conf("a borda do retângulo não tem degrau", absf(na_borda - logo_fora) < 0.01,
		"salto de " + ("%.4f" % absf(na_borda - logo_fora)) + " m na fronteira")

	# Determinismo: a mesma pergunta, a mesma resposta. É o que permite que
	# cliente e servidor (e dois quadros seguidos) concordem sem sincronizar.
	_conf("a altura é determinística",
		Ter.altura_em(13.37, -4.2) == Ter.altura_em(13.37, -4.2))
	_conf("a altura é contínua entre células vizinhas",
		absf(Ter.altura_em(2.0 - 0.0001, 5.0) - Ter.altura_em(2.0 + 0.0001, 5.0)) < 0.001)

	# E a diagonal: dentro da MESMA célula, os dois triângulos se encontram em
	# v == u. É a costura mais fácil de errar da opção A, porque as duas
	# baricêntricas são fórmulas diferentes que precisam dar o mesmo número.
	var pior_diagonal : float = 0.0
	for i in 200:
		var t : float = float(i) / 200.0 * 2.0
		var px : float = -20.0 + t
		var pz : float = -20.0 + t
		pior_diagonal = maxf(pior_diagonal,
			absf(Ter.altura_em(px - 0.0001, pz + 0.0001)
				- Ter.altura_em(px + 0.0001, pz - 0.0001)))
	_conf("os dois triângulos se encontram na diagonal", pior_diagonal < 0.001,
		"salto de " + ("%.6f" % pior_diagonal) + " m na diagonal da célula")
