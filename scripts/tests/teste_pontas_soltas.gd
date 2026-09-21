## teste_pontas_soltas.gd — O alarme contra a peça que existe e não faz nada.
##
## ── Por que este arquivo existe ─────────────────────────────────────────────
##
## Em um mês eu achei **cinco** vezes a mesma classe de defeito, e todas as
## cinco por acidente, enquanto procurava outra coisa:
##
##   Fase 17 — o `kit` de golpes nascia `[]` e o único `.kit =` do repositório
##             estava dentro de um teste. Apertar a tecla não fazia nada.
##   Fase 18 — `is_alpha` era um `@export` que **nada** ligava: nenhum Alpha
##             jamais nasceu no jogo, e 151 espécies curadas à mão não eram
##             lidas por ninguém.
##   Fase 21 — a ação `pokeball` já existia no InputMap, sem leitor.
##   Fase 21b— `PokebolaLancada3D.resolveu` era emitido e **ninguém escutava**:
##             o jogador capturava e o Pokémon evaporava.
##   21/09  — `HudCombate3D.gd` existe e **nenhuma cena o instancia**.
##
## Nenhuma dessas dá erro. Nenhuma reprova teste. O código está lá, parece
## certo, e o jogo simplesmente não faz aquilo. **É o formato de defeito deste
## projeto**, e cinco achados por acidente é sorte, não método.
##
## ── O que este teste faz, e o que ele NÃO faz ───────────────────────────────
##
## Ele **não** exige que todo sinal tenha ouvinte. Isso seria errado: metade dos
## sinais da V3 é de apresentação, e a HUD é do Codex — cobrar ouvinte agora
## reprovaria a suíte por trabalho que legitimamente ainda não existe.
##
## Ele exige que toda ponta solta esteja **declarada**, com motivo, na lista
## abaixo. A diferença é tudo: uma ponta declarada é uma pendência que alguém
## pode ler; uma ponta não declarada é silêncio. **Silêncio é o inimigo.**
##
## Um sinal novo sem ouvinte e sem declaração **reprova** — e a mensagem diz as
## duas saídas: ligue-o, ou escreva aqui por que ele ainda não tem ouvinte.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 6

## As pontas soltas CONHECIDAS da V3, e o motivo de cada uma.
##
## ⚠️ Toda linha aqui é uma dívida, não um perdão. Quando a HUD do Codex ligar
## um destes, a linha sai — e o teste continua protegendo o resto.
const DECLARADAS : Dictionary = {
	# ── Esperando a HUD de combate (Codex). Ver docs/agent-handoff.md.
	"vida_mudou": "barra de vida — HUD do Codex, ainda não instanciada em cena",
	"oxigenio_mudou": "medidor de ar do mergulho (Fase 14) — HUD do Codex",
	"afogou": "aviso de afogamento — HUD do Codex. O DANO já acontece em "
		+ "`_tick_travessia`; este sinal é só o aviso na tela",
	"stamina_mudou": "barra de fôlego — HUD do Codex",
	"capturou": "a mensagem da captura (Fase 21b) — HUD do Codex. A captura em "
		+ "si JÁ é guardada no save; este sinal só conta ao jogador",
	"corpo_deixado": "o relógio da §28 sobre o corpo — HUD do Codex",
	"errou": "a bola caiu sem acertar — HUD do Codex",
	"modo_mudou": "quem está no controle (treinador/Pokémon) — HUD do Codex",
	"transferencia_iniciada": "a transição de assumir o Pokémon — efeito do Codex",
	"transferencia_concluida": "idem",

	# ── Pontas de apresentação sem tela ainda, mas que não são combate.
	"comecou_a_andar": "passos e animação — o `PlayerVisual3D` do Codex hoje "
		+ "lê `estado_visual_de_locomocao()`, não este sinal",
	"parou": "idem",
	"desapareceu": "selvagem despejado por distância (Fase 11) — serve pra "
		+ "depuração e pra HUD de população; nada de gameplay depende dele",
}

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("== Pontas soltas: o que existe e não faz nada ==")
	_sinais_sem_ouvinte()
	_pecas_sem_cena()
	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)

