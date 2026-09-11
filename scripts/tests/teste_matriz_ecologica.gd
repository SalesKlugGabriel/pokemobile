## teste_matriz_ecologica.gd — 10/09. A matriz ecológica do Gabriel está
## aplicada de verdade no mapa novo?
##
## A matriz (guardada na memória desde 10/09, pra aplicar SÓ depois da
## geografia) tem regras, não só listas. Este teste cobra as que dá pra
## verificar em dado:
##
##   1. Bioma determina fauna — cada rota longa tem VÁRIAS faixas de
##      spawn, não uma lista única do começo ao fim.
##   2. Rota longa muda de ecossistema — faixas vizinhas não podem ter
##      exatamente a mesma fauna.
##   3. Sobreposição, não blocos estanques — faixas vizinhas compartilham
##      ALGUMA espécie (mundo conectado, não "lista A, lista B").
##   4. Camadas de raridade — toda faixa tem comum E raro, não tudo no
##      mesmo peso.
##   5. Onix é raro FORA de caverna (regra explícita da matriz).
##   6. Cada faixa cobre pedaço real do mapa e nenhuma se sobrepõe (senão
##      `ZoneManager.find_zone_id` devolveria sempre a primeira).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

## rota => quantas faixas de bioma a matriz pede
const FAIXAS_ESPERADAS := {
	"rota_viridian_pallet":   2,
	"rota_pewter_viridian":   3,
	"rota_pewter_cerulean":   5,
	"rota_cerulean_saffron":  4,
	"rota_saffron_celadon":   4,
	"rota_saffron_vermilion": 2,
	"rota_saffron_lavender":  5,
	"rota_lavender_fuchsia":  7,
}

func _initialize() -> void:
	print("=== Teste: matriz ecológica aplicada (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var zonas : Array = zj.get("zones", [])

	for rota in FAIXAS_ESPERADAS:
		var faixas : Array = []
		for z in zonas:
			if String(z.get("map_id", "")) == rota:
				faixas.append(z)
		var esperado : int = FAIXAS_ESPERADAS[rota]

		# 1. bioma determina fauna: várias faixas, não uma lista só
		_assert(faixas.size() == esperado,
			"%s: tem %d faixas de bioma (esperado %d)" % [rota, faixas.size(), esperado])
		if faixas.size() < 2:
			continue

		# ordena pelo eixo da rota (norte-sul usa y; leste-oeste usa x)
		var vertical : bool = int(faixas[0]["tile_rect"]["h"]) != 100
		faixas.sort_custom(func(a, b):
			var ka : int = int(a["tile_rect"]["y"]) if vertical else int(a["tile_rect"]["x"])
			var kb : int = int(b["tile_rect"]["y"]) if vertical else int(b["tile_rect"]["x"])
			return ka < kb)

		var sem_buraco := true
		var anterior_fim := 0
		for i in faixas.size():
			var f : Dictionary = faixas[i]
			var r : Dictionary = f["tile_rect"]
			var ini : int = int(r["y"]) if vertical else int(r["x"])
			var tam : int = int(r["h"]) if vertical else int(r["w"])

			# 6. faixas encostam sem sobrepor (find_zone_id devolve a 1ª que casa)
			if ini != anterior_fim:
				sem_buraco = false
			anterior_fim = ini + tam

			var mons : Array = f.get("wild_pokemon", [])
			_assert(mons.size() >= 4, "%s: a faixa '%s' tem fauna própria (%d espécies)" % [rota, f["id"], mons.size()])

			# 4. camadas de raridade: não pode ser tudo no mesmo peso
			var pesos := {}
			for m in mons:
				pesos[int(m.get("weight", 0))] = true
			_assert(pesos.size() >= 2,
				"%s/%s: tem camadas de raridade (comum e raro, não tudo igual)" % [rota, f["id"]])

			# 5. Onix só é raro fora de caverna
			for m in mons:
				if int(m.get("id", 0)) == 95:   # Onix
					_assert(int(m.get("weight", 99)) <= 5,
						"%s/%s: Onix é RARO fora de caverna (regra da matriz)" % [rota, f["id"]])

			if i > 0:
				var ids_a := _ids(faixas[i - 1])
				var ids_b := _ids(f)
				# 2. faixas vizinhas não são a mesma fauna
				_assert(ids_a != ids_b,
					"%s: '%s' e '%s' têm faunas diferentes (a rota muda de ecossistema)"
					% [rota, faixas[i - 1]["id"], f["id"]])
				# 3. mas compartilham alguma espécie (sobreposição)
				var comum := false
				for id_a in ids_a:
					if id_a in ids_b:
						comum = true
				_assert(comum,
					"%s: '%s' e '%s' compartilham espécie (sobreposição, não bloco estanque)"
					% [rota, faixas[i - 1]["id"], f["id"]])

		_assert(sem_buraco, "%s: as faixas se encostam sem buraco nem sobreposição" % rota)

	# ---- Identidade ecológica das cidades que a matriz destaca ----
	var por_id := {}
	for z in zonas:
		por_id[String(z.get("id", ""))] = z
	_checar_tem(por_id, "saffron_city", [52, 88, 109], "Saffron é URBANA (Meowth/Grimer/Koffing)")
	_checar_tem(por_id, "lavender_town", [92, 104], "Lavender tem fantasma e Cubone")
	_checar_tem(por_id, "celadon_city", [43, 102], "Celadon tem identidade vegetal (Oddish/Exeggcute)")
	_checar_tem(por_id, "vermilion_city", [98, 72], "Vermilion é portuária (Krabby/Tentacool)")
	_checar_tem(por_id, "cinnabar_planalto", [126, 77], "o planalto de Cinnabar é vulcânico (Magmar/Ponyta)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _ids(zona: Dictionary) -> Array:
	var out : Array = []
	for m in zona.get("wild_pokemon", []):
		out.append(int(m.get("id", 0)))
	out.sort()
	return out

func _checar_tem(por_id: Dictionary, zid: String, exigidos: Array, msg: String) -> void:
	if not por_id.has(zid):
		_assert(false, "zona '%s' existe" % zid)
		return
	var ids := _ids(por_id[zid])
	var faltando : Array = []
	for e in exigidos:
		if not (e in ids):
			faltando.append(e)
	_assert(faltando.is_empty(), "%s (faltando: %s)" % [msg, str(faltando)])

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
