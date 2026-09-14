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
var xp : int = 0
var nome_exibido : String = "?"
var tipos : Array = ["Normal"]
var stats : Dictionary = {}
var vida : int = 1
var vida_maxima : int = 1
var golpes : Array = []          ## entradas de moves.json
var recargas : Array[float] = []
var _recarga_total : Array[float] = []
var _derrotado : bool = false

## §16 a §24: buffs, debuffs e status. Existia como regra provada e sem
## consumidor — agora é aqui que ela vive.
var efeitos : LivroDeEfeitos = LivroDeEfeitos.new()

## §32: quanto dano cada um causou neste combatente, por id. É o que decide a
## divisão de XP — e ela é por DANO, não por quem deu o último golpe.
var dano_recebido_por : Dictionary = {}
var ultimo_a_bater : int = 0

## §19: segundos desde o último dano. A regeneração natural só começa depois de
## `SEGUNDOS_FORA_DE_COMBATE` sem apanhar e sem status negativo.
var _sem_apanhar : float = 0.0
var _regen_acumulada : float = 0.0

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
	# §19: apanhar reinicia o relógio da regeneração, sempre.
	_sem_apanhar = 0.0
	_regen_acumulada = 0.0
	if de_quem != null and is_instance_valid(de_quem):
		var id : int = de_quem.get_instance_id()
		dano_recebido_por[id] = int(dano_recebido_por.get(id, 0)) + dano
		ultimo_a_bater = id
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

## §19: *"todo Pokémon tem regeneração natural de HP. Em combate/aggro NÃO
## existe. Para começar: fora de combate, sem status negativo, sem receber dano,
## 5 segundos. Qualquer dano reinicia. Movimento não interrompe."*
##
## A fração é pequena de propósito: a regeneração serve pra não obrigar o
## jogador a voltar ao Centro Pokémon depois de cada arranhão, não pra tornar
## a luta anterior irrelevante.
const SEGUNDOS_FORA_DE_COMBATE : float = 5.0
const REGEN_POR_SEGUNDO : float = 0.012   ## fração da vida máxima

func _tick_regeneracao(delta: float) -> void:
	if _derrotado or vida >= vida_maxima:
		return
	# Status negativo interrompe e reinicia o contador (§19).
	if not efeitos.status.is_empty():
		_sem_apanhar = 0.0
		return
	if em_combate():
		_sem_apanhar = 0.0
		return
	_sem_apanhar += delta
	if _sem_apanhar < SEGUNDOS_FORA_DE_COMBATE:
		return
	_regen_acumulada += float(vida_maxima) * REGEN_POR_SEGUNDO * delta
	if _regen_acumulada >= 1.0:
		var ganho : int = int(_regen_acumulada)
		_regen_acumulada -= float(ganho)
		vida = mini(vida_maxima, vida + ganho)
		vida_mudou.emit(vida, vida_maxima)

## Está em combate? Sobrescrito por quem sabe responder — o selvagem sabe pelo
## estado dele, o Pokémon do jogador pela ordem ativa.
func em_combate() -> bool:
	return false

func _tick_combate(delta: float) -> void:
	var acabaram : Array[String] = efeitos.passo(delta)
	for nome in acabaram:
		FloatingText.show_text(get_tree().current_scene,
			global_position + Vector2(0, -180), "%s passou" % nome,
			Color(0.7, 0.9, 0.7))
	_tick_regeneracao(delta)
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
	if incapacitado():
		return "não consegue agir"

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
	var dano_total : int = 0
	for a in atingidos:
		if a is CombatenteV2 and not (a as CombatenteV2).esta_derrotado():
			var c : CombatenteV2 = a
			# `detalhar` em vez de `calcular`: o relatório precisa do
			# multiplicador de tipo, e recalcular na tela seria a segunda conta
			# que a AGENTS.md proíbe.
			var d : Dictionary = DanoV2.detalhar(g, stats_de_ataque(), c.stats_de_defesa())
			var dano : int = int(d["final"])
			c.sofrer(dano, self)
			dano_total += dano
			EventBus.golpe_resolvido.emit(RelatorioDeGolpe.montar(
				g, self, c, dano, d, c.vida, c.vida_maxima))
			_aplicar_status(g, c)
	_drenar(g, dano_total)
	_cast_alvo = null
	golpe_encerrado.emit(slot, "impacto")
	telegrafia_encerrada.emit(_cast_id, "impacto")

