## Terreno3D.gd — O terreno do laboratório (§23, §26).
##
## Malha gerada por código, com altura, encosta, praia e fundo de água.
## **Decisão 3 (14/09): sem plugin de terreno de terceiros.** Motivos no
## `GAMEPLAY_V3.md` — resumo: o renderer é `gl_compatibility`, o slice é pequeno
## de propósito, e dependência externa num pivô que já tem risco é risco a mais.
##
## ── A regra que governa o desenho (§26) ─────────────────────────────────────
##
## *"Transição: terra → areia → água rasa → água profunda. **Sem parede
## artificial entre mar e terra.**"*
##
## Era queixa antiga do Gabriel no mundo 2D — a muralha de árvores na costa. Em
## 3D isso não se resolve com regra de colisão: resolve-se com **relevo**. A
## altura desce continuamente até abaixo do nível do mar, e o jogador entra na
## água andando. Se a malha tiver degrau ali, a parede volta.
##
## ── Por que a altura é uma FUNÇÃO, e não um mapa de pixels ──────────────────
##
## `altura_em(x, z)` é matemática pura e determinística. Isso dá três coisas de
## graça: o mesmo terreno em qualquer máquina, colisão que concorda com o visual
## por construção (os dois leem a mesma função), e a possibilidade de perguntar
## a altura de um ponto sem raycast — que é o que o spawn vai precisar.
class_name Terreno3D
extends Node3D

## Tamanho do laboratório, em metros. Pequeno de propósito (§10): não é Kanto.
const LARGURA : float = 160.0
const PROFUNDIDADE : float = 160.0

## Resolução da malha. 2 m por quadrado é grosseiro e suficiente pra provar
## controle e travessia; refinar antes de saber se presta é otimizar no escuro.
const PASSO : float = 2.0

## §26: os níveis que definem a costa.
const NIVEL_DO_MAR : float = 0.0
const FIM_DA_AREIA : float = 1.2      ## acima disto já é terra
const AGUA_RASA_ATE : float = -1.5    ## abaixo disto é água profunda

## Cores provisórias. Arte é do Codex (§48) — isto é só pra dar pra ver onde
## cada coisa começa enquanto a mecânica é testada.
const COR_TERRA : Color = Color(0.28, 0.40, 0.22)
const COR_AREIA : Color = Color(0.76, 0.70, 0.50)
const COR_ROCHA : Color = Color(0.42, 0.40, 0.38)

var _malha : MeshInstance3D = null
var _corpo : StaticBody3D = null

func _ready() -> void:
	_gerar()

# ──────────────────────────────────────────────────────────────────────────────
# A altura
# ──────────────────────────────────────────────────────────────────────────────

## A altura do terreno num ponto. **A única fonte de verdade da geografia.**
##
## Visual e colisão leem esta mesma função, então nunca podem discordar — é o
## tipo de divergência que produz o jogador andando no ar ou afundando no chão.
static func altura_em(x: float, z: float) -> float:
	# Uma inclinação geral do norte pro sul: é ela que cria a costa. Sem um
	# sentido dominante, a "praia" viraria poças espalhadas.
	var base : float = (z / PROFUNDIDADE) * 14.0 - 3.0

	# Colinas. Senos de períodos diferentes, que não se repetem visivelmente na
	# escala do laboratório.
	base += sin(x * 0.055) * cos(z * 0.041) * 3.4
	base += sin(x * 0.017 + 1.3) * 2.1
	base += cos(z * 0.023 - 0.7) * 1.6

	# O morro rochoso, com FALÉSIA de verdade (§23: "cliffs").
	#
	# 🔴 A primeira versão subia 14 m ao longo de 26 m de raio — uma rampa de
	# ~28°, que o treinador sobe andando. O teste pegou: **não havia uma única
	# encosta íngreme no mapa inteiro**, então a regra de ângulo máximo do
	# controlador nunca era exercida, e a §23 pedia falésia que não existia.
	#
	# Agora o perfil tem duas partes: um platô alto no topo e uma PAREDE curta
	# na borda. É a parede que faz o morro ser um obstáculo a contornar, e não
	# uma ladeira a subir — que é a diferença entre relevo e decoração.
	const RAIO_DO_MORRO : float = 26.0
	const RAIO_DO_PLATO : float = 20.0
	const ALTURA_DO_MORRO : float = 16.0
	var ao_morro := Vector2(x - 46.0, z + 40.0).length()
	if ao_morro < RAIO_DO_PLATO:
		base += ALTURA_DO_MORRO
	elif ao_morro < RAIO_DO_MORRO:
		# 16 m caindo em 6 m de distância: ~70°, parede de verdade. O
		# `smoothstep` evita a quina dura no topo e na base sem suavizar a
		# ponto de virar rampa.
		var t : float = (ao_morro - RAIO_DO_PLATO) / (RAIO_DO_MORRO - RAIO_DO_PLATO)
		base += ALTURA_DO_MORRO * (1.0 - smoothstep(0.0, 1.0, t))

	# A praia. Onde a altura passa perto do nível do mar, ela é ACHATADA — é o
	# que transforma o encontro de terra e água numa faixa caminhável em vez de
	# um degrau. É a §26 virando geometria.
	#
	# 🔴 A primeira versão usava `if absf(...) < 2.5`, e o teste pegou: um
	# achatamento CONDICIONAL cria um degrau exatamente na borda da condição.
	# Ponto logo dentro da faixa era puxado 0,55 pro nível do mar, ponto logo
	# fora não era — e a diferença virava um salto de **1,60 m em 0,78 m**.
	#
	# Ou seja: o código escrito pra evitar a "parede artificial entre mar e
	# terra" estava construindo uma. A correção é o achatamento virar CONTÍNUO —
	# força máxima no nível do mar, caindo suavemente até zero na borda da faixa.
	const FAIXA_DA_PRAIA : float = 2.5
	var distancia_do_mar : float = absf(base - NIVEL_DO_MAR)
	var peso : float = 1.0 - smoothstep(0.0, FAIXA_DA_PRAIA, distancia_do_mar)
	if peso > 0.0:
		base = lerpf(base, NIVEL_DO_MAR - 0.35, 0.55 * peso)
	return base

