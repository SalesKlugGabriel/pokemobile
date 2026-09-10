## ChuvaOverlay.gd — desenha a chuva na tela (09/09). CanvasLayer própria (não
## Control direto num Node2D) — a mesma lição do bug da tira de remédio de
## mais cedo hoje (09/09): só uma CanvasLayer garante espaço de TELA de
## verdade, independente de onde a câmera do mundo está olhando. Sem textura
## nova: CPUParticles2D sem `texture` desenha o quad branco padrão do motor.
extends CanvasLayer

const QTD_GOTAS         : int   = 200
const VELOCIDADE_MIN    : float = 900.0
const VELOCIDADE_MAX    : float = 1300.0
const COR_GOTA          : Color = Color(0.75, 0.82, 0.95, 0.5)

var _particulas : CPUParticles2D

func _ready() -> void:
	layer = 3  # acima do mundo (mapa/entidades), abaixo do HUD (layer 5+)

	_particulas = CPUParticles2D.new()
	_particulas.name = "Gotas"
	_particulas.emitting = false
	_particulas.amount = QTD_GOTAS
	_particulas.lifetime = 1.1
	_particulas.preprocess = 1.1  # já nasce com gotas em todas as alturas
	_particulas.direction = Vector2(0.25, 1.0)
	_particulas.spread = 3.0
	_particulas.gravity = Vector2.ZERO
	_particulas.initial_velocity_min = VELOCIDADE_MIN
	_particulas.initial_velocity_max = VELOCIDADE_MAX
	_particulas.scale_amount_min = 1.5
	_particulas.scale_amount_max = 3.0
	_particulas.color = COR_GOTA
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(_particulas)

	_reposicionar()
	get_viewport().size_changed.connect(_reposicionar)

func _reposicionar() -> void:
	var tela : Vector2 = get_viewport().get_visible_rect().size
	_particulas.position = Vector2(tela.x * 0.5, -20.0)
	_particulas.emission_rect_extents = Vector2(tela.x * 0.6, 4.0)

func set_chovendo(ativo: bool) -> void:
	if _particulas:
		_particulas.emitting = ativo
