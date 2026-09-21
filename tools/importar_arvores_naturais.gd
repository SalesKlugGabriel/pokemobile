## Importador de sprite sheet gerada: chroma key, separação dos quatro objetos,
## redução NEAREST e encaixe nos slots 2x3 existentes. Não desenha arte nova.
## Reproduzível: godot4 --headless --script res://tools/importar_arvores_naturais.gd
extends SceneTree

const FONTE := "res://assets/sprites/environment/arvores_fonte_20260911.png"
const BACKUP := "res://assets/old/overworld_20260911.png"

func _initialize() -> void:
	var fonte := Image.load_from_file(FONTE)
	var atlas := Image.load_from_file(BACKUP)
	if fonte == null or atlas == null:
		push_error("Fonte e backup são obrigatórios; nenhum arquivo foi substituído.")
		quit(1)
		return
	fonte.convert(Image.FORMAT_RGBA8)
	var largura := fonte.get_width()
	var altura := fonte.get_height()
	var mascara := PackedByteArray()
	mascara.resize(largura * altura)
	for y in altura:
		for x in largura:
			var cor := fonte.get_pixel(x, y)
			# O gerador não entregou alpha: magenta é a chave explícita de import.
			# Branco neutro residual nos vãos também é fundo, não folha/tronco.
			var chave := cor.r > 0.55 and cor.b > 0.40 and cor.g < minf(cor.r, cor.b) * 0.7
			var neutro := minf(cor.r, minf(cor.g, cor.b)) > 0.62 and maxf(cor.r, maxf(cor.g, cor.b)) - minf(cor.r, minf(cor.g, cor.b)) < 0.16
			if not chave and not neutro and cor.a > 0.5:
				mascara[y * largura + x] = 1
	# Objetos conectados, em vez de quatro recortes iguais que cortariam copas.
	var grupos: Array = []
	for i in mascara.size():
		if mascara[i] != 1:
			continue
		var fila := PackedInt32Array([i])
		mascara[i] = 2
		var cursor := 0
		while cursor < fila.size():
			var p := fila[cursor]
			cursor += 1
			var x := p % largura
			var y := p / largura
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
					continue
				var proximo: int = ny * largura + nx
				if mascara[proximo] == 1:
					mascara[proximo] = 2
					fila.append(proximo)
		if fila.size() >= 2000:
			grupos.append(fila)
	grupos.sort_custom(func(a, b): return a.size() > b.size())
	if grupos.size() != 4:
		push_error("Esperava quatro árvores inteiras; encontrado %d. Atlas preservado." % grupos.size())
		quit(1)
		return
	grupos.sort_custom(func(a, b): return _centro_x(a, largura) < _centro_x(b, largura))
	var sprites := Image.create(1024, 384, false, Image.FORMAT_RGBA8)
	for especie in 4:
		var grupo: PackedInt32Array = grupos[especie]
		var x0 := largura
		var y0 := altura
		var x1 := 0
		var y1 := 0
		for p in grupo:
			x0 = mini(x0, p % largura)
			x1 = maxi(x1, p % largura)
			y0 = mini(y0, p / largura)
			y1 = maxi(y1, p / largura)
		var objeto := Image.create(x1 - x0 + 1, y1 - y0 + 1, false, Image.FORMAT_RGBA8)
		for p in grupo:
			objeto.set_pixel(p % largura - x0, p / largura - y0, fonte.get_pixel(p % largura, p / largura))
		var fator := minf(232.0 / objeto.get_width(), 352.0 / objeto.get_height())
		objeto.resize(roundi(objeto.get_width() * fator), roundi(objeto.get_height() * fator), Image.INTERPOLATE_NEAREST)
		var pos := Vector2i(especie * 256 + (256 - objeto.get_width()) / 2, 366 - objeto.get_height())
		sprites.blit_rect(objeto, Rect2i(Vector2i.ZERO, objeto.get_size()), pos)
		# Fundo do atlas continua opaco: camada 0 não tem chão atrás da árvore.
		for y in 3:
			for x in 2:
				atlas.blit_rect(atlas, Rect2i(0, 0, 128, 128), Vector2i(especie * 256 + x * 128, (11 + y) * 128))
		print("Árvore %d: %dx%d, margem preservada" % [especie, objeto.get_width(), objeto.get_height()])
	# Sombra de contato escalonada, sem blur, por baixo dos quatro recortes.
	for especie in 4:
		for y in range(338, 377):
			for x in range(52, 226):
				var dx := (float(x) - 139.0) / 87.0
				var dy := (float(y) - 357.0) / 20.0
				if dx * dx + dy * dy < 1.0:
					var pos := Vector2i(especie * 256 + x, 11 * 128 + y)
					var c := atlas.get_pixelv(pos)
					atlas.set_pixelv(pos, c.lerp(Color(0.07, 0.12, 0.04), 0.27))
	atlas.blend_rect(sprites, Rect2i(0, 0, 1024, 384), Vector2i(0, 11 * 128))
	if sprites.save_png("res://assets/sprites/environment/arvores_naturais.png") != OK or atlas.save_png("res://assets/tilesets/overworld.png") != OK:
		quit(1)
		return
	print("IMPORT_ARVORES_OK: somente linhas 11–13 substituídas, fonte e backup preservados.")
	quit()

func _centro_x(grupo: PackedInt32Array, largura: int) -> float:
	var soma := 0.0
	for p in grupo:
		soma += p % largura
	return soma / grupo.size()
