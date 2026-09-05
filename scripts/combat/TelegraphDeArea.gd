## TelegraphDeArea.gd — O aviso no chão antes do golpe de área cair (05/09).
##
## Segundo item do MVP das Dungeons Elementais, e o que transforma "risco" em
## algo justo. Até aqui um golpe de área acontecia no mesmo instante em que o
## Pokémon decidia usá-lo: dano do nada, impossível de evitar. Isso não é
## dificuldade, é sorte — e o Gabriel pediu risco de verdade, não azar.
##
## Com o telegraph, o golpe passa a ter QUATRO FASES, e o dano só sai na
## terceira:
##
##   1. CARGA (0,30 s) — quem vai atacar dá uma inflada. Ainda dá pra reagir.
##   2. AVISO (0,90 s) — o círculo aparece no chão e vai enchendo. É a janela
##      pra sair de dentro dele.
##   3. IMPACTO (0,15 s) — o círculo pisca e o dano sai, mirando quem está
##      dentro NAQUELE instante — não em quem estava quando o golpe começou.
##      É isso que faz desviar funcionar de verdade.
##   4. RESCALDO (0,60 s) — o círculo apaga. Só leitura, sem efeito.
##
## Desenhado ABAIXO das entidades (entra logo depois do TileMap na cena), pra
## marcar o chão sem tapar o Pokémon que o jogador precisa estar vendo.
class_name TelegraphDeArea
extends Node2D

const CARGA    : float = 0.30
const AVISO    : float = 0.90
const IMPACTO  : float = 0.15
const RESCALDO : float = 0.60

## Janela total entre decidir o golpe e o dano sair. Quem chama espera isto.
const ATE_O_DANO : float = CARGA + AVISO

var raio : float = 128.0
var cor : Color = Color(1.0, 0.45, 0.2)
var _preenchimento : float = 0.0   ## 0..1, quanto o círculo já encheu
var _clarao : float = 0.0          ## 0..1, o flash do impacto

## Chamada única: cria, anima as 4 fases e se apaga sozinha.
## `atacante` é opcional — é quem infla na fase de carga.
static func disparar(cena: Node, centro: Vector2, raio_px: float, cor_do_tipo: Color, atacante: Node = null) -> void:
	if cena == null or raio_px <= 0.0:
		return
	var t := TelegraphDeArea.new()
	t.raio = raio_px
	t.cor = cor_do_tipo
	t.global_position = centro
	cena.add_child(t)
	# Logo depois do TileMap (índice 0) = desenha no chão, debaixo de todo
	# mundo. Sem isso o aviso tapa justamente o Pokémon que ele avisa.
	if cena.get_child_count() > 1:
		cena.move_child(t, 1)
	t._animar(atacante)

func _animar(atacante: Node) -> void:
	var tw := create_tween()

	# 1. CARGA — a inflada de quem vai bater.
	if atacante != null and is_instance_valid(atacante):
		var sp := atacante.get_node_or_null("Sprite") as Node2D
		if sp != null:
			var base : Vector2 = sp.scale
			var tc := atacante.create_tween()
			tc.tween_property(sp, "scale", base * 1.18, CARGA).set_trans(Tween.TRANS_SINE)
			tc.tween_property(sp, "scale", base, IMPACTO)
	tw.tween_interval(CARGA)

	# 2. AVISO — o círculo enchendo. Enche acelerando (TRANS_QUAD, EASE_IN):
	# devagar no começo e rápido no fim, então "está quase" se lê sozinho.
	tw.tween_method(_definir_preenchimento, 0.0, 1.0, AVISO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. IMPACTO — o clarão. O dano em si sai de quem chamou, no mesmo
	# instante (ATE_O_DANO), pra lógica de dano não morar na camada visual.
	tw.tween_method(_definir_clarao, 1.0, 0.0, IMPACTO)

	# 4. RESCALDO — apaga.
	tw.tween_property(self, "modulate:a", 0.0, RESCALDO)
	tw.tween_callback(queue_free)

func _definir_preenchimento(v: float) -> void:
	_preenchimento = v
	queue_redraw()

func _definir_clarao(v: float) -> void:
	_clarao = v
	queue_redraw()

func _draw() -> void:
	# Borda: onde o golpe termina. Sempre visível, mesmo com o círculo vazio.
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.85), 4.0, true)
	# Miolo tênue: mostra que a área inteira conta, não só a borda.
	draw_circle(Vector2.ZERO, raio, Color(cor.r, cor.g, cor.b, 0.12))
	# Preenchimento: o relógio. Quando encosta na borda, o golpe cai.
	if _preenchimento > 0.0:
		draw_circle(Vector2.ZERO, raio * _preenchimento, Color(cor.r, cor.g, cor.b, 0.34))
	if _clarao > 0.0:
		draw_circle(Vector2.ZERO, raio, Color(1, 1, 1, 0.55 * _clarao))

## Cor por tipo do golpe — a leitura mais rápida possível de "o que vem aí".
## Fogo laranja, água azul, elétrico amarelo: o jogador não lê o nome do
## golpe no meio da briga, ele lê a cor.
const COR_POR_TIPO : Dictionary = {
	"fire": Color(1.0, 0.42, 0.15),
	"water": Color(0.28, 0.6, 1.0),
	"electric": Color(1.0, 0.85, 0.2),
	"grass": Color(0.4, 0.85, 0.35),
	"ice": Color(0.55, 0.9, 1.0),
	"poison": Color(0.72, 0.35, 0.85),
	"ground": Color(0.82, 0.66, 0.36),
	"rock": Color(0.7, 0.6, 0.4),
	"psychic": Color(1.0, 0.45, 0.7),
	"ghost": Color(0.5, 0.4, 0.75),
	"dragon": Color(0.45, 0.4, 0.9),
	"dark": Color(0.4, 0.35, 0.38),
	"steel": Color(0.72, 0.75, 0.8),
	"fairy": Color(1.0, 0.65, 0.85),
	"fighting": Color(0.85, 0.35, 0.25),
	"flying": Color(0.65, 0.72, 0.95),
	"bug": Color(0.65, 0.78, 0.25),
	"normal": Color(0.85, 0.85, 0.8),
}

## Minúsculas na força: o moves.json grava o tipo capitalizado ("Fire"), e a
## tabela acima é minúscula. Sem isto TODO golpe de área saía com a cor padrão
## laranja — a leitura por cor existiria no código e não na tela. Achado pelo
## teste, não a olho.
static func cor_do_tipo(tipo: String) -> Color:
	return COR_POR_TIPO.get(tipo.to_lower(), Color(1.0, 0.45, 0.2))
