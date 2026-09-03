## SpriteBuilder.gd — Cria SpriteFrames em runtime a partir dos spritesheets.
## Usado por entidades no _on_ready() para popular o AnimatedSprite2D sem editor.
##
## Spritesheet layout (384×512, tiles 128×128 — migração tile128, 03/09):
##   col 0 = idle, col 1 = walk_a, col 2 = walk_b
##   row 0 = down, row 1 = up, row 2 = left, row 3 = right
class_name SpriteBuilder
extends RefCounted

const TILE : int = 128   # migração tile128 (03/09): era 16
const DIRS : Array = ["down", "up", "left", "right"]

## Cria SpriteFrames para entidade com spritesheet 384×512 (tile 128,
## padrão desde a migração tile128 de 03/09). texture_path: caminho res://
## para o PNG. tile: LARGURA de cada frame em px (a Bicicleta usa 256,
## maior que o resto do jogo de propósito, pro desenho ter espaço pra
## mostrar o personagem montado; ver docs/customizacao-personagem.md,
## "footprint de colisão continua pequeno mesmo com o sprite maior" — quem
## usa o sprite ajusta a posição pra compensar, não é decisão daqui).
## tile_h: ALTURA de cada frame, só quando diferente da largura (03/09,
## pedido do Gabriel: Treinador/NPC podem ter "2 tiles de altura por 1 de
## largura" — sprite mais alto que largo, tipo Zelda/Stardew, pra caber
## corpo humano de verdade sem ficar espremido num quadrado). -1 = usa o
## mesmo valor de `tile` (quadrado, como todo o resto do jogo).
static func build_entity_frames(texture_path: String, tile: int = TILE, tile_h: int = -1) -> SpriteFrames:
	var tex : Texture2D = load(texture_path)
	if not tex:
		push_warning("SpriteBuilder: não encontrou '%s'" % texture_path)
		return null
	return build_entity_frames_from_texture(tex, tile, tile_h)

## Mesma coisa que build_entity_frames(), mas recebe a Texture2D já pronta
## em vez de um caminho res:// — usado quando a textura vem de outro lugar
## (Editor Visual, 02/09: sprite editada baixada em bytes no boot, não
## empacotada no jogo, então não existe um caminho res:// pra ela).
static func build_entity_frames_from_texture(tex: Texture2D, tile: int = TILE, tile_h: int = -1) -> SpriteFrames:
	var th : int = tile_h if tile_h > 0 else tile
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for row in DIRS.size():
		var dir : String = DIRS[row]

		# idle_<dir> — 1 frame estático
		sf.add_animation("idle_" + dir)
		sf.set_animation_loop("idle_" + dir, true)
		sf.set_animation_speed("idle_" + dir, 5.0)
		sf.add_frame("idle_" + dir, _atlas(tex, 0, row, tile, th))

		# walk_<dir> — 2 frames alternados
		sf.add_animation("walk_" + dir)
		sf.set_animation_loop("walk_" + dir, true)
		sf.set_animation_speed("walk_" + dir, 8.0)
		sf.add_frame("walk_" + dir, _atlas(tex, 1, row, tile, th))
		sf.add_frame("walk_" + dir, _atlas(tex, 2, row, tile, th))

	# Fallback genérico "idle" e "walk" (sem sufixo de direção)
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 5.0)
	sf.add_frame("idle", _atlas(tex, 0, 0, tile, th))

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 8.0)
	sf.add_frame("walk", _atlas(tex, 1, 0, tile, th))
	sf.add_frame("walk", _atlas(tex, 2, 0, tile, th))

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
## - Formato NOVO (4 direções reais — mesmo layout do Treinador/NPC,
##   build_entity_frames): 3 colunas × 4 linhas, tile = largura/3. Migração
##   tile128 (03/09) trocou o tile de 32 pra 128 (sheet 384×512) — em vez de
##   cravar o tamanho no código de novo, o tile agora é CALCULADO a partir
##   da própria largura da imagem (largura/3), então uma futura troca de
##   resolução não precisa voltar aqui pra mudar um número mágico. Todas as
##   151 espécies estão neste formato desde 02/09 (arte real, baixada via
##   PokeAPI — pedido do Gabriel de usar sprite pronta em vez de gerar por
##   IA); só precisa ter pelo menos 96px de largura pra não confundir com o
##   formato antigo abaixo.
## - Formato ANTIGO (32×16, 2 frames, sem direção real): só sobra em
##   `placeholder.png` agora — nunca quebra se algum id vier sem arte.
## species_id: número da espécie (1–151) ou 0 para placeholder.
## shiny: usa a variante shiny se já existir (mon_XXX_shiny.png), senão cai
## pro normal — nunca fica sem sprite nenhum por falta da variante shiny.
static func build_pokemon_frames(species_id: int, shiny: bool = false) -> SpriteFrames:
	var path : String = pokemon_sprite_path(species_id, shiny)
	# Achado (Editor Visual, 02/09): se o Gabriel editou esta sprite pelo
	# editor, usa a versão editada (baixada uma vez no boot pelo
	# SpriteOverrides) em vez da que veio empacotada no jogo.
	var override_name : String = path.get_file()
	var tex : Texture2D = SpriteOverrides.get_texture(override_name) if SpriteOverrides.has_override(override_name) else null
	if not tex:
		tex = load(path)
	if not tex:
		tex = load("res://assets/sprites/pokemon/placeholder.png")
	if not tex:
		push_warning("SpriteBuilder: sprite de pokémon não encontrado para id=%d" % species_id)
		return null

	if tex.get_width() >= 96:
		var detected_tile := tex.get_width() / 3
		return build_entity_frames_from_texture(tex, detected_tile)

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

static func _atlas(tex: Texture2D, col: int, row: int, tile: int = TILE, tile_h: int = -1) -> AtlasTexture:
	var th : int = tile_h if tile_h > 0 else tile
	return _atlas_rect(tex, Rect2(col * tile, row * th, tile, th))

static func _atlas_rect(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at
