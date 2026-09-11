## teste_reengenharia_combate.gd — 11/09/2026.
##
## Trava a reengenharia do combate que o Gabriel pediu. O item 45 dele lista 17
## coisas pra testar; cada seção abaixo é uma delas, na mesma ordem.
##
## Uma decisão sobre COMO testar, porque ela explica o formato do arquivo: a
## fórmula nova tem variação de ±10% e crítico de 5%, então "dano == 37" seria
## um teste que passa hoje e falha amanhã sem nada ter mudado. Em vez disso,
## cada regra é medida por AMOSTRA (algumas centenas de golpes) e o que se
## cobra é a RELAÇÃO — "com STAB sai 25% mais que sem", "super efetivo sai o
## dobro do normal". Relação não depende de sorte.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_reengenharia_combate.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const AMOSTRA : int = 400

## Autoload NÃO é identificador num teste `--script`. O jeito que funciona
## neste projeto (lição registrada em progresso.md) é declarar uma variável de
## membro com o MESMO nome e preencher via `root.get_node()`.
var GameData : Node

func _initialize() -> void:
	print("=== Teste: reengenharia do combate (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")

	_1_dano_fisico()
	_2_dano_especial()
	_3_stab()
	_4_5_6_tipos()
	_7_critico()
	_8_nature()
	_9_cooldown()
	_10_11_area()
	_12_morte_e_teto()
	_13_barra_de_vida()
	_14_15_16_aggro_coleira_bando()
	_17_status()
	_regras_da_regua()
	_desempenho()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# Ferramenta: dano médio de uma configuração
# ──────────────────────────────────────────────────────────────────────────

func _medio(golpe: Dictionary, atacante: Dictionary, defensor: Dictionary) -> float:
	var soma : float = 0.0
	for i in AMOSTRA:
		soma += float(DamageCalculator.calculate_damage(golpe, atacante, defensor))
	return soma / float(AMOSTRA)

## Um atacante/defensor "de laboratório": stats redondos, sem item, sem
## habilidade, sem status — pra que o que muda entre dois testes seja só a
## coisa que o teste quer medir.
func _atacante(atk: int = 100, spa: int = 100, nivel: int = 30, tipos: Array = []) -> Dictionary:
	return {"atk": atk, "spa": spa, "level": nivel, "types": tipos}

## 🔴 `vida = 0` de propósito: tanto o TETO (90% da vida máxima) quanto o PISO
## (2% da vida máxima) só valem quando o defensor declara vida. Zerando, este
## defensor mede a FÓRMULA CRUA, sem as duas redes de segurança no meio.
## (Descoberto quebrando este teste: com vida de 100.000 o piso de 2% virava
## 2.000 de dano e engolia tudo que o teste queria medir.)
func _defensor(dfn: int = 100, spd: int = 100, tipos: Array = ["Normal"], vida: int = 0) -> Dictionary:
	return {"def": dfn, "spd": spd, "types": tipos, "max_hp": vida, "hp": vida, "level": 30}

func _golpe(power: int, tipo: String = "Normal", categoria: String = "physical") -> Dictionary:
	return {"power": power, "type": tipo, "category": categoria, "name": "Teste"}

# ──────────────────────────────────────────────────────────────────────────
# 1. Dano físico — usa ATK contra DEF
# ──────────────────────────────────────────────────────────────────────────
func _1_dano_fisico() -> void:
	var base := _medio(_golpe(60), _atacante(100, 10), _defensor(100, 10))
	var forte := _medio(_golpe(60), _atacante(200, 10), _defensor(100, 10))
	var duro := _medio(_golpe(60), _atacante(100, 10), _defensor(200, 10))

	_assert(base > 0.0, "golpe físico causa dano (%.1f em média)" % base)
	_assert(forte > base * 1.8, "o DOBRO de ataque quase dobra o dano (%.1f -> %.1f)" % [base, forte])
	_assert(duro < base * 0.6, "o DOBRO de defesa corta o dano quase pela metade (%.1f -> %.1f)" % [base, duro])

	# A stat ESPECIAL não pode interferir num golpe físico — era o contrário
	# que acontecia antes (só existia uma stat ofensiva pra tudo).
	var com_spa_absurdo := _medio(_golpe(60), _atacante(100, 9999), _defensor(100, 10))
	_assert(absf(com_spa_absurdo - base) < base * 0.1,
		"sp_atk gigante NÃO muda um golpe físico (%.1f vs %.1f)" % [base, com_spa_absurdo])

	# Defesa altíssima nunca zera o dano (regra explícita do item 10).
	var contra_muralha := _medio(_golpe(60), _atacante(50, 10), _defensor(9999, 10))
	_assert(contra_muralha >= 1.0, "defesa altíssima reduz, mas nunca zera o dano (%.2f)" % contra_muralha)

	# 🔴 Fase 2: o piso proporcional de 2% foi REMOVIDO (ver CombatBalance).
	# A regra é a mais simples possível: imunidade dá 0, qualquer outro golpe
	# que acerta dá pelo menos 1. Nunca 0 por defesa alta.
	var tanque := {"def": 99999, "spd": 99999, "types": ["Rock"],
		"max_hp": 500, "hp": 500, "level": 30}
	var no_tanque : int = DamageCalculator.calculate_damage(_golpe(20), _atacante(10, 10, 5), tanque)
	_assert(no_tanque == 1,
		"a maior defesa possível reduz o golpe a 1 — nunca a 0 (%d)" % no_tanque)
	var imune_mesmo : int = DamageCalculator.calculate_damage(
		_golpe(200, "Electric", "special"), _atacante(999, 999, 100),
		{"def": 1, "spd": 1, "types": ["Ground"], "max_hp": 500, "hp": 500})
	_assert(imune_mesmo == 0, "imunidade continua sendo 0 de verdade (%d)" % imune_mesmo)

	# O nível participa da conta — era exatamente isto que faltava.
	var lv10 := _medio(_golpe(60), _atacante(100, 10, 10), _defensor(100, 10))
	var lv50 := _medio(_golpe(60), _atacante(100, 10, 50), _defensor(100, 10))
	_assert(lv50 > lv10 * 2.0,
		"o mesmo golpe no Lv.50 bate MUITO mais que no Lv.10 (%.1f -> %.1f)" % [lv10, lv50])

