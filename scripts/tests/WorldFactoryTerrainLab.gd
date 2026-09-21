## WORLD_LAB Fase 4 — terreno isolado da fábrica, sem gameplay/spawn/scatter.
extends Node3D

const WorldSpec := preload("res://scripts/world_factory/WorldSpec.gd")
const TerrainFactory := preload("res://scripts/world_factory/WorldTerrainFactory.gd")
const VegetationScatter := preload("res://scripts/world_factory/WorldVegetationScatter.gd")
const PLAYER_V1 := preload("res://assets/characters/player_v1/player_v1.glb")
const TERRAIN_SHADER := preload("res://assets/shaders/v3/terrain.gdshader")
const WATER_SHADER := preload("res://assets/shaders/v3/water.gdshader")
const ROCK_VARIANTS := {
	"small": preload("res://assets/models/environment/rocks/rock_small.glb"),
	"round": preload("res://assets/models/environment/rocks/rock_round.glb"),
	"angular": preload("res://assets/models/environment/rocks/rock_angular.glb"),
	"large": preload("res://assets/models/environment/rocks/rock_large.glb"),
	"flat": preload("res://assets/models/environment/rocks/rock_flat.glb")
}
const TREE_VARIANTS := {
	"a": preload("res://assets/models/environment/trees/tree_a.glb"),
	"b": preload("res://assets/models/environment/trees/tree_b.glb"),
	"c": preload("res://assets/models/environment/trees/tree_c.glb"),
	"d": preload("res://assets/models/environment/trees/tree_d.glb"),
	"e": preload("res://assets/models/environment/trees/tree_e.glb")
}
const TREE_LOD1_VARIANTS := {
	"a": preload("res://assets/models/environment/trees/tree_a_lod1.glb"),
	"b": preload("res://assets/models/environment/trees/tree_b_lod1.glb"),
	"c": preload("res://assets/models/environment/trees/tree_c_lod1.glb"),
	"d": preload("res://assets/models/environment/trees/tree_d_lod1.glb"),
	"e": preload("res://assets/models/environment/trees/tree_e_lod1.glb")
}
const GRASS_VARIANTS := {
	"short": preload("res://assets/models/environment/grass/grass_short.glb"),
	"mid": preload("res://assets/models/environment/grass/grass_mid.glb"),
	"tall": preload("res://assets/models/environment/grass/grass_tall.glb")
}
const CORAL_VARIANTS := {
	"branch": preload("res://assets/models/environment/corals/coral_branch.glb"),
	"crown": preload("res://assets/models/environment/corals/coral_crown.glb"),
	"fan": preload("res://assets/models/environment/corals/coral_fan.glb")
}

var factory: WorldTerrainFactory
var chunk_count := 0
var vegetation_count := {}


func _ready() -> void:
	var spec := WorldSpec.carregar_world_lab()
	var errors := WorldSpec.validar(spec)
	if not errors.is_empty():
		push_error("WORLD_LAB spec inválida: " + str(errors))
		return
	factory = TerrainFactory.new(spec)
	_build_chunks(spec)
	_build_water(spec)
	_build_rock_formations(spec)
	_build_vegetation(spec)
	_place_scale_reference(spec)
	_configure_camera()


func _build_chunks(spec: Dictionary) -> void:
	var bounds: Dictionary = spec["bounds_m"]
	var terrain: Dictionary = spec["terrain"]
	var count_x := int(float(bounds["width"]) / float(terrain["chunk_size_m"]))
	var count_z := int(float(bounds["depth"]) / float(terrain["chunk_size_m"]))
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("sea_level", factory.nivel_do_mar())
	material.set_shader_parameter("shoreline_height", factory.largura_linha_dagua_m() * 0.18)
	material.set_shader_parameter("beach_height", factory.largura_praia_m() * 0.26)
	material.set_shader_parameter("rock_height", float(terrain.get("rock_height_start_m", 10.0)))
	material.set_shader_parameter("rock_slope", float(terrain.get("rock_slope_start", 0.42)))
	for cx in count_x:
		for cz in count_z:
			var root := Node3D.new()
			root.name = "TerrainChunk_%d_%d" % [cx, cz]
			add_child(root)
			var mesh := factory.gerar_malha_chunk(cx, cz)
			var visual := MeshInstance3D.new()
			visual.name = "Visual"
			visual.mesh = mesh
			visual.material_override = material
			root.add_child(visual)
			var body := StaticBody3D.new()
			body.name = "Collision"
			var shape := CollisionShape3D.new()
			shape.shape = mesh.create_trimesh_shape()
			body.add_child(shape)
			root.add_child(body)
			chunk_count += 1


func _build_water(spec: Dictionary) -> void:
	var bounds: Dictionary = spec["bounds_m"]
	var terrain: Dictionary = spec["terrain"]
	var water := MeshInstance3D.new()
	water.name = "WaterVisualOnly"
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(bounds["width"]), float(bounds["depth"]))
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	water.mesh = plane
	water.position = Vector3(
		float(bounds["min_x"]) + float(bounds["width"]) * .5,
		float(terrain["sea_level_m"]),
		float(bounds["min_z"]) + float(bounds["depth"]) * .5)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	add_child(water)


