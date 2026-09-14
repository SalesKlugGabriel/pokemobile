## simular_equilibrio_v2.gd — Passo 7: recalibrar o Alpha depois da §13.
##
## ── Por que isto é obrigatório e não "a gente vê depois" ─────────────────────
##
## O Alpha foi calibrado na Fase 2 **com crítico e variação**. A V2 tirou os
## dois (§13). Isso não muda só a média: **mata a cauda.** Uma luta que antes se
## ganhava no crítico de sorte agora não se ganha nunca — e uma que se perdia
## por azar agora não se perde nunca.
##
## Qualquer número herdado da Fase 2 é, a partir de agora, um palpite com cara
## de fato. Este arquivo mede de novo.
##
## ── Como ele mede ────────────────────────────────────────────────────────────
##
## Roda a luta inteira no papel: dois combatentes, dano determinístico, ataque
## básico e golpes com as recargas reais. Sem cena, sem física — o que se quer
## saber é quem ganha e em quantos segundos, não onde cada um pisou.
##
## Isto **não é teste**: não reprova, imprime tabela. Roda sob demanda com
## `godot4 --headless --script res://scripts/tests/simular_equilibrio_v2.gd`.
extends SceneTree

var GameData : Node
var Dano : GDScript
## Carregada por caminho pelo mesmo motivo de sempre: ela toca em `RNGManager`
## (autoload) e citá-la pelo nome obriga a compilar antes dos autoloads existirem.
var Stats : GDScript
var _rodou : bool = false

## Quanto tempo uma luta pode durar antes de ser declarada empate. 90 s é
## generoso de propósito: se passar disso, o problema não é equilíbrio, é que
## ninguém consegue matar ninguém.
const TETO_DE_SEGUNDOS : float = 90.0
const PASSO : float = 0.1

func _initialize() -> void:
	print("== Simulação de equilíbrio — Gameplay V2 (dano determinístico) ==")

