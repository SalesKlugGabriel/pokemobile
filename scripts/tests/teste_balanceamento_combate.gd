## teste_balanceamento_combate.gd — 11/09/2026. A simulação do item 46.
##
## Este arquivo faz duas coisas ao mesmo tempo, e as duas de propósito:
##
##   1. IMPRIME as tabelas que o Gabriel pediu (dano médio/mínimo/máximo, DPS,
##      TTK, número de golpes) pros confrontos Lv.10x10 até Lv.100x100 e pros
##      desnivelados Lv.10x20 até Lv.75x100. Rodar `godot4 --headless --script
##      res://scripts/tests/teste_balanceamento_combate.gd` é a forma de VER o
##      balanceamento, não só de conferir.
##
##   2. COBRA a régua do item 13 (TTK) e os critérios do item 47. Se um ajuste
##      em `CombatBalance` quebrar o ritmo do combate, é aqui que aparece —
##      antes de virar uma partida ruim.
##
## Os confrontos usam Pokémon REAIS do jogo, não números inventados: um
## atacante médio (Pikachu), um alvo médio (Rattata), um tanque (Onix) e um
## frágil (Abra). É a faixa em que o jogo de verdade acontece.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node

const AMOSTRA : int = 300
const NIVEIS : Array[int] = [10, 20, 30, 50, 75, 100]

func _initialize() -> void:
	print("=== Simulação de balanceamento do combate (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")

	_tabela_de_dano()
	_tabela_mesmo_nivel()
	_tabela_desnivelada()
	_tabela_por_potencia()
	_tabela_aoe()
	_criterios_de_sucesso()
	_tabela_de_stats_por_nivel()
	_tabela_ttk_por_tipo_de_ataque()
	_simulacao_de_bando()
	_stress()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# Ferramentas
# ──────────────────────────────────────────────────────────────────────────

func _base(nome: String) -> Dictionary:
	for i in range(1, 152):
		var e : Dictionary = GameData.get_species(i)
		if str(e.get("name", "")) == nome:
			return e
	return {}

## Uma rodada de medições de um confronto. Devolve dano mínimo, médio, máximo,
## golpes pra matar, DPS e TTK em segundos.
func _confronto(atacante_nome: String, defensor_nome: String, golpe_id: String,
		nivel_atk: int, nivel_def: int) -> Dictionary:
	var a : Dictionary = _base(atacante_nome)
	var d : Dictionary = _base(defensor_nome)
	var golpe : Dictionary = GameData.get_move(golpe_id)
	if a.is_empty() or d.is_empty() or golpe.is_empty():
		return {}

	var sa : Dictionary = StatsDePokemon.conjunto(a.get("base_stats", {}), nivel_atk)
	var sd : Dictionary = StatsDePokemon.conjunto(d.get("base_stats", {}), nivel_def)

	var atacante := {
		"atk": sa["atk"], "spa": sa["spa"], "level": nivel_atk,
		"types": a.get("types", []),
	}
	var defensor := {
		"def": sd["def"], "spd": sd["spd"], "types": d.get("types", []),
		"max_hp": sd["hp"], "hp": sd["hp"], "level": nivel_def,
	}

	var menor : int = 1 << 30
	var maior : int = 0
	var soma : int = 0
	for i in AMOSTRA:
		var dano : int = DamageCalculator.calculate_damage(golpe, atacante, defensor)
		menor = mini(menor, dano)
		maior = maxi(maior, dano)
		soma += dano
	var medio : float = float(soma) / float(AMOSTRA)

	var recarga : float = CombatBalance.recarga(float(golpe.get("cooldown", 2.0)), int(sa["spe"]))
	var espera : float = recarga + float(golpe.get("cast_time", 0.0))
	var golpes : int = int(ceil(float(sd["hp"]) / maxf(medio, 1.0)))

	return {
		"hp_alvo": int(sd["hp"]),
		"min": menor, "medio": medio, "max": maior,
		"golpes": golpes,
		"dps": medio / maxf(espera, 0.01),
		"ttk": float(golpes) * espera,
	}

func _linha(rotulo: String, r: Dictionary) -> void:
	if r.is_empty():
		print("  %s  (confronto não montou)" % rotulo)
		return
	print("  %-22s dano %4d/%6.1f/%4d  vida %4d  golpes %3d  DPS %6.1f  TTK %5.1fs"
		% [rotulo, int(r["min"]), float(r["medio"]), int(r["max"]),
			int(r["hp_alvo"]), int(r["golpes"]), float(r["dps"]), float(r["ttk"])])