# ──────────────────────────────────────────────────────────────────────────────

## Todos os arquivos que podem LIGAR um sinal: código e cena.
##
## ⚠️ As três formas contam, e esquecer uma produz falso alarme: `x.connect(`,
## `connect("x",` e a linha `[connection signal="x"]` de um `.tscn`. A primeira
## versão deste teste só via a primeira, e acusou 60 sinais soltos onde havia 51.
func _tudo_que_liga() -> Dictionary:
	var liga : Dictionary = {}
	for p in _arquivos(["scripts", "scenes"], [".gd", ".tscn"]):
		var t : String = FileAccess.get_file_as_string(p)
		for r in [RegEx.create_from_string(r"(\w+)\.connect\("),
				RegEx.create_from_string(r'connect\(\s*"(\w+)"'),
				RegEx.create_from_string(r'\[connection signal="(\w+)"')]:
			for m in r.search_all(t):
				liga[m.get_string(1)] = true
	return liga

func _arquivos(pastas: Array, exts: Array) -> Array:
	var fora : Array = []
	var fila : Array = pastas.duplicate()
	while not fila.is_empty():
		var d : String = "res://" + str(fila.pop_back())
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			var cheio : String = d + "/" + n
			if dir.current_is_dir():
				fila.append(cheio.replace("res://", ""))
			else:
				for e in exts:
					if n.ends_with(str(e)):
						fora.append(cheio)
			n = dir.get_next()
		dir.list_dir_end()
	return fora

## A peça é citada por ALGUÉM que não seja ela mesma?
func _usada_fora(base: String, proprio: String, _usadas: Dictionary) -> bool:
	var re := RegEx.create_from_string("\\b" + base + "\\b")
	for p in _arquivos(["scenes", "scripts"], [".tscn", ".gd"]):
		if p == proprio or p.contains("/tests/"):
			continue
		if re.search(FileAccess.get_file_as_string(p)) != null:
			return true
	return false

func _sinais_sem_ouvinte() -> void:
	print("\n-- Sinais da V3 sem ninguém escutando --")

	var liga : Dictionary = _tudo_que_liga()
	_conf("a varredura achou conexões de verdade", liga.size() > 10,
		str(liga.size()) + " nomes ligados — a busca não está enxergando")

	var re_sig := RegEx.create_from_string("(?m)^signal\\s+(\\w+)")
	var soltos : Array = []
	var total : int = 0
	for p in _arquivos(["scripts/gameplay_v3"], [".gd"]):
		var t : String = FileAccess.get_file_as_string(p)
		for m in re_sig.search_all(t):
			var nome : String = m.get_string(1)
			total += 1
			if not liga.has(nome):
				soltos.append([nome, p])

	print("   ", total, " sinais na V3 · ", soltos.size(), " sem ouvinte")
	_conf("a V3 declara sinais", total > 5)

	# 🔴 A conferência que dá nome ao arquivo.
	var nao_declarados : Array = []
	for s in soltos:
		if not DECLARADAS.has(str(s[0])):
			nao_declarados.append("%s (%s)" % [s[0], str(s[1]).get_file()])
	_conf("toda ponta solta está DECLARADA com motivo",
		nao_declarados.is_empty(),
		"\n       sem declaração: " + ", ".join(nao_declarados)
			+ "\n       → ligue o sinal, OU escreva em DECLARADAS por que ele "
			+ "ainda não tem ouvinte. Silêncio não é opção.")

	# E o simétrico: uma declaração que sobrou é ruído. Quando o Codex ligar a
	# HUD, as linhas têm de sair — senão a lista vira um cemitério que ninguém
	# confia, e aí ela para de proteger.
	var sobrando : Array = []
	for nome in DECLARADAS.keys():
		if liga.has(str(nome)):
			sobrando.append(str(nome))
	_conf("nenhuma declaração sobrando (sinal que JÁ foi ligado)",
		sobrando.is_empty(),
		"já têm ouvinte, tire de DECLARADAS: " + ", ".join(sobrando))

	print("   dívida declarada hoje: ", DECLARADAS.size(), " pontas — a maioria "
		+ "esperando a HUD do Codex")

