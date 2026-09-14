## CombatenteV2.gd — O que é comum entre o Pokémon do jogador e o selvagem.
##
## Stats, vida, golpes, recargas e o ato de bater. Existe pra as duas entidades
## da V2 não terem duas cópias da mesma conta — que é como dois lugares passam a
## discordar sobre o mesmo fato.
##
## ── O que esta classe NÃO faz ────────────────────────────────────────────────
##
## Não decide. O Pokémon do jogador obedece a `MesaDeComandos`; o selvagem
## decide por `ComportamentoSelvagem`. Aqui fica só a mecânica que os dois
## compartilham: quanto de vida, quanto de dano, quando a recarga acaba.
##
## Reaproveita `StatsDePokemon`, `KitDeCombate`, `FormaDeArea` e `DanoV2` sem
## alterar nenhuma delas.
extends CharacterBody2D
class_name CombatenteV2

signal vida_mudou(atual: int, maximo: int)
signal derrotado(quem: Node)
signal golpe_iniciado(slot: int, golpe: Dictionary, duracao: float)
signal golpe_encerrado(slot: int, motivo: String)

## Telegrafia (§9), no formato que o Codex pediu: geometria JÁ resolvida em
## pixels de mundo, com `cast_id` pra ele saber qual aviso apagar. Ver
## `Telegrafia.gd` — a resolução acontece uma vez, do lado do gameplay, pra
## área desenhada e área que acerta nunca serem duas contas diferentes.
signal golpe_telegrafado(cast_id: int, dados: Dictionary)
signal telegrafia_encerrada(cast_id: int, motivo: String)

const TILE : float = 128.0

var species_id : int = 1
var nivel : int = 5
var nome_exibido : String = "?"
var tipos : Array = ["Normal"]
var stats : Dictionary = {}
var vida : int = 1
var vida_maxima : int = 1
var golpes : Array = []          ## entradas de moves.json
var recargas : Array[float] = []
var _recarga_total : Array[float] = []
var _derrotado : bool = false

## Cast em andamento. Um só: §10 diz que a direção trava quando a skill começa,
## e duas skills em cast ao mesmo tempo não teriam como travar duas direções.
var _cast_slot : int = -1
var _cast_resta : float = 0.0
var _cast_dir : Vector2 = Vector2.RIGHT
var _cast_alvo : Node = null
var _cast_id : int = 0

func montar(id_especie: int, nv: int, golpes_ids: Array = []) -> void:
	species_id = id_especie
	nivel = maxi(1, nv)
	var esp : Dictionary = GameData.get_species(species_id)
	nome_exibido = str(esp.get("name", "#%d" % species_id))
	tipos = esp.get("types", ["Normal"])
	stats = StatsDePokemon.conjunto(esp.get("base_stats", {}), nivel)
	# A vida da V2, não a da V1 — ver `BalanceV2.gd` pro motivo medido.
	vida_maxima = BalanceV2.vida(int(stats.get("hp", 1)))
	vida = vida_maxima

	golpes.clear()
	for mid in golpes_ids:
		var m : Dictionary = GameData.get_move(str(mid))
		if m.is_empty():
			# GRITA. Golpe que não existe sumindo calado é como um Pokémon vai pra
			# briga com metade do kit e ninguém entende por que ele apanha — este
			# projeto já foi mordido por essa classe de bug mais de uma vez.
			push_warning("golpe inexistente em moves.json: '%s' (%s)" % [str(mid), nome_exibido])
			PonteDeFeedback.anotar("golpe inexistente: %s" % str(mid))
			continue
		golpes.append(m)
	recargas.resize(golpes.size())
	_recarga_total.resize(golpes.size())
	recargas.fill(0.0)
	_recarga_total.fill(0.0)
	vida_mudou.emit(vida, vida_maxima)

func esta_derrotado() -> bool:
	return _derrotado

func fracao_de_vida() -> float:
	return 0.0 if vida_maxima <= 0 else float(vida) / float(vida_maxima)

## O dicionário que `DanoV2` espera de quem ataca.
func stats_de_ataque() -> Dictionary:
	return {
		"level": nivel, "types": tipos,
		"atk": int(stats.get("atk", 50)), "spa": int(stats.get("spa", 50)),
	}

## E o de quem apanha. `max_hp`/`hp` entram porque o teto anti-hit-kill depende
## deles — sem isso o para-quedas não abre.
func stats_de_defesa() -> Dictionary:
	return {
		"level": nivel, "types": tipos,
		"def": int(stats.get("def", 50)), "spd": int(stats.get("spd", 50)),
		"max_hp": vida_maxima, "hp": vida,
	}

func sofrer(dano: int, de_quem: Node = null) -> void:
	if _derrotado or dano <= 0:
		return
	vida = maxi(0, vida - dano)
	vida_mudou.emit(vida, vida_maxima)
	if vida <= 0:
		_derrotado = true
		derrotado.emit(self)
	elif de_quem != null:
		ao_ser_atingido(de_quem)