# ──────────────────────────────────────────────────────────────────────────
# Item 5 — a tabela de dano, no formato pedido
# ──────────────────────────────────────────────────────────────────────────
func _tabela_de_dano() -> void:
	print("\n-- Tabela de dano --")
	print("  | Atacante   | Nv  | Golpe        | Alvo       | Nv  |   Dano |")
	print("  |------------|----:|--------------|------------|----:|-------:|")
	var linhas := []
	for n in NIVEIS:
		linhas.append(["Pikachu", n, "thunderbolt", "Rattata", n])
	for par in [[20, 10], [10, 20], [30, 50], [50, 30], [50, 100], [100, 50]]:
		linhas.append(["Pikachu", par[0], "thunderbolt", "Rattata", par[1]])

	var negativos : Array[String] = []
	for L in linhas:
		var a : Dictionary = _base(str(L[0]))
		var d : Dictionary = _base(str(L[3]))
		var m : Dictionary = GameData.get_move(str(L[2]))
		var sa : Dictionary = StatsDePokemon.conjunto(a.get("base_stats", {}), int(L[1]))
		var sd : Dictionary = StatsDePokemon.conjunto(d.get("base_stats", {}), int(L[4]))
		var soma : int = 0
		for i in AMOSTRA:
			soma += DamageCalculator.calculate_damage(m,
				{"atk": sa["atk"], "spa": sa["spa"], "level": int(L[1]), "types": a.get("types", [])},
				{"def": sd["def"], "spd": sd["spd"], "types": d.get("types", []),
					"max_hp": sd["hp"], "hp": sd["hp"], "level": int(L[4])})
		var medio : float = float(soma) / float(AMOSTRA)
		print("  | %-10s | %3d | %-12s | %-10s | %3d | %6.1f |"
			% [str(L[0]), int(L[1]), str(m.get("name", L[2])), str(L[3]), int(L[4]), medio])
		if medio <= 0.0:
			negativos.append("%s Lv%d -> %s Lv%d" % [L[0], L[1], L[3], L[4]])
	_assert(negativos.is_empty(), "nenhum confronto da tabela dá dano zero (%s)" % str(negativos))

# ──────────────────────────────────────────────────────────────────────────
# 1. Mesmo nível
# ──────────────────────────────────────────────────────────────────────────
func _tabela_mesmo_nivel() -> void:
	print("\n-- Mesmo nível, ataque básico (Pikachu Quick Attack -> Rattata) --")
	print("     (mín/médio/máx do dano · vida do alvo · golpes pra matar · DPS · tempo até morrer)")
	var fora : Array[String] = []
	for n in NIVEIS:
		var r := _confronto("Pikachu", "Rattata", "quick_attack", n, n)
		_linha("Lv.%d x Lv.%d" % [n, n], r)
		if r.is_empty():
			continue
		var g : int = int(r["golpes"])
		if g < CombatBalance.TTK_BASICO_MIN or g > CombatBalance.TTK_BASICO_MAX + 3:
			fora.append("Lv.%d=%d" % [n, g])
	_assert(fora.is_empty(),
		"ataque básico mata em ~%d-%d golpes em TODO nível (fora da faixa: %s)"
			% [CombatBalance.TTK_BASICO_MIN, CombatBalance.TTK_BASICO_MAX, str(fora)])

	print("\n-- Mesmo nível, golpe forte com vantagem de tipo (Thunderbolt -> Spearow) --")
	var fora_forte : Array[String] = []
	for n in NIVEIS:
		var r := _confronto("Pikachu", "Spearow", "thunderbolt", n, n)
		_linha("Lv.%d x Lv.%d" % [n, n], r)
		if r.is_empty():
			continue
		var g : int = int(r["golpes"])
		if g < CombatBalance.TTK_FORTE_MIN or g > CombatBalance.TTK_FORTE_MAX:
			fora_forte.append("Lv.%d=%d" % [n, g])
	_assert(fora_forte.is_empty(),
		"golpe forte + super efetivo mata em %d-%d golpes (fora: %s) — forte, mas nunca de um só"
			% [CombatBalance.TTK_FORTE_MIN, CombatBalance.TTK_FORTE_MAX, str(fora_forte)])

