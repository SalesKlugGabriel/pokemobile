## teste_gameplay_v3_fase18.gd — Alpha (Fase 18).
##
## ── O que esta fase encontrou ───────────────────────────────────────────────
##
## 🔴 **O Alpha nunca existiu no jogo.** `WildPokemon.is_alpha` é um `@export` e
## **nada no repositório o liga** — nem código, nem cena, nem teste. Régua de
## stats, trava de captura, drop exclusivo e escala visual: tudo escrito,
## testado em unidade, e inalcançável a partir do jogo.
##
## 🔴 **E `is_alpha_eligible` não era lido por ninguém.** 151 espécies com a
## chave preenchida à mão, 92 elegíveis — e zero consultas. Curadoria que nunca
## curou.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
##   1. **Voltar ao Alpha inalcançável.** A conferência do mundo é a que
##      importa: o spawner produz Alpha, e ele nasce diferente de verdade.
##   2. **Caterpie Alpha.** A curadoria por espécie tem de valer, e falhar
##      FECHADA — espécie sem a chave não é elegível.
##   3. **A raridade escorregar.** O Gabriel fixou os três números em 18/09:
##      elite 2%, Alpha 0,5%, +0,1% por elite derrotado nas últimas 3 horas.
##      Cada um deles é conferido aqui como número, e a janela é conferida
##      expirando — um bônus que não expira é outra regra.
##   4. **Dois multiplicadores pro mesmo Alpha.** A §30 pede UM número pros seis
##      stats; `CombatBalance` tem a tabela medida da V1 e `BalanceV2` tem a
##      especificação. A especificação ganha, e num lugar só.
##   5. **Alpha capturável.** É o que o separa de troféu.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _especies : Dictionary = {}

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 18: Alpha ===")
	_carregar()
	_curadoria()
	_sorteio()
	_o_que_muda()
	_captura_e_loot()

func _carregar() -> void:
	var f := FileAccess.open("res://data/pokemon/species.json", FileAccess.READ)
	_conf("species.json abre", f != null)
	if f == null:
		return
	var lido = JSON.parse_string(f.get_as_text())
	_conf("species.json é JSON válido", lido is Dictionary)
	if lido is Dictionary:
		_especies = lido

# ──────────────────────────────────────────────────────────────────────────────
# 1. A curadoria que ninguém lia
# ──────────────────────────────────────────────────────────────────────────────

func _curadoria() -> void:
	print("\n-- §30: nem toda espécie vira Alpha --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")

	var elegiveis : int = 0
	for chave in _especies:
		if bool((_especies[chave] as Dictionary).get("is_alpha_eligible", false)):
			elegiveis += 1
	_conf("a curadoria existe no dado e não é trivial",
		elegiveis > 0 and elegiveis < _especies.size(),
		"%d de %d — se fosse tudo ou nada, a lista não decidiria nada"
			% [elegiveis, _especies.size()])

	_conf("Charizard é elegível", R.elegivel(_especies.get("6", {})))
	_conf("Caterpie NÃO é elegível", not R.elegivel(_especies.get("10", {})),
		"é exatamente o bicho que a lista existe pra manter fora")

	# Falha fechada: a diferença entre "não decidido" e "liberado".
	_conf("espécie sem a chave não é elegível", not R.elegivel({}),
		"se o padrão fosse true, espécie nova viraria miniboss sem ninguém decidir")
	_conf("dicionário vazio não quebra", not R.elegivel({"name": "Fantasma"}))

# ──────────────────────────────────────────────────────────────────────────────
# 2. A raridade — a régua que o Gabriel fixou em 18/09
# ──────────────────────────────────────────────────────────────────────────────