## §17/§18: o status do golpe, se ele tiver um e a sorte deixar.
##
## 🔴 Reescrito em 14/09 na auditoria de dados. A primeira versão lia
## `golpe.effect` **como se fosse o nome do status** e exigia `status_chance > 0`
## — e as duas coisas estavam erradas:
##
##  - o campo `effect` é uma linguagem própria: `burn_10` é queimar com 10% de
##    chance, `paralysis` é paralisar com a chance padrão. "burn_10" nunca seria
##    o nome de um status.
##  - `status_chance` vale 0 em 160 dos 192 golpes, porque a chance mora DENTRO
##    do `effect` na maioria deles.
##
## Resultado: **status nunca era aplicado na V2, em golpe nenhum**, e nada
## avisava. `StatusEffectController` já sabia decodificar isso desde sempre — o
## erro foi eu escrever um segundo interpretador em vez de procurar o que
## existia.
func _aplicar_status(golpe: Dictionary, alvo: CombatenteV2) -> void:
	var efeito := str(golpe.get("effect", "none"))
	if efeito == "" or efeito == "none":
		return
	var padrao : int = StatusEffectController.chance_do_golpe(golpe)
	var r : Dictionary = StatusEffectController.resolve_status_effect(efeito, padrao)
	if r.is_empty():
		return
	if not RNGManager.chance(float(r["chance"]) / 100.0):
		return
	var nome := str(r["status"])
	var duracao : float = StatusEffectController.roll_sleep_duration() \
		if nome == "sleep" else 6.0
	if alvo.efeitos.aplicar_status(nome, duracao, float(golpe.get("power", 20)) * 0.15):
		EventBus.status_aplicado.emit(
			RelatorioDeGolpe.de_status(nome, golpe, self, alvo))

## §20: *"skills de drenagem curam baseado no dano REAL causado. Se dano final
## = 0, cura = 0. Nunca pode ultrapassar 100% do dano."*
##
## "Dano real" é o ponto: curar pelo dano teórico faria drenagem contra um alvo
## imune curar do mesmo jeito, o que a §20 proíbe com todas as letras.
## 🔴 Também reescrito na auditoria: a primeira versão lia um campo `drenagem`
## que **nenhum dos 192 golpes tem**. A drenagem é codificada no `effect`, como
## `drain_50`. Outro zero silencioso meu, no mesmo arquivo e no mesmo dia.
##
## Achado junto: a drenagem **nunca funcionou na V1 tampouco** — `drain_50`
## aparece em 4 golpes (Absorb, Mega Drain, Giga Drain, Dream Eater) e nenhum
## código do jogo lê. Eles davam dano e curavam nada desde sempre.
static func fracao_de_drenagem(golpe: Dictionary) -> float:
	var efeito := str(golpe.get("effect", "none"))
	if not efeito.begins_with("drain_"):
		return 0.0
	# `drain_50` e `drain_50_sleeping_only` — pega o primeiro número depois do _
	var partes := efeito.split("_")
	if partes.size() < 2 or not partes[1].is_valid_int():
		return 0.0
	return clampf(float(partes[1].to_int()) / 100.0, 0.0, 1.0)

func _drenar(golpe: Dictionary, dano_causado: int) -> void:
	if dano_causado <= 0:
		return
	var fracao : float = fracao_de_drenagem(golpe)
	if fracao <= 0.0:
		return
	var cura : int = mini(dano_causado, int(round(float(dano_causado) * fracao)))
	if cura <= 0 or vida >= vida_maxima:
		return
	vida = mini(vida_maxima, vida + cura)
	vida_mudou.emit(vida, vida_maxima)
	FloatingText.show_text(get_tree().current_scene,
		global_position + Vector2(0, -180), "+%d" % cura, Color(0.5, 1.0, 0.6))

## §11: crowd control impede agir. Quem está dormindo ou congelado nem tenta.
func incapacitado() -> bool:
	return efeitos.tem_status("sleep") or efeitos.tem_status("freeze")

## Em que grupos este combatente procura inimigo. Sobrescrito pelas subclasses —
## é o que faz o Pokémon do jogador não bater no próprio treinador.
func grupos_inimigos() -> Array:
	return []
