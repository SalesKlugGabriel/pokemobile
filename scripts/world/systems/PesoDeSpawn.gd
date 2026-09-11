## PesoDeSpawn.gd — quanto cada espécie pesa no sorteio AGORA, dado o
## horário e o clima (10/09).
##
## É o último pedaço da matriz ecológica do Gabriel: "floresta muda fauna de
## dia pra noite; área de rio aumenta aquáticos na chuva; região vulcânica
## aumenta tipo fogo". Os dois sistemas que alimentam isso já existiam
## (CicloDoDia e ClimaDinamico, 09/09) — faltava o spawn escutar.
##
## Mora AQUI, separado do SpawnManager, por um motivo prático: o
## SpawnManager depende de autoloads (WorldManager, RNGManager), e autoload
## não é identificador em teste headless — a regra ficaria inalcançável
## justamente pro teste que prova que ela está certa. Aqui é função pura:
## entra dado, sai número.
##
## Orientado a DADO, nunca a lista no código. Cada entrada de
## `wild_pokemon` no zones.json pode trazer:
##
##   "bonus": {"noite": 4.0, "chuva": 2.0}   multiplica o peso na condição
##   "so_em": ["noite", "amanhecer"]          só aparece nesses períodos
##
## Sem esses campos nada muda — toda zona que não quis variar continua
## sorteando exatamente como sempre sorteou.
class_name PesoDeSpawn
extends RefCounted

## Períodos que o CicloDoDia produz (`periodo_de`): amanhecer, dia,
## entardecer, noite.
static func efetivo(entry: Dictionary, periodo: String, chovendo: bool) -> float:
	var so_em : Array = entry.get("so_em", [])
	if not so_em.is_empty() and not (periodo in so_em):
		return 0.0

	var peso : float = float(entry.get("weight", 1))
	var bonus : Dictionary = entry.get("bonus", {})
	if bonus.has(periodo):
		peso *= float(bonus[periodo])
	if chovendo and bonus.has("chuva"):
		peso *= float(bonus["chuva"])
	return maxf(peso, 0.0)

## Soma dos pesos efetivos — 0 significa "ninguém aparece nesta condição",
## e quem chama tem que tratar isso (não sortear em vez de sortear errado).
static func total(table: Array, periodo: String, chovendo: bool) -> float:
	var soma : float = 0.0
	for entry in table:
		soma += efetivo(entry, periodo, chovendo)
	return soma
