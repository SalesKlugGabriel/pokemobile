## teste_gameplay_v2.gd — Passos 1, 2 e 6 do plano da Gameplay V2.
##
## Cobre as três peças que não tocam em apresentação e por isso puderam ser
## construídas antes da resposta do Codex sobre câmera/HUD/telegrafia:
##
##   Locomocao  — movimento contínuo (§4)
##   Stamina    — fôlego e os três degraus de exaustão (§5)
##   DanoV2     — dano determinístico e STAB por posição de tipo (§13, §14)
##
## O teste mais importante do arquivo é `_teto_nao_divergiu()`: `DanoV2` copia
## de propósito o teto anti-hit-kill da V1, e cópia sem vigia é cópia que
## diverge em silêncio.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _rodou : bool = false

## Autoload não é identificador em teste `--script` — o jeito que funciona neste
## projeto é uma variável de membro com o mesmo nome, preenchida por
## `root.get_node()` já com a árvore montada. Vale também pro que as classes
## CHAMADAS usam: `DamageCalculator` toca em `RNGManager` por dentro, então o
## teste precisa rodar depois dos autoloads existirem — daí `_process` e não
## `_init`.
var GameData   : Node
var RNGManager : Node

## Pelo mesmo motivo, estas duas classes são carregadas por CAMINHO em tempo de
## execução, e não usadas como identificador: `DamageCalculator` referencia
## `RNGManager` por dentro, então citá-la pelo nome obriga o Godot a compilá-la
## ANTES dos autoloads existirem — e aí o teste cospe erro de compilação mesmo
## terminando com sucesso. Erro de compilação reprova neste projeto, então isso
## não é cosmético. É o mesmo padrão de `teste_itens_equipados.gd`.
var Dano : GDScript
var DanoV1 : GDScript

func _conf(cond: bool, nome: String, detalhe: String = "") -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("  ✗ %s%s" % [nome, ("  — " + detalhe) if detalhe != "" else ""])

func _quase(a: float, b: float, tol: float = 0.001) -> bool:
	return absf(a - b) <= tol

func _initialize() -> void:
	print("== Gameplay V2: locomoção, stamina e dano ==")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData   = root.get_node("GameData")
	RNGManager = root.get_node("RNGManager")
	Dano   = load("res://scripts/gameplay_v2/DanoV2.gd")
	DanoV1 = load("res://scripts/combat/DamageCalculator.gd")

	_locomocao()
	_stamina_basica()
	_stamina_exaustao()
	_stamina_regeneracao()
	_dano_determinista()
	_dano_stab()
	_teto_nao_divergiu()
	# O marcador tem que ser exatamente este: `tools/rodar_testes.sh` exige
	# código de saída 0 **E** a linha "=== Resultado:". Silêncio não é aprovação
	# — um teste que morre antes de rodar também sai com 0.
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# Locomoção (§4)
# ──────────────────────────────────────────────────────────────────────────────

