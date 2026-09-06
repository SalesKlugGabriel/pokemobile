## RecompensasDeCovil.gd — O que a dungeon paga, e o santuário antes do chefe
## (06/09).
##
## A regra que orienta tudo aqui: **a recompensa tem que ser algo que o jogador
## não consegue de outro jeito.** EXP e dinheiro se conseguem em qualquer lugar;
## o que uma dungeon vende é acesso.
##
##   ANEL 4 (elite) — a pedra de evolução do tipo, garantida na PRIMEIRA vez e
##                    ~15% nas seguintes. As 5 pedras já existiam no jogo e
##                    quase não tinham fonte; isto lhes dá um lugar.
##   ANEL 5 (arena) — o santuário: cura completa e salvamento ao entrar. E, na
##                    primeira vitória, a MT exclusiva do tipo.
##
## Por que o santuário não é bondade: se o jogador perde pro chefe com 40% de
## vida porque gastou poção no anel 3, ele aprende "eu devia ter poupado", não
## "eu devia ter desviado". O caminho testa recurso, o chefe testa execução —
## e misturar as duas lições é o jeito mais rápido de um chefe virar injusto.
##
## Sem reset semanal por relógio (a referência do PokeXGames usa, porque é MMO
## com economia real). Aqui a limitação natural é melhor: o lendário é único e a
## pedra é garantida só na primeira vez. Repetir paga menos — decrescente, não
## bloqueado.
class_name RecompensasDeCovil
extends RefCounted

const CHANCE_PEDRA_REPETIDA : float = 0.15

## MT exclusiva por dungeon — só cai aqui, não se compra em lugar nenhum.
const MT_DO_COVIL : Dictionary = {
	"ilha_gelida": "tm17",
}

## Chamado pelo BaseMap ao montar o mapa.
static func ao_entrar(map_id: String) -> void:
	var covil := RegrasDeCovil.dungeon_do_mapa(map_id)
	if covil == "":
		return
	var anel := RegrasDeCovil.anel_do_mapa(map_id)
	if anel == 4 and _e_ultimo_andar_de_elite(covil, map_id):
		_pagar_pedra(covil)
	elif anel == 5:
		_santuario(covil)

static func _e_ultimo_andar_de_elite(covil: String, map_id: String) -> bool:
	var d : Dictionary = RegrasDeCovil.DUNGEONS[covil]
	var elite : Array = d["elite"]
	if elite.is_empty():
		return false
	return map_id == str(d["prefixo"]) + "_" + str(elite[elite.size() - 1])

## O santuário: cura completa e salva. É o que faz a luta começar sempre com o
## time inteiro — então perder é sobre a luta, não sobre o quanto se gastou
## chegando até aqui.
static func _santuario(covil: String) -> void:
	var salvar = _no("SaveManager")
	if salvar == null:
		return
	salvar.heal_team()
	salvar.save_game()
	# O Follower em cena também: curar só o save deixaria o Pokémon que está
	# lutando com a vida velha (mesma armadilha do CuraDeCampo).
	var lider : Dictionary = salvar.get_pokemon_at(0)
	if not lider.is_empty():
		CuraDeCampo.sincronizar_follower(int(lider.get("hp_current", 0)))
	_avisar("Santuário: seu time foi curado por completo. Boa sorte.")
	var barramento = _no("EventBus")
	if barramento != null:
		barramento.dungeon_santuario.emit(covil)

static func _pagar_pedra(covil: String) -> void:
	var d : Dictionary = RegrasDeCovil.DUNGEONS[covil]
	var pedra : String = str(d.get("pedra", ""))
	if pedra == "":
		return
	var salvar = _no("SaveManager")
	if salvar == null:
		return
	var estado := _estado(covil)
	var primeira : bool = not bool(estado.get("pedra", false))
	if primeira:
		estado["pedra"] = true
		_gravar(covil, estado)
	elif randf() > CHANCE_PEDRA_REPETIDA:
		return
	salvar.add_item(pedra, 1)
	salvar.save_game()
	var nome := _nome_do_item(pedra)
	_avisar(("Você encontrou %s!" % nome) if primeira else ("Mais %s!" % nome))

## Chamado quando o chefe do covil é derrotado (ou capturado): a MT exclusiva
## sai UMA vez só, na primeira vitória.
static func ao_vencer_chefe(especie: int) -> void:
	for covil in RegrasDeCovil.DUNGEONS:
		var d : Dictionary = RegrasDeCovil.DUNGEONS[covil]
		if int(d.get("chefe", -1)) != especie:
			continue
		var estado := _estado(covil)
		estado["limpezas"] = int(estado.get("limpezas", 0)) + 1
		var mt : String = str(MT_DO_COVIL.get(covil, ""))
		var primeira : bool = not bool(estado.get("mt", false))
		if primeira and mt != "":
			estado["mt"] = true
			var salvar = _no("SaveManager")
			if salvar != null:
				salvar.add_item(mt, 1)
			_avisar("Você recebeu %s — só existe aqui." % _nome_do_item(mt))
		_gravar(covil, estado)
		var salvar2 = _no("SaveManager")
		if salvar2 != null:
			salvar2.save_game()
		return

static func limpezas(covil: String) -> int:
	return int(_estado(covil).get("limpezas", 0))

# ──────────────────────────────────────────────────────────────────────────
# Estado no save
# ──────────────────────────────────────────────────────────────────────────
static func _estado(covil: String) -> Dictionary:
	var salvar = _no("SaveManager")
	if salvar == null:
		return {}
	var mundo : Dictionary = salvar.save_data.get("world", {})
	var covis : Dictionary = mundo.get("covis", {})
	return covis.get(covil, {})

static func _gravar(covil: String, estado: Dictionary) -> void:
	var salvar = _no("SaveManager")
	if salvar == null:
		return
	var mundo : Dictionary = salvar.save_data.get("world", {})
	var covis : Dictionary = mundo.get("covis", {})
	covis[covil] = estado
	mundo["covis"] = covis
	salvar.save_data["world"] = mundo

static func _no(nome: String):
	var laco := Engine.get_main_loop()
	if laco == null or not (laco is SceneTree):
		return null
	return (laco as SceneTree).root.get_node_or_null(nome)

static func _nome_do_item(item_id: String) -> String:
	var dados = _no("GameData")
	if dados == null:
		return item_id
	return str(dados.get_item(item_id).get("name", item_id))

## Busca o barramento pelo nó em vez de usar o identificador global: uma classe
## `class_name` que cita um autoload direto não carrega nos testes headless
## (armadilha já conhecida do projeto — foi por isso que a tabela de ninhos
## saiu de NinhoLendario pra CovisLendarios em 05/09).
static func _avisar(texto: String) -> void:
	var barramento = _no("EventBus")
	if barramento != null:
		barramento.notification_requested.emit(texto)