## Gancho: o selvagem usa pra acordar e revidar. O Pokémon do jogador ignora —
## quem decide o alvo dele é o jogador (§7).
func ao_ser_atingido(_de_quem: Node) -> void:
	pass

# ──────────────────────────────────────────────────────────────────────────────
# Recargas e cast
# ──────────────────────────────────────────────────────────────────────────────

func _tick_combate(delta: float) -> void:
	for i in recargas.size():
		if recargas[i] > 0.0:
			recargas[i] = maxf(0.0, recargas[i] - delta)
	if _cast_slot >= 0:
		_cast_resta -= delta
		if _cast_resta <= 0.0:
			_resolver_cast()

func esta_castando() -> bool:
	return _cast_slot >= 0

## Progresso 0→1 de uma recarga. É o que a HUD consome; ela não refaz a conta.
func progresso_da_recarga(slot: int) -> float:
	if slot < 0 or slot >= recargas.size():
		return 1.0
	var total : float = _recarga_total[slot]
	if recargas[slot] <= 0.0 or total <= 0.0:
		return 1.0
	return clampf(1.0 - (recargas[slot] / total), 0.0, 1.0)

## Tenta usar o golpe do slot. Devolve o motivo da recusa, ou "" se saiu.
##
## Motivo em texto, e não `false`, porque "não deu" sem dizer por quê é o pior
## retorno possível — some na tela e vira relatório de bug impossível de achar.
func usar(slot: int, direcao: Vector2, alvo: Node = null) -> String:
	if _derrotado:
		return "derrotado"
	if slot < 0 or slot >= golpes.size():
		return "slot vazio"
	if recargas[slot] > 0.0:
		return "recarregando"
	if esta_castando():
		return "já está usando outro golpe"

	var g : Dictionary = golpes[slot]
	if alvo != null and alvo is Node2D:
		if not FormaDeArea.no_alcance(global_position, alvo as Node2D, g):
			return "longe demais"

	# §12, literal: *"Speed NÃO reduz universalmente cooldown de skills."*
	# Ela afeta movimentação, frequência do ataque básico e aproximação em
	# TARGET — e só. A V1 encurta a recarga por velocidade; a V2 não, de
	# propósito, senão o Pokémon rápido teria vantagem em tudo ao mesmo tempo.
	# (Achado do Codex na revisão de 14/09.)
	var recarga : float = float(g.get("cooldown", 2.0))
	recargas[slot] = recarga
	_recarga_total[slot] = recarga

	# §10: a direção TRAVA aqui e não acompanha mais o alvo. Se o alvo sair da
	# trajetória, o golpe erra — é o que faz esquivar por movimentação existir.
	_cast_slot = slot
	_cast_dir = direcao.normalized() if direcao != Vector2.ZERO else Vector2.RIGHT
	_cast_alvo = alvo
	_cast_resta = float(g.get("cast_time", 0.0))

	var dados : Dictionary = Telegrafia.dados(
		g, global_position, _cast_dir, _cast_resta, e_hostil(), self, alvo)
	_cast_id = int(dados["cast_id"])
	golpe_iniciado.emit(slot, g, _cast_resta)
	golpe_telegrafado.emit(_cast_id, dados)
	if _cast_resta <= 0.0:
		_resolver_cast()
	return ""

## Este golpe é ameaça pro jogador? Quem responde é a subclasse — a mesma área
## vermelha não pode significar "corra" e "fique" ao mesmo tempo.
func e_hostil() -> bool:
	return false

## §11: crowd control interrompe o cast — mas a recarga JÁ correu e continua
## correndo. Interromper não devolve o golpe.
func interromper(motivo: String = "interrompido") -> void:
	if _cast_slot < 0:
		return
	var s := _cast_slot
	_cast_slot = -1
	_cast_alvo = null
	golpe_encerrado.emit(s, motivo)
	# §11 / pedido do Codex: interrupção apaga o aviso NA HORA. Deixar a UI
	# derrubar por timer mostraria um ataque que já foi cancelado.
	telegrafia_encerrada.emit(_cast_id, motivo)

func _resolver_cast() -> void:
	var slot := _cast_slot
	if slot < 0:
		return
	var g : Dictionary = golpes[slot]
	_cast_slot = -1

	var atingidos : Array = FormaDeArea.alvos(
		global_position, _cast_dir, g, grupos_inimigos(), [self])
	for a in atingidos:
		if a is CombatenteV2 and not (a as CombatenteV2).esta_derrotado():
			var c : CombatenteV2 = a
			var dano : int = DanoV2.calcular(g, stats_de_ataque(), c.stats_de_defesa())
			c.sofrer(dano, self)
	_cast_alvo = null
	golpe_encerrado.emit(slot, "impacto")
	telegrafia_encerrada.emit(_cast_id, "impacto")

## Em que grupos este combatente procura inimigo. Sobrescrito pelas subclasses —
## é o que faz o Pokémon do jogador não bater no próprio treinador.
func grupos_inimigos() -> Array:
	return []
