## Corpo3D.gd — O corpo que se pode capturar ou saquear, agora em 3D (Fase 21).
##
## ── O que mudou do `Corpo` da V2, e o que NÃO mudou ─────────────────────────
##
## A RFC da V3 lista `Corpo` entre os sistemas **adaptados**, com a frase que
## define este arquivo: *"a regra fica e a interface muda"*. Então:
##
## **NÃO mudou** — nada. `RegrasDeCorpo` é chamada sem uma linha alterada: a
## janela de 10 a 15 s, a tentativa única, a chance escondida, o teto de 95%, o
## Alpha incapturável, o loot sorteado no nascimento. Aquilo já estava provado.
##
## **Mudou** — três coisas, todas de interface:
##   1. `Node3D` em vez de `Node2D`, e a posição é onde o corpo caiu no mundo.
##   2. Ele nasce de um `PokemonInstance3D`, não de um `CombatenteV2`.
##   3. A captura deixou de ser um clique num cadáver na tela e passou a ser
##      **uma bola atravessando o espaço** — quem decide se ela chegou é
##      `RegraDeArremesso`; quem decide se pegou continua sendo `RegrasDeCorpo`.
##
## ── Por que o corpo copia tudo de quem caiu ─────────────────────────────────
##
## Porque o selvagem sai de cena. Guardar uma referência a ele seria depender de
## um nó que pode não existir mais quando a bola pousar — e a bola leva tempo pra
## chegar, de propósito. É a mesma razão do `Corpo` da V2, e vale mais aqui.
extends Node3D
class_name Corpo3D

signal mudou(id: int, estado: Dictionary)
signal removido(id: int, motivo: String)

var dados : Dictionary = {}
var _restante : float = 0.0
var _avisou : bool = false

## O raio do corpo como alvo. Sai da altura jogável de quem caiu: um Onix
## comprimido é um alvo maior que um Caterpie, e ignorar isso faria a bola
## atravessar o meio de um bicho enorme sem acertar.
var raio_de_alvo : float = 0.6

## Sorteio injetável — a mesma disciplina do spawner. Sem isto, o teste
## dependeria de sorte pra passar, e um teste que reprova por sorteio ensina a
## ignorar vermelho.
var sortear : Callable = _sortear_padrao

func _sortear_padrao() -> float:
	var rng := get_node_or_null("/root/RNGManager")
	return rng.randf() if rng != null else randf()

# ──────────────────────────────────────────────────────────────────────────────

## Nasce onde o Pokémon caiu. Tudo que a captura precisa é copiado AGORA.
##
## ⚠️ `static` e recebendo o pai: é o contrato de nascimento da Fase 11 — a
## posição é escrita ANTES de entrar na árvore, senão o corpo passa um quadro na
## origem do mundo e a física catapulta quem estiver lá.
## `de_quem` é `Node3D` e não `PokemonInstance3D`: o corpo lê quatro campos e
## copia, então depender da **forma** em vez do nome mantém as duas soltas — e
## de quebra permite testar o corpo sem subir uma entidade inteira.
##
## ⚠️ Eu cheguei a escrever aqui que o tipo concreto causava dependência cíclica.
## **Estava errado, e medi:** `PokemonInstance3D.new()` pelo identificador já
## travava num teste `--script` **antes** desta fase existir (conferido com
## `git stash`). É por isso que todo teste do projeto carrega a entidade com
## `load()`. O acoplamento frouxo aqui continua valendo pelos motivos acima —
## só não foi ele que resolveu nada.
## ⚠️ `sorteio` entra pelo NASCIMENTO, e não depois.
##
## O `_ready` — que é quem sorteia o loot — dispara **dentro** do `add_child`
## quando o pai já está na árvore. Um teste que criasse o corpo e só então
## trocasse `sortear` chegaria tarde, e o resultado sairia diferente a cada
## execução. Foi o que aconteceu ao escrever `teste_loot_chega_na_mochila`: uma
## rodada largou poção, a seguinte não largou nada. Teste que reprova por
## sorteio ensina a ignorar vermelho.
static func nascer(pai: Node, de_quem: Node3D,
		sorteio_de_duracao: float, sorteio: Callable = Callable()) -> Corpo3D:
	var c := Corpo3D.new()
	c.position = onde_caiu(de_quem)
	if sorteio.is_valid():
		c.sortear = sorteio
	c.montar(de_quem, sorteio_de_duracao)
	pai.add_child(c)
	return c

