## teste_v3_liga_no_save.gd — A V3 ligada no save de verdade (19/09).
##
## ── O que estava solto, e por que isto não era "esperar o save da V3" ───────
##
## O `QUADRO` dizia que três pendências minhas dependiam de "a V3 ter save". Ao
## abrir, o save **já existia**: `SaveManager` é autoload da V2, com mochila,
## time, MOs e até precedente pra estado de mundo (`defeated_alphas`). O que
## faltava não era construir — era **ligar**.
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **A permissão que some em silêncio.** O comentário do laboratório
##      apontava a chave `"items"`; a real é `"inventory"`. Ligar pelo que
##      estava escrito leria `{}`, e `permissoes_de({}, ...)` devolve `[]` —
##      falha fechada. O jogador perderia Surf e Voar **sem erro nenhum**, com
##      a tela dizendo "você não tem a MO", que é uma frase plausível.
##   2. **A bancada promovida a save.** Se a mochila do jogador estiver vazia,
##      a resposta certa é `[]`, não cair na mochila de teste — senão um save
##      legítimo ganha travessia que ninguém conquistou.
##   3. **O bônus de Alpha que evapora ao salvar.** A janela de 3 h vivia só em
##      memória; fechar o jogo zerava o que o jogador tinha acabado de ganhar.
##   4. **A lista trocada no carregar.** `derrotas_de_elite` é compartilhada
##      POR REFERÊNCIA entre spawners. Restaurar com `=` separaria dois
##      spawners em silêncio — o mesmo bug que já aconteceu uma vez aqui.
##   5. **O save antigo que quebra.** `load_game` faz `save_data = parsed`, uma
##      substituição crua: sem migração, a chave nova não existe em quem já
##      jogava.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 26

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

## ⚠️ `_initialize`, **não** `_init` — e agora eu sei a distinção exata, depois
## de cinco encontros com a mesma armadilha.
##
## `_init()` roda ANTES de os autoloads entrarem na árvore, então o identificador
## `GameData` ainda não existe e **qualquer script que o cite não compila** —
## inclusive um que eu só quero instanciar, como o `SpawnerSelvagem3D`. O erro
## sai como "Identifier not found" numa linha que não é a minha, e o arquivo
## segue rodando o resto, o que faz parecer bug do código sob teste.
##
## `_initialize()` roda depois. É por isso que o `teste_gameplay_v3_fase11` faz
## exatamente o mesmo `load()` deste spawner e passa.
func _initialize() -> void:
	print("== A V3 ligada no save de verdade ==")

	_a_chave_certa()
	_permissoes_da_mochila()
	_janela_de_elite_no_save()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)

# ──────────────────────────────────────────────────────────────────────────────
# 1. A chave existe mesmo, e a errada não
# ──────────────────────────────────────────────────────────────────────────────

func _a_chave_certa() -> void:
	print("\n-- A chave da mochila --")

	# ⚠️ Lido do ARQUIVO, não do autoload: autoload não é identificador em teste
	# `--script` — a lição de quatro fases seguidas. Aqui eu quero justamente
	# conferir o dicionário padrão declarado no código-fonte.
	var fonte : String = FileAccess.get_file_as_string(
		"res://scripts/autoloads/SaveManager.gd")
	_conf("SaveManager foi lido", fonte.length() > 100)
	_conf('a mochila se chama "inventory"', fonte.contains('"inventory"'))
	_conf('e NÃO existe uma chave "items" no save',
		not fonte.contains('save_data["items"]'),
		'apareceu save_data["items"] — a chave errada voltou')
	_conf("a chave nova do Alpha está declarada",
		fonte.contains('"elites_derrotados"'))
	# A migração é obrigatória porque `load_game` substitui o dicionário inteiro.
	_conf("load_game substitui o dicionário cru (por isso migrar é obrigatório)",
		fonte.contains("save_data = parsed"))
	_conf("existe migração pra save antigo",
		fonte.contains("_migrar_elites_derrotados"))

# ──────────────────────────────────────────────────────────────────────────────
# 2. As permissões saem da mochila
# ──────────────────────────────────────────────────────────────────────────────

func _permissoes_da_mochila() -> void:
	print("\n-- Permissões: da mochila, não de uma lista cravada --")

	var Maq : GDScript = load("res://scripts/gameplay_v3/pokemon/RegraDeMaquina.gd")
	var catalogo : Dictionary = {}
	var cru = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/items/items.json"))
	if cru is Dictionary:
		catalogo = cru
	_conf("o catálogo de itens carrega", not catalogo.is_empty())

	# O formato da mochila da V2 é {id: quantidade} — o mesmo que o jogo usa.
	var com_as_duas : Array = Maq.permissoes_de({"hm02": 1, "hm04": 1}, catalogo)
	_conf("MO de Voar e de Surfar dão as duas travessias",
		Maq.TRAVESSIA_AR in com_as_duas and Maq.TRAVESSIA_AGUA in com_as_duas,
		str(com_as_duas))

	# 🔴 O cenário do bug: a chave errada devolveria isto, e sem erro nenhum.
	var vazia : Array = Maq.permissoes_de({}, catalogo)
	_conf("mochila vazia não concede nada (falha fechada)", vazia.is_empty(),
		str(vazia))
	_conf("uma poção não vira travessia",
		Maq.permissoes_de({"potion": 3}, catalogo).is_empty())
	# Quantidade zero é ter tido e gastado — não é ter.
	_conf("quantidade zero não concede",
		Maq.permissoes_de({"hm02": 0}, catalogo).is_empty())
	# E a lista simples também funciona, que é como a bancada chama.
	_conf("lista simples de ids também funciona",
		Maq.TRAVESSIA_AR in Maq.permissoes_de(["hm02"], catalogo))

	# O laboratório: declara de onde leu. Sem isso, bancada e save concedendo
	# a mesma coisa são indistinguíveis.
	var fonte_lab : String = FileAccess.get_file_as_string(
		"res://scripts/gameplay_v3/Laboratorio3D.gd")
	_conf("o laboratório lê a mochila real", fonte_lab.contains('"inventory"'))
	_conf("o laboratório declara a origem da permissão",
		fonte_lab.contains("origem_das_permissoes"))
	_conf("e usa get_node_or_null pro SaveManager, não o identificador",
		fonte_lab.contains('get_node_or_null("/root/SaveManager")'),
		"citar o autoload direto faz o arquivo não compilar em teste --script")