## Tipo de superfície num ponto. Usado pra cor, pra som de passo e — mais pra
## frente — pra decidir se o Pokémon aquático pode entrar (§27).
static func superficie_em(x: float, z: float) -> String:
	var y := altura_em(x, z)
	if y <= AGUA_RASA_ATE:
		return "agua_profunda"
	if y < NIVEL_DO_MAR:
		return "agua_rasa"
	if y < FIM_DA_AREIA:
		return "areia"
	if y > 12.0:
		return "rocha"
	return "terra"

# ──────────────────────────────────────────────────────────────────────────────
# A malha
# ──────────────────────────────────────────────────────────────────────────────

func _gerar() -> void:
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)

	var colunas : int = int(LARGURA / PASSO)
	var linhas : int = int(PROFUNDIDADE / PASSO)
	var x0 : float = -LARGURA * 0.5
	var z0 : float = -PROFUNDIDADE * 0.5

	for i in colunas:
		for j in linhas:
			var xa : float = x0 + i * PASSO
			var xb : float = xa + PASSO
			var za : float = z0 + j * PASSO
			var zb : float = za + PASSO
			var a := Vector3(xa, altura_em(xa, za), za)
			var b := Vector3(xb, altura_em(xb, za), za)
			var c := Vector3(xb, altura_em(xb, zb), zb)
			var d := Vector3(xa, altura_em(xa, zb), zb)
			# Dois triângulos por quadrado, com a cor por vértice — assim a
			# transição areia/terra é um degradê e não uma linha reta.
			_triangulo(ferramenta, a, b, c)
			_triangulo(ferramenta, a, c, d)

	ferramenta.generate_normals()
	var malha : ArrayMesh = ferramenta.commit()

	_malha = MeshInstance3D.new()
	_malha.name = "Superficie"
	_malha.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	_malha.material_override = mat
	add_child(_malha)

	# Colisão a partir da MESMA malha: visual e colisão não podem divergir.
	_corpo = StaticBody3D.new()
	_corpo.name = "Colisao"
	var forma := CollisionShape3D.new()
	forma.shape = malha.create_trimesh_shape()
	_corpo.add_child(forma)
	add_child(_corpo)

	_montar_agua()

func _triangulo(f: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		f.set_color(_cor_da_altura(v.y))
		f.add_vertex(v)

func _cor_da_altura(y: float) -> Color:
	if y < NIVEL_DO_MAR:
		return COR_AREIA.darkened(0.25)   # fundo submerso
	if y < FIM_DA_AREIA:
		return COR_AREIA
	if y > 12.0:
		return COR_ROCHA
	# Degradê entre areia e terra: sem ele a costa vira uma linha desenhada.
	return COR_AREIA.lerp(COR_TERRA, clampf((y - FIM_DA_AREIA) / 4.0, 0.0, 1.0))

## A água. Plano simples e **sem colisão**: quem decide se dá pra entrar é o
## controlador de travessia (§27), não uma parede física. Água que empurra o
## jogador é exatamente a "parede artificial" que a §26 proíbe.
func _montar_agua() -> void:
	var agua := MeshInstance3D.new()
	agua.name = "Agua"
	var plano := PlaneMesh.new()
	plano.size = Vector2(LARGURA * 1.4, PROFUNDIDADE * 1.4)
	agua.mesh = plano
	agua.position.y = NIVEL_DO_MAR
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.38, 0.55, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	agua.material_override = mat
	add_child(agua)

# ──────────────────────────────────────────────────────────────────────────────
# Perguntas que o resto do jogo faz ao terreno
# ──────────────────────────────────────────────────────────────────────────────

## Um ponto sobre o terreno, dado x e z. Serve pra nascer entidade sem raycast.
static func ponto_em(x: float, z: float, acima: float = 0.0) -> Vector3:
	return Vector3(x, altura_em(x, z) + acima, z)

## Dá pra andar aqui a pé? Água profunda, não — ali é surf (§27).
static func caminhavel(x: float, z: float) -> bool:
	return altura_em(x, z) > AGUA_RASA_ATE

## A inclinação no ponto, em radianos. Lê a mesma função de altura, então
## concorda com a colisão por construção.
static func inclinacao_em(x: float, z: float) -> float:
	var d : float = PASSO * 0.5
	var dx : float = altura_em(x + d, z) - altura_em(x - d, z)
	var dz : float = altura_em(x, z + d) - altura_em(x, z - d)
	var normal := Vector3(-dx, 2.0 * d, -dz).normalized()
	return normal.angle_to(Vector3.UP)