## Onde o corpo caiu, de forma segura.
##
## 🔴 `global_position` num nó **fora da árvore** devolve `(0,0,0)` — com um
## erro no console que se perde no meio de mil outros, mas sem exceção. E um
## corpo na origem do mundo não é um detalhe: é o contrato de nascimento da
## Fase 11, onde um `CharacterBody3D` que aparece na origem **catapulta** quem
## estiver lá.
##
## Medido em 20/09 escrevendo o teste desta fase: um nó adicionado dentro de
## `_initialize` ainda não está na árvore, e `global_position` devolvia a origem
## em silêncio. No jogo de verdade o selvagem está sempre na árvore quando cai —
## mas "sempre" não é uma garantia que valha um bug dessa família.
static func onde_caiu(de_quem: Node3D) -> Vector3:
	if de_quem.is_inside_tree():
		return de_quem.global_position
	return de_quem.position

func montar(de_quem: Node3D, sorteio_de_duracao: float) -> void:
	var esp : Dictionary = {}
	var id_da_especie : int = int(de_quem.get("species_id")) \
		if de_quem.get("species_id") != null else 0
	var dados_do_jogo := get_node_or_null("/root/GameData")
	if dados_do_jogo != null:
		esp = dados_do_jogo.get_species(id_da_especie)

	_restante = RegrasDeCorpo.duracao(sorteio_de_duracao)
	# Lido por nome, com padrão: o corpo aceita qualquer nó que tenha estes
	# campos, o que também o torna testável sem subir uma entidade inteira.
	var altura : float = float(de_quem.get("altura_real")) \
		if de_quem.get("altura_real") != null else 1.0
	raio_de_alvo = maxf(0.4, altura * 0.35)
	dados = {
		"id": get_instance_id(),
		"species_id": int(de_quem.get("species_id")) \
			if de_quem.get("species_id") != null else 0,
		"nome": str(esp.get("name", "Pokémon")),
		"nivel": int(de_quem.get("nivel")) if de_quem.get("nivel") != null else 1,
		"catch_rate": int(esp.get("catch_rate", 45)),
		"shiny": false,
		# ⚠️ Lido de quem caiu, não recalculado: `PokemonInstance3D.capturavel`
		# já saiu de `RegraDeAlpha.perfil()` no nascimento. Recalcular aqui seria
		# uma segunda decisão sobre a mesma coisa, e elas divergiriam no dia em
		# que a régua do Alpha mudar.
		"capturavel": bool(de_quem.get("capturavel")) \
			if de_quem.get("capturavel") != null else true,
		"lendario": false,
		"tentativa_usada": false,
		"restante": _restante,
		"loot": [],
	}

func _ready() -> void:
	add_to_group("corpo_v3")
	# O loot nasce junto do corpo, não no momento de pegar: sorteado no clique,
	# dois cliques dariam dois resultados pro mesmo cadáver — e o jogador
	# aprenderia a clicar de novo.
	dados["loot"] = RegrasDeCorpo.loot(
		int(dados["nivel"]), not bool(dados["capturavel"]),
		_sorte_do_treinador(),
		[sortear.call(), sortear.call(), sortear.call()],
		_helds_do_catalogo())
	mudou.emit(int(dados["id"]), estado())

func _process(delta: float) -> void:
	_restante = maxf(0.0, _restante - delta)
	dados["restante"] = _restante

	if not _avisou and _restante <= RegrasDeCorpo.AVISO_EM:
		_avisou = true
		_anotar("o corpo de %s vai sumir" % str(dados["nome"]))
		mudou.emit(int(dados["id"]), estado())

	if _restante <= 0.0:
		_sumir("expirou")

func _sumir(motivo: String) -> void:
	removido.emit(int(dados["id"]), motivo)
	queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# A tentativa
# ──────────────────────────────────────────────────────────────────────────────

## §28: uma tentativa por corpo.
##
## A chance **não** vai no retorno, de propósito: expor o número transformaria a
## decisão numa planilha, que é o oposto do que a §28 pede.
func tentar_capturar(ball: String, sorte: int = 0) -> Dictionary:
	var pode : Dictionary = RegrasDeCorpo.pode_tentar(dados)
	if not bool(pode["pode"]):
		# Recusa não gasta nada: nem a tentativa, nem a bola.
		return {"pegou": false, "gastou": false, "motivo": str(pode["motivo"])}

	var r : Dictionary = RegrasDeCorpo.tentar(dados, ball, sortear.call(), sorte)
	dados["tentativa_usada"] = true
	mudou.emit(int(dados["id"]), estado())
	_anotar("tentou capturar %s com %s: %s"
		% [str(dados["nome"]), ball, "pegou" if bool(r["pegou"]) else "falhou"])

	if bool(r["pegou"]):
		_sumir("capturado")
		return {"pegou": true, "gastou": true, "motivo": "",
			"species_id": int(dados["species_id"]), "nivel": int(dados["nivel"])}
	# §28: falhou, perdeu. O corpo some na hora — insistir não é uma opção.
	_sumir("fugiu")
	return {"pegou": false, "gastou": true, "motivo": str(r["motivo"])}