func _sorteio() -> void:
	print("\n-- a régua do Gabriel: 2% elite, 0,5% Alpha, +0,1% por elite caído --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")
	var charizard : Dictionary = _especies.get("6", {})
	var caterpie : Dictionary = _especies.get("10", {})

	# Os três números que ele fixou, conferidos como números.
	_conf("elite é 2%", PerigoDaZona.CHANCE_DE_ELITE_MAX == 0.02,
		"%.3f" % PerigoDaZona.CHANCE_DE_ELITE_MAX)
	_conf("Alpha começa em 0,5%", R.CHANCE_BASE == 0.005)
	_conf("e sobe 0,1% por elite", R.BONUS_POR_ELITE == 0.001)
	_conf("a janela é de 3 horas", R.JANELA_SEGUNDOS == 3.0 * 3600.0)

	# A curadoria ganha do sorteio, sempre.
	_conf("elegível + sorteio bom = Alpha", R.sortear(charizard, 0.0))
	_conf("NÃO elegível = nunca Alpha, nem com o sorteio perfeito",
		not R.sortear(caterpie, 0.0),
		"a curadoria tem de ganhar do sorteio, não o contrário")
	_conf("elegível + sorteio ruim = não é Alpha", not R.sortear(charizard, 0.99))

	# A fronteira exata, pra ninguém trocar < por <= sem perceber.
	_conf("o limite é exclusivo",
		R.sortear(charizard, R.CHANCE_BASE - 0.0001)
		and not R.sortear(charizard, R.CHANCE_BASE))

	# ── A janela de 3 horas ──
	var agora : float = 1_000_000.0
	var hora : float = 3600.0
	_conf("sem nenhum elite derrotado, a chance é a base",
		is_equal_approx(R.chance([], agora), R.CHANCE_BASE))
	_conf("três elites recentes dão exatamente +0,3%",
		is_equal_approx(R.chance([agora - 60.0, agora - 120.0, agora - 180.0], agora),
			R.CHANCE_BASE + 3.0 * R.BONUS_POR_ELITE),
		"%.4f" % R.chance([agora - 60.0, agora - 120.0, agora - 180.0], agora))
	_conf("elite de 4 horas atrás não conta mais",
		is_equal_approx(R.chance([agora - 4.0 * hora], agora), R.CHANCE_BASE),
		"a janela é o ponto: o bônus tem de expirar sozinho")
	_conf("elite de 2h59 ainda conta",
		R.chance([agora - (3.0 * hora - 60.0)], agora) > R.CHANCE_BASE)
	_conf("a fronteira da janela é exclusiva",
		is_equal_approx(R.chance([agora - 3.0 * hora], agora), R.CHANCE_BASE))
	_conf("relógio que anda pra trás não vira bônus eterno",
		is_equal_approx(R.chance([agora + hora], agora), R.CHANCE_BASE),
		"derrota no futuro contaria pra sempre, porque nunca sai da janela")

	# ── O teto (proposto por mim, confirmado por ele em 18/09) ──
	var muitas : Array = []
	for i in 500:
		muitas.append(agora - float(i))
	_conf("o bônus tem teto", R.chance(muitas, agora) <= R.CHANCE_MAXIMA,
		"sem teto, 500 elites levariam a chance a 50,5%% e a raridade sumiria")
	_conf("e o teto é bem maior que a base", R.CHANCE_MAXIMA > R.CHANCE_BASE * 2.0)

	# ── O perigo da zona escala os dois pela mesma régua ──
	_conf("em zona sem perigo nenhum, Alpha não nasce",
		R.chance([], agora, 0.0) == 0.0,
		"se não escalasse, um Alpha apareceria em Pallet Town, onde elite é 0%")
	_conf("o perigo escala proporcionalmente",
		is_equal_approx(R.chance([], agora, 0.5), R.CHANCE_BASE * 0.5))
	_conf("perigo acima de 1 não estoura a conta",
		is_equal_approx(R.chance([], agora, 9.0), R.CHANCE_BASE))
	_conf("o teto é da raridade, não do produto",
		R.chance(muitas, agora, 1.0) > R.chance(muitas, agora, 0.5))

# ──────────────────────────────────────────────────────────────────────────────
# 3. O que muda quando é
# ──────────────────────────────────────────────────────────────────────────────

