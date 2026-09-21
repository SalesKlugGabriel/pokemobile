## teste_player_v1_frente.gd — Pra que lado o treinador olha (21/09).
##
## ── O moonwalk ──────────────────────────────────────────────────────────────
##
## O Gabriel: *"o player sempre anda de costas (moon walk)"*. Em 17/09 eu já
## tinha errado este mesmo diagnóstico **duas vezes lendo código**, então desta
## vez a resposta veio de medir o asset.
##
## Em Godot, um nó com `rotation.y = 0` olha pra **−Z**, e
## `Locomocao3D.girar_para` mira −Z corretamente (foi corrigido em 17/09, com a
## medição no próprio comentário). Se o modelo olha pro outro lado, o corpo vira
## pro rumo certo e o boneco aparece de costas.
##
## ── O que este arquivo trava ────────────────────────────────────────────────
##
##   1. **A medição.** A frente do GLB é medida aqui, dos vértices — não lida de
##      um documento. A RFC-007 declarava "frente −Z" e a medida diz +Z; foi a
##      declaração que estava errada, e ela enganou dois agentes.
##   2. **A correção não some.** Enquanto o asset olhar pra +Z, a compensação de
##      180° em `PlayerVisual3D` tem de existir.
##   3. **E não sobra.** No dia em que o Codex reexportar o modelo de frente pra
##      −Z, este teste **reprova** e manda apagar a compensação — senão o
##      moonwalk volta, invertido.
##
## É o mesmo desenho da lista de pontas soltas: o teste falha nos **dois**
## sentidos, porque uma correção órfã é tão ruim quanto uma correção faltando.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 7

## Abaixo disto é sapato; acima, cabeça e boné. Os dois apontam pra frente num
## humanoide, e concordar entre si é o que dá confiança na medida.
const ALTURA_DO_PE : float = 0.15
const ALTURA_DA_CABECA : float = 1.35

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

var _quadro : int = 0

func _initialize() -> void:
	print("== Pra que lado o treinador olha ==")

func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro < 2:
		return false

	var frente_em_z : float = _medir_frente()
	_conf("a compensação de 180° existe enquanto o asset olhar pra +Z",
		(frente_em_z > 0.0) == _tem_correcao(),
		"o asset olha pra " + ("+Z" if frente_em_z > 0.0 else "−Z")
			+ " e a correção " + ("existe" if _tem_correcao() else "NÃO existe")
			+ " — as duas coisas têm de andar juntas, senão é moonwalk (ou o "
			+ "moonwalk ao contrário)")

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────

## Mede pra que lado o modelo olha. Devolve o Z médio das pontas (dedos do pé e
## aba do boné): positivo = olha pra +Z.
func _medir_frente() -> float:
	print("\n-- Medindo o GLB, vértice a vértice --")

	var cena := load("res://assets/characters/player_v1/player_v1.glb") as PackedScene
	_conf("o GLB do treinador carrega", cena != null)
	if cena == null:
		return 0.0

	var m := cena.instantiate()
	root.add_child(m)
	var malhas : Array = []
	_juntar(m, malhas)
	_conf("o modelo tem malhas", malhas.size() > 0, str(malhas.size()))

	var pe := _extremos(malhas, -INF, ALTURA_DO_PE)
	var cabeca := _extremos(malhas, ALTURA_DA_CABECA, INF)
	m.queue_free()

	print("   sapatos: %d vértices · z de %+.3f a %+.3f"
		% [int(pe["n"]), float(pe["min"]), float(pe["max"])])
	print("   boné:    %d vértices · z de %+.3f a %+.3f"
		% [int(cabeca["n"]), float(cabeca["min"]), float(cabeca["max"])])

	_conf("achou vértices no pé e na cabeça",
		int(pe["n"]) > 50 and int(cabeca["n"]) > 50,
		"as faixas de altura não bateram com este modelo")

	# Qual lado se projeta mais: é pra lá que o corpo aponta.
	var frente_do_pe : float = float(pe["max"]) + float(pe["min"])
	var frente_da_cabeca : float = float(cabeca["max"]) + float(cabeca["min"])

	# ⚠️ A trava que dá confiança à medida: pé e cabeça têm de concordar. Se
	# discordarem, a régua é que está errada — e aí eu não posso afirmar nada.
	_conf("o pé e a cabeça apontam pro MESMO lado",
		(frente_do_pe > 0.0) == (frente_da_cabeca > 0.0),
		"pé %+.3f x cabeça %+.3f — medida não confiável"
			% [frente_do_pe, frente_da_cabeca])

	var frente : float = frente_do_pe + frente_da_cabeca
	print("   → a frente do modelo é ",
		"+Z (ao contrário do padrão do Godot)" if frente > 0.0 else "−Z (padrão)")
	_conf("a medida é clara, não empate", absf(frente) > 0.05,
		"%+.4f — perto demais de zero pra decidir" % frente)

	# E a régua contra a qual tudo isto existe: o Godot olha pra −Z.
	_conf("Locomocao3D.girar_para mira −Z (a convenção do Godot)",
		_mira_menos_z(),
		"se isto mudar, a correção do visual precisa mudar junto")
	return frente

## `girar_para` devolve 0 quando o corpo anda pra −Z? É o que define a
## convenção que o modelo precisa respeitar.
func _mira_menos_z() -> bool:
	var Loc : GDScript = load("res://scripts/gameplay_v3/movimento/Locomocao3D.gd")
	var alvo : float = Loc.girar_para(0.0, Vector3(0, 0, -5), 1.0, 100000.0)
	return absf(alvo) < 0.01

func _tem_correcao() -> bool:
	var t : String = FileAccess.get_file_as_string(
		"res://scripts/gameplay_v3/presentation/PlayerVisual3D.gd")
	return t.contains("CORRECAO_DE_FRENTE") and t.contains("rotate_y(")

func _extremos(malhas: Array, y_min: float, y_max: float) -> Dictionary:
	var zmin : float = INF
	var zmax : float = -INF
	var n : int = 0
	for no in malhas:
		var arr = no.mesh.surface_get_arrays(0)
		if arr == null or arr.size() == 0:
			continue
		var vs : PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in vs:
			var g : Vector3 = no.global_transform * v
			if g.y < y_min or g.y > y_max:
				continue
			zmin = minf(zmin, g.z)
			zmax = maxf(zmax, g.z)
			n += 1
	return {"min": zmin if n > 0 else 0.0, "max": zmax if n > 0 else 0.0, "n": n}

func _juntar(n: Node, fora: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		fora.append(n)
	for f in n.get_children():
		_juntar(f, fora)
