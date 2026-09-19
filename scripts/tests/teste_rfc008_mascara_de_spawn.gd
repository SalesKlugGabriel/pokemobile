## teste_rfc008_mascara_de_spawn.gd — A máscara de spawn (RFC-008).
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **O corpo que escorrega ao nascer.** 3,25% do laboratório passa de 46°;
##      quem nasce ali desce a falésia antes de a IA decidir nada.
##   2. **O terrestre que nasce afogando.** Água profunda era ponto de spawn
##      válido — a Fase 14 o barrava no quadro SEGUINTE.
##   3. **A segunda cópia da regra de água.** A metade molhada é delegada a
##      `RegraDeTravessia.pode_estar_em`; se alguém reimplementar aqui, este
##      teste compara as duas e reprova.
##   4. **O mundo que esvazia na praia.** Se o spawner desistisse na primeira
##      recusa, a densidade cairia perto da costa **em silêncio**. O laço de
##      tentativas é conferido.
##   5. **A regra vazando pra locomoção.** Nascer ≠ andar: um aquático vivo pode
##      sair da água, e esta máscara não pode ter mudado isso.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 29

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _init() -> void:
	print("== RFC-008: máscara de spawn ==")

	var Hab : GDScript = load("res://scripts/gameplay_v3/mundo/RegraDeHabitabilidade.gd")
	var Trav : GDScript = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	var Loc : GDScript = load("res://scripts/gameplay_v3/movimento/Locomocao3D.gd")
	var Ter : GDScript = load("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
	var Perfil : GDScript = load("res://scripts/gameplay_v3/pokemon/MovementProfile.gd")
	_conf("as regras carregam",
		Hab != null and Trav != null and Loc != null and Ter != null)

	_inclinacao(Hab, Loc, Perfil)
	_agua(Hab, Trav, Perfil)
	_seco(Hab, Perfil)
	_no_terreno_de_verdade(Hab, Loc, Ter, Perfil)
	_motivos(Hab)

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)

# ──────────────────────────────────────────────────────────────────────────────

func _inclinacao(Hab: GDScript, Loc: GDScript, Perfil: GDScript) -> void:
	print("\n-- A encosta --")

	var limite : float = rad_to_deg(Loc.ANGULO_MAXIMO_DE_SUBIDA)
	print("   limite de chão deste jogo: ", "%.0f" % limite, "°")
	_conf("o limite vem do Locomocao3D, não de um número local",
		absf(limite - 46.0) < 0.5, ("%.2f" % limite) + "°")

	_conf("terreno plano serve pra quem anda",
		not Hab.ingreme_demais(Perfil.GROUND_BIPED, 0.0, limite))
	_conf("encosta suave serve",
		not Hab.ingreme_demais(Perfil.GROUND_BIPED, limite - 5.0, limite))
	_conf("parede barra quem anda",
		Hab.ingreme_demais(Perfil.GROUND_BIPED, limite + 5.0, limite))
	# A borda exata. `>=` trocado por `>` deixaria passar o caso limite, que é
	# justamente onde o corpo fica indeciso entre ficar em pé e escorregar.
	_conf("exatamente no limite já barra",
		Hab.ingreme_demais(Perfil.GROUND_BIPED, limite, limite))

	# Quem voa não é perguntado — o mesmo princípio da Fase 16 (capacidade antes
	# de permissão). Um Pidgeot não escorrega numa parede que nunca encostou.
	_conf("quem voa ignora a encosta",
		not Hab.ingreme_demais(Perfil.FLYING, 80.0, limite))
	# 🔴 ACHADO, e ele não é desta regra: `HOVERING` **não está em
	# `IMPLEMENTADOS`**, então `MovementProfile.obter` devolve o perfil de
	# `ground_biped` (com aviso) e `voa` vira `false`. Ou seja, hoje quem paira
	# é tratado como quem anda — inclusive aqui.
	#
	# O teste afirma **o que é verdade**, não o que eu gostaria: quando o
	# arquétipo for implementado, ele passa a ignorar a encosta de graça, e esta
	# linha é que vai reprovar — avisando que o comportamento mudou.
	_conf("quem paira ainda NÃO voa (hovering não implementado)",
		Hab.ingreme_demais(Perfil.HOVERING, 80.0, limite),
		"hovering passou a voar — a §15 foi implementada, reveja esta linha")
	# E o pesado NÃO ganha exceção: peso não é permissão pra ficar em pé numa
	# parede, e dar exceção aqui seria regra escrita por conveniência.
	_conf("o pesado não ganha exceção",
		Hab.ingreme_demais(Perfil.GROUND_HEAVY, limite + 1.0, limite))

