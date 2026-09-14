## PokemonAtivoV2.gd — O Pokémon do jogador, na V2 (§6, §7, §12).
##
## Diferença central em relação ao `FollowerPokemon` da V1: aquele é um
## guarda-costas totalmente autônomo — escolhe alvo, decide quando bater, e o
## jogador só aperta as skills. Aqui ele **obedece**: seguir, atacar, ir,
## manter, recuar (§7).
##
## ── O ataque básico (§12) ────────────────────────────────────────────────────
##
## *"Automático; apenas contra alvo explicitamente selecionado; não troca de
## alvo automaticamente; pode ocorrer enquanto o Pokémon se move; sempre é
## Physical."*
##
## As três metades disso importam juntas: automático tira do jogador a tarefa
## chata de clicar pra dar dano, "só contra alvo selecionado" impede o Pokémon
## de puxar briga sozinha, e "não troca de alvo" faz o jogador continuar dono da
## decisão mesmo com o dano saindo sem ele.
extends CombatenteV2
class_name PokemonAtivoV2

const DISTANCIA_DE_REPOUSO : float = 190.0   ## atrás do treinador
const DISTANCIA_DE_COMBATE : float = 150.0   ## do alvo, quando manda atacar
const FOLGA : float = 40.0                   ## não fica corrigindo posição por 1 px
const VELOCIDADE_BASE : float = 700.0

## §12: "Speed afeta movimentação, frequência do ataque básico e velocidade de
## aproximação". O expoente baixo é de propósito — Speed importa, mas um
## Pokémon rápido não pode andar 3× mais que um lento, senão a equipe inteira
## vira "escolha o mais rápido".
const PESO_DA_VELOCIDADE : float = 0.35

## Contratos que o Codex pediu na revisão de 14/09. `ordem_mudou` inclui a volta
## automática pra SEGUIR quando o alvo some ou o destino é alcançado — era o
## caso que ele apontou como o mais fácil de a HUD perder.
signal ordem_mudou(ordem: String, alvo_id: int)
signal recarga_mudou(slot: int, progresso: float)

var treinador : Node2D = null
var comandos : MesaDeComandos = MesaDeComandos.new()

## Última recarga emitida por slot, pra não mandar sinal 60×/s com o mesmo
## número (§63: não recalcular nem reemitir tudo todo quadro).
var _ultimo_progresso : Array[float] = []
const PASSO_DO_SINAL : float = 0.05

var _cd_basico : float = 0.0
## §61: sem isto ele encosta na primeira parede entre ele e o alvo e fica lá.
var _contorno : Contorno = Contorno.new()

func _ready() -> void:
	add_to_group("pokemon_do_jogador")

func grupos_inimigos() -> Array:
	return ["selvagem_v2"]

## §19: com alvo válido, está em combate — e não regenera. Sem alvo, o relógio
## de 5 segundos começa a correr.
func em_combate() -> bool:
	return comandos.alvo_valido()

func velocidade() -> float:
	var spe : int = int(stats.get("spe", 50))
	return VELOCIDADE_BASE * (1.0 + (float(spe) - 50.0) / 100.0 * PESO_DA_VELOCIDADE)

# ──────────────────────────────────────────────────────────────────────────────
# O laço
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if esta_derrotado():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_tick_combate(delta)
	comandos.passo(delta)

	# Uma ordem que perdeu o sentido volta pro repouso sozinha — senão o Pokémon
	# fica olhando pro lugar onde o alvo estava. AVISA, porque a HUD não tem
	# como adivinhar uma mudança que ninguém pediu.
	if comandos.ordem == MesaDeComandos.ATACAR and not comandos.alvo_valido():
		comandos.concluir()
		_avisar_ordem()

	_avisar_recargas()

	_mover(delta)
	_ataque_basico(delta)

func _mover(_delta: float) -> void:
	# Sem `:=`: `_destino_da_ordem()` devolve Vector2 **ou** null ("fique
	# parado"), e o Godot não infere tipo de retorno variante.
	var destino = _destino_da_ordem()
	if destino == null:
		velocity = velocity.move_toward(Vector2.ZERO, 4000.0 * 0.016)
		_aplicar_movimento()
		return

	var d : Vector2 = (destino as Vector2) - global_position
	if d.length() <= FOLGA:
		velocity = velocity.move_toward(Vector2.ZERO, 4000.0 * 0.016)
	else:
		velocity = d.normalized() * velocidade()
	velocity = _contorno.ajustar(velocity, global_position, _delta)
	_aplicar_movimento()