func _build_rock_formations(spec: Dictionary) -> void:
	var visual: Dictionary = spec.get("visual", {})
	var formations: Array = visual.get("rock_formations", [])
	var root := Node3D.new()
	root.name = "RockFormations"
	add_child(root)
	for formation_value in formations:
		if not formation_value is Dictionary:
			push_warning("WORLD_LAB ignorou formação rochosa inválida")
			continue
		var formation: Dictionary = formation_value
		var variant := str(formation.get("variant", ""))
		var packed := ROCK_VARIANTS.get(variant) as PackedScene
		if packed == null:
			push_warning("WORLD_LAB não encontrou variante de rocha: %s" % variant)
			continue
		var position_m: Array = formation.get("position_m", [])
		if position_m.size() != 2:
			push_warning("WORLD_LAB ignorou rocha sem position_m: %s" % formation.get("id", "?"))
			continue
		var x := float(position_m[0])
		var z := float(position_m[1])
		var rock := packed.instantiate() as Node3D
		rock.name = "Rock_%s" % str(formation.get("id", variant))
		rock.position = Vector3(x, factory.altura_em(x, z) - 0.03, z)
		rock.rotation_degrees.y = float(formation.get("yaw_deg", 0.0))
		rock.scale = Vector3.ONE * float(formation.get("scale", 1.0))
		root.add_child(rock)


func _build_vegetation(spec: Dictionary) -> void:
	var scatter := VegetationScatter.new(spec, factory)
	var groups := scatter.gerar()
	var visual: Dictionary = spec.get("visual", {})
	var vegetation: Dictionary = visual.get("vegetation", {})
	var visibility: Dictionary = vegetation.get("visibility", {})
	var tree_settings: Dictionary = vegetation.get("trees", {})
	var root := Node3D.new()
	root.name = "Vegetation"
	add_child(root)

	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://assets/shaders/v3/vegetation.gdshader")
	var tree_material := ShaderMaterial.new()
	tree_material.shader = preload("res://assets/shaders/v3/tree.gdshader")
	var fade := float(visibility["fade_margin_m"])
	vegetation_count = {}
	for kind in ["short", "mid", "tall"]:
		var items: Array = groups["grass_" + kind]
		_add_multimesh(root, "Grass_%s" % kind.capitalize(), GRASS_VARIANTS[kind], items,
			grass_material, 0.0, float(visibility["grass_end_m"]), fade)
		vegetation_count["grass_" + kind] = items.size()

	var trees_by_variant := {}
	for item in groups["trees"]:
		var variant := str(item.get("variant", ""))
		if not trees_by_variant.has(variant):
			trees_by_variant[variant] = []
		trees_by_variant[variant].append(item)
	for variant in TREE_VARIANTS:
		var items: Array = trees_by_variant.get(variant, [])
		_add_multimesh(root, "Trees_%s" % variant.to_upper(), TREE_VARIANTS[variant], items,
			tree_material, 0.0, float(tree_settings["lod0_end_m"]), fade, true)
		_add_multimesh(root, "TreesLod1_%s" % variant.to_upper(), TREE_LOD1_VARIANTS[variant], items,
			tree_material, float(tree_settings["lod0_end_m"]) - float(tree_settings["lod_overlap_m"]),
			float(visibility["tree_end_m"]), fade, false)
	vegetation_count["trees"] = (groups["trees"] as Array).size()

	var corals_by_variant := {}
	for item in groups["corals"]:
		var variant := str(item.get("variant", ""))
		if not corals_by_variant.has(variant):
			corals_by_variant[variant] = []
		corals_by_variant[variant].append(item)
	for variant in CORAL_VARIANTS:
		var items: Array = corals_by_variant.get(variant, [])
		_add_multimesh(root, "Corals_%s" % variant.capitalize(), CORAL_VARIANTS[variant], items,
			null, 0.0, float(visibility["coral_end_m"]), fade)
	vegetation_count["corals"] = (groups["corals"] as Array).size()


func _add_multimesh(root: Node3D, node_name: String, packed: PackedScene, items: Array, material: Material, range_begin: float, range_end: float, fade: float, casts_shadow: bool = true) -> void:
	if items.is_empty():
		return
	var mesh := _extract_mesh(packed)
	if mesh == null:
		push_warning("WORLD_LAB não encontrou mesh em vegetação: %s" % node_name)
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	for index in items.size():
		var item: Dictionary = items[index]
		var scale := float(item["scale"])
		var basis := Basis(Vector3.UP, float(item["yaw"])).scaled(Vector3.ONE * scale)
		multimesh.set_instance_transform(index, Transform3D(basis, item["position"]))
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = multimesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_begin = range_begin
	visual.visibility_range_begin_margin = fade if range_begin > 0.0 else 0.0
	visual.visibility_range_end = range_end
	visual.visibility_range_end_margin = fade
	visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(visual)


func _extract_mesh(packed: PackedScene) -> Mesh:
	var source := packed.instantiate()
	var visual := source.find_child("*", true, false) as MeshInstance3D
	if visual == null:
		source.free()
		return null
	var mesh := visual.mesh
	source.free()
	return mesh


func _place_scale_reference(spec: Dictionary) -> void:
	var spawn: Array = spec["manual_reservations"][0]["center_m"]
	var x := float(spawn[0])
	var z := float(spawn[1])
	var player := PLAYER_V1.instantiate() as Node3D
	player.name = "PlayerV1ScaleReference"
	player.position = Vector3(x, factory.altura_em(x, z) + .01, z)
	add_child(player)
	var animation := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation and animation.has_animation("PLAYER_V1_IDLE"):
		animation.play("PLAYER_V1_IDLE")


func _configure_camera() -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	camera.position = Vector3(13.0, 13.0, 58.0)
	camera.fov = 60.0
	camera.look_at(Vector3(-2.0, 1.5, 7.0), Vector3.UP)
