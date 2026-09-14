## RegrasDeUltimate.gd — A ultimate só na última evolução.
##
## Pedido do Gabriel: *"as passivas conforme a pokedex informa, **a ultimate
## somente na última evolução**"*.
##
## ── Por que a regra existe ───────────────────────────────────────────────────
##
## É a mesma preocupação que gerou os slots por estágio evolutivo: impedir que
## um Pokémon não-evoluído carregue o poder de um evoluído. Sem isso, evoluir
## vira só troca de sprite — e o jogador que segura a evolução por capricho não
## perde nada.
##
## Com isso, a última evolução ganha uma coisa que **só ela** tem. É pouco
## código e muda o valor de evoluir.
##
## ── O que conta como ultimate ────────────────────────────────────────────────
##
## O poder do golpe, e não uma lista de nomes. `CombatBalance` já documentava
## "power 150 (ultimate)" como o topo da escala; aqui o corte é 140, que pega
## os 5 golpes mais devastadores do jogo (Hyper Beam, Self-Destruct, Explosion,
## Sky Attack, Last Resort) sem varrer a faixa de 120 junto.
##
## Lista de nomes seria cadastro paralelo pra manter em sincronia — e um golpe
## novo de poder 160 entraria como comum, calado. O poder é o dado.
class_name RegrasDeUltimate
extends RefCounted

## Poder a partir do qual um golpe é ultimate.
const PODER_MINIMO : int = 140

## Este golpe é ultimate?
static func e_ultimate(golpe: Dictionary) -> bool:
	return int(golpe.get("power", 0)) >= PODER_MINIMO

## Este Pokémon pode equipar ultimate?
##
## Reaproveita `KitDeCombate.estagio_evolutivo()`, que já sabe ler a cadeia de
## `evolution_to` — não há segunda forma de responder "ele é a última evolução".
##
## Pokémon que não evolui nunca (Tauros, Lapras, lendários) **conta como última
## evolução**: ele já é o fim da linha dele. Negar a ultimate a quem não tem
## como evoluir seria punir a espécie por não ter cadeia.
static func pode_equipar(species_id: int, especies: Dictionary) -> bool:
	var esp : Dictionary = especies.get(species_id, especies.get(str(species_id), {}))
	if esp.is_empty():
		return false
	# `evolution_to` ausente ou nulo = não evolui = é o fim da linha.
	var proximo = esp.get("evolution_to")
	return proximo == null or int(proximo) <= 0

## A checagem completa, com motivo em português pra mostrar na tela.
## Devolve {"pode", "motivo"}.
static func conferir(golpe: Dictionary, species_id: int, especies: Dictionary) -> Dictionary:
	if not e_ultimate(golpe):
		return {"pode": true, "motivo": ""}
	if pode_equipar(species_id, especies):
		return {"pode": true, "motivo": ""}
	var nome := str(golpe.get("name", golpe.get("id", "esse golpe")))
	var esp : Dictionary = especies.get(species_id, especies.get(str(species_id), {}))
	var quem := str(esp.get("name", "Este Pokémon"))
	return {
		"pode": false,
		"motivo": "%s só pode ser usado na última evolução. %s ainda evolui." % [nome, quem],
	}

## Todos os golpes ultimate do jogo. Serve pra tela de kit poder marcá-los, e
## pro teste conferir que o corte não varreu o jogo inteiro.
static func listar(golpes: Dictionary) -> Array[String]:
	var out : Array[String] = []
	for id in golpes.keys():
		if e_ultimate(golpes[id]):
			out.append(str(id))
	out.sort()
	return out