## Para onde ir nesta ordem, ou `null` se é pra ficar parado.
func _destino_da_ordem():
	match comandos.ordem:
		MesaDeComandos.MANTER:
			return null
		MesaDeComandos.IR:
			if global_position.distance_to(comandos.ponto) <= FOLGA:
				comandos.concluir()   # chegou: volta a seguir
				return null
			return comandos.ponto
		MesaDeComandos.ATACAR:
			var alvo : Node2D = comandos.alvo as Node2D
			# Para a uma distância do alvo, não em cima dele: ficar dentro do
			# inimigo esconde os dois e quebra a leitura da luta (§59).
			var para_o_alvo : Vector2 = global_position - alvo.global_position
			if para_o_alvo == Vector2.ZERO:
				para_o_alvo = Vector2.RIGHT
			return alvo.global_position + para_o_alvo.normalized() * DISTANCIA_DE_COMBATE
		_:
			# SEGUIR e RECUAR vão os dois pro treinador. A diferença está em
			# `aceita_engajar()`, não no destino: quem recua também anda pra
			# perto, só não briga no caminho.
			if treinador == null:
				return null
			return treinador.global_position - Vector2(0, -DISTANCIA_DE_REPOUSO)

func _aplicar_movimento() -> void:
	velocity = WorldManager.filtrar_velocidade(
		global_position + Vector2(0, TILE * 0.25), velocity, true)
	move_and_slide()

# ──────────────────────────────────────────────────────────────────────────────
# Ataque básico (§12)
# ──────────────────────────────────────────────────────────────────────────────

## Base de 1,1 s entre ataques básicos, encurtada pela velocidade. É o piso de
## dano constante que existe pra a luta não parar quando todas as skills estão
## em recarga.
const INTERVALO_BASICO : float = 1.1
const ALCANCE_BASICO : float = 200.0
const PODER_BASICO : int = 35

func _ataque_basico(delta: float) -> void:
	if _cd_basico > 0.0:
		_cd_basico -= delta
		return
	# §12: SÓ contra alvo explicitamente escolhido, e nunca troca sozinho.
	if not comandos.alvo_valido():
		return
	var alvo : CombatenteV2 = comandos.alvo as CombatenteV2
	if alvo == null or global_position.distance_to(alvo.global_position) > ALCANCE_BASICO:
		return

	# §12: o ataque básico é SEMPRE físico, e do tipo primário do Pokémon —
	# assim ele nunca é neutro por acidente nem ignora a tabela de tipos.
	var golpe := {
		"id": "ataque_basico", "name": "Ataque", "power": PODER_BASICO,
		"type": tipos[0] if not tipos.is_empty() else "Normal",
		"category": "physical", "area_type": "single",
	}
	alvo.sofrer(DanoV2.calcular(golpe, stats_de_ataque(), alvo.stats_de_defesa()), self)
	_cd_basico = CombatBalance.recarga(INTERVALO_BASICO, int(stats.get("spe", 50)))
	EventBus.follower_skill_used.emit(-1, "ataque_basico")

# ──────────────────────────────────────────────────────────────────────────────
# Ordens — a porta que o jogador (e a HUD) usa
# ──────────────────────────────────────────────────────────────────────────────

func ordenar(ordem: String, dados: Dictionary = {}) -> bool:
	var deu := comandos.ordenar(ordem, dados)
	if deu:
		PonteDeFeedback.anotar("ordem: %s" % comandos.descricao())
		_avisar_ordem()
	return deu

func _avisar_ordem() -> void:
	var a : Node = comandos.alvo if comandos.alvo_valido() else null
	ordem_mudou.emit(comandos.ordem, a.get_instance_id() if a != null else 0)

## Progresso de recarga por slot, só quando muda o bastante pra aparecer.
func _avisar_recargas() -> void:
	if _ultimo_progresso.size() != golpes.size():
		_ultimo_progresso.resize(golpes.size())
		_ultimo_progresso.fill(-1.0)
	for i in golpes.size():
		var p : float = progresso_da_recarga(i)
		if absf(p - _ultimo_progresso[i]) < PASSO_DO_SINAL and not is_equal_approx(p, 1.0):
			continue
		if is_equal_approx(p, _ultimo_progresso[i]):
			continue
		_ultimo_progresso[i] = p
		recarga_mudou.emit(i, p)

func usar_skill(slot: int) -> String:
	var alvo : Node = comandos.alvo if comandos.alvo_valido() else null
	var dir : Vector2 = Vector2.RIGHT
	if alvo is Node2D:
		dir = ((alvo as Node2D).global_position - global_position).normalized()
	elif velocity != Vector2.ZERO:
		dir = velocity.normalized()
	var motivo := usar(slot, dir, alvo)
	if motivo == "":
		PonteDeFeedback.anotar("usou o golpe %d" % (slot + 1))
	else:
		PonteDeFeedback.anotar("golpe %d recusado: %s" % [slot + 1, motivo])
	return motivo