func _o_que_muda() -> void:
	print("\n-- §30: +35% nos seis, e um número só --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")
	var B = load("res://scripts/gameplay_v2/BalanceV2.gd")
	var C = load("res://scripts/combat/CombatBalance.gd")

	var base := {"hp": 100, "attack": 100, "defense": 100,
		"sp_atk": 100, "sp_def": 100, "speed": 100}
	var forte : Dictionary = R.stats(base)
	_conf("os seis stats sobem", forte.size() == base.size()
		and forte.values().all(func(v): return int(v) > 100))

	# O ponto da §30: UM multiplicador, não seis. Se algum dia virar uma tabela
	# por stat, esta linha reprova — que é o que ela existe pra fazer.
	var distintos : Array = []
	for chave in forte:
		if not (int(forte[chave]) in distintos):
			distintos.append(int(forte[chave]))
	_conf("com a mesma base, os seis dão o MESMO número", distintos.size() == 1,
		"um '+35%% em tudo' vira seis números diferentes sem ninguém perceber: %s"
			% str(distintos))

	_conf("o multiplicador não é redeclarado aqui — vem do BalanceV2",
		int(forte["hp"]) == B.alpha(100))
	_conf("e a régua medida da V1 continua existindo, diferente, sem ser usada",
		C.ALPHA_HP_MULT != B.ALPHA_MULT,
		"são duas réguas de verdade; a §30 é que decide qual vale")

	_conf("um stat de valor 1 não vira 0", int((R.stats({"hp": 1}) as Dictionary)["hp"]) >= 1)

	_conf("a escala visual vem do BalanceV2", R.escala_visual() == B.ALPHA_ESCALA_VISUAL)
	_conf("e é maior que 1 — um Alpha se reconhece de longe", R.escala_visual() > 1.0)

	var p : Dictionary = R.perfil(true)
	var comum : Dictionary = R.perfil(false)
	_conf("o perfil do Alpha traz a categoria de golpes dele",
		str(p["categoria"]) == R.CATEGORIA)
	_conf("o de quem não é Alpha não muda nada",
		str(comum["categoria"]) == RegraDeMovePool.CATEGORIA_PADRAO
		and float(comum["escala"]) == 1.0 and bool(comum["capturavel"]))

	# A faixa de golpes do Alpha já existia desde a Fase 3 — esta fase liga.
	var K = load("res://scripts/combat/KitDeCombate.gd")
	_conf("Alpha carrega mais golpes que um selvagem comum",
		K.slots_de_selvagem(6, 30, R.CATEGORIA, _especies)
		> K.slots_de_selvagem(6, 30, "comum", _especies),
		"ser miniboss é brigar diferente, não só ter números maiores")

# ──────────────────────────────────────────────────────────────────────────────
# 4. Obstáculo, não troféu
# ──────────────────────────────────────────────────────────────────────────────

func _captura_e_loot() -> void:
	print("\n-- §30: não se captura, e o drop não obedece à sorte --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")

	var nao : Dictionary = R.pode_capturar(true)
	_conf("Alpha não pode ser capturado", not bool(nao["pode"]))
	_conf("e o jogador ouve por quê", not str(nao["motivo"]).is_empty(),
		str(nao["motivo"]))
	_conf("um selvagem comum pode", bool((R.pode_capturar(false) as Dictionary)["pode"]))

	# §30: o drop exclusivo ignora Luck. Sorteios cravados nos dois casos.
	var sorteios := [0.99, 0.01, 0.01]
	var sem_sorte : Array = R.loot(30, true, 0, sorteios)
	var com_sorte : Array = R.loot(30, true, 999, sorteios)
	_conf("o Alpha larga o drop exclusivo", sem_sorte.size() > 0)
	_conf("e a sorte NÃO muda o que é exclusivo dele",
		str(sem_sorte) == str(com_sorte),
		"se mudasse, especializar em sorte viraria obrigatório: %s vs %s"
			% [str(sem_sorte), str(com_sorte)])
	_conf("quem não é Alpha não larga o exclusivo",
		(R.loot(30, false, 0, sorteios) as Array).size()
		< (sem_sorte as Array).size())

# ──────────────────────────────────────────────────────────────────────────────
# Com corpo de verdade: o Alpha passa a existir
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
	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")

	var comum = P.nascer(mundo, 6, 60, Vector3(0, 2, 0), "ground_biped")
	var chefe = P.nascer(mundo, 6, 60, Vector3(30, 2, 30), "ground_biped",
		RegraDeMovePool.CATEGORIA_PADRAO, true)

	# 🔴 A conferência que define a fase: antes dela, nenhum Alpha nascia.
	_conf("um Alpha nasce, e se declara", chefe.alpha and not comum.alpha,
		"o `is_alpha` da V2 não era ligado por NADA no repositório")
	_conf("o Alpha tem mais vida que o mesmo bicho no mesmo nível",
		chefe.vida_maxima > comum.vida_maxima,
		"%d vs %d" % [chefe.vida_maxima, comum.vida_maxima])
	_conf("a vida nasce cheia mesmo depois do multiplicador",
		chefe.vida == chefe.vida_maxima,
		"aplicar o Alpha depois da vida deixaria a barra discordando do stat")
	# ⚠️ As bases vêm do JSON que este teste já leu, não de `GameData`:
	# autoload **não é identificador** num teste `--script`. É a terceira vez
	# que essa armadilha aparece (RNGManager/Fase 11, PonteDeFeedback/Fase 13)
	# — e aqui ela derrubou o arquivo inteiro na compilação, que é o jeito bom
	# de ela falhar.
	var bases : Dictionary = (_especies.get("6", {}) as Dictionary).get("base_stats", {})
	_conf("e bate exatamente com a regra, sem conta nova na entidade",
		chefe.vida_maxima == BalanceV2.vida(int((R.stats(
			StatsDePokemon.conjunto(bases, 60)) as Dictionary)["hp"])))

	_conf("o Alpha é maior", chefe.altura_real > comum.altura_real,
		"%.2f m vs %.2f m" % [chefe.altura_real, comum.altura_real])
	_conf("o Alpha não é capturável, e o comum é",
		not chefe.capturavel and comum.capturavel)
	# ⚠️ Nível 60, não 30: no 30 o learnset do Charizard só oferece 5 golpes, e
	# os DOIS ficariam em 5 — limitados pelo pool, não pelos slots. A primeira
	# versão desta linha reprovou por isso, com a regra certa.
	_conf("o Alpha carrega o kit de miniboss",
		(chefe.kit as Array).size() > (comum.kit as Array).size(),
		"%d vs %d golpes" % [(chefe.kit as Array).size(), (comum.kit as Array).size()])
	_conf("e o kit dele não é vazio", (chefe.kit as Array).size() > 0)

	# A curadoria avisa quando alguém força um Alpha que não devia existir —
	# avisa, não corrige: corrigir calado esconderia o erro de quem chamou.
	var caterpie = P.nascer(mundo, 10, 10, Vector3(60, 2, 60), "ground_biped",
		RegraDeMovePool.CATEGORIA_PADRAO, true)
	_conf("forçar Alpha em espécie não elegível ainda produz o corpo",
		caterpie != null and caterpie.alpha,
		"a regra avisa; quem decide o spawn é o spawner, e ele consulta a curadoria")

	_contagem_de_elites(mundo)

