## PlayerVisual3D — ponte de apresentação do Player V1 para o corpo do treinador.
##
## Não controla posição, yaw, física, stamina ou input. O pai
## `TrainerController3D` é a única autoridade dessas decisões e entrega somente
## o estado visual canônico da RFC-007: `idle`, `walk` ou `run`.
class_name PlayerVisual3D
extends Node3D

const CENA_DO_PLAYER := "res://assets/characters/player_v1/player_v1.glb"
const CLIPES_POR_ESTADO := {
	"idle": "PLAYER_V1_IDLE",
	"walk": "PLAYER_V1_WALK",
	"run": "PLAYER_V1_RUN",
}

## 🔴 21/09 — o moonwalk, e por que esta correção existe.
##
## O Gabriel: *"o player sempre anda de costas (moon walk)"*. A causa foi
## **medida**, não deduzida — em 17/09 eu já errei este mesmo diagnóstico duas
## vezes lendo código.
##
## Somei os vértices do GLB por altura e olhei pra que lado eles crescem:
##
##     sapatos (y < 0,15) · 626 vértices · z de −0,119 a +0,273
##     boné    (y > 1,35) · 878 vértices · z de −0,133 a +0,239
##
## Dedos do pé e aba do boné apontam os dois pra **+Z**. Ou seja: **a frente do
## modelo é +Z**, e a RFC-007 declarava −Z. A afirmação estava errada.
##
## Em Godot, um nó com `rotation.y = 0` olha pra −Z, e `Locomocao3D.girar_para`
## mira −Z corretamente. Com o modelo de frente pra +Z, o corpo vira pro rumo
## certo e o boneco aparece de costas — exatamente o moonwalk.
##
## ⚠️ A RFC-007 proíbe **"correção de 180° silenciosa"**, e ela está certa: uma
## rotação escondida transforma um defeito de asset num mistério de gameplay.
## Esta correção não é silenciosa — ela é declarada aqui, medida acima, e
## **travada por teste**: `teste_player_v1_frente.gd` remede o GLB e reprova se
## a orientação do asset mudar. No dia em que o Codex reexportar o modelo de
## frente pra −Z, o teste reprova e manda apagar estas duas linhas.
const CORRECAO_DE_FRENTE : float = PI

var _modelo: Node3D = null
var _animacao: AnimationPlayer = null
var _estado_pendente := "idle"
var _fallback_ativo := false


func _ready() -> void:
	name = "PlayerVisualV1"
	_instanciar_modelo()
	apresentar_locomocao(_estado_pendente)


## A única porta da apresentação de locomoção. Não aceita intenção de corrida,
## stamina nem velocidade: essas regras vivem no controlador de gameplay.
func apresentar_locomocao(estado: String) -> void:
	_estado_pendente = estado if CLIPES_POR_ESTADO.has(estado) else "idle"
	if _animacao == null:
		return
	var clipe: String = CLIPES_POR_ESTADO[_estado_pendente]
	if not _animacao.has_animation(clipe):
		push_warning("Player V1 sem Action esperada: " + clipe)
		return
	if _animacao.current_animation != clipe:
		_animacao.play(clipe, 0.12)


func tem_modelo() -> bool:
	return _modelo != null and not _fallback_ativo


func fallback_ativo() -> bool:
	return _fallback_ativo


func clipe_atual() -> String:
	return _animacao.current_animation if _animacao != null else ""


func _instanciar_modelo() -> void:
	var cena := load(CENA_DO_PLAYER) as PackedScene
	if cena == null:
		_ativar_fallback("não foi possível carregar " + CENA_DO_PLAYER)
		return
	_modelo = cena.instantiate() as Node3D
	if _modelo != null:
		# Ver CORRECAO_DE_FRENTE: o asset olha pra +Z; o Godot e o
		# `girar_para` esperam −Z.
		_modelo.rotate_y(CORRECAO_DE_FRENTE)
	if _modelo == null:
		_ativar_fallback("o GLB não instanciou como Node3D")
		return
	_modelo.name = "PlayerV1GLB"
	add_child(_modelo)
	_animacao = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animacao == null:
		_ativar_fallback("o GLB não contém AnimationPlayer")


## Falha de asset não pode voltar silenciosamente à cápsula amarela antiga.
## O magenta emissivo comunica visualmente o problema no laboratório e mantém
## o treinador localizável enquanto a causa é corrigida.
func _ativar_fallback(motivo: String) -> void:
	_fallback_ativo = true
	push_warning("PlayerVisual3D: fallback visível — " + motivo)
	if _modelo != null:
		_modelo.queue_free()
		_modelo = null
	_animacao = null
	var vis := MeshInstance3D.new()
	vis.name = "PlayerV1FallbackVisivel"
	var malha := CapsuleMesh.new()
	malha.radius = 0.35
	malha.height = 1.60
	vis.mesh = malha
	vis.position.y = 0.80
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.05, 0.68)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.0, 0.35)
	vis.material_override = mat
	add_child(vis)