func _agua(Hab: GDScript, Trav: GDScript, Perfil: GDScript) -> void:
	print("\n-- A água: delegada, nunca recopiada --")

	# A prova de que não há segunda cópia: para TODA combinação de arquétipo e
	# superfície molhada, a máscara tem de dar exatamente a mesma resposta que a
	# regra de travessia. Se alguém reimplementar a água aqui, isto diverge.
	var molhadas : Array = [Trav.AGUA_RASA, Trav.AGUA_PROFUNDA]
	var divergencias : int = 0
	for arq in Perfil.IMPLEMENTADOS:
		for sup in molhadas:
			if Hab.superficie_serve(arq, sup) != Trav.pode_estar_em(arq, sup):
				divergencias += 1
	_conf("a máscara concorda com a travessia em toda superfície molhada",
		divergencias == 0, str(divergencias) + " divergências")

	_conf("terrestre não nasce em água profunda",
		not Hab.superficie_serve(Perfil.GROUND_BIPED, Trav.AGUA_PROFUNDA))
	# Água rasa é praia. Barrar ali criaria parede invisível exatamente onde o
	# jogador mais anda — é a decisão da Fase 14, e ela continua valendo.
	_conf("terrestre NASCE em água rasa",
		Hab.superficie_serve(Perfil.GROUND_BIPED, Trav.AGUA_RASA))
	_conf("quem nada nasce em água profunda",
		Hab.superficie_serve(Perfil.AQUATIC, Trav.AGUA_PROFUNDA))
	_conf("quem voa nasce sobre água profunda",
		Hab.superficie_serve(Perfil.FLYING, Trav.AGUA_PROFUNDA))

func _seco(Hab: GDScript, Perfil: GDScript) -> void:
	print("\n-- A terra seca --")

	_conf("o aquático NÃO nasce em terra",
		not Hab.superficie_serve(Perfil.AQUATIC, "terra"))
	# O anfíbio existe exatamente pra isto. Barrá-lo aqui apagaria o arquétipo.
	_conf("o anfíbio nasce em terra",
		Hab.superficie_serve(Perfil.AMPHIBIOUS, "terra"))
	_conf("o terrestre nasce em terra",
		Hab.superficie_serve(Perfil.GROUND_BIPED, "terra"))
	_conf("só o aquático conta como 'só vive na água'",
		Hab.so_vive_na_agua(Perfil.AQUATIC)
			and not Hab.so_vive_na_agua(Perfil.AMPHIBIOUS)
			and not Hab.so_vive_na_agua(Perfil.FLYING))

	# ⚠️ A trava que impede a regra de vazar: nascer não é andar. A máscara é
	# uma regra de SPAWN; se ela tivesse mudado `pode_estar_em`, um aquático
	# vivo perderia o direito de sair da água e a Fase 14 mudaria por tabela.
	var Trav : GDScript = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")
	_conf("o aquático VIVO continua podendo estar em terra",
		Trav.pode_estar_em(Perfil.AQUATIC, "terra"),
		"a máscara de spawn vazou pra regra de movimento")