func _process(_d: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	Dano = load("res://scripts/gameplay_v2/DanoV2.gd")
	Stats = load("res://scripts/combat/StatsDePokemon.gd")

	_comparar_v1_v2()
	_tabela_de_alpha()
	_tabela_de_ritmo()
	_nivel_pra_encarar_o_alpha()
	print("\n=== Resultado: simulação concluída ===")
	quit(0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# Um combatente de papel
# ──────────────────────────────────────────────────────────────────────────────

func _montar(species_id: int, nivel: int, golpes_ids: Array,
		mult_hp: float = 1.0, mult_atk: float = 1.0) -> Dictionary:
	var esp : Dictionary = GameData.get_species(species_id)
	var stats : Dictionary = Stats.conjunto(esp.get("base_stats", {}), nivel)
	var golpes : Array = []
	for m in golpes_ids:
		var g : Dictionary = GameData.get_move(str(m))
		if not g.is_empty():
			golpes.append(g)
	var hp : int = int(float(BalanceV2.vida(int(stats.get("hp", 1)))) * mult_hp)
	return {
		"nome": str(esp.get("name", "#%d" % species_id)),
		"nivel": nivel, "tipos": esp.get("types", ["Normal"]),
		"stats": stats, "golpes": golpes,
		"hp_max": hp, "hp": hp,
		"atk": int(float(stats.get("atk", 50)) * mult_atk),
		"spa": int(float(stats.get("spa", 50)) * mult_atk),
		"recargas": [], "cd_basico": 0.0,
	}

func _ataque(c: Dictionary) -> Dictionary:
	return {"level": c["nivel"], "types": c["tipos"],
			"atk": c["atk"], "spa": c["spa"]}

func _defesa(c: Dictionary) -> Dictionary:
	return {"level": c["nivel"], "types": c["tipos"],
			"def": int(c["stats"].get("def", 50)), "spd": int(c["stats"].get("spd", 50)),
			"max_hp": c["hp_max"], "hp": c["hp"]}

# ──────────────────────────────────────────────────────────────────────────────
# A luta
# ──────────────────────────────────────────────────────────────────────────────

## Devolve {"vencedor", "segundos", "vida_restante_frac"}.
## `calc` é o GDScript do dano — é o que deixa comparar V1 e V2 na mesma luta.
func _lutar(a: Dictionary, b: Dictionary, calc: GDScript) -> Dictionary:
	a = a.duplicate(true); b = b.duplicate(true)
	a["recargas"].resize(a["golpes"].size()); a["recargas"].fill(0.0)
	b["recargas"].resize(b["golpes"].size()); b["recargas"].fill(0.0)

	var t : float = 0.0
	while t < TETO_DE_SEGUNDOS:
		t += PASSO
		_agir(a, b, calc)
		if int(b["hp"]) <= 0:
			return {"vencedor": a["nome"], "segundos": t,
					"vida_restante_frac": float(a["hp"]) / float(a["hp_max"])}
		_agir(b, a, calc)
		if int(a["hp"]) <= 0:
			return {"vencedor": b["nome"], "segundos": t,
					"vida_restante_frac": float(b["hp"]) / float(b["hp_max"])}
	return {"vencedor": "empate", "segundos": TETO_DE_SEGUNDOS,
			"vida_restante_frac": float(a["hp"]) / float(a["hp_max"])}

## Escala aplicada ao dano, pra simular uma régua diferente sem editar
## `CombatBalance` (que é da V1 e não pode ser tocada — decisão D-001).
var escala_de_dano : float = 1.0

## V1 e V2 não compartilham nome de função de propósito — `DanoV2` é uma classe
## nova, não um remendo na antiga. Uma porta só aqui evita espalhar o `if`.
func _bater(calc: GDScript, golpe: Dictionary, atk: Dictionary, def: Dictionary) -> int:
	var d : int = 0
	if calc.has_method("calcular"):
		d = int(calc.calcular(golpe, atk, def))
	else:
		d = int(calc.calculate_damage(golpe, atk, def))
	return maxi(1, int(round(float(d) * escala_de_dano)))

func _agir(quem: Dictionary, alvo: Dictionary, calc: GDScript) -> void:
	# Ataque básico: sempre disponível, é o piso de dano.
	quem["cd_basico"] = float(quem["cd_basico"]) - PASSO
	if float(quem["cd_basico"]) <= 0.0:
		var basico := {"id": "basico", "power": 35,
			"type": quem["tipos"][0] if not quem["tipos"].is_empty() else "Normal",
			"category": "physical", "area_type": "single"}
		alvo["hp"] = int(alvo["hp"]) - _bater(calc, basico, _ataque(quem), _defesa(alvo))
		quem["cd_basico"] = CombatBalance.recarga(1.1, int(quem["stats"].get("spe", 50)))

	# O golpe mais forte que estiver pronto. É o que um jogador atento faz, e
	# calibrar contra jogo ruim produz chefe fácil demais.
	var melhor : int = -1
	var melhor_dano : int = 0
	for i in quem["golpes"].size():
		if float(quem["recargas"][i]) > 0.0:
			quem["recargas"][i] = float(quem["recargas"][i]) - PASSO
			continue
		var d : int = _bater(calc, quem["golpes"][i], _ataque(quem), _defesa(alvo))
		if d > melhor_dano:
			melhor_dano = d
			melhor = i
	if melhor >= 0:
		alvo["hp"] = int(alvo["hp"]) - melhor_dano
		quem["recargas"][melhor] = CombatBalance.recarga(
			float(quem["golpes"][melhor].get("cooldown", 2.0)),
			int(quem["stats"].get("spe", 50)))

# ──────────────────────────────────────────────────────────────────────────────
# O que mudou ao tirar crítico e variação
# ──────────────────────────────────────────────────────────────────────────────

func _comparar_v1_v2() -> void:
	print("\n-- O efeito de tirar crítico e variação (§13)")
	print("   Mesma luta, 60 repetições em cada motor.\n")
	var v1 : GDScript = load("res://scripts/combat/DamageCalculator.gd")

	# 🔴 Confronto NEUTRO de propósito. A primeira versão usava Charizard
	# (Fire/Flying) contra Onix (Rock/Ground) — Rock bate 4× nele e Fire bate
	# 0,5× no Onix. O jogador perdia 0/60 e eu quase recalibrei o Alpha em cima
	# disso. A chacina estava CERTA (§15: 4× continua 4×); errada estava a
	# escolha do par. Calibrar equilíbrio contra um confronto decidido pelo tipo
	# mede o tipo, não o equilíbrio.
	var jogador := _montar(6, 40, ["ember", "dragon_rage", "slash", "fire_spin"])
	var inimigo := _montar(20, 38, ["tackle", "quick_attack", "headbutt"])  # Raticate, Normal
	_mostrar_confronto(jogador, inimigo)

	for par in [["V1 (com sorte)", v1], ["V2 (determinístico)", Dano]]:
		var vitorias : int = 0
		var soma : float = 0.0
		var menor : float = 9999.0
		var maior : float = 0.0
		for i in 60:
			var r : Dictionary = _lutar(jogador, inimigo, par[1])
			if str(r["vencedor"]) == str(jogador["nome"]):
				vitorias += 1
			var s : float = float(r["segundos"])
			soma += s
			menor = minf(menor, s)
			maior = maxf(maior, s)
		print("   %-22s vitórias %2d/60 · duração média %5.1f s · faixa %.1f–%.1f s"
			% [par[0], vitorias, soma / 60.0, menor, maior])

	print("\n   A faixa é o ponto: na V2 ela colapsa pra um valor só. A luta")
	print("   deixa de ter cauda — não se ganha por sorte nem se perde por azar.")

	# O contraste que a primeira versão escondeu: com o tipo contra, nenhum
	# ajuste de HP ou ATK salva. É informação, não bug.
	print("\n   Pra referência, o mesmo Charizard contra Onix (Rock/Ground):")
	var onix := _montar(74, 38, ["rock_throw", "tackle"])
	_mostrar_confronto(jogador, onix)
	var r : Dictionary = _lutar(jogador, onix, Dano)
	print("      resultado: %s em %.1f s — o tipo decide antes do equilíbrio."
		% [str(r["vencedor"]), float(r["segundos"])])

## Imprime a tabela de tipos do confronto. Sem isto, um resultado extremo parece
## desequilíbrio quando é só vantagem elemental funcionando.
func _mostrar_confronto(a: Dictionary, b: Dictionary) -> void:
	var a_em_b : float = DamageCalculator.get_type_multiplier(
		str(a["tipos"][0]), b["tipos"])
	var b_em_a : float = DamageCalculator.get_type_multiplier(
		str(b["tipos"][0]), a["tipos"])
	print("   %s %s  ×%.2f →  %s %s  ×%.2f ←"
		% [str(a["nome"]), str(a["tipos"]), a_em_b,
		   str(b["nome"]), str(b["tipos"]), b_em_a])

# ──────────────────────────────────────────────────────────────────────────────
# A recalibração do Alpha
# ──────────────────────────────────────────────────────────────────────────────

func _tabela_de_alpha() -> void:
	print("\n-- Alpha: quanto ele precisa ter pra ser miniboss e não parede")
	print("   §30 do Gabriel: \"+35%% em todos os seis stats clássicos\" → 1,35.")
	print("   Alvo de projeto: o jogador GANHA, mas chega perto de perder —")
	print("   sobrando menos de 40%% da vida.\n")
	print("   HP×    ATK×   vencedor        duração   vida do jogador no fim")

	# Mesmo confronto neutro da comparação acima, pelo mesmo motivo.
	var jogador := _montar(6, 40, ["ember", "dragon_rage", "slash", "fire_spin"])
	var melhor : Array = []
	var melhor_nota : float = -1.0

	# 🔴 A grade desceu. A primeira ia de 2,0 a 4,0 de HP porque foi herdada da
	# régua atual (ALPHA_HP_MULT = 3,0, medida na Fase 2). Só que a §30 do
	# Gabriel diz outra coisa, com todas as letras: **"+35% em todos os seis
	# stats clássicos"** — ou seja 1,35 em tudo, não ×3 de vida.
	#
	# Medir 2,0–4,0 era medir a régua velha contra a especificação nova e
	# chamar o resultado de calibração.
	for hp_mult in [1.0, 1.2, 1.35, 1.5, 2.0, 3.0]:
		for atk_mult in [1.0, 1.2, 1.35, 1.5]:
			var alpha := _montar(20, 42, ["tackle", "quick_attack", "headbutt", "body_slam"],
				hp_mult, atk_mult)
			alpha["nome"] = "Alpha"
			var r : Dictionary = _lutar(jogador, alpha, Dano)
			var ganhou : bool = str(r["vencedor"]) == str(jogador["nome"])
			var sobrou : float = float(r["vida_restante_frac"]) if ganhou else 0.0
			print("   %.1f    %.2f   %-14s  %5.1f s   %s"
				% [hp_mult, atk_mult, str(r["vencedor"]), float(r["segundos"]),
				   ("%.0f%%" % (sobrou * 100.0)) if ganhou else "—"])

			# Nota: quanto mais perto do alvo de projeto, melhor.
			if not ganhou:
				continue
			var s : float = float(r["segundos"])
			if sobrou > 0.40:
				continue
			# Entre os válidos, prefere a luta mais apertada.
			var nota : float = 1.0 - sobrou
			if nota > melhor_nota:
				melhor_nota = nota
				melhor = [hp_mult, atk_mult, s, sobrou]

	print("\n   Régua ATUAL em CombatBalance: HP ×%.2f · ATK ×%.2f"
		% [CombatBalance.ALPHA_HP_MULT, CombatBalance.ALPHA_ATK_MULT])
	if melhor.is_empty():
		print("   ⚠️ NENHUMA combinação da grade caiu na faixa de projeto.")
		print("      Não invento um número: ou a grade precisa ser mais larga,")
		print("      ou o alvo de projeto está errado. Fica declarado, não chutado.")
	else:
		print("   Melhor da grade:  HP ×%.2f · ATK ×%.2f  →  %.1f s, sobrando %.0f%%"
			% [melhor[0], melhor[1], melhor[2], float(melhor[3]) * 100.0])


# ──────────────────────────────────────────────────────────────────────────────
# O achado que a calibração do Alpha revelou
# ──────────────────────────────────────────────────────────────────────────────

## 🔴 A tabela do Alpha mostrou que NENHUM multiplicador funciona: um inimigo
## do mesmo nível ganha com qualquer vantagem, e o jogador mal vence um inimigo
## SEM bônus nenhum (3% de vida sobrando).
##
## Isso não é problema do Alpha. É a razão entre DANO e VIDA: a luta inteira
## dura 4 segundos, e em 4 segundos não dá pra posicionar, ler ataque nem
## esquivar — que é a §9 inteira. Quem tiver qualquer margem ganha antes de o
## jogador ter chance de jogar.
##
## Esta tabela mede o que muda quando o dano encolhe. Não altero nada por conta
## própria: é decisão do Gabriel, e a régua da V1 não pode ser tocada (D-001).
func _tabela_de_ritmo() -> void:
	print("\n-- 🔴 A razão dano/vida: quanto dura uma luta equilibrada")
	print("   Charizard Lv40 contra Raticate Lv40 (confronto neutro, mesmo nível).")
	print("   Um Action RPG precisa de tempo pra posicionar — 4 s não dá.\n")
	print("   dano×   duração   vida do vencedor   leitura")

	var a := _montar(6, 40, ["ember", "dragon_rage", "slash", "fire_spin"])
	var b := _montar(20, 40, ["tackle", "quick_attack", "headbutt", "body_slam"])

	for k in [1.0, 0.7, 0.5, 0.35, 0.25, 0.15, 0.10]:
		escala_de_dano = k
		var r : Dictionary = _lutar(a, b, Dano)
		var s : float = float(r["segundos"])
		var leitura := "rápido demais"
		if s >= 15.0 and s <= 45.0:
			leitura = "← faixa de Action RPG"
		elif s > 45.0:
			leitura = "arrastado"
		print("   %.2f    %5.1f s   %14s   %s"
			% [k, s, "%.0f%%" % (float(r["vida_restante_frac"]) * 100.0), leitura])
	escala_de_dano = 1.0

	print("\n   Régua atual: BASE_DAMAGE_MULTIPLIER = %.2f · HP_SCALE = %.2f"
		% [CombatBalance.BASE_DAMAGE_MULTIPLIER, CombatBalance.HP_SCALE])
	print("   A V2 pode mudar isso em BalanceV2 sem tocar na V1 (D-001).")
	print("   NÃO alterei nada: é decisão do Gabriel, não minha.")

## A §30 fixa o Alpha em +35%. Então a pergunta deixa de ser "que número dar a
## ele" e passa a ser **"o que isso exige do jogador"** — que é a resposta útil
## pra quem vai desenhar onde o Alpha aparece no mundo.
func _nivel_pra_encarar_o_alpha() -> void:
	print("\n-- O Alpha a +35%: que nível o jogador precisa ter")
	print("   Alpha Raticate Lv40 com +35% nos seis stats (§30), fixo.")
	print("   Confronto neutro, pra medir nível e não vantagem de tipo.\n")
	print("   nível do jogador   vencedor     duração   vida no fim")

	var primeiro_que_ganha : int = -1
	for nv in [40, 42, 44, 46, 48, 50, 55]:
		var jogador := _montar(6, nv, ["ember", "dragon_rage", "slash", "fire_spin"])
		var alpha := _montar(20, 40, ["tackle", "quick_attack", "headbutt", "body_slam"],
			BalanceV2.ALPHA_MULT, BalanceV2.ALPHA_MULT)
		alpha["nome"] = "Alpha"
		var r : Dictionary = _lutar(jogador, alpha, Dano)
		var ganhou : bool = str(r["vencedor"]) != "Alpha" and str(r["vencedor"]) != "empate"
		if ganhou and primeiro_que_ganha < 0:
			primeiro_que_ganha = nv
		print("   Lv%-15d %-11s %5.1f s   %s"
			% [nv, str(r["vencedor"]), float(r["segundos"]),
			   ("%.0f%%" % (float(r["vida_restante_frac"]) * 100.0)) if ganhou else "—"])

	print("")
	if primeiro_que_ganha < 0:
		print("   ⚠️ O jogador não ganhou em NENHUM nível da grade. Isso quer dizer")
		print("      que +35% nos seis stats é forte demais pro ritmo atual, ou que")
		print("      o Alpha precisa de uma contrapartida (janela de abertura,")
		print("      fase vulnerável). Fica declarado — não vou inventar número.")
	else:
		print("   O jogador passa a ganhar a partir de Lv%d — ou seja, o Alpha a" % primeiro_que_ganha)
		print("   +35%% custa cerca de %d níveis de vantagem." % (primeiro_que_ganha - 40))
		print("   É esse o número que decide ONDE um Alpha pode aparecer no mundo.")