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

## Cria SpriteFrames para entidade com spritesheet 48×64 (tile 16, padrão).
## texture_path: caminho res:// para o PNG. tile: tamanho de cada frame em
## px (02/09: sprites de marcha — Bicicleta/Montaria/Surf/Voar — usam 32,
## maiores que o resto do jogo de propósito, pro desenho ter espaço pra
## mostrar o personagem montado; ver docs/customizacao-personagem.md,
## "footprint de colisão continua pequeno mesmo com o sprite maior" — quem
## usa o sprite ajusta a posição pra compensar, não é decisão daqui).
static func build_entity_frames(texture_path: String, tile: int = TILE) -> SpriteFrames:
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
		sf.add_frame("idle_" + dir, _atlas(tex, 0, row, tile))

		# walk_<dir> — 2 frames alternados
		sf.add_animation("walk_" + dir)
		sf.set_animation_loop("walk_" + dir, true)
		sf.set_animation_speed("walk_" + dir, 8.0)
		sf.add_frame("walk_" + dir, _atlas(tex, 1, row, tile))
		sf.add_frame("walk_" + dir, _atlas(tex, 2, row, tile))

	# Fallback genérico "idle" e "walk" (sem sufixo de direção)
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 5.0)
	sf.add_frame("idle", _atlas(tex, 0, 0, tile))

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 8.0)
	sf.add_frame("walk", _atlas(tex, 1, 0, tile))
	sf.add_frame("walk", _atlas(tex, 2, 0, tile))

	return sf

## Caminho do sprite de uma espécie, com fallback em 3 níveis: shiny
## dedicado → normal dedicado → placeholder. Nunca quebra por espécie sem
## arte ainda (a maioria das 151, enquanto a arte nova vai sendo gerada aos
## poucos — pedido do Gabriel, 02/09, "primeira temporada, 151 Pokémons,
## mesmo conceito" do player/tileset).
static func pokemon_sprite_path(species_id: int, shiny: bool = false) -> String:
	var normal_path : String = (
		"res://assets/sprites/pokemon/mon_%03d.png" % species_id
		if species_id >= 1 and species_id <= 151
		else "res://assets/sprites/pokemon/placeholder.png"
	)
	if shiny:
		var shiny_path := normal_path.replace(".png", "_shiny.png")
		if ResourceLoader.exists(shiny_path):
			return shiny_path
	return normal_path

## Cria SpriteFrames para Pokémon. Detecta sozinho o formato do arquivo:
## - Formato NOVO (48×64, 4 direções reais — mesmo layout do Treinador/NPC,
##   ver build_entity_frames() acima): gerado aos poucos, espécie por
##   espécie, a partir de 02/09. Já suporta virar de lado/costas de verdade.
## - Formato ANTIGO (32×16, 2 frames, sem direção real — todas as 151
##   espécies até 02/09): mesmo frame único repetido nas 4 direções, como
##   sempre funcionou. Nenhuma espécie quebra enquanto espera a arte nova.
## species_id: número da espécie (1–151) ou 0 para placeholder.
## shiny: usa a variante shiny se já existir (mon_XXX_shiny.png), senão cai
## pro normal — nunca fica sem sprite nenhum por falta da variante shiny.
static func build_pokemon_frames(species_id: int, shiny: bool = false) -> SpriteFrames:
	var path : String = pokemon_sprite_path(species_id, shiny)
	var tex : Texture2D = load(path)
	if not tex:
		tex = load("res://assets/sprites/pokemon/placeholder.png")
	if not tex:
		push_warning("SpriteBuilder: sprite de pokémon não encontrado para id=%d" % species_id)
		return null

	if tex.get_width() >= 48 and tex.get_height() >= 64:
		return build_entity_frames(path, 16)

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

static func _atlas(tex: Texture2D, col: int, row: int, tile: int = TILE) -> AtlasTexture:
	return _atlas_rect(tex, Rect2(col * tile, row * tile, tile, tile))

static func _atlas_rect(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at
