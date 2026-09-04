## PokemonScale.gd — Escala visual do Pokémon baseada na altura oficial da
## Pokédex (03/09, pedido do Gabriel): "o tamanho visual deve respeitar a
## altura oficial... Pikachu < Charmander < Bulbasaur < Charizard << Onix",
## mas sem deixar um Pokémon de 8,8m (Onix) virar gigante e "destruir o
## mapa" — escala com teto/piso configurável, não altura crua.
##
## Fórmula: escala = clamp((altura / REFERENCE_HEIGHT_M) ^ SCALE_POWER,
## MIN_SCALE, MAX_SCALE). SCALE_POWER < 1 (raiz quadrada) COMPRIME a faixa
## enorme de alturas reais (0,2m a 8,8m nas 151 espécies da 1ª geração) em
## algo jogável — linear puro faria Onix ficar 44x maior que o menor
## Pokémon, o oposto do que o Gabriel pediu ("não quero que... ocupe
## metade da tela simplesmente porque sua altura é grande").
## REFERENCE_HEIGHT_M = 1.0 não foi chutado — é a MEDIANA real das 151
## alturas (conferido com heights.json), então a maioria dos Pokémon fica
## perto da escala 1.0 (do tamanho de 1 tile, como já era antes desta
## mudança) e só os extremos (bem pequenos/bem grandes) se destacam.
class_name PokemonScale
extends RefCounted

const REFERENCE_HEIGHT_M : float = 1.0
const SCALE_POWER        : float = 0.5
const MIN_SCALE          : float = 0.6
const MAX_SCALE          : float = 2.2

const HEIGHTS_PATH : String = "res://data/pokemon/heights.json"

## Geometria do sprite dentro do frame de 128px, garantida pelo pipeline de arte
## (tools/alinhar_pe_pokemon.py): TODA espécie tem o pé na mesma linha e a mesma
## altura nominal de corpo — a diferença de tamanho entre espécies vem daqui
## (get_visual_scale), não do tamanho do PNG. Quem precisa saber "onde termina o
## corpo" (ex: pôr a barra de vida logo acima da cabeça) usa topo_do_corpo() em
## vez de chutar um deslocamento fixo: era um -160 cravado que deixava a barra
## boiando longe dos Pokémon pequenos (achado em jogo, 04/09).
const LINHA_PE_FRAME : float = 120.0
const ALTURA_CORPO   : float = 75.0
const FRAME          : float = 128.0

## Y (local à entidade) do topo do corpo, já considerando a escala da espécie.
## base_offset_y: o mesmo que a entidade passa pra anchor_sprite_bottom().
static func topo_do_corpo(base_offset_y: float, escala: float) -> float:
	var pe_y : float = base_offset_y + FRAME / 2.0 - (FRAME - LINHA_PE_FRAME) * escala
	return pe_y - ALTURA_CORPO * escala

static var _heights : Dictionary = {}
static var _loaded  : bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(HEIGHTS_PATH, FileAccess.READ)
	if not f:
		push_warning("PokemonScale: heights.json não encontrado — todas as espécies usam altura de referência (escala 1.0)")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_heights = parsed

## Altura oficial em metros. Cai pra REFERENCE_HEIGHT_M (escala neutra,
## 1.0) se a espécie não tiver altura cadastrada — nunca quebra por
## espécie faltando dado, só fica "do tamanho médio".
static func get_height_m(species_id: int) -> float:
	_ensure_loaded()
	return _heights.get(str(species_id), REFERENCE_HEIGHT_M)

static func get_visual_scale(species_id: int) -> float:
	var h : float = get_height_m(species_id)
	var raw : float = pow(h / REFERENCE_HEIGHT_M, SCALE_POWER)
	return clampf(raw, MIN_SCALE, MAX_SCALE)

## Aplica a escala ao AnimatedSprite2D mantendo o PÉ do Pokémon fixo no
## chão — sem isto, escalar o sprite pelo centro faria um Pokémon grande
## "flutuar" (cresce pra cima E pra baixo) em vez de crescer só pra cima
## a partir de onde ele pisa (regra 8/9 do pedido do Gabriel: "separar
## sprite de collider" e "ponto de origem = base/pés do Pokémon").
## base_offset_y: a posição Y que o nó Sprite já tinha (no editor/cena)
## quando a escala era 1.0 — cada classe (WildPokemon/FollowerPokemon) já
## define a sua própria pra ficar bem alinhada com o resto do corpo.
## frame_size: tamanho nativo do quadro (128 hoje, migração tile128).
static func anchor_sprite_bottom(sprite: Node2D, base_offset_y: float, scale: float, frame_size: float = 128.0) -> void:
	sprite.scale = Vector2(scale, scale)
	var half := frame_size / 2.0
	var bottom_y := base_offset_y + half  # ponto fixo: onde o pé encosta, em escala 1.0
	sprite.position.y = bottom_y - half * scale