## Os helds tier 1 que existem no catálogo, em ordem estável.
##
## Ordenado de propósito: `Dictionary.keys()` não promete ordem, e um drop que
## dependesse dela seria sorteio diferente a cada execução — o oposto de
## determinístico. Ordenar é o que permite o teste reproduzir o resultado.
func _helds_do_catalogo() -> Array:
	var jogo := get_node_or_null("/root/GameData")
	if jogo == null:
		return []
	var fora : Array = []
	for id in jogo.items.keys():
		var it : Dictionary = jogo.items[id]
		if str(it.get("category", "")) == "held" and int(it.get("tier", 0)) == 1:
			fora.append(str(id))
	fora.sort()
	return fora

## Pega UM item do chão, e ele vai PRA MOCHILA. §35: não existe "pegar tudo";
## cada item é um ato.
##
## 🔴 Até 21/09 esta função existia e **ninguém a chamava** — conferido por
## grep: a única chamada no repositório estava no laboratório da V2. O loot
## nascia no corpo, expirava com ele, e nunca chegava ao jogador.
##
## Devolve `{"item", "qtd", "guardado", "motivo"}`. `guardado` é falso quando não
## há save (laboratório, teste headless): o item sai do chão e o relatório **diz**
## que não foi guardado, em vez de desaparecer calado.
func pegar(indice: int) -> Dictionary:
	var loot : Array = dados["loot"]
	if indice < 0 or indice >= loot.size():
		return {}
	var item : Dictionary = loot[indice]
	loot.remove_at(indice)
	dados["loot"] = loot
	mudou.emit(int(dados["id"]), estado())

	var id : String = str(item.get("item", ""))
	var qtd : int = int(item.get("qtd", 1))
	var fora : Dictionary = {"item": id, "qtd": qtd, "guardado": false, "motivo": ""}

	# ⚠️ `get_node_or_null`, nunca o identificador do autoload — a lição de
	# cinco fases.
	var save := get_node_or_null("/root/SaveManager")
	if save == null:
		fora["motivo"] = "sem save nesta cena — o item não foi guardado"
		_anotar("pegou %s (sem save)" % id)
		return fora

	# 🔴 A trava que impede o item fantasma. Três dos quatro ids que
	# `RegrasDeCorpo.loot` entregava não existiam no catálogo; guardar um id
	# inexistente põe lixo no save do jogador, e lixo em save não se limpa.
	var jogo := get_node_or_null("/root/GameData")
	if jogo != null and not jogo.items.has(id):
		fora["motivo"] = "item '%s' não existe no catálogo — não guardei" % id
		push_warning(fora["motivo"])
		_anotar(fora["motivo"])
		return fora

	save.add_item(id, qtd)
	save.save_game()
	fora["guardado"] = true
	_anotar("pegou %s x%d" % [id, qtd])
	return fora

# ──────────────────────────────────────────────────────────────────────────────

## O estado pra HUD. **Sem a chance de captura**, de propósito (§28).
func estado() -> Dictionary:
	return {
		"id": int(dados["id"]),
		"nome": str(dados["nome"]),
		"nivel": int(dados["nivel"]),
		"pos": global_position,
		"segundos_restantes": _restante,
		"acabando": _restante <= RegrasDeCorpo.AVISO_EM,
		"capturavel": bool(dados["capturavel"]),
		"tentativa_usada": bool(dados["tentativa_usada"]),
		"raio_de_alvo": raio_de_alvo,
		"loot": (dados["loot"] as Array).duplicate(true),
	}

func _sorte_do_treinador() -> int:
	if not is_inside_tree():
		return 0
	for grupo in ["treinador_v3", "treinador_v2"]:
		var t := get_tree().get_nodes_in_group(grupo)
		if not t.is_empty() and t[0].get("sorte") != null:
			return int(t[0].get("sorte"))
	return 0

## ⚠️ `get_node_or_null`, nunca o identificador `PonteDeFeedback` — autoload não
## é identificador em teste `--script`, e citá-lo faria este arquivo inteiro
## parar de compilar num teste que só queria instanciar o corpo.
func _anotar(texto: String) -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.anotar(texto)