# ──────────────────────────────────────────────────────────────────────────────

func _pecas_sem_cena() -> void:
	print("\n-- Peças que existem e nenhuma cena usa --")

	# 🔴 `scripts/tests/` fica FORA desta conta, e é o ponto do arquivo inteiro.
	#
	# Um teste que instancia a peça faz ela **parecer** usada. Foi exatamente
	# assim que o kit vazio sobreviveu às Fases 9 a 16: os testes sempre
	# injetavam o kit à mão, então tudo passava e o jogo não tinha golpe
	# nenhum. Contar teste como uso seria construir o mesmo ponto cego de novo,
	# agora dentro da ferramenta que existe pra achá-lo.
	#
	# A primeira versão deste teste incluía `scripts/tests` e deu `HudCombate3D`
	# como usada — ela é instanciada só pelo teste do Codex, e nenhuma cena a
	# põe no jogo.
	var usadas : Dictionary = {}
	for p in _arquivos(["scenes", "scripts"], [".tscn", ".gd"]):
		if p.contains("/tests/"):
			continue
		var t : String = FileAccess.get_file_as_string(p)
		# As três formas de usar uma peça: pelo caminho, instanciando, e — o
		# caso das classes puras — **só citando o nome**. `RegraDeArremesso`
		# nunca é `.new()` nem carregada por caminho: ela é chamada
		# estaticamente, e ignorar isso acusa toda regra pura de órfã.
		for r in [RegEx.create_from_string(r'res://([^"\'\)\s]+\.gd)'),
				RegEx.create_from_string(r"\b([A-Z]\w+)\.new\("),
				RegEx.create_from_string(r"\b([A-Z][A-Za-z0-9_]{3,})\b")]:
			for m in r.search_all(t):
				var nome : String = m.get_string(1)
				usadas[nome.get_file().get_basename()] = true
				usadas[nome] = true

	# A apresentação da V3: é exatamente onde a HudCombate3D estava escondida.
	var orfas : Array = []
	for p in _arquivos(["scripts/gameplay_v3/presentation"], [".gd"]):
		var base : String = p.get_file().get_basename()
		# Citada pelo PRÓPRIO arquivo não conta: `class_name X` sempre aparece
		# lá dentro.
		if not _usada_fora(base, p, usadas):
			orfas.append(base)

	print("   órfãs em presentation/: ", ", ".join(orfas) if orfas.size() else "nenhuma")
	# ⚠️ Isto é um AVISO contado, não uma reprovação: a HUD é do Codex e ele
	# está ligando agora. O que o teste trava é o número não crescer sem
	# ninguém perceber.
	_conf("a apresentação da V3 não acumulou órfãs novas", orfas.size() <= 1,
		str(orfas) + " — peça que existe e nenhuma cena instancia")

	# E a trava que vale pra sempre: todo arquivo de regra da V3 é alcançado por
	# alguém. Uma regra órfã é uma decisão escrita que o jogo não toma.
	var regras_orfas : Array = []
	for p in _arquivos(["scripts/gameplay_v3"], [".gd"]):
		var base : String = p.get_file().get_basename()
		if base.begins_with("Regra") and not _usada_fora(base, p, usadas):
			regras_orfas.append(base)
	_conf("nenhuma REGRA da V3 está órfã", regras_orfas.is_empty(),
		str(regras_orfas) + " — regra escrita que ninguém chama é decisão que "
		+ "o jogo não toma")
