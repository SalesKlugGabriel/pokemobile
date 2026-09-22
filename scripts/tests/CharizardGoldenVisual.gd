## Cena visual de escala e leitura do Charizard; sem gameplay nem lógica própria.
extends Node3D

const CHARIZARD := preload("res://assets/models/pokemon/6.glb")
const PLAYER := preload("res://assets/characters/player_v1/player_v1.glb")


func _ready() -> void:
	var solo := MeshInstance3D.new()
	solo.name = "SoloEscala"
	var plano := PlaneMesh.new()
	plano.size = Vector2(12, 12)
	solo.mesh = plano
	var areia := StandardMaterial3D.new()
	areia.albedo_color = Color(0.62, 0.63, 0.55)
	areia.roughness = 0.96
	solo.material_override = areia
	add_child(solo)

	var charizard := CHARIZARD.instantiate() as Node3D
	charizard.name = "CharizardGolden"
	charizard.position.x = 0.70
	add_child(charizard)
	var treinador := PLAYER.instantiate() as Node3D
	treinador.name = "TreinadorEscala160cm"
	treinador.position.x = -1.15
	add_child(treinador)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-53, -30, 0)
	sol.light_energy = 1.5
	add_child(sol)
	var ambiente := WorldEnvironment.new()
	var ceu := Environment.new()
	ceu.background_mode = Environment.BG_COLOR
	ceu.background_color = Color(0.37, 0.53, 0.68)
	ceu.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ceu.ambient_light_color = Color(0.70, 0.76, 0.82)
	ceu.ambient_light_energy = 0.7
	ambiente.environment = ceu
	add_child(ambiente)
	var camera := Camera3D.new()
	camera.name = "CameraGameplayDistance"
	camera.position = Vector3(2.8, 2.35, -4.1)
	camera.fov = 55
	add_child(camera)
	camera.look_at(Vector3(-0.1, 0.85, 0), Vector3.UP)
	camera.current = true
