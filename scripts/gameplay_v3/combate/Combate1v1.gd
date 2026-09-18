## Combate1v1.gd — O laço de uma batalha (Fase 12).
##
## Executor. **Nenhuma regra mora aqui**: começar, terminar e o resultado vêm de
## `RegraDeCombate`. O que sobra é o que só um nó pode fazer — vigiar distância,
## trocar o alvo do selvagem, segurar o spawner e avisar o mundo.
##
## ── O que esta fase junta ───────────────────────────────────────────────────
##
## É a primeira que não constrói peça nova: ela liga as cinco anteriores.
##
## ```
## Fase 7  transferência ── o jogador vira o Pokémon
## Fase 8  1ª pessoa     ── e vê pelos olhos dele
## Fase 9  básico        ── e bate
## Fase 10 skills        ── e usa as quatro
## Fase 11 selvagem      ── contra alguém que decide sozinho
##          ↓
## Fase 12 COMBATE       ── com começo, meio e FIM declarado
## ```
##
## ── Por que "fim declarado" é o ponto ───────────────────────────────────────
##
## Sem esta fase já dava pra bater num selvagem e vê-lo cair. O que não existia
## era o **evento**: ninguém sabia dizer que uma batalha começou, terminou, e
## como. É isso que a Fase 13 (voltar a ser o treinador) vai escutar, e é isso
## que a tela precisa pra mostrar qualquer coisa.
class_name Combate1v1
extends Node

## A batalha começou. `defensor` é o Pokémon do jogador; `selvagem`, o outro.
signal comecou(defensor: Node3D, selvagem: Node3D)

## E terminou — com **um** resultado, declarado **uma vez**.
signal terminou(resultado: String, defensor: Node3D, selvagem: Node3D)

## Quem está lutando agora. `null` = ninguém.
var defensor : Node3D = null
var selvagem : Node3D = null

## O spawner, pra segurar enquanto a briga corre. Opcional: sem ele, o combate
## funciona igual — só o mundo continua povoando em volta.
var spawner : Node = null

## Os candidatos a começar briga. O `Laboratorio3D` (ou o mundo) preenche; em
## geral é o grupo `selvagem_v3`.
var vigiar : Callable = _vigiar_padrao

var _segundos_sem_dano : float = 0.0
var _vida_anterior : Dictionary = {}

func em_combate() -> bool:
	return defensor != null and selvagem != null

# ──────────────────────────────────────────────────────────────────────────────
# Começar
# ──────────────────────────────────────────────────────────────────────────────

## O Pokémon que o jogador está controlando. Sem ele não há batalha — o treinador
## sozinho não luta (§17: ele fica no mundo, e é o Pokémon que briga).
var pokemon_do_jogador : Node3D = null

func _process(delta: float) -> void:
	if em_combate():
		_tick(delta)
		return
	_procurar_briga()

## Alguém hostil chegou perto o bastante?
func _procurar_briga() -> void:
	if pokemon_do_jogador == null or not is_instance_valid(pokemon_do_jogador):
		return
	if pokemon_do_jogador.has_method("esta_derrotado") and pokemon_do_jogador.esta_derrotado():
		return

	for candidato in vigiar.call():
		if candidato == null or not is_instance_valid(candidato) or candidato == pokemon_do_jogador:
			continue
		var d : float = Vector3(
			candidato.global_position.x - pokemon_do_jogador.global_position.x, 0.0,
			candidato.global_position.z - pokemon_do_jogador.global_position.z).length()
		var hostil : bool = bool(candidato.get("provocado")) \
			or ComportamentoSelvagem.comeca_briga(str(candidato.get("personalidade")))
		if RegraDeCombate.pode_comecar(d, hostil, not candidato.esta_derrotado(),
				not pokemon_do_jogador.esta_derrotado(), em_combate()):
			iniciar(pokemon_do_jogador, candidato)
			return

