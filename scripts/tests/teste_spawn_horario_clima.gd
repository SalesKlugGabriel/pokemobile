## teste_spawn_horario_clima.gd — 10/09. O último pedaço da matriz
## ecológica: a fauna muda com HORÁRIO e CLIMA?
##
## A matriz do Gabriel pede "floresta muda fauna de dia pra noite; área de
## rio aumenta aquáticos na chuva; região vulcânica aumenta tipo fogo", e
## aponta os dois sistemas que já existiam como gancho (CicloDoDia,
## ClimaDinamico). Faltava o spawn escutar — agora escuta, por DADO
## (`bonus` e `so_em` em cada entrada de wild_pokemon), não por lista
## cravada no código.
##
## Este teste prova as duas pontas: a conta de peso reage à condição, e os
## dados certos foram marcados nas zonas certas.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: spawn reage a horário e clima (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- A conta de peso ----
	var comum := {"id": 19, "name": "Rattata", "weight": 30}
	var so_noite := {"id": 92, "name": "Gastly", "weight": 10, "so_em": ["noite"]}
	var chuvoso := {"id": 54, "name": "Psyduck", "weight": 10, "bonus": {"chuva": 2.0}}
	var noturno := {"id": 41, "name": "Zubat", "weight": 10, "bonus": {"noite": 4.0}}

	_assert(PesoDeSpawn.efetivo(comum, "dia", false) == 30.0,
		"espécie sem condição nenhuma mantém o peso de sempre")
	_assert(PesoDeSpawn.efetivo(so_noite, "dia", false) == 0.0,
		"'so_em: noite' NÃO aparece de dia (peso zero)")
	_assert(PesoDeSpawn.efetivo(so_noite, "noite", false) == 10.0,
		"'so_em: noite' aparece à noite")
	_assert(PesoDeSpawn.efetivo(chuvoso, "dia", false) == 10.0,
		"bônus de chuva não vale com tempo seco")
	_assert(PesoDeSpawn.efetivo(chuvoso, "dia", true) == 20.0,
		"bônus de chuva dobra o peso quando chove")
	_assert(PesoDeSpawn.efetivo(noturno, "noite", false) == 40.0,
		"bônus de noite multiplica o peso depois do anoitecer")
	_assert(PesoDeSpawn.efetivo(noturno, "dia", false) == 10.0,
		"de dia o mesmo bicho volta ao peso normal")

	# ---- Sorteio nunca devolve quem está com peso zero ----
	var tabela : Array = [so_noite]
	_assert(PesoDeSpawn.total(tabela, "dia", false) == 0.0,
		"tabela só com bicho de noite soma peso ZERO de dia — o SpawnManager não sorteia nada em vez de sortear errado")
	_assert(PesoDeSpawn.total(tabela, "noite", false) > 0.0,
		"a mesma tabela volta a ter peso à noite")

	# ---- Os dados: as zonas que a matriz nomeia foram marcadas ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var por_id := {}
	for z in zj.get("zones", []):
		por_id[String(z.get("id", ""))] = z

	_tem_condicao(por_id, "lavender_town", "noite",
		"Lavender: fantasma/Drowzee/Zubat aumentam à noite (matriz)")
	_tem_condicao(por_id, "rota_lf_vale_rio", "chuva",
		"Vale do Rio: aquáticos aumentam na chuva (matriz)")
	_tem_condicao(por_id, "rota_cs_lago", "chuva",
		"Margem do Lago: aquáticos aumentam na chuva (matriz)")
	_so_em(por_id, "rota_pv_floresta", "noite",
		"Floresta de Viridian tem bicho SÓ de noite (a mata muda no escuro)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _tem_condicao(por_id: Dictionary, zid: String, chave: String, msg: String) -> void:
	if not por_id.has(zid):
		_assert(false, "zona '%s' existe" % zid)
		return
	var achou := false
	for m in por_id[zid].get("wild_pokemon", []):
		var b : Dictionary = m.get("bonus", {})
		if b.has(chave):
			achou = true
	_assert(achou, msg)

func _so_em(por_id: Dictionary, zid: String, periodo: String, msg: String) -> void:
	if not por_id.has(zid):
		_assert(false, "zona '%s' existe" % zid)
		return
	var achou := false
	for m in por_id[zid].get("wild_pokemon", []):
		if periodo in m.get("so_em", []):
			achou = true
	_assert(achou, msg)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
