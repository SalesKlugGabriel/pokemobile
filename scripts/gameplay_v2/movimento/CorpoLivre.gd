## CorpoLivre.gd — O corpo que anda sem grid (§4 da especificação de 13/09).
##
## É a casca com nó em volta da matemática de `Locomocao.gd`. Toda conta mora
## lá; aqui só entra o que precisa de `CharacterBody2D`: ler entrada, mover,
## colidir, e avisar quando mudou de tile.
##
## ── O que este nó garante pro resto do jogo ──────────────────────────────────
##
## `grid_pos` continua existindo e continua certo. O mundo inteiro pergunta em
## que tile o jogador está — warp, pesca, surf, mergulho, zona de spawn,
## quest — e nada disso precisa ser reescrito: o tile passa a ser **derivado**
## da posição, em vez de ser a posição.
##
## É por isso que a V2 consegue trocar o movimento sem tocar nos 36 mapas.
##
## ── Colisão ──────────────────────────────────────────────────────────────────
##
## Usa `WorldManager.filtrar_velocidade()`, a mesma função que `WildPokemon` e
## `FollowerPokemon` já usam há semanas. Ela testa os eixos separadamente, então
## esbarrar numa quina faz deslizar em vez de travar — que é exatamente o que
## se quer num corredor de 1 tile, o risco nº 1 do plano.
extends CharacterBody2D
class_name CorpoLivre

signal tile_mudou(novo: Vector2i, anterior: Vector2i)
signal parou()
signal comecou_a_andar()

const TAMANHO_DO_TILE : int = 128

## Preenchido por quem controla (jogador ou IA), uma vez por frame, antes do
## `_physics_process`. Vetor bruto: o analógico pela metade anda pela metade.
var intencao : Vector2 = Vector2.ZERO
var quer_correr : bool = false

## Multiplicador externo de velocidade — é por aqui que a exaustão da stamina
## e a lentidão do mergulho entram, sem que este nó precise conhecer nenhum dos
## dois. Regra do projeto: quem sabe a regra não é quem executa o movimento.
var fator_de_velocidade : float = 1.0

## Permitir entrar em tile de água (surf). Mesmo parâmetro que os Pokémon usam.
var permite_agua : bool = false

var facing : int = 0   ## o enum de BaseEntity.Direction: 0 baixo, 1 esq, 2 dir, 3 cima
var grid_pos : Vector2i = Vector2i.ZERO

var _parado_antes : bool = true

func _ready() -> void:
	grid_pos = Locomocao.tile_de(global_position, TAMANHO_DO_TILE)

## Põe o corpo no centro de um tile. É como um warp deve chegar — no meio, não
## encostado na parede que o corredor tem do outro lado.
func ir_para_tile(tile: Vector2i) -> void:
	global_position = Locomocao.centro_do_tile(tile, TAMANHO_DO_TILE)
	grid_pos = tile
	velocity = Vector2.ZERO

func esta_parado() -> bool:
	return Locomocao.esta_parado(velocity)

func _physics_process(delta: float) -> void:
	var alvo := Locomocao.velocidade_alvo(intencao, quer_correr, fator_de_velocidade)
	velocity = Locomocao.avancar(velocity, alvo, delta)

	if not esta_parado():
		facing = Locomocao.direcao_olhada(velocity, facing)

	# O filtro de colisão do mundo em tiles, aplicado ao pé (e não ao centro do
	# sprite): é a mesma referência que os Pokémon usam, senão o treinador
	# entraria em parede com os pés enquanto a cabeça ainda está do lado de fora.
	velocity = WorldManager.filtrar_velocidade(
		global_position + Vector2(0, TAMANHO_DO_TILE * 0.25), velocity, permite_agua)
	move_and_slide()

	_conferir_tile()
	_conferir_parada()

func _conferir_tile() -> void:
	var novo := Locomocao.tile_de(global_position, TAMANHO_DO_TILE)
	if novo != grid_pos:
		var anterior := grid_pos
		grid_pos = novo
		tile_mudou.emit(novo, anterior)

## Sinais de começar e parar existem pra stamina e animação não precisarem
## comparar velocidade por conta própria — cada um comparando do seu jeito é
## como dois lugares passam a discordar sobre o mesmo fato.
func _conferir_parada() -> void:
	var agora := esta_parado()
	if agora == _parado_antes:
		return
	_parado_antes = agora
	if agora:
		parou.emit()
	else:
		comecou_a_andar.emit()