func _no_terreno_de_verdade(Hab: GDScript, Loc: GDScript, Ter: GDScript,
		Perfil: GDScript) -> void:
	print("\n-- No terreno de verdade: quanto o mundo recusa --")

	var limite : float = rad_to_deg(Loc.ANGULO_MAXIMO_DE_SUBIDA)
	var recusados : int = 0
	var por_ingreme : int = 0
	var por_agua : int = 0
	var total : int = 0
	var x : float = -70.0
	while x <= 70.0:
		var z : float = -70.0
		while z <= 70.0:
			var v : Dictionary = Hab.pode_nascer(Perfil.GROUND_BIPED,
				Ter.superficie_em(x, z),
				rad_to_deg(Ter.inclinacao_em(x, z)), limite)
			if not bool(v["pode"]):
				recusados += 1
				if str(v["motivo"]) == Hab.INGREME:
					por_ingreme += 1
				else:
					por_agua += 1
			total += 1
			z += 1.7
		x += 1.7

	var fracao : float = float(recusados) / float(total)
	print("   ", total, " pontos · recusados ", recusados,
		"  (", "%.1f" % (fracao * 100.0), "%)  ·  encosta ", por_ingreme,
		" · água ", por_agua)

	# O mundo recusa ALGUMA coisa — se recusasse zero, a máscara seria enfeite.
	_conf("a máscara recusa pontos de verdade no terreno", recusados > 0)
	_conf("a encosta aparece entre os motivos", por_ingreme > 0,
		"nenhuma recusa por encosta — a medição da RFC-006 não se reproduz")
	# E recusa MINORIA. Se o laboratório virasse majoritariamente inabitável, a
	# regra estaria errada, não o mundo — e o jogador veria o mundo vazio.
	_conf("mas recusa a minoria do mapa", fracao < 0.5,
		("%.1f" % (fracao * 100.0)) + "% recusado")

	# Quem voa passa em todo lugar: a prova de que o arquétipo realmente muda a
	# resposta, e não é um parâmetro decorativo.
	var recusados_voador : int = 0
	var xx : float = -70.0
	while xx <= 70.0:
		var zz : float = -70.0
		while zz <= 70.0:
			if not bool(Hab.pode_nascer(Perfil.FLYING, Ter.superficie_em(xx, zz),
					rad_to_deg(Ter.inclinacao_em(xx, zz)), limite)["pode"]):
				recusados_voador += 1
			zz += 1.7
		xx += 1.7
	_conf("o voador nasce em qualquer lugar do laboratório",
		recusados_voador == 0, str(recusados_voador) + " recusas pro voador")

	# O laço de tentativas: com a fração medida de recusa, a chance de todas as
	# tentativas falharem tem de ser desprezível. Senão o spawner desiste demais
	# e o mundo esvazia sem ninguém entender por quê.
	var chance_de_falhar_tudo : float = pow(fracao, float(Hab.TENTATIVAS))
	print("   chance das ", Hab.TENTATIVAS, " tentativas falharem juntas: ",
		"%.8f" % chance_de_falhar_tudo)
	_conf("o laço de tentativas cobre a taxa de recusa medida",
		chance_de_falhar_tudo < 0.001,
		("%.6f" % chance_de_falhar_tudo) + " — o spawner desistiria demais")

func _motivos(Hab: GDScript) -> void:
	print("\n-- O motivo vem junto --")

	var Perfil : GDScript = load("res://scripts/gameplay_v3/pokemon/MovementProfile.gd")
	var Trav : GDScript = load("res://scripts/gameplay_v3/mundo/RegraDeTravessia.gd")

	_conf("recusa por encosta diz por quê",
		Hab.pode_nascer(Perfil.GROUND_BIPED, "terra", 80.0, 46.0)["motivo"]
			== Hab.INGREME)
	_conf("recusa por água diz por quê",
		Hab.pode_nascer(Perfil.GROUND_BIPED, Trav.AGUA_PROFUNDA, 0.0, 46.0)["motivo"]
			== Hab.FUNDO_DEMAIS)
	_conf("recusa por terra seca diz por quê",
		Hab.pode_nascer(Perfil.AQUATIC, "terra", 0.0, 46.0)["motivo"]
			== Hab.SECO_DEMAIS)
	_conf("quando pode, o motivo é vazio",
		Hab.pode_nascer(Perfil.GROUND_BIPED, "terra", 0.0, 46.0)["motivo"] == Hab.OK)
	_conf("todo motivo tem explicação em português",
		Hab.explicar(Hab.INGREME).length() > 10
			and Hab.explicar(Hab.FUNDO_DEMAIS).length() > 10
			and Hab.explicar(Hab.SECO_DEMAIS).length() > 10)
