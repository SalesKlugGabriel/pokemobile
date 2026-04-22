## SpriteBuilder.gd — Cria SpriteFrames em runtime a partir dos spritesheets.
## Usado por entidades no _on_ready() para popular o AnimatedSprite2D sem editor.
##
## Spritesheet layout (48×64, tiles 16×16):
##   col 0 = idle, col 1 = walk_a, col 2 = walk_b
##   row 0 = down, row 1 = up, row 2 = left, row 3 = right
class_name SpriteBuilder
extends RefCounted

const TILE : int = 16
const DIRS : Array = ["down", "up", "left", "right"]

## Cria SpriteFrames para entidade com spritesheet 48×64.
## texture_path: caminho res:// para o PNG.
static func build_entity_frames(texture_path: String) -> SpriteFrames:
	var tex : Texture2D = load(texture_path)
	if not tex:
		push_warning("SpriteBuilder: não encontrou '%s'" % texture_path)
		return null

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for row in DIRS.size():
		var dir : String = DIRS[row]

		# idle_<dir> — 1 frame estático
		sf.add_animation("idle_" + dir)
		sf.set_animation_loop("idle_" + dir, true)
		sf.set_animation_speed("idle_" + dir, 5.0)
		sf.add_frame("idle_" + dir, _atlas(tex, 0, row))

		# walk_<dir> — 2 frames alternados
		sf.add_animation("walk_" + dir)
		sf.set_animation_loop("walk_" + dir, true)
		sf.set_animation_speed("walk_" + dir, 8.0)
		sf.add_frame("walk_" + dir, _atlas(tex, 1, row))
		sf.add_frame("walk_" + dir, _atlas(tex, 2, row))

	# Fallback genérico "idle" e "walk" (sem sufixo de direção)
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 5.0)
	sf.add_frame("idle", _atlas(tex, 0, 0))

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 8.0)
	sf.add_frame("walk", _atlas(tex, 1, 0))
	sf.add_frame("walk", _atlas(tex, 2, 0))

	return sf

## Cria SpriteFrames para Pokémon (spritesheet 32×16, 2 frames lado a lado).
## species_id: número da espécie (1–151) ou 0 para placeholder.
static func build_pokemon_frames(species_id: int) -> SpriteFrames:
	var path : String
	if species_id >= 1 and species_id <= 151:
		path = "res://assets/sprites/pokemon/mon_%03d.png" % species_id
	else:
		path = "res://assets/sprites/pokemon/placeholder.png"

	var tex : Texture2D = load(path)
	if not tex:
		tex = load("res://assets/sprites/pokemon/placeholder.png")
	if not tex:
		push_warning("SpriteBuilder: sprite de pokémon não encontrado para id=%d" % species_id)
		return null

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	# idle — frame 0
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 3.0)
	sf.add_frame("idle", _atlas_rect(tex, Rect2(0, 0, 16, 16)))

	# walk — 2 frames
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 6.0)
	sf.add_frame("walk", _atlas_rect(tex, Rect2(0, 0, 16, 16)))
	sf.add_frame("walk", _atlas_rect(tex, Rect2(16, 0, 16, 16)))

	# aliases idle_down / walk_down (compatibilidade com BaseEntity._play_anim)
	for dir in SpriteBuilder.DIRS:
		sf.add_animation("idle_" + dir)
		sf.set_animation_loop("idle_" + dir, true)
		sf.set_animation_speed("idle_" + dir, 3.0)
		sf.add_frame("idle_" + dir, _atlas_rect(tex, Rect2(0, 0, 16, 16)))

		sf.add_animation("walk_" + dir)
		sf.set_animation_loop("walk_" + dir, true)
		sf.set_animation_speed("walk_" + dir, 6.0)
		sf.add_frame("walk_" + dir, _atlas_rect(tex, Rect2(0, 0, 16, 16)))
		sf.add_frame("walk_" + dir, _atlas_rect(tex, Rect2(16, 0, 16, 16)))

	return sf

# ──────────────────────────────────────────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────────────────────────────────────────

static func _atlas(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	return _atlas_rect(tex, Rect2(col * TILE, row * TILE, TILE, TILE))

static func _atlas_rect(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at