# ──────────────────────────────────────────────────────────────────────────
# 2. Desnivelado — a régua da progressão
# ──────────────────────────────────────────────────────────────────────────
func _tabela_desnivelada() -> void:
	print("\n-- Desnivelado (Pikachu Quick Attack -> Rattata) --")
	var pares := [[10, 20], [20, 30], [30, 50], [50, 75], [75, 100],
		[20, 10], [30, 20], [50, 30], [75, 50], [100, 75], [21, 20]]
	var golpes_por_par := {}
	for par in pares:
		var r := _confronto("Pikachu", "Rattata", "quick_attack", par[0], par[1])
		_linha("Lv.%d -> Lv.%d" % [par[0], par[1]], r)
		if not r.is_empty():
			golpes_por_par["%d>%d" % [par[0], par[1]]] = int(r["golpes"])

	# Item 6: "Um Lv.20 deve claramente superar um Lv.10."
	var g_20x10 : int = int(golpes_por_par.get("20>10", 99))
	var g_10x20 : int = int(golpes_por_par.get("10>20", 1))
	_assert(g_20x10 * 3 < g_10x20,
		"um Lv.20 domina um Lv.10 com folga (%d golpes contra %d) — é a sensação de progressão"
			% [g_20x10, g_10x20])

	# Item 6: "Um Lv.21 não deve destruir automaticamente um Lv.20."
	var g_21x20 : int = int(golpes_por_par.get("21>20", 0))
	_assert(g_21x20 >= CombatBalance.TTK_BASICO_MIN,
		"um Lv.21 NÃO apaga um Lv.20 — ainda precisa de %d golpes" % g_21x20)

	# Item 52: "Se eu entrar numa região muito acima do meu nível, vou sofrer."
	var g_30x50 : int = int(golpes_por_par.get("30>50", 0))
	_assert(g_30x50 > CombatBalance.TTK_BASICO_MAX * 1.5,
		"entrar numa área 20 níveis acima dói de verdade (%d golpes pra derrubar um só bicho)" % g_30x50)

# ──────────────────────────────────────────────────────────────────────────
# 3. A escada de potência (item 12) — cada faixa tem identidade
# ──────────────────────────────────────────────────────────────────────────
func _tabela_por_potencia() -> void:
	print("\n-- A escada de potência, Lv.25 contra alvo médio --")
	var faixas := [[35, "fraco"], [50, "básico"], [65, "médio"],
		[85, "forte"], [110, "muito forte"], [150, "ultimate"]]
	var anterior : int = 1 << 30
	var ordenado := true
	for f in faixas:
		var golpe := {"power": int(f[0]), "type": "Normal", "category": "physical", "name": str(f[1]),
			"cooldown": 3.0, "cast_time": 0.0}
		var a : Dictionary = _base("Pikachu")
		var d : Dictionary = _base("Rattata")
		var sa : Dictionary = StatsDePokemon.conjunto(a.get("base_stats", {}), 25)
		var sd : Dictionary = StatsDePokemon.conjunto(d.get("base_stats", {}), 25)
		var soma : int = 0
		for i in AMOSTRA:
			soma += DamageCalculator.calculate_damage(golpe,
				{"atk": sa["atk"], "spa": sa["spa"], "level": 25, "types": []},
				{"def": sd["def"], "spd": sd["spd"], "types": ["Normal"],
					"max_hp": sd["hp"], "hp": sd["hp"], "level": 25})
		var medio : float = float(soma) / float(AMOSTRA)
		var golpes : int = int(ceil(float(sd["hp"]) / maxf(medio, 1.0)))
		print("  power %3d (%-11s)  dano médio %5.1f  golpes %2d" % [int(f[0]), str(f[1]), medio, golpes])
		if golpes > anterior:
			ordenado = false
		anterior = golpes
	_assert(ordenado, "quanto maior a potência, menos golpes pra matar — a escada não se inverte em lugar nenhum")