# ──────────────────────────────────────────────────────────────────────────
# 2. Dano especial — usa SP_ATK contra SP_DEF
# ──────────────────────────────────────────────────────────────────────────
func _2_dano_especial() -> void:
	var base := _medio(_golpe(60, "Normal", "special"), _atacante(10, 100), _defensor(10, 100))
	var forte := _medio(_golpe(60, "Normal", "special"), _atacante(10, 200), _defensor(10, 100))
	_assert(forte > base * 1.8, "sp_atk dobrado quase dobra o dano especial (%.1f -> %.1f)" % [base, forte])

	var com_atk_absurdo := _medio(_golpe(60, "Normal", "special"), _atacante(9999, 100), _defensor(10, 100))
	_assert(absf(com_atk_absurdo - base) < base * 0.1,
		"ataque físico gigante NÃO muda um golpe especial (%.1f vs %.1f)" % [base, com_atk_absurdo])

	var contra_spd_alta := _medio(_golpe(60, "Normal", "special"), _atacante(10, 100), _defensor(10, 200))
	_assert(contra_spd_alta < base * 0.6,
		"sp_def dobrada corta o dano especial (%.1f -> %.1f)" % [base, contra_spd_alta])

	# 🔴 O caso concreto da auditoria: Alakazam tem attack 50 e sp_atk 135, e
	# atacava com 50. Este teste existe pra isso não voltar.
	var alakazam : Dictionary = GameData.get_species(65).get("base_stats", {})
	_assert(int(alakazam.get("sp_atk", 0)) > int(alakazam.get("attack", 0)) * 2,
		"Alakazam continua sendo um atacante especial nos dados (sp_atk %d, attack %d)"
			% [int(alakazam.get("sp_atk", 0)), int(alakazam.get("attack", 0))])
	var stats_al : Dictionary = StatsDePokemon.conjunto(alakazam, 50)
	var como_especial := _medio(_golpe(90, "Psychic", "special"),
		{"atk": stats_al["atk"], "spa": stats_al["spa"], "level": 50, "types": ["Psychic"]},
		_defensor(80, 80))
	var como_fisico := _medio(_golpe(90, "Psychic", "physical"),
		{"atk": stats_al["atk"], "spa": stats_al["spa"], "level": 50, "types": ["Psychic"]},
		_defensor(80, 80))
	_assert(como_especial > como_fisico * 2.0,
		"Alakazam bate MUITO mais forte com golpe especial do que com físico (%.0f vs %.0f)"
			% [como_especial, como_fisico])

# ──────────────────────────────────────────────────────────────────────────
# 3. STAB
# ──────────────────────────────────────────────────────────────────────────
func _3_stab() -> void:
	var sem := _medio(_golpe(60, "Fire"), _atacante(100, 10, 30, ["Water"]), _defensor())
	var com := _medio(_golpe(60, "Fire"), _atacante(100, 10, 30, ["Fire"]), _defensor())
	var razao : float = com / maxf(sem, 0.001)
	_assert(absf(razao - CombatBalance.STAB_MULTIPLIER) < 0.08,
		"golpe do mesmo tipo do Pokémon dá +25%% (medido x%.2f)" % razao)

	var segundo_tipo := _medio(_golpe(60, "Fire"), _atacante(100, 10, 30, ["Flying", "Fire"]), _defensor())
	_assert(segundo_tipo > sem * 1.15, "STAB vale também pro SEGUNDO tipo da espécie")

	_assert(is_equal_approx(DamageCalculator.stab_multiplier("Fire", []), 1.0),
		"sem lista de tipos não há STAB (quem chamar sem informar não ganha bônus de graça)")