# ──────────────────────────────────────────────────────────────────────────────
# 3. A janela de 3 h atravessa o save
# ──────────────────────────────────────────────────────────────────────────────

func _janela_de_elite_no_save() -> void:
	print("\n-- A janela de 3 h do Alpha atravessa o salvar/carregar --")

	var Spawner : GDScript = load(
		"res://scripts/gameplay_v3/mundo/SpawnerSelvagem3D.gd")
	var Alpha : GDScript = load(
		"res://scripts/gameplay_v3/pokemon/RegraDeAlpha.gd")

	var s = Spawner.new()
	# Relógio injetado: o teste não pode depender do relógio da máquina, senão
	# ele passa hoje e reprova numa máquina com data diferente.
	var agora : float = 1_000_000.0
	s.agora = func(): return agora

	s.registrar_elite_derrotado(agora - 60.0)        # 1 min atrás
	s.registrar_elite_derrotado(agora - 3600.0)      # 1 h atrás
	s.registrar_elite_derrotado(agora - 4.0 * 3600.0)  # 4 h — fora da janela
	_conf("carimbo fora da janela já sai na hora de registrar",
		s.derrotas_de_elite.size() == 2, str(s.derrotas_de_elite.size()))

	var salvo : Array = s.para_o_save()
	_conf("o save leva só o que está dentro da janela", salvo.size() == 2,
		str(salvo))
	_conf("o que vai pro save é uma CÓPIA",
		not is_same(salvo, s.derrotas_de_elite),
		"salvar entregou a lista viva — quem mexer no save mexe no jogo")

	# Carregar noutro spawner.
	var outro = Spawner.new()
	outro.agora = func(): return agora
	# A referência que precisa sobreviver: dois spawners compartilhando a
	# contagem é o desenho da Fase 18.
	var lista_viva : Array = outro.derrotas_de_elite
	# (guardada antes de carregar, pra provar que o carregar não a troca)
	outro.do_save(salvo)
	_conf("carregar traz os 2 carimbos", outro.derrotas_de_elite.size() == 2)
	_conf("carregar preenche NO LUGAR, sem trocar a lista",
		is_same(lista_viva, outro.derrotas_de_elite),
		"a lista foi reatribuída — dois spawners se separariam em silêncio")

	# O bônus tem de ser o mesmo dos dois lados. É isso que o jogador sente.
	var antes : float = Alpha.chance(s.derrotas_de_elite, agora, 1.0)
	var depois : float = Alpha.chance(outro.derrotas_de_elite, agora, 1.0)
	print("   chance de Alpha: antes ", "%.4f" % antes, " · depois ",
		"%.4f" % depois)
	_conf("a chance de Alpha sobrevive ao salvar/carregar",
		is_equal_approx(antes, depois),
		("%.6f" % antes) + " x " + ("%.6f" % depois))
	_conf("e os 2 elites realmente valeram bônus",
		antes > Alpha.CHANCE_BASE, ("%.6f" % antes))

	# ⚠️ O tempo passa com o jogo FECHADO — é o ponto de usar carimbo Unix.
	# Quatro horas depois, os dois carimbos venceram e o bônus some sozinho.
	var muito_depois : float = agora + 4.0 * 3600.0
	var terceiro = Spawner.new()
	terceiro.agora = func(): return muito_depois
	terceiro.do_save(salvo)
	_conf("carimbo vencido é descartado ao carregar",
		terceiro.derrotas_de_elite.is_empty(),
		str(terceiro.derrotas_de_elite))
	_conf("e a chance volta pra base",
		is_equal_approx(Alpha.chance(terceiro.derrotas_de_elite, muito_depois, 1.0),
			Alpha.CHANCE_BASE))

	# Lixo no save não pode contaminar a janela.
	var sujo = Spawner.new()
	sujo.agora = func(): return agora
	sujo.do_save([agora - 10.0, "isto não é um carimbo", null, agora - 20.0])
	_conf("carimbo inválido é descartado, não contamina",
		sujo.derrotas_de_elite.size() == 2, str(sujo.derrotas_de_elite))
	sujo.do_save("nem isto é uma lista")
	_conf("save corrompido vira lista vazia, não erro",
		sujo.derrotas_de_elite.is_empty())

	s.free()
	outro.free()
	terceiro.free()
	sujo.free()