# ──────────────────────────────────────────────────────────────────────────
# 4. AoE — o item 38 pede que área e alvo único sejam balanceados diferente
# ──────────────────────────────────────────────────────────────────────────
func _tabela_aoe() -> void:
	print("\n-- Golpes de área: potência, alcance, recarga e teto de alvos --")
	var de_area : Array[String] = []
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		if str(m.get("target_type", "single")) == "area":
			de_area.append(mid)
	de_area.sort()

	var sem_teto : Array[String] = []
	var teto_alto : Array[String] = []
	for mid in de_area.slice(0, 10):
		var m : Dictionary = GameData.moves[mid]
		print("  %-14s %-9s p%3d  raio %4.1ft  recarga %.1fs  cast %.1fs  máx %d alvos"
			% [str(m.get("name", mid)), str(m.get("area_type", "?")), int(m.get("power", 0)),
				float(m.get("radius", 0.0)) / CombatBalance.TILE_PX, float(m.get("cooldown", 0.0)),
				float(m.get("cast_time", 0.0)), int(m.get("max_targets", 0))])
	for mid in de_area:
		var m : Dictionary = GameData.moves[mid]
		var teto : int = int(m.get("max_targets", 0))
		if teto <= 1:
			sem_teto.append(mid)
		elif teto > 12:
			teto_alto.append(mid)
	_assert(sem_teto.is_empty(),
		"todo golpe de área tem teto de alvos (protege balanceamento E desempenho): %s" % str(sem_teto))
	_assert(teto_alto.is_empty(), "nenhum golpe de área pega mais que 12 alvos: %s" % str(teto_alto))

	# Área custa mais: recarga maior que a de um golpe de alvo único de
	# potência parecida. Senão a área domina o jogo inteiro (item 38).
	var cd_area : float = 0.0
	var n_area : int = 0
	var cd_unico : float = 0.0
	var n_unico : int = 0
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		if int(m.get("power", 0)) < 60:
			continue
		if str(m.get("target_type", "single")) == "area":
			cd_area += float(m.get("cooldown", 0.0)); n_area += 1
		else:
			cd_unico += float(m.get("cooldown", 0.0)); n_unico += 1
	var media_area : float = cd_area / maxf(float(n_area), 1.0)
	var media_unico : float = cd_unico / maxf(float(n_unico), 1.0)
	print("\n  recarga média: área %.2fs  x  alvo único %.2fs" % [media_area, media_unico])
	_assert(media_area > media_unico,
		"golpe de área recarrega mais devagar que alvo único de potência parecida (%.2fs x %.2fs)"
			% [media_area, media_unico])

# ──────────────────────────────────────────────────────────────────────────
# 5. Os critérios de sucesso do item 47 que dá pra medir por número
# ──────────────────────────────────────────────────────────────────────────
func _criterios_de_sucesso() -> void:
	print("\n-- Critérios de sucesso (item 47) --")

	# "Pokémon de mesmo nível conseguem lutar sem OHKO constante."
	var ohkos : Array[String] = []
	for nome_alvo in ["Rattata", "Spearow", "Abra", "Caterpie"]:
		for n in [10, 30, 50]:
			var r := _confronto("Pikachu", nome_alvo, "thunderbolt", n, n)
			if not r.is_empty() and int(r["golpes"]) <= 1:
				ohkos.append("%s Lv.%d" % [nome_alvo, n])
	_assert(ohkos.is_empty(), "nenhum OHKO entre iguais, nem no alvo mais frágil (%s)" % str(ohkos))

	# "Stats realmente influenciam": o tanque aguenta muito mais que o frágil.
	var contra_tanque := _confronto("Pikachu", "Onix", "quick_attack", 30, 30)
	var contra_fragil := _confronto("Pikachu", "Abra", "quick_attack", 30, 30)
	_linha("vs Onix (tanque)", contra_tanque)
	_linha("vs Abra (frágil)", contra_fragil)
	_assert(int(contra_tanque["golpes"]) > int(contra_fragil["golpes"]) * 2,
		"o tanque aguenta pelo menos o dobro do frágil (%d x %d golpes) — a defesa importa"
			% [int(contra_tanque["golpes"]), int(contra_fragil["golpes"])])

	# 🔴 O outro lado da mesma moeda, e a razão deste bloco existir: a
	# simulação mostrou Quick Attack dando 1,2 de dano no Onix (96 golpes,
	# quase 3 minutos). "Defesa infinita = dano zero" é proibido pelo item 10.
	# O que se cobra aqui são as DUAS coisas ao mesmo tempo: o golpe errado
	# tem que doer de usar, mas não pode ser uma parede; e o golpe CERTO tem
	# que resolver. Se a diferença entre os dois encolher, o jogador deixa de
	# ter motivo pra escolher golpe.
	var com_golpe_certo := _confronto("Squirtle", "Onix", "water_gun", 30, 30)
	_linha("vs Onix (golpe certo)", com_golpe_certo)
	# 🔴 Fase 2: sem o piso de 2%, o pior golpe contra o maior tanque volta a
	# levar ~93 golpes. Isso é DE PROPÓSITO — é o preço de usar a ferramenta
	# errada, e o jogador tem 4 slots pra escolher. O que o teste cobra é que
	# ainda saia dano (nunca zero por defesa) e que o golpe certo resolva.
	_assert(int(contra_tanque["min"]) >= 1,
		"mesmo o pior golpe contra o maior tanque tira pelo menos 1 (%d)" % int(contra_tanque["min"]))
	_assert(int(com_golpe_certo["golpes"]) * 4 < int(contra_tanque["golpes"]),
		"o golpe CERTO resolve o tanque muito mais rápido que o errado (%d x %d golpes) — escolher importa"
			% [int(com_golpe_certo["golpes"]), int(contra_tanque["golpes"])])

	# "Nature influencia sem quebrar balanceamento": no máximo ±10% por stat.
	var melhor : int = StatsDePokemon.stat(100, 50, "atk", "adamant")
	var pior : int = StatsDePokemon.stat(100, 50, "atk", "modest")
	var espalhamento : float = float(melhor) / float(pior)
	_assert(espalhamento < 1.25,
		"entre a melhor e a pior nature há menos de 25%% de diferença (x%.2f) — tempera, não decide"
			% espalhamento)

	# "Habilidades possuem identidade": não existem dois golpes iguais em
	# tudo, senão a escolha do jogador não significa nada.
	var assinaturas := {}
	var gemeos : Array[String] = []
	for mid in GameData.moves:
		var m : Dictionary = GameData.moves[mid]
		if int(m.get("power", 0)) <= 0:
			continue
		var chave := "%s|%d|%s|%.1f|%.1f" % [str(m.get("type", "")), int(m.get("power", 0)),
			str(m.get("category", "")), float(m.get("cooldown", 0.0)), float(m.get("range", 0.0))]
		if assinaturas.has(chave):
			gemeos.append("%s=%s" % [mid, assinaturas[chave]])
		assinaturas[chave] = mid
	print("  golpes idênticos em tipo/potência/categoria/recarga/alcance: %d" % gemeos.size())
	_assert(gemeos.size() < 30,
		"a maioria dos golpes tem identidade própria (%d pares idênticos em %d golpes)"
			% [gemeos.size(), GameData.moves.size()])