# ──────────────────────────────────────────────────────────────────────────
# 4, 5, 6. Resistência, fraqueza e imunidade
# ──────────────────────────────────────────────────────────────────────────
func _4_5_6_tipos() -> void:
	var normal := _medio(_golpe(60, "Water"), _atacante(), _defensor(100, 100, ["Normal"]))
	var super_ef := _medio(_golpe(60, "Water"), _atacante(), _defensor(100, 100, ["Fire"]))
	var resiste := _medio(_golpe(60, "Water"), _atacante(), _defensor(100, 100, ["Grass"]))

	_assert(absf(super_ef / normal - 2.0) < 0.15, "super efetivo dá o dobro (x%.2f)" % (super_ef / normal))
	_assert(absf(resiste / normal - 0.5) < 0.08, "pouco efetivo dá metade (x%.2f)" % (resiste / normal))

	# Fraqueza dupla: Água contra Terra/Pedra é x4.
	var quadruplo := _medio(_golpe(60, "Water"), _atacante(), _defensor(100, 100, ["Ground", "Rock"]))
	_assert(absf(quadruplo / normal - 4.0) < 0.4, "fraqueza dupla dá x4 (x%.2f)" % (quadruplo / normal))

	# Resistência dupla: Grama contra Fogo/Voador é x0.25.
	var um_quarto := _medio(_golpe(60, "Grass"), _atacante(), _defensor(100, 100, ["Fire", "Flying"]))
	_assert(absf(um_quarto / normal - 0.25) < 0.05, "resistência dupla dá x0.25 (x%.2f)" % (um_quarto / normal))

	# Imunidade é ZERO de verdade, não "1 de dano".
	var imune := DamageCalculator.calculate_damage(
		_golpe(200, "Electric", "special"), _atacante(999, 999, 100), _defensor(1, 1, ["Ground"]))
	_assert(imune == 0, "imunidade de tipo dá 0, não 1 (Elétrico em Terra: %d)" % imune)
	var fantasma := DamageCalculator.calculate_damage(
		_golpe(200), _atacante(999, 999, 100), _defensor(1, 1, ["Ghost"]))
	_assert(fantasma == 0, "Normal não acerta Fantasma (%d)" % fantasma)

# ──────────────────────────────────────────────────────────────────────────
# 7. Crítico
# ──────────────────────────────────────────────────────────────────────────
func _7_critico() -> void:
	var criticos : int = 0
	var n : int = 6000
	for i in n:
		if DamageCalculator.is_critical():
			criticos += 1
	var taxa : float = float(criticos) / float(n)
	_assert(absf(taxa - CombatBalance.CRIT_CHANCE) < 0.015,
		"crítico sai em ~5%% das vezes (medido %.1f%% em %d golpes)" % [taxa * 100.0, n])
	_assert(is_equal_approx(CombatBalance.CRIT_MULTIPLIER, 1.5), "crítico multiplica por 1.5")

	# O crítico aparece no relatório de depuração — é assim que dá pra
	# explicar um golpe que saiu fora da curva.
	var achou_critico := false
	for i in 200:
		var d := DamageCalculator.detalhar(_golpe(60), _atacante(), _defensor())
		if bool(d.get("critico", false)):
			achou_critico = true
			_assert(is_equal_approx(float(d["mult_critico"]), 1.5),
				"quando é crítico o relatório mostra x1.5")
			break
	_assert(achou_critico, "em 200 golpes pelo menos um foi crítico (senão a chance está zerada)")

# ──────────────────────────────────────────────────────────────────────────
# 8. Nature
# ──────────────────────────────────────────────────────────────────────────
func _8_nature() -> void:
	var base : int = StatsDePokemon.stat(100, 50, "atk", "hardy")
	var sobe : int = StatsDePokemon.stat(100, 50, "atk", "adamant")   # +atk
	var desce : int = StatsDePokemon.stat(100, 50, "atk", "modest")   # -atk
	_assert(sobe > base and desce < base,
		"nature muda a stat pros dois lados (neutra %d, +atk %d, -atk %d)" % [base, sobe, desce])
	_assert(absf(float(sobe) / float(base) - 1.10) < 0.02, "nature positiva dá +10%%")
	_assert(absf(float(desce) / float(base) - 0.90) < 0.02, "nature negativa dá -10%%")

	_assert(StatsDePokemon.NATURES.size() == 25, "as 25 natures estão cadastradas")
	var neutras : int = 0
	for n in StatsDePokemon.NATURES:
		var e : Dictionary = StatsDePokemon.NATURES[n]
		if e["boost"] == e["cut"]:
			neutras += 1
	_assert(neutras == 5, "exatamente 5 natures são neutras (%d)" % neutras)

	# HP nunca é afetado por nature — regra da série, e o que impede uma
	# nature de virar +10%% de vida de graça.
	var hp_a : int = StatsDePokemon.hp_maximo(100, 50)
	_assert(is_equal_approx(StatsDePokemon.multiplicador_de_nature("adamant", "hp"), 1.0),
		"nature não mexe no HP")
	_assert(hp_a == StatsDePokemon.hp_maximo(100, 50), "o HP é sempre o mesmo pro mesmo nível/base")

	# A tabela que GameData expunha continua respondendo igual (nada que já
	# chamava por lá quebrou ao mover a tabela).
	_assert(GameData.NATURES.size() == 25, "GameData continua expondo as 25 natures")