## O laço que faz o bônus existir de verdade: elite cai → contagem sobe →
## chance sobe → a janela esquece sozinha. Cada elo separado, porque é assim
## que se descobre QUAL deles quebrou.
func _contagem_de_elites(mundo: Node3D) -> void:
	print("\n-- o bônus, ponta a ponta --")
	var R = load("res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")
	var S = load("res://scripts/gameplay_v3/mundo/SpawnerSelvagem3D.gd")
	var spawner = S.new()
	mundo.add_child(spawner)

	# Relógio injetado: três horas de espera não cabem num teste.
	var relogio := {"t": 1_000_000.0}
	spawner.agora = func(): return float(relogio["t"])

	_conf("o spawner começa sem elite nenhum na conta",
		spawner.derrotas_de_elite.is_empty())

	spawner.registrar_elite_derrotado()
	spawner.registrar_elite_derrotado()
	_conf("dois elites caídos entram na conta",
		spawner.derrotas_de_elite.size() == 2)
	_conf("e a chance sobe exatamente +0,2%",
		is_equal_approx(R.chance(spawner.derrotas_de_elite, float(relogio["t"])),
			R.CHANCE_BASE + 2.0 * R.BONUS_POR_ELITE))

	# Passam 4 horas. O bônus tem de sumir sozinho, sem ninguém limpar.
	relogio["t"] += 4.0 * 3600.0
	_conf("depois de 4 horas a chance volta à base",
		is_equal_approx(R.chance(spawner.derrotas_de_elite, float(relogio["t"])),
			R.CHANCE_BASE))

	# E a lista não fica crescendo pra sempre por trás.
	spawner.registrar_elite_derrotado()
	_conf("a lista esquece o que saiu da janela",
		spawner.derrotas_de_elite.size() == 1,
		"guardar derrota velha é memória vazando devagar: %d"
			% spawner.derrotas_de_elite.size())

	# 🔴 A lista é compartilhável POR REFERÊNCIA — é o que permite dois
	# spawners contarem juntos. Se a limpeza reatribuísse em vez de limpar no
	# lugar, eles se separariam em silêncio na primeira limpeza.
	var compartilhada : Array = spawner.derrotas_de_elite
	relogio["t"] += 4.0 * 3600.0
	spawner.registrar_elite_derrotado()
	_conf("a limpeza não troca a lista por outra",
		compartilhada.size() == spawner.derrotas_de_elite.size()
		and compartilhada == spawner.derrotas_de_elite,
		"dois spawners que compartilhavam a contagem deixariam de compartilhar")

## A guarda da Fase 16: teste que aborta calado é teste que passa mentindo.
const CONFERENCIAS_ESPERADAS : int = 58

func _terminar() -> void:
	var total : int = ok + fail
	if total < CONFERENCIAS_ESPERADAS:
		fail += 1
		print("  FALHOU  só %d de %d conferências rodaram — alguma abortou calada"
			% [total, CONFERENCIAS_ESPERADAS])
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
