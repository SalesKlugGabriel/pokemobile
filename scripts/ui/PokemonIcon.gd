## PokemonIcon.gd — Ícone de um Pokémon a partir da folha de sprites (04/09).
##
## Por que existe: no teste de gameplay a Pokédex apareceu com 12 Bulbasaurs
## empilhados e nenhuma outra espécie. A causa: `mon_001.png` não é um ícone, é
## a FOLHA DE ANIMAÇÃO inteira (384x256 ou 384x512 — 3 colunas de quadros por
## 2 ou 4 direções). A tela mandava a folha crua pro TextureRect, que desenhava
## os 384px de largura; cada linha da lista virava a altura da folha e só a
## primeira espécie cabia na tela.
##
## Duas telas precisavam da mesma coisa (Pokédex e Time), então o recorte mora
## aqui em vez de ser copiado nas duas — a regra de não duplicar solução.
class_name PokemonIcon
extends RefCounted

## Quadro parado, virado pra frente: coluna 0, linha 0 da folha.
const COLUNAS : int = 3

## Devolve a textura do quadro parado da espécie, ou null se não houver sprite.
## O recorte é por AtlasTexture (não copia pixel nenhum — é uma janela sobre a
## textura que já está carregada).
static func textura(species_id: int, shiny: bool = false) -> Texture2D:
	var sufixo := "_shiny" if shiny else ""
	var caminho := "res://assets/sprites/pokemon/mon_%03d%s.png" % [species_id, sufixo]
	if not ResourceLoader.exists(caminho):
		return null
	var folha : Texture2D = load(caminho)
	if folha == null:
		return null
	var largura_quadro := int(folha.get_width() / float(COLUNAS))
	# A folha pode ter 2 ou 4 linhas (algumas espécies não têm lateral própria);
	# usar a largura do quadro como altura mantém o recorte quadrado em ambas.
	var altura_quadro := mini(largura_quadro, folha.get_height())
	var atlas := AtlasTexture.new()
	atlas.atlas = folha
	atlas.region = Rect2(0, 0, largura_quadro, altura_quadro)
	return atlas

## Monta um TextureRect já dimensionado pra caber numa linha de lista.
## `lado` é o tamanho final em pixels de tela.
static func criar(species_id: int, lado: int = 40, shiny: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(lado, lado)
	# EXPAND_IGNORE_SIZE é o que faltava: sem ele o TextureRect cresce até o
	# tamanho natural da textura (era esse o bug das 12 cópias).
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art não borra
	tr.texture = textura(species_id, shiny)
	return tr
