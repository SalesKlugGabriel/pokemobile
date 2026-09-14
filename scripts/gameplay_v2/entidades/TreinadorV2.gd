## TreinadorV2.gd — O jogador na V2 (§4, §5).
##
## Junta as três peças já construídas e testadas: `CorpoLivre` (movimento
## contínuo), `Stamina` (fôlego) e `MesaDeComandos` (ordens ao Pokémon, através
## do `PokemonAtivoV2`).
##
## ── §4: o treinador pode morrer ──────────────────────────────────────────────
##
## *"Quando nenhum Pokémon estiver fora da Pokéball: treinador pode ser atacado,
## recebe dano, pode morrer."* Ele tem vida própria aqui, e quem escolhe entre
## ele e o Pokémon é o selvagem (`SelvagemV2._escolher_alvo`).
extends CorpoLivre
class_name TreinadorV2

signal stamina_mudou(atual: float, maximo: float, estado: String)
signal vida_mudou(atual: int, maximo: int)
signal caiu()

var stamina : Stamina = Stamina.new()
var pokemon : PokemonAtivoV2 = null

var vida : int = 100
var vida_maxima : int = 100
var nivel : int = 1
var xp : int = 0
## §28: Luck entra na chance de captura e no loot comum.
var sorte : int = 0
var _no_chao : bool = false

func _ready() -> void:
	super._ready()
	add_to_group("treinador_v2")
	add_to_group("player")   # a ponte de feedback já procura este grupo

func _physics_process(delta: float) -> void:
	if _no_chao:
		intencao = Vector2.ZERO
		quer_correr = false
		super._physics_process(delta)
		return

	_ler_entrada()
	_tick_stamina(delta)
	super._physics_process(delta)

## Quando false, este nó NÃO lê teclado: a `intencao` vem de fora.
##
## Existe por dois motivos concretos, não por gosto de configuração:
## os **controles de toque** do Codex precisam empurrar a intenção sem disputar
## com o teclado, e o **teste** precisa dirigir o treinador sem fingir tecla.
## Sem isso, `_ler_entrada()` sobrescrevia tudo todo quadro de física — foi
## exatamente o que o primeiro teste da cena pegou.
var le_teclado : bool = true

func _ler_entrada() -> void:
	if not le_teclado:
		return
	# Uma fonte só de intenção. O toque do Codex preenche o MESMO campo — é o
	# que impede uma regra nova de precisar ser escrita duas vezes (§7 do plano).
	intencao = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	quer_correr = Input.is_action_pressed("run") and stamina.atual > 0.0

func _tick_stamina(delta: float) -> void:
	var acoes : Array = []
	# Correr só cobra se estiver de fato saindo do lugar: parado segurando o
	# botão de corrida não é corrida, e cobrar isso seria armadilha invisível.
	if quer_correr and intencao != Vector2.ZERO:
		acoes.append("correr")

	if stamina.passo(delta, acoes, esta_parado()):
		stamina_mudou.emit(stamina.atual, stamina.maximo(), stamina.estado())

	# A exaustão entra no movimento por aqui — `CorpoLivre` não conhece stamina,
	# e `Stamina` não conhece movimento. Cada um sabe só o que é seu.
	fator_de_velocidade = stamina.fator_de_velocidade()

# ──────────────────────────────────────────────────────────────────────────────
# Vida (§4)
# ──────────────────────────────────────────────────────────────────────────────

func esta_derrotado() -> bool:
	return _no_chao

func sofrer(dano: int, _de_quem: Node = null) -> void:
	if _no_chao or dano <= 0:
		return
	vida = maxi(0, vida - dano)
	vida_mudou.emit(vida, vida_maxima)
	PonteDeFeedback.anotar("treinador levou %d de dano (%d/%d)" % [dano, vida, vida_maxima])
	if vida <= 0:
		_no_chao = true
		PonteDeFeedback.anotar("treinador caiu")
		caiu.emit()

## O que `DanoV2` precisa pra bater no treinador. Ele não tem tipo elemental
## nem defesa de Pokémon — mesmo valor neutro que a V1 já usava, até existir
## uma fórmula própria de defesa do treinador (isso é dívida declarada, não
## esquecimento).
func stats_de_defesa() -> Dictionary:
	return {"level": 1, "types": [], "def": 50, "spd": 50,
			"max_hp": vida_maxima, "hp": vida}

func reviver() -> void:
	_no_chao = false
	vida = vida_maxima
	stamina.definir(stamina.maximo())
	vida_mudou.emit(vida, vida_maxima)