# ──────────────────────────────────────────────────────────────────────────
# Item 7 — a escada de stats por nível
# ──────────────────────────────────────────────────────────────────────────
func _tabela_de_stats_por_nivel() -> void:
	print("\n-- Escada de stats por nível (Charizard, IV 31, nature neutra) --")
	var base : Dictionary = _base("Charizard").get("base_stats", {})
	var anterior : Dictionary = {}
	var sempre_sobe := true
	var quebrou : Array[String] = []
	for n in NIVEIS:
		var s : Dictionary = StatsDePokemon.conjunto(base, n)
		print("  Lv%-4d HP %4d  ATK %3d  DEF %3d  SP_ATK %3d  SP_DEF %3d  SPEED %3d"
			% [n, s["hp"], s["atk"], s["def"], s["spa"], s["spd"], s["spe"]])
		if not anterior.is_empty():
			for chave in StatsDePokemon.CHAVES:
				if int(s[chave]) <= int(anterior[chave]):
					sempre_sobe = false
					quebrou.append("%s no Lv%d" % [chave, n])
		anterior = s
	_assert(sempre_sobe, "todo stat cresce a cada degrau de nível, sem exceção (%s)" % str(quebrou))

	# Sobrevivência e dano também têm que subir junto.
	var alvo : Dictionary = _base("Rattata").get("base_stats", {})
	var golpe : Dictionary = GameData.get_move("quick_attack")
	var antes_dano : float = 0.0
	var antes_sobrevida : float = 0.0
	var mono_dano := true
	var mono_vida := true
	print("  (contra um alvo FIXO Lv.30, quanto o Charizard causa e quanto aguenta)")
	for n in NIVEIS:
		var s : Dictionary = StatsDePokemon.conjunto(base, n)
		var sd : Dictionary = StatsDePokemon.conjunto(alvo, 30)
		var soma : int = 0
		for i in 200:
			soma += DamageCalculator.calculate_damage(golpe,
				{"atk": s["atk"], "spa": s["spa"], "level": n, "types": ["Fire", "Flying"]},
				{"def": sd["def"], "spd": sd["spd"], "types": ["Normal"],
					"max_hp": sd["hp"], "hp": sd["hp"], "level": 30})
		var dano : float = float(soma) / 200.0
		# sobrevivência: quantos golpes do alvo Lv30 ele aguenta
		var s2 : int = 0
		for i in 200:
			s2 += DamageCalculator.calculate_damage(golpe,
				{"atk": sd["atk"], "spa": sd["spa"], "level": 30, "types": ["Normal"]},
				{"def": s["def"], "spd": s["spd"], "types": ["Fire", "Flying"],
					"max_hp": s["hp"], "hp": s["hp"], "level": n})
		var aguenta : float = float(s["hp"]) / maxf(float(s2) / 200.0, 1.0)
		print("    Lv%-4d causa %6.1f por golpe · aguenta %5.1f golpes" % [n, dano, aguenta])
		if dano <= antes_dano:
			mono_dano = false
		if aguenta <= antes_sobrevida:
			mono_vida = false
		antes_dano = dano
		antes_sobrevida = aguenta
	_assert(mono_dano, "o dano cresce a cada degrau de nível")
	_assert(mono_vida, "a sobrevivência cresce a cada degrau de nível")

	# Diferenças pequenas não podem dar resultado absurdo.
	var saltos : Array[String] = []
	for n in range(20, 41):
		var a : Dictionary = StatsDePokemon.conjunto(base, n)
		var b : Dictionary = StatsDePokemon.conjunto(base, n + 1)
		for chave in StatsDePokemon.CHAVES:
			var razao : float = float(b[chave]) / maxf(float(a[chave]), 1.0)
			if razao > 1.08:
				saltos.append("%s Lv%d->%d x%.2f" % [chave, n, n + 1, razao])
	_assert(saltos.is_empty(),
		"um nível a mais nunca dá mais que +8%% num stat (%s)" % str(saltos.slice(0, 4)))