# ──────────────────────────────────────────────────────────────────────────
# 9. Cooldown
# ──────────────────────────────────────────────────────────────────────────
func _9_cooldown() -> void:
	var lento : float = CombatBalance.recarga(4.0, 0)
	var rapido : float = CombatBalance.recarga(4.0, 300)
	_assert(rapido < lento, "mais velocidade = recarga menor (%.2fs -> %.2fs)" % [lento, rapido])
	_assert(rapido >= lento * (1.0 - CombatBalance.MAX_COOLDOWN_REDUCTION) - 0.01,
		"a velocidade encurta no máximo 40%% — sem teto, um Pokémon rápido atacaria sem parar")

	var absurdo : float = CombatBalance.recarga(4.0, 999999, 0.9)
	_assert(absurdo >= CombatBalance.MIN_COOLDOWN_SEC,
		"existe um piso absoluto de recarga (%.2fs)" % absurdo)
	_assert(CombatBalance.recarga(1.0, 0) <= 1.0, "sem velocidade nenhuma, a recarga é a do golpe")

	# Todo golpe dos dados tem recarga declarada e dentro da faixa do item 18.
	var sem_cd : Array[String] = []
	var fora : Array[String] = []
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		var cd : float = float(m.get("cooldown", -1.0))
		if cd <= 0.0:
			sem_cd.append(mid)
		elif cd > 20.0:
			fora.append(mid)
	_assert(sem_cd.is_empty(), "todo golpe tem recarga própria (%d sem)" % sem_cd.size())
	_assert(fora.is_empty(), "nenhuma recarga passa de 20s (%s)" % str(fora))

# ──────────────────────────────────────────────────────────────────────────
# 10 e 11. Área e múltiplos alvos
# ──────────────────────────────────────────────────────────────────────────
func _10_11_area() -> void:
	var R : float = 400.0
	var o := Vector2.ZERO
	var dir := Vector2.RIGHT

	# Círculo pega dos dois lados; cone e linha, só pra frente.
	_assert(FormaDeArea._esta_dentro("circle", o, dir, Vector2(-300, 0), R, 256.0),
		"círculo pega quem está ATRÁS do atacante")
	_assert(not FormaDeArea._esta_dentro("cone", o, dir, Vector2(-300, 0), R, 256.0),
		"cone NÃO pega quem está atrás")
	_assert(FormaDeArea._esta_dentro("cone", o, dir, Vector2(300, 0), R, 256.0),
		"cone pega quem está bem na frente")
	_assert(not FormaDeArea._esta_dentro("cone", o, dir, Vector2(100, 350), R, 256.0),
		"cone NÃO pega quem está muito pro lado")
	_assert(FormaDeArea._esta_dentro("line", o, dir, Vector2(350, 60), R, 256.0),
		"linha pega quem está à frente e perto do eixo")
	_assert(not FormaDeArea._esta_dentro("line", o, dir, Vector2(350, 300), R, 256.0),
		"linha NÃO pega quem está longe do eixo")
	_assert(not FormaDeArea._esta_dentro("line", o, dir, Vector2(-350, 0), R, 256.0),
		"linha NÃO pega pra trás")
	_assert(not FormaDeArea._esta_dentro("ring", o, dir, Vector2(50, 0), R, 256.0),
		"anel deixa livre quem está colado no centro")
	_assert(FormaDeArea._esta_dentro("ring", o, dir, Vector2(350, 0), R, 256.0),
		"anel pega quem está na borda")
	_assert(not FormaDeArea._esta_dentro("circle", o, dir, Vector2(500, 0), R, 256.0),
		"nada além do raio entra")

	# Com nós de verdade na árvore: contagem, teto e não-repetição.
	var pais := Node2D.new()
	root.add_child(pais)
	var criados : Array[Node2D] = []
	for i in 12:
		var n := Node2D.new()
		n.global_position = Vector2(30.0 * (i + 1), 0)
		n.add_to_group("alvo_de_teste")
		pais.add_child(n)
		criados.append(n)

	var golpe_area := {"area_type": "circle", "radius": 1000.0, "max_targets": 5}
	var pegos : Array = FormaDeArea.alvos(Vector2.ZERO, dir, golpe_area, "alvo_de_teste")
	_assert(pegos.size() == 5, "o teto de alvos é respeitado (%d de 12 no raio)" % pegos.size())

	var repetidos := false
	var vistos : Array = []
	for a in pegos:
		if a in vistos:
			repetidos = true
		vistos.append(a)
	_assert(not repetidos, "nenhum alvo aparece duas vezes no mesmo golpe (sem dano duplicado)")

	_assert(pegos[0] == criados[0], "os alvos vêm ordenados do mais perto pro mais longe")

	var so_um : Array = FormaDeArea.alvos(Vector2.ZERO, dir,
		{"area_type": "single", "radius": 1000.0}, "alvo_de_teste")
	_assert(so_um.size() == 1, "golpe de alvo único pega um só, mesmo com 12 no raio")

	var excluindo : Array = FormaDeArea.alvos(Vector2.ZERO, dir, golpe_area,
		"alvo_de_teste", [criados[0]])
	_assert(not (criados[0] in excluindo), "quem está na lista de exclusão nunca é acertado")

	pais.queue_free()

	# Os 6 golpes de referência do item 21 estão configurados nos dados.
	var referencia := {
		"earthquake": "circle", "blizzard": "circle", "petal_dance": "circle",
		"surf": "line", "gust": "cone", "confusion": "single",
	}
	for mid in referencia:
		var m : Dictionary = GameData.get_move(mid)
		_assert(not m.is_empty(), "o golpe '%s' existe nos dados" % mid)
		if m.is_empty():
			continue
		_assert(str(m.get("area_type", "")) == referencia[mid],
			"%s tem forma '%s'" % [str(m.get("name", mid)), referencia[mid]])
		if referencia[mid] != "single":
			_assert(int(m.get("max_targets", 0)) > 1,
				"%s acerta mais de um alvo (teto %d)" % [str(m.get("name", mid)), int(m.get("max_targets", 0))])
			_assert(float(m.get("radius", 0.0)) > 0.0, "%s tem raio de verdade" % str(m.get("name", mid)))

	# Todo golpe tem alcance e tempo de conjuração declarados.
	var sem_alcance : int = 0
	var sem_cast : int = 0
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		if not m.has("range"):
			sem_alcance += 1
		if not m.has("cast_time"):
			sem_cast += 1
	_assert(sem_alcance == 0, "todo golpe declara alcance (%d sem)" % sem_alcance)
	_assert(sem_cast == 0, "todo golpe declara tempo de conjuração (%d sem)" % sem_cast)

