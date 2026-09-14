## ValidadorDeModelo.gd — A régua de um modelo de Pokémon.
##
## Nasceu do primeiro modelo entregue (Charizard, Codex, 14/09). Ele estava
## **certo em tudo, e deitado**: o eixo de altura tinha ido pro −Z em vez do +Y,
## clássico Blender Z-up que não foi convertido no export.
##
##     como veio   → altura 2,239 m · pés em Y = −0,659
##     girando 90° → altura 1,700 m · pés em Y =  0,000   ← a Pokédex, exata
##
## ── Por que isto existe, e não um "roda o script de novo" ───────────────────
##
## Com a decisão de usar modelos 3D, vão chegar **151 deles**, um de cada vez,
## ao longo de meses. Um modelo torto que entra em silêncio é um Pokémon que
## afunda no chão e ninguém liga a causa ao export de três semanas atrás.
##
## Então a régua mede **contra o dado que já existe** (`heights.json`, 151
## alturas reais) e grita quando não bate. É o mesmo padrão que pegou a tabela
## de tipos com 15 dos 18 e a drenagem que nunca curou.
##
## ⚠️ **Lição da régua de densidade, que eu não quero repetir:** calibrar contra
## a coisa errada produz número convincente e falso. Por isso aqui a referência
## é a altura da Pokédex, e não uma média de modelos — uma régua que se calibra
## pelos próprios casos aceita o erro sistemático de todos eles.
class_name ValidadorDeModelo
extends RefCounted

## Quanto a altura pode divergir da Pokédex e ainda passar. 8% cobre estilo
## (um bicho um pouco mais empinado) sem deixar passar um eixo trocado, que
## erra por dezenas de por cento.
const TOLERANCIA_DE_ALTURA : float = 0.08

## Quanto os pés podem sair do zero, em metros.
const TOLERANCIA_DOS_PES : float = 0.05

## A caixa que a malha ocupa, no espaço do nó — a verdade do que o jogo vê.
static func caixa(no: Node3D) -> AABB:
	var agg := AABB()
	var primeiro := true
	var pilha : Array = [no]
	while not pilha.is_empty():
		var atual = pilha.pop_back()
		for c in atual.get_children():
			pilha.append(c)
		if atual is MeshInstance3D:
			var m : MeshInstance3D = atual
			var mundo : AABB = m.global_transform * m.get_aabb()
			if primeiro:
				agg = mundo
				primeiro = false
			else:
				agg = agg.merge(mundo)
	return agg

## Confere um modelo já instanciado contra o contrato.
##
## Devolve {"ok", "problemas": [texto], "altura", "pes", "correcao_x"}.
## `correcao_x` é o giro em X que arrumaria — 0 quando não há o que arrumar.
static func conferir(no: Node3D, species_id: int) -> Dictionary:
	var esperada : float = PokemonScale.get_height_m(species_id)
	var a := caixa(no)
	var problemas : Array[String] = []

	var erro : float = absf(a.size.y - esperada) / maxf(0.01, esperada)
	if erro > TOLERANCIA_DE_ALTURA:
		problemas.append("altura %.2f m, a Pokédex diz %.2f m (%.0f%% de erro)"
			% [a.size.y, esperada, erro * 100.0])
	if absf(a.position.y) > TOLERANCIA_DOS_PES:
		problemas.append("os pés estão em Y = %.2f, deviam estar em 0" % a.position.y)

	# O eixo trocado é o erro mais comum de export, e tem assinatura própria:
	# girar 90° em X faz a altura bater. Detectar isso separa "modelo errado"
	# de "modelo certo, exportado torto" — e as duas coisas se resolvem de
	# formas diferentes.
	var correcao : float = 0.0
	if not problemas.is_empty():
		for graus in [90.0, -90.0]:
			if _altura_girando(no, graus, esperada):
				correcao = graus
				problemas.append("⚠️ girando %+.0f° em X a altura bate: o eixo de altura foi exportado errado (Blender Z-up)" % graus)
				break

	return {
		"ok": problemas.is_empty(),
		"problemas": problemas,
		"altura": a.size.y,
		"altura_esperada": esperada,
		"pes": a.position.y,
		"correcao_x": correcao,
	}

## A altura bateria se o modelo fosse girado? Mede de verdade, girando uma
## cópia — não estima por trigonometria, que é onde eu errei ao conferir o
## primeiro modelo na mão.
static func _altura_girando(no: Node3D, graus: float, esperada: float) -> bool:
	var giro := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(graus)), Vector3.ZERO)
	var a := caixa(no)
	var girada : AABB = giro * a
	return absf(girada.size.y - esperada) / maxf(0.01, esperada) <= TOLERANCIA_DE_ALTURA

## As animações que o contrato exige (`docs/POKEMON_MODEL_PIPELINE.md`).
const ANIMACOES_EXIGIDAS : Array[String] = ["idle", "walk", "attack", "hurt"]

static func conferir_animacoes(no: Node) -> Dictionary:
	var ap = no.find_child("AnimationPlayer", true, false)
	if ap == null:
		return {"ok": false, "faltando": ANIMACOES_EXIGIDAS.duplicate(),
				"achadas": []}
	var tem : Array = ap.get_animation_list()
	var faltando : Array[String] = []
	for nome in ANIMACOES_EXIGIDAS:
		if not nome in tem:
			faltando.append(nome)
	return {"ok": faltando.is_empty(), "faltando": faltando, "achadas": tem}

## O relatório inteiro, em português, pra log e pro recado de feedback.
static func relatorio(no: Node3D, species_id: int) -> String:
	var r := conferir(no, species_id)
	var an := conferir_animacoes(no)
	if bool(r["ok"]) and bool(an["ok"]):
		return ""
	var linhas : Array[String] = ["modelo #%d fora do contrato:" % species_id]
	for p in r["problemas"]:
		linhas.append("  • %s" % str(p))
	if not bool(an["ok"]):
		linhas.append("  • animações faltando: %s" % ", ".join(an["faltando"]))
	linhas.append("  (contrato em docs/POKEMON_MODEL_PIPELINE.md)")
	return "\n".join(linhas)