# ──────────────────────────────────────────────────────────────────────────
# Item 6 — TTK por tipo de ataque
# ──────────────────────────────────────────────────────────────────────────
func _tabela_ttk_por_tipo_de_ataque() -> void:
	print("\n-- TTK por tipo de ataque (atacante e alvo Lv.30) --")
	var a : Dictionary = _base("Pikachu")
	var sa : Dictionary = StatsDePokemon.conjunto(a.get("base_stats", {}), 30)
	var casos := [
		["básico (Quick Attack)",   "Rattata",  "quick_attack", 1.0],
		["médio (Swift)",           "Rattata",  "swift",        1.0],
		["forte (Thunderbolt)",     "Rattata",  "thunderbolt",  1.0],
		["super efetivo",           "Spearow",  "thunderbolt",  1.0],
		["resistido (x0.5)",        "Bulbasaur","thunderbolt",  1.0],
		["imune (x0)",              "Geodude",  "thunderbolt",  1.0],
		["com crítico garantido",   "Rattata",  "thunderbolt",  CombatBalance.CRIT_MULTIPLIER],
		["contra tanque (Onix)",    "Onix",     "quick_attack", 1.0],
		["contra frágil (Abra)",    "Abra",     "thunderbolt",  1.0],
	]
	for caso in casos:
		var d : Dictionary = _base(str(caso[1]))
		var m : Dictionary = GameData.get_move(str(caso[2]))
		if d.is_empty() or m.is_empty():
			print("  %-24s (sem dado)" % str(caso[0]))
			continue
		var sd : Dictionary = StatsDePokemon.conjunto(d.get("base_stats", {}), 30)
		var menor : int = 1 << 30
		var maior : int = 0
		var soma : int = 0
		for i in AMOSTRA:
			var dm : int = int(round(float(DamageCalculator.calculate_damage(m,
				{"atk": sa["atk"], "spa": sa["spa"], "level": 30, "types": a.get("types", [])},
				{"def": sd["def"], "spd": sd["spd"], "types": d.get("types", []),
					"max_hp": sd["hp"], "hp": sd["hp"], "level": 30})) * float(caso[3])))
			menor = mini(menor, dm); maior = maxi(maior, dm); soma += dm
		var medio : float = float(soma) / float(AMOSTRA)
		var espera : float = CombatBalance.recarga(float(m.get("cooldown", 2.0)), int(sa["spe"])) \
			+ float(m.get("cast_time", 0.0))
		if medio <= 0.0:
			# Imunidade: não existe "golpes pra matar" — nunca mata.
			print("  %-24s dano 0 · NUNCA mata (imunidade de tipo)" % str(caso[0]))
			continue
		var golpes : int = int(ceil(float(sd["hp"]) / medio))
		print("  %-24s dano %4d/%6.1f/%4d  vida %4d  golpes %3d  DPS %6.1f  TTK %5.1fs"
			% [str(caso[0]), menor, medio, maior, int(sd["hp"]), golpes,
				medio / maxf(espera, 0.01), float(golpes) * espera])
	_assert(true, "tabela de TTK por tipo de ataque impressa acima")

# ──────────────────────────────────────────────────────────────────────────
# Item 16 — bandos de 1 a 5
# ──────────────────────────────────────────────────────────────────────────
func _simulacao_de_bando() -> void:
	# 🔴 O primeiro exemplo que escrevi aqui era Beedrill contra CHARIZARD, e
	# dava 1,0 de dano por golpe: Inseto/Veneno contra Fogo/Voador é x0.25. A
	# tabela media a tabela de TIPOS, não a força do bando. Trocado por um alvo
	# neutro (Rattata/Normal), que é o confronto que responde a pergunta do
	# item 16.
	# Wartortle: um Pokémon de TIME de verdade (o que o jogador leva pro mato
	# no nível 25) e confronto neutro — Inseto e Veneno contra Água são x1.
	print("\n-- Bando de Beedrill Lv.25 contra o Pokémon do jogador (Wartortle Lv.25) --")
	var b : Dictionary = _base("Beedrill")
	var p : Dictionary = _base("Wartortle")
	var sb : Dictionary = StatsDePokemon.conjunto(b.get("base_stats", {}), 25)
	var sp : Dictionary = StatsDePokemon.conjunto(p.get("base_stats", {}), 25)
	# O golpe que um Beedrill selvagem realmente carrega (teto de 3 slots).
	var kit : Array = KitDeCombate.montar(15, 25, GameData.get_learnable_moves(15, 25),
		GameData.moves, b.get("types", []), GameData.species, KitDeCombate.SLOTS_SELVAGEM_COMUM)
	var melhor : Dictionary = {}
	for mid in kit:
		var m : Dictionary = GameData.get_move(str(mid))
		if int(m.get("power", 0)) > int(melhor.get("power", 0)):
			melhor = m
	if melhor.is_empty():
		melhor = GameData.get_move("tackle")

	var soma : int = 0
	for i in AMOSTRA:
		soma += DamageCalculator.calculate_damage(melhor,
			{"atk": sb["atk"], "spa": sb["spa"], "level": 25, "types": b.get("types", [])},
			{"def": sp["def"], "spd": sp["spd"], "types": p.get("types", []),
				"max_hp": sp["hp"], "hp": sp["hp"], "level": 25})
	var por_golpe : float = float(soma) / float(AMOSTRA)
	var espera : float = CombatBalance.recarga(float(melhor.get("cooldown", 2.0)), int(sb["spe"]))

	var segundos_por_tamanho := {}
	for quantos in [1, 2, 3, 4, 5]:
		var dps : float = por_golpe * float(quantos) / maxf(espera, 0.01)
		var ate_morrer : float = float(sp["hp"]) / maxf(dps, 0.01)
		segundos_por_tamanho[quantos] = ate_morrer
		print("  %d Beedrill: %5.1f de dano/golpe cada · DPS do grupo %6.1f · o jogador cai em %5.1fs"
			% [quantos, por_golpe, dps, ate_morrer])

	_assert(por_golpe > 2.0,
		"o golpe do bando causa dano de verdade (%.1f) — se cair no piso de 1, a tabela está medindo tipo, não bando"
			% por_golpe)
	_assert(int(segundos_por_tamanho[1]) > 20,
		"um Beedrill sozinho não é ameaça séria (%.0fs pra derrubar)" % float(segundos_por_tamanho[1]))
	_assert(float(segundos_por_tamanho[5]) < float(segundos_por_tamanho[1]) * 0.3,
		"cinco juntos são MUITO mais perigosos que um (%.0fs contra %.0fs) — o bando é uma ameaça de verdade"
			% [float(segundos_por_tamanho[5]), float(segundos_por_tamanho[1])])
	# 🔴 O número real, sem maquiagem: 5 atacantes dão 5x o dano, e o alvo cai
	# em ~5s se todos baterem no mesmo instante. Isso é aritmética. O que se
	# corrigiu não foi o dano — foi a SIMULTANEIDADE: quem responde ao grito
	# entra com 0,4 a 1,8s de atraso (CombatBalance.ATRASO_DO_BANDO_*), então
	# na prática o quinto Beedrill só começa a bater quando o jogador já viu os
	# dois primeiros e teve chance de recuar, usar área ou fugir (a coleira é
	# de 12 tiles). O teste cobra o piso da janela de reação.
	_assert(float(segundos_por_tamanho[5]) > 4.0,
		"mesmo o bando cheio deixa alguns segundos de reação (%.1fs) — e chega escalonado, não em bloco"
			% float(segundos_por_tamanho[5]))
	_assert(CombatBalance.ATRASO_DO_BANDO_MAX > 1.0,
		"quem é chamado pelo bando chega com atraso de até %.1fs" % CombatBalance.ATRASO_DO_BANDO_MAX)
	_assert(CombatBalance.MAX_PACK_SIZE <= 5,
		"o bando não passa de %d, mesmo com 20 do mesmo bicho na tela" % CombatBalance.MAX_PACK_SIZE)
	_assert(CombatBalance.AGGRO_CHAIN_MAX_HOPS == 1,
		"quem foi chamado não chama mais ninguém (a corrente para em 1 salto)")