# ──────────────────────────────────────────────────────────────────────────
# 12. Morte, e o teto que impede o hit-kill
# ──────────────────────────────────────────────────────────────────────────
func _12_morte_e_teto() -> void:
	# O pior caso possível: Lv.100 com ultimate crítica contra um Lv.10 frágil.
	var vitima := {"def": 30, "spd": 30, "types": ["Normal"], "max_hp": 100, "hp": 100, "level": 10}
	var pior : int = 0
	for i in AMOSTRA:
		pior = maxi(pior, DamageCalculator.calculate_damage(
			_golpe(160), _atacante(400, 400, 100, ["Normal"]), vitima))
	_assert(pior < 100,
		"nem o pior golpe possível mata de UM um alvo com vida cheia (%d de %d)" % [pior, 100])
	_assert(pior >= int(100 * CombatBalance.TETO_DE_DANO_POR_GOLPE) - 1,
		"...mas chega perto: o teto é 90%% da vida (%d)" % pior)

	# O teto NÃO pode tornar imortal quem já está quase morrendo.
	var quase := {"def": 30, "spd": 30, "types": ["Normal"], "max_hp": 100, "hp": 5, "level": 10}
	var nele : int = DamageCalculator.calculate_damage(
		_golpe(160), _atacante(400, 400, 100, ["Normal"]), quase)
	_assert(nele >= 5, "quem está com 5%% de vida morre normalmente (o teto não vale aí): %d" % nele)

	# E o relatório conta quando o teto agiu — senão viraria mágica invisível.
	var d := DamageCalculator.detalhar(_golpe(160), _atacante(400, 400, 100, ["Normal"]), vitima)
	_assert(int(d.get("segurado_pelo_teto", 0)) > int(d.get("final", 0)),
		"o relatório mostra quanto o golpe teria dado sem o teto (%d -> %d)"
			% [int(d.get("segurado_pelo_teto", 0)), int(d.get("final", 0))])

	# Alpha: recalibrado. O que era 929 de dano num alvo de 98 de vida.
	_assert(CombatBalance.ALPHA_ATK_MULT < 2.0,
		"o Alpha não multiplica mais o ataque por 3 (x%.2f)" % CombatBalance.ALPHA_ATK_MULT)
	_assert(CombatBalance.ALPHA_HP_MULT > CombatBalance.ALPHA_ATK_MULT,
		"o Alpha é uma PAREDE (muito HP), não um apagador de tela (muito ataque)")

# ──────────────────────────────────────────────────────────────────────────
# 13. Barra de vida do selvagem
# ──────────────────────────────────────────────────────────────────────────
func _13_barra_de_vida() -> void:
	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains("float(current_hp) / float(max_hp)"),
		"a barra é calculada do HP REAL, não de um número visual separado")
	_assert(fonte.contains("func _update_health_bar"), "existe a função que atualiza a barra")
	_assert(fonte.contains("_update_health_bar()") and fonte.contains("func take_damage"),
		"levar dano atualiza a barra")
	_assert(fonte.contains("_texto_do_rotulo"),
		"o rótulo acima do bicho é montado por uma função só (nome, nível e vida juntos)")
	_assert(fonte.contains("Nv.%d") and fonte.contains("_nome_da_especie()"),
		"o rótulo mostra NOME e NÍVEL do bicho")
	_assert(fonte.contains("%d/%d"), "o rótulo mostra vida atual / vida máxima")

# ──────────────────────────────────────────────────────────────────────────
# 14, 15, 16. Aggro, coleira e bando
# ──────────────────────────────────────────────────────────────────────────
func _14_15_16_aggro_coleira_bando() -> void:
	_assert(ComportamentoSelvagem.TODAS.size() == 7,
		"as 7 personalidades existem (%d)" % ComportamentoSelvagem.TODAS.size())

	# Os rótulos antigos do species.json continuam sendo entendidos.
	for antigo in ["aggressive", "neutral", "flee"]:
		_assert(ComportamentoSelvagem.normalizar(antigo) in ComportamentoSelvagem.TODAS,
			"o rótulo antigo '%s' é traduzido pra uma personalidade nova" % antigo)
	_assert(ComportamentoSelvagem.normalizar("disparate_qualquer") == ComportamentoSelvagem.DEFENSIVO,
		"rótulo desconhecido cai no mais inofensivo, nunca num que persegue")

	# Aggro: quem começa briga e quem não começa.
	_assert(not ComportamentoSelvagem.comeca_briga(ComportamentoSelvagem.PASSIVO),
		"passivo NÃO ataca sem motivo")
	_assert(ComportamentoSelvagem.comeca_briga(ComportamentoSelvagem.AGRESSIVO),
		"agressivo ataca sozinho")
	_assert(ComportamentoSelvagem.raio_de_aggro(ComportamentoSelvagem.PASSIVO) == 0.0,
		"passivo não tem raio de perseguição")
	_assert(ComportamentoSelvagem.raio_de_aggro(ComportamentoSelvagem.PREDADOR)
		> ComportamentoSelvagem.raio_de_aggro(ComportamentoSelvagem.AGRESSIVO),
		"o predador percebe de mais longe que o agressivo comum")
	_assert(ComportamentoSelvagem.raio_de_aggro(ComportamentoSelvagem.DEFENSIVO)
		< ComportamentoSelvagem.raio_de_aggro(ComportamentoSelvagem.AGRESSIVO),
		"o defensivo só reage quando você chega perto")

	# Coleira: ninguém persegue pra sempre.
	for p in ComportamentoSelvagem.TODAS:
		var r : float = ComportamentoSelvagem.raio_de_coleira(p)
		_assert(r > 0.0 and r < INF, "'%s' tem coleira finita (%.0f px)" % [p, r])
	_assert(ComportamentoSelvagem.raio_de_coleira(ComportamentoSelvagem.TERRITORIAL)
		< ComportamentoSelvagem.raio_de_coleira(ComportamentoSelvagem.PREDADOR),
		"o territorial solta o alvo muito antes do predador")

	# Fuga por vida baixa.
	_assert(not ComportamentoSelvagem.deve_fugir(ComportamentoSelvagem.AGRESSIVO, 1.0),
		"com vida cheia o agressivo não foge")
	_assert(ComportamentoSelvagem.deve_fugir(ComportamentoSelvagem.AGRESSIVO, 0.1),
		"com vida baixa até o agressivo foge")
	_assert(ComportamentoSelvagem.deve_fugir(ComportamentoSelvagem.FUGITIVO, 1.0),
		"o fugitivo foge mesmo com vida cheia")

	# Bando: mesma espécie, perto, com teto, e sem corrente.
	# Um dublê mínimo: Node2D com `species_id`. Precisa ser Node2D de verdade
	# (a busca mede distância) e precisa TER a propriedade — um Node2D cru
	# devolve null em `get("species_id")`.
	var molde := GDScript.new()
	molde.source_code = "extends Node2D\nvar species_id : int = 0\n"
	molde.reload()

	var pais := Node2D.new()
	root.add_child(pais)
	var lider : Node2D = molde.new()
	lider.species_id = 15
	pais.add_child(lider)
	lider.global_position = Vector2.ZERO

	var turma : Array = []
	for i in 10:
		var n : Node2D = molde.new()
		n.species_id = 15
		pais.add_child(n)
		n.global_position = Vector2(60.0 * (i + 1), 0)
		turma.append(n)
	var estranho : Node2D = molde.new()
	estranho.species_id = 19
	pais.add_child(estranho)
	estranho.global_position = Vector2(60, 0)
	turma.append(estranho)

	var ouviram : Array = ComportamentoSelvagem.quem_ouve_o_grito(lider, turma, 15, 0)
	_assert(ouviram.size() <= CombatBalance.MAX_PACK_SIZE,
		"no máximo %d respondem ao grito (%d responderam)" % [CombatBalance.MAX_PACK_SIZE, ouviram.size()])
	_assert(not (estranho in ouviram), "um bicho de OUTRA espécie não entra no bando")
	for o in ouviram:
		_assert(lider.global_position.distance_to(o.global_position)
			<= CombatBalance.PACK_RADIUS_TILES * CombatBalance.TILE_PX,
			"quem respondeu estava dentro do raio do bando")

	var segunda_onda : Array = ComportamentoSelvagem.quem_ouve_o_grito(lider, turma, 15, 1)
	_assert(segunda_onda.is_empty(),
		"quem foi CHAMADO não chama mais ninguém — é o que impede o mapa inteiro de acordar")

	pais.queue_free()

	# E o WildPokemon usa tudo isso de verdade.
	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains("ComportamentoSelvagem.raio_de_coleira"),
		"o selvagem consulta a coleira ao perseguir (não só ao passear)")
	_assert(fonte.contains("responder_ao_grito"), "o selvagem sabe responder ao grito do bando")
	_assert(fonte.contains("State.RETORNAR") and fonte.contains("State.FUGIR"),
		"existem os estados de voltar pra casa e de fugir")
	_assert(fonte.contains("CombatBalance.COMBAT_TICK_SEC"),
		"a IA pensa no ritmo do combate, não 60 vezes por segundo")

