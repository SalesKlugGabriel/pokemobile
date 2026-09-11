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

	_tabela_mesmo_nivel()
	_tabela_desnivelada()
	_tabela_por_potencia()
	_tabela_aoe()
	_criterios_de_sucesso()

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
	_assert(int(contra_tanque["golpes"]) <= 60,
		"nem o pior golpe contra o maior tanque vira parede intransponível (%d golpes)"
			% int(contra_tanque["golpes"]))
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

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