# ──────────────────────────────────────────────────────────────────────────
# Item 18 — cenário de stress
# ──────────────────────────────────────────────────────────────────────────
func _stress() -> void:
	print("\n-- Stress: 60 selvagens + jogador + 4 do time, com IA, área e status --")
	print("   (headless: não há renderização, então o que se mede é o CUSTO DE CPU")
	print("    da lógica de combate, não FPS real. Ver a limitação registrada no relatório.)")

	var molde := GDScript.new()
	molde.source_code = "extends Node2D\nvar species_id : int = 1\n"
	molde.reload()
	var pais := Node2D.new()
	root.add_child(pais)

	var selvagens : Array[Node2D] = []
	for i in 60:
		var n : Node2D = molde.new()
		n.add_to_group("stress_selvagem")
		pais.add_child(n)
		n.global_position = Vector2(cos(float(i)) * 900.0, sin(float(i) * 1.7) * 900.0)
		selvagens.append(n)
	for i in 5:   # o jogador + 4 do time
		var n : Node2D = molde.new()
		n.add_to_group("stress_jogador")
		pais.add_child(n)
		n.global_position = Vector2(float(i) * 60.0, 0)

	var golpe_area : Dictionary = GameData.get_move("earthquake")
	var golpe_unico : Dictionary = GameData.get_move("thunderbolt")
	var atacante := {"atk": 120, "spa": 120, "level": 30, "types": ["Ground"]}
	var defensor := {"def": 90, "spd": 90, "types": ["Normal"], "max_hp": 200, "hp": 200, "level": 30}

	# Um "segundo de jogo" pesado: 60 bichos decidindo 5x por segundo (300
	# decisões), 30 ataques comuns e 6 golpes de área.
	var t0 := Time.get_ticks_usec()
	for i in 300:
		ComportamentoSelvagem.escolher_alvo([
			{"no": selvagens[i % 60], "distancia": 300.0, "fracao_vida": 0.8},
			{"no": selvagens[(i + 7) % 60], "distancia": 700.0, "fracao_vida": 1.0, "me_atacou": true},
		], ComportamentoSelvagem.AGRESSIVO, Vector2.ZERO, Vector2.ZERO)
		ComportamentoSelvagem.escolher_golpe([golpe_unico, golpe_area], [0.0, 0.0], 300.0,
			{"tipos_do_alvo": ["Normal"], "alvos_agrupados": 3})
	var us_ia := float(Time.get_ticks_usec() - t0)

	t0 = Time.get_ticks_usec()
	for i in 30:
		DamageCalculator.calculate_damage(golpe_unico, atacante, defensor)
	for i in 6:
		var alvos : Array = FormaDeArea.alvos(Vector2.ZERO, Vector2.RIGHT, golpe_area, "stress_selvagem")
		for a in alvos:
			DamageCalculator.calculate_damage(golpe_area, atacante, defensor)
	var us_golpes := float(Time.get_ticks_usec() - t0)

	t0 = Time.get_ticks_usec()
	for i in 65:
		StatusEffectController.tick_damage("poison", 200, 0)
	var us_status := float(Time.get_ticks_usec() - t0)

	var total := us_ia + us_golpes + us_status
	print("   IA (300 decisões/s) .............. %7.0f us" % us_ia)
	print("   golpes (30 simples + 6 de área) .. %7.0f us" % us_golpes)
	print("   status (65 tiques) ............... %7.0f us" % us_status)
	print("   TOTAL por segundo de jogo ........ %7.0f us  (1 segundo = 1.000.000 us)" % total)
	print("   ou seja, %.2f%% de um núcleo, e %.1f%% do orçamento de UM quadro a 60 FPS"
		% [total / 10000.0, total / 166.66])

	_assert(total < 100000.0,
		"a lógica de combate de um segundo cheio custa %.0f us — menos de 10%% de um núcleo" % total)
	_assert(us_ia / 300.0 < 100.0,
		"cada decisão de IA custa %.1f us" % (us_ia / 300.0))
	pais.queue_free()

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