# ──────────────────────────────────────────────────────────────────────────
# 17. Status
# ──────────────────────────────────────────────────────────────────────────
func _17_status() -> void:
	# Queimadura corta o golpe físico pela metade, e não mexe no especial.
	var limpo := _medio(_golpe(60), _atacante(), _defensor())
	var queimado := _medio(_golpe(60), {"atk": 100, "spa": 100, "level": 30, "status": "burn"}, _defensor())
	_assert(absf(queimado / limpo - 0.5) < 0.08,
		"queimadura corta o golpe FÍSICO pela metade (x%.2f)" % (queimado / limpo))

	var esp_limpo := _medio(_golpe(60, "Normal", "special"), _atacante(), _defensor())
	var esp_queimado := _medio(_golpe(60, "Normal", "special"),
		{"atk": 100, "spa": 100, "level": 30, "status": "burn"}, _defensor())
	_assert(absf(esp_queimado / esp_limpo - 1.0) < 0.08,
		"queimadura NÃO mexe no golpe especial (x%.2f)" % (esp_queimado / esp_limpo))

	# O dano ao longo do tempo é por tique controlado, nunca por quadro.
	_assert(CombatBalance.STATUS_TICK_SEC > 0.0,
		"veneno/queimadura dão dano a cada %.1fs, não a cada quadro" % CombatBalance.STATUS_TICK_SEC)
	var dano_veneno : int = StatusEffectController.tick_damage("poison", 200, 0)
	_assert(dano_veneno > 0, "veneno causa dano por tique (%d de 200 de vida)" % dano_veneno)
	_assert(StatusEffectController.is_incapacitated("sleep"),
		"quem está dormindo não age")
	_assert(not StatusEffectController.is_incapacitated("burn"),
		"quem está queimado continua agindo (só bate menos)")

# ──────────────────────────────────────────────────────────────────────────
# As regras da régua central (item 37) e do data-driven (item 49)
# ──────────────────────────────────────────────────────────────────────────
func _regras_da_regua() -> void:
	# Tudo que decide equilíbrio mora num lugar só.
	var mapa : Dictionary = load("res://scripts/combat/CombatBalance.gd").get_script_constant_map()
	for campo in ["BASE_DAMAGE_MULTIPLIER", "HP_SCALE", "LEVEL_SCALE", "CRIT_CHANCE",
			"CRIT_MULTIPLIER", "STAB_MULTIPLIER", "TYPE_SUPER_EFFECTIVE", "TYPE_RESISTANCE",
			"DAMAGE_VARIANCE_MIN", "DAMAGE_VARIANCE_MAX", "AGGRO_RADIUS_TILES",
			"PACK_RADIUS_TILES", "LEASH_RADIUS_TILES", "MAX_PACK_SIZE"]:
		_assert(mapa.has(campo), "a régua central define %s" % campo)

	# Nenhuma fórmula de stat sobrou espalhada: os três antigos chamam o único.
	for arquivo in ["res://scripts/autoloads/SaveManager.gd",
			"res://scripts/battle/BattlePokemon.gd",
			"res://scripts/combat/DamageCalculator.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("StatsDePokemon."),
			"%s usa a fórmula única de stat" % arquivo.get_file())

	# E as três dão o MESMO número pro mesmo Pokémon — era isso que não
	# acontecia (Pikachu Lv20 tinha 47 de vida no menu e 72 na luta).
	var base_pikachu : Dictionary = GameData.get_species(25).get("base_stats", {})
	var pelo_stats : int = StatsDePokemon.hp_maximo(int(base_pikachu.get("hp", 35)), 20, 15)
	var pelo_damage : int = DamageCalculator.calculate_hp(int(base_pikachu.get("hp", 35)), 20, 15)
	_assert(pelo_stats == pelo_damage,
		"menu e combate mostram a MESMA vida (%d = %d)" % [pelo_stats, pelo_damage])

	# Data-driven: nenhum golpe é tratado por nome dentro do código de combate.
	for arquivo in ["res://scripts/entities/WildPokemon.gd",
			"res://scripts/entities/FollowerPokemon.gd",
			"res://scripts/combat/DamageCalculator.gd",
			"res://scripts/combat/FormaDeArea.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		for proibido in ["== \"earthquake\"", "== \"blizzard\"", "== \"surf\"", "== \"petal_dance\""]:
			_assert(not fonte.contains(proibido),
				"%s não trata golpe por nome (%s)" % [arquivo.get_file(), proibido])

	# O depurador de dano existe e sabe explicar.
	var d := DamageCalculator.detalhar(_golpe(90, "Electric", "special"),
		_atacante(50, 145, 32, ["Electric"]), _defensor(60, 98, ["Flying"]))
	var texto := CombateDebug.formatar(d, "Pikachu", "Spearow")
	for pedaco in ["Pikachu", "Spearow", "power", "stat ofensiva", "stat defensiva",
			"STAB", "crítico", "variação", "DANO FINAL"]:
		_assert(texto.contains(pedaco), "o relatório de dano mostra '%s'" % pedaco)
	_assert(texto.contains("super efetivo"), "o relatório diz em português que foi super efetivo")