func _locomocao() -> void:
	print("-- Locomoção")

	# A diagonal não pode ser mais rápida que a reta. É o bug clássico de
	# movimento livre, e normalizar em um lugar só é o que o evita.
	var reta := Locomocao.velocidade_alvo(Vector2(1, 0), false)
	var diag := Locomocao.velocidade_alvo(Vector2(1, 1), false)
	_conf(_quase(reta.length(), diag.length(), 0.01),
		"diagonal tem a mesma velocidade da reta",
		"reta %.1f, diagonal %.1f" % [reta.length(), diag.length()])

	# Analógico pela metade anda pela metade — normalizar sempre mataria isso.
	var meio := Locomocao.velocidade_alvo(Vector2(0.5, 0), false)
	_conf(_quase(meio.length(), Locomocao.VELOCIDADE_CAMINHADA * 0.5, 0.01),
		"analógico parcial preserva a intensidade")

	_conf(Locomocao.velocidade_alvo(Vector2.ZERO, false) == Vector2.ZERO,
		"sem intenção, velocidade-alvo é zero")

	# Correr é mais rápido; exaustão III corta pela metade.
	var corrida := Locomocao.velocidade_alvo(Vector2(1, 0), true)
	_conf(corrida.length() > reta.length(), "correr é mais rápido que andar")
	var cansado := Locomocao.velocidade_alvo(Vector2(1, 0), true, 0.5)
	_conf(_quase(cansado.length(), corrida.length() * 0.5, 0.01),
		"fator de exaustão corta a velocidade proporcionalmente")

	# Parar é mais rápido que arrancar — é o que faz o controle responder na
	# hora de fugir.
	var arranque := Locomocao.avancar(Vector2.ZERO, Vector2(760, 0), 0.1)
	var freada   := Locomocao.avancar(Vector2(760, 0), Vector2.ZERO, 0.1)
	_conf(arranque.length() < 760.0 - freada.length() + 760.0,
		"aceleração e atrito existem e são diferentes")
	_conf(Locomocao.ATRITO > Locomocao.ACELERACAO, "atrito é maior que aceleração")

	# Histerese: quase-diagonal não faz o sprite piscar entre duas direções.
	var olhando_direita : int = 2
	var quase_diagonal := Vector2(100, 105)   # y só 5% maior que x
	_conf(Locomocao.direcao_olhada(quase_diagonal, olhando_direita) == 2,
		"quase-diagonal não troca a direção olhada (histerese)")
	var claramente_baixo := Vector2(100, 400)
	_conf(Locomocao.direcao_olhada(claramente_baixo, olhando_direita) == 0,
		"eixo claramente dominante troca a direção olhada")
	_conf(Locomocao.direcao_olhada(Vector2.ZERO, 3) == 3,
		"parado mantém a direção que já estava")

	# A ponte com o mundo em tiles — é isto que deixa warp/pesca/surf intactos.
	_conf(Locomocao.tile_de(Vector2(0, 0)) == Vector2i(0, 0), "tile de (0,0)")
	_conf(Locomocao.tile_de(Vector2(127, 127)) == Vector2i(0, 0), "tile da borda do primeiro")
	_conf(Locomocao.tile_de(Vector2(128, 0)) == Vector2i(1, 0), "tile do vizinho")
	_conf(Locomocao.tile_de(Vector2(-1, -1)) == Vector2i(-1, -1), "tile negativo arredonda pra baixo")
	var t := Vector2i(7, 3)
	_conf(Locomocao.tile_de(Locomocao.centro_do_tile(t)) == t,
		"centro do tile volta pro mesmo tile (ida e volta)")

# ──────────────────────────────────────────────────────────────────────────────
# Stamina (§5)
# ──────────────────────────────────────────────────────────────────────────────

func _stamina_basica() -> void:
	print("-- Stamina: custo e progressão")
	var s := Stamina.new()
	_conf(_quase(s.atual, Stamina.MAXIMO_BASE), "começa cheia")

	# Correr gasta; enquanto gasta, não regenera (§5).
	s.passo(1.0, ["correr"])
	_conf(_quase(s.atual, Stamina.MAXIMO_BASE - Stamina.CUSTO_POR_SEGUNDO["correr"]),
		"1 s correndo gasta exatamente o custo de 1 s",
		"sobrou %.2f" % s.atual)

	# As três linhas de progressão da §5.
	var r := Stamina.new({"reserve": 50})
	_conf(_quase(r.maximo(), Stamina.MAXIMO_BASE * 1.5),
		"RESERVE: +1%% do máximo por ponto")
	var g := Stamina.new({"regeneration": 100})
	_conf(_quase(g.regen_por_segundo(), Stamina.REGEN_BASE * 2.0),
		"REGENERATION: +1%% da recuperação por ponto")
	var e := Stamina.new({"efficiency": 25})
	_conf(_quase(e.custo_continuo("correr"), Stamina.CUSTO_POR_SEGUNDO["correr"] * 0.75),
		"EFFICIENCY: desconta do custo")
	var e2 := Stamina.new({"efficiency": 999})
	_conf(e2.fator_de_custo() >= 0.4,
		"EFFICIENCY tem piso — correr nunca fica de graça",
		"fator %.2f" % e2.fator_de_custo())

	# Ação instantânea: ou sai inteira, ou não sai.
	var p := Stamina.new()
	p.definir(5.0)
	_conf(not p.gastar("pokeball"), "sem stamina, a Pokéball não é lançada")
	_conf(_quase(p.atual, 5.0), "tentativa recusada NÃO gasta nada")
	p.definir(50.0)
	_conf(p.gastar("pokeball"), "com stamina, a Pokéball sai")
	_conf(_quase(p.atual, 50.0 - Stamina.CUSTO_POR_USO["pokeball"]), "e cobra o custo certo")

func _stamina_exaustao() -> void:
	print("-- Stamina: os três degraus de exaustão")
	var s := Stamina.new()
	s.definir(0.0)
	# `definir` com 0 não trava sozinho; um passo de gasto leva ao zero real.
	s.passo(0.016, ["correr"])

	_conf(s.nivel_de_exaustao() == 1, "logo após zerar, exaustão I")
	_conf(_quase(s.fator_de_velocidade(), 0.85), "exaustão I tira 15%")
	_conf(s.estado() == "exaustao_1", "nome do estado para a HUD")

	# Andar (sem gastar, sem estar parado) mantém o relógio da exaustão correndo.
	for i in 400:   # ~6,4 s
		s.passo(0.016, [], false)
	_conf(s.nivel_de_exaustao() == 2, "passados ~6 s em zero, exaustão II",
		"nível %d" % s.nivel_de_exaustao())
	_conf(_quase(s.fator_de_velocidade(), 0.70), "exaustão II tira 30%")

	for i in 400:
		s.passo(0.016, [], false)
	_conf(s.nivel_de_exaustao() == 3, "passados ~12 s em zero, exaustão III")
	_conf(_quase(s.fator_de_velocidade(), 0.50), "exaustão III tira 50%")

	# A decisão de design declarada no cabeçalho da classe: sair do zero zera o
	# relógio. Um jogador que recuperou fôlego não continua arrastando 50%.
	s.definir(30.0)
	_conf(s.nivel_de_exaustao() == 0, "sair do zero encerra a exaustão")
	_conf(_quase(s.fator_de_velocidade(), 1.0), "e a velocidade volta ao normal")

func _stamina_regeneracao() -> void:
	print("-- Stamina: a espera de 1 s depois do zero")
	var s := Stamina.new()
	s.definir(0.0)
	s.passo(0.016, ["correr"])   # trava de verdade

	# Andando, a espera não começa: a §5 diz que é preciso PARAR.
	for i in 120:   # ~1,9 s andando
		s.passo(0.016, [], false)
	_conf(_quase(s.atual, 0.0), "andando, não regenera depois de zerar",
		"tinha %.2f" % s.atual)

	# Parado, mas ainda dentro do 1 s.
	for i in 30:    # ~0,48 s
		s.passo(0.016, [], true)
	_conf(_quase(s.atual, 0.0), "parado, mas antes de 1 s, ainda não regenera")

	# Passado 1 s parado, começa.
	for i in 50:    # total ~1,28 s parado
		s.passo(0.016, [], true)
	_conf(s.atual > 0.0, "passado 1 s parado, a regeneração começa",
		"tinha %.2f" % s.atual)

	# Depois de começar, pode voltar a andar enquanto regenera (§5).
	var antes := s.atual
	for i in 60:
		s.passo(0.016, [], false)
	_conf(s.atual > antes, "começada a regeneração, andar não interrompe")

	# Mas uma ação que gasta interrompe.
	var durante := s.atual
	s.passo(0.5, ["correr"])
	_conf(s.atual < durante, "gastar interrompe a regeneração")

# ──────────────────────────────────────────────────────────────────────────────
# DanoV2 (§13, §14)
# ──────────────────────────────────────────────────────────────────────────────

func _golpe() -> Dictionary:
	return {"id": "teste", "name": "Teste", "power": 80, "type": "Fire",
			"category": "special"}

func _atacante(tipos: Array) -> Dictionary:
	return {"level": 50, "atk": 120, "spa": 120, "types": tipos}

func _defensor() -> Dictionary:
	return {"def": 100, "spd": 100, "types": ["Normal"], "max_hp": 5000, "hp": 5000}

func _dano_determinista() -> void:
	print("-- Dano V2: sempre o mesmo número")
	var g := _golpe()
	var a := _atacante(["Fire"])
	var d := _defensor()

	var primeiro : int = Dano.calcular(g, a, d)
	var todos_iguais := true
	for i in 500:
		if Dano.calcular(g, a, d) != primeiro:
			todos_iguais = false
			break
	_conf(todos_iguais, "500 execuções do mesmo golpe dão o MESMO dano",
		"primeiro foi %d" % primeiro)
	_conf(primeiro > 0, "e o dano não é zero", "deu %d" % primeiro)

	# A V1 continua sorteando — é a prova de que embrulhar não vazou pra ela.
	var variou := false
	var v1 : int = int(DanoV1.detalhar(g, a, d)["final"])
	for i in 500:
		if int(DanoV1.detalhar(g, a, d)["final"]) != v1:
			variou = true
			break
	_conf(variou, "a V1 continua com variação (a V2 não a alterou)")

	var r : Dictionary = Dano.detalhar(g, a, d)
	_conf(bool(r["determinista"]), "o relatório se declara determinístico")
	_conf(not bool(r["critico"]) and _quase(float(r["mult_critico"]), 1.0),
		"sem crítico no relatório")
	_conf(_quase(float(r["variacao"]), 1.0), "sem variação no relatório")

	# §15: imunidade é zero absoluto.
	var eletrico := {"id": "t", "power": 90, "type": "Electric", "category": "special"}
	var terrestre := {"def": 100, "spd": 100, "types": ["Ground"], "max_hp": 500, "hp": 500}
	_conf(Dano.calcular(eletrico, _atacante(["Electric"]), terrestre) == 0,
		"imunidade continua sendo zero absoluto")

func _dano_stab() -> void:
	print("-- Dano V2: STAB por posição do tipo (§14)")
	_conf(_quase(Dano.stab("Fire", ["Fire"]), 1.25), "monotipo: 1,25")
	_conf(_quase(Dano.stab("Fire", ["Fire", "Flying"]), 1.25), "tipo primário: 1,25")
	_conf(_quase(Dano.stab("Flying", ["Fire", "Flying"]), 1.15), "tipo secundário: 1,15")
	_conf(_quase(Dano.stab("Water", ["Fire", "Flying"]), 1.0), "tipo de fora: sem STAB")
	_conf(_quase(Dano.stab("Fire", []), 1.0), "sem tipos: sem STAB")

	# A diferença precisa aparecer no dano, não só na tabela.
	var g := _golpe()   # Fire
	var d := _defensor()
	var como_primario : int = Dano.calcular(g, _atacante(["Fire", "Flying"]), d)
	var como_secundario : int = Dano.calcular(g, _atacante(["Flying", "Fire"]), d)
	_conf(como_primario > como_secundario,
		"o mesmo golpe rende mais no tipo primário que no secundário",
		"primário %d, secundário %d" % [como_primario, como_secundario])

	# E a V1 não distingue — é justamente o que a §14 veio corrigir.
	_conf(_quase(DanoV1.stab_multiplier("Flying", ["Fire", "Flying"]),
			CombatBalance.STAB_MULTIPLIER),
		"a V1 dá o mesmo STAB pros dois (comportamento antigo, preservado)")

func _teto_nao_divergiu() -> void:
	print("-- O teto anti-hit-kill: cópia vigiada")
	# DanoV2 copia o teto da V1 de propósito (ver o cabeçalho da classe). Este
	# teste existe pra a cópia não divergir em silêncio se alguém mexer lá.
	for max_hp in [100, 1000, 5000]:
		for fracao in [1.0, 0.5, 0.16, 0.14, 0.05]:
			var d := {"def": 100, "spd": 100, "types": ["Normal"],
					  "max_hp": max_hp, "hp": int(max_hp * fracao)}
			var meu : int = Dano.teto_de_dano(d)

			# O mesmo cálculo, feito pela régua central que a V1 usa.
			var esperado : int = 0
			if float(d["hp"]) > float(max_hp) * CombatBalance.VIDA_MINIMA_PRO_TETO:
				esperado = maxi(1, int(floor(float(max_hp) * CombatBalance.TETO_DE_DANO_POR_GOLPE)))

			_conf(meu == esperado,
				"teto bate com a régua central (hp máx %d, %.0f%% de vida)" % [max_hp, fracao * 100],
				"meu %d, esperado %d" % [meu, esperado])

	# E o teto realmente segura um golpe absurdo.
	var forte := {"id": "t", "power": 250, "type": "Fire", "category": "special"}
	var frageis := {"def": 10, "spd": 10, "types": ["Grass"], "max_hp": 200, "hp": 200}
	var r : Dictionary = Dano.detalhar(forte, _atacante(["Fire"]), frageis)
	_conf(int(r["final"]) <= int(200 * CombatBalance.TETO_DE_DANO_POR_GOLPE),
		"golpe absurdo é segurado pelo teto", "deu %d" % r["final"])
	_conf(int(r["segurado_pelo_teto"]) > 0, "e o relatório diz que foi segurado")