## Começa a batalha. Público porque o mundo pode forçar um encontro (um treinador
## rival, um chefe) sem depender da distância.
func iniciar(quem_defende: Node3D, quem_ataca: Node3D) -> bool:
	if em_combate() or quem_defende == null or quem_ataca == null:
		return false
	defensor = quem_defende
	selvagem = quem_ataca
	_segundos_sem_dano = 0.0
	_vida_anterior = {
		defensor.get_instance_id(): int(defensor.vida),
		selvagem.get_instance_id(): int(selvagem.vida),
	}

	# O selvagem para de mirar no treinador e passa a mirar em quem vai lutar com
	# ele. Sem isto, ele atravessaria a briga inteira correndo atrás de quem está
	# parado a dez metros — que é o que ele estava fazendo até aqui.
	if selvagem.has_method("virar_selvagem") or "alvo_hostil" in selvagem:
		selvagem.alvo_hostil = defensor
		selvagem.provocado = true

	# 1v1 sem arena: ninguém entra. O spawner para de criar, e os dois
	# combatentes deixam de ser alvo válido pros outros selvagens.
	if spawner != null and is_instance_valid(spawner):
		spawner.ativo = false
	_marcar_em_combate(true)

	EventBus.battle_started.emit()
	PonteDeFeedback.anotar("batalha começou: %s x %s" % [
		str(defensor.nome_exibido), str(selvagem.nome_exibido)])
	comecou.emit(defensor, selvagem)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# Correr, e terminar
# ──────────────────────────────────────────────────────────────────────────────

func _tick(delta: float) -> void:
	if not is_instance_valid(defensor) or not is_instance_valid(selvagem):
		_encerrar(RegraDeCombate.FUGA)
		return

	# "Sem dano" é medido pela vida dos dois, não por um sinal — assim vale pra
	# qualquer fonte de dano, inclusive as que ainda não existem (veneno, queda).
	var mudou : bool = false
	for quem in [defensor, selvagem]:
		var antes : int = int(_vida_anterior.get(quem.get_instance_id(), quem.vida))
		if int(quem.vida) != antes:
			mudou = true
		_vida_anterior[quem.get_instance_id()] = int(quem.vida)
	_segundos_sem_dano = 0.0 if mudou else _segundos_sem_dano + delta

	var d : float = Vector3(
		selvagem.global_position.x - defensor.global_position.x, 0.0,
		selvagem.global_position.z - defensor.global_position.z).length()

	var r := RegraDeCombate.resultado(
		not defensor.esta_derrotado(), not selvagem.esta_derrotado(),
		d, _segundos_sem_dano)
	if RegraDeCombate.acabou(r):
		_encerrar(r)

func _encerrar(r: String) -> void:
	var quem_defendeu := defensor
	var quem_atacou := selvagem
	defensor = null
	selvagem = null
	_vida_anterior.clear()
	_segundos_sem_dano = 0.0

	_marcar_em_combate(false)
	if spawner != null and is_instance_valid(spawner):
		spawner.ativo = true

	# O selvagem que sobreviveu à fuga volta a viver a vida dele: se continuasse
	# provocado e mirando, ele perseguiria o jogador pelo mapa — e a coleira da
	# Fase 11 até o traria de volta, mas com o alvo errado na cabeça.
	if r == RegraDeCombate.FUGA and is_instance_valid(quem_atacou) \
			and not quem_atacou.esta_derrotado():
		quem_atacou.provocado = false
		quem_atacou.alvo_hostil = null

	EventBus.battle_ended.emit({"resultado": r})
	PonteDeFeedback.anotar("batalha terminou: %s" % RegraDeCombate.frase(r))
	terminou.emit(r, quem_defendeu, quem_atacou)

# ──────────────────────────────────────────────────────────────────────────────

## Marca os dois como "em combate", pra `RegraDeCombate.pode_engajar` manter os
## outros fora. Não congela ninguém: o terceiro continua com a IA dele, só deixa
## de ter estes dois como alvo.
func _marcar_em_combate(valor: bool) -> void:
	for quem in [defensor, selvagem]:
		if quem != null and is_instance_valid(quem):
			quem.set_meta("em_combate", valor)

func _vigiar_padrao() -> Array:
	return get_tree().get_nodes_in_group("selvagem_v3")