# ──────────────────────────────────────────────────────────────────────────
# Desempenho (item 40) — os caminhos quentes têm que caber no quadro
# ──────────────────────────────────────────────────────────────────────────
func _desempenho() -> void:
	# Orçamento de um quadro a 60 FPS: 16.666 microssegundos. O combate inteiro
	# precisa caber numa FATIA disso, junto com pintura de mapa, animação e
	# tudo mais. Os tetos abaixo são folgados de propósito (a medição real fica
	# muito abaixo) — o que se quer pegar é REGRESSÃO de ordem de grandeza, não
	# variação de 20% num servidor compartilhado.
	var molde := GDScript.new()
	molde.source_code = "extends Node2D\nvar species_id : int = 1\n"
	molde.reload()
	var pais := Node2D.new()
	root.add_child(pais)
	for i in 60:   # o teto de selvagens vivos ao mesmo tempo (SpawnManager)
		var n : Node2D = molde.new()
		n.add_to_group("perf_alvo_teste")
		pais.add_child(n)
		n.global_position = Vector2(float(i) * 71.0 - 2000.0, float(i) * 37.0 - 1000.0)

	var golpe := {"area_type": "circle", "radius": 640.0, "max_targets": 6}
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, golpe, "perf_alvo_teste")
	var us_area : float = float(Time.get_ticks_usec() - t0) / 1000.0
	# 🔴 O teto era 50 us, escolhido a partir de uma medição minha que estava
	# ERRADA: eu tinha medido com os 60 bichos espalhados aleatoriamente num
	# quadrado gigante, então quase nenhum caía dentro do raio e a busca não
	# fazia trabalho nenhum (2 us). Com os bichos de fato ao redor, o custo real
	# é ~71 us — 0,4% de um quadro a 60 FPS, pra um evento que acontece algumas
	# vezes por segundo. O teto abaixo é o triplo disso: pega regressão de ordem
	# de grandeza sem falhar por variação de servidor compartilhado.
	_assert(us_area < 200.0,
		"buscar alvos de área entre 60 bichos custa %.1f us (teto 200; ~0,4%% de um quadro)" % us_area)

	t0 = Time.get_ticks_usec()
	for i in 5000:
		DamageCalculator.calculate_damage(_golpe(60, "Fire", "special"),
			_atacante(80, 90, 30, ["Fire"]), _defensor(70, 75, ["Grass"], 200))
	var us_dano : float = float(Time.get_ticks_usec() - t0) / 5000.0
	_assert(us_dano < 60.0, "uma conta de dano custa %.1f us (teto 60)" % us_dano)

	pais.queue_free()

	# A IA não pode voltar a pensar a 60 FPS.
	_assert(CombatBalance.COMBAT_TICK_SEC >= 0.1,
		"a IA decide no máximo %d vezes por segundo, não 60" % int(1.0 / CombatBalance.COMBAT_TICK_SEC))
	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	var i_relogio := fonte.find("_relogio_de_combate -= delta")
	var i_alvo := fonte.find("_find_target()", i_relogio)
	_assert(i_relogio > 0 and i_alvo > i_relogio,
		"procurar alvo acontece DENTRO do tique de combate (era 60x por segundo por bicho)")

	# Todo golpe de área tem teto de alvos — é balanceamento E desempenho.
	var sem_teto : int = 0
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		if str(m.get("target_type", "single")) == "area" and int(m.get("max_targets", 0)) <= 0:
			sem_teto += 1
	_assert(sem_teto == 0, "nenhum golpe de área varre sem limite de alvos (%d sem teto)" % sem_teto)

func _assert(cond: bool, msg: String) -> void:
	if msg.is_empty():
		return
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
