## NinhoLendario.gd — O lendário esperando no fim do covil (05/09).
##
## Pedido do Gabriel: os três pássaros atrás de um minigame cada, "incrivelmente
## difíceis de alcançar". Chegar é o desafio; este arquivo é o que está lá no
## fim.
##
## Três regras, e cada uma existe por um motivo:
##
## 1. NASCE UMA VEZ SÓ POR PARTIDA. Se o jogador derrota o lendário sem
##    capturá-lo, ele não reaparece — é o que faz a decisão de gastar a
##    Pokébola pesar. Guardado no save (`lendarios_derrotados`), não em memória,
##    senão sair do jogo daria outra chance.
##
## 2. NASCE SOZINHO NO NINHO. O andar do ninho não tem lista de Pokémon selvagem
##    (`wild_pokemon: []` no zones.json), pra nenhum Zubat aparecer no meio do
##    encontro e roubar a cena.
##
## 3. NÍVEL 50 E NÃO FOGE. É o teto do jogo por larga margem — o jogador chega
##    lá pelo caminho, não por nível.
class_name NinhoLendario
extends Node

## A tabela de ninhos e a busca de chão livre moram em `CovisLendarios`, junto
## do gerador dos andares — aquele arquivo não depende de autoload nenhum, e é
## por isso que o teste headless consegue alcançá-los.

const NIVEL_LENDARIO : int = 50

## Chamado pelo BaseMap ao terminar de montar o mapa.
static func povoar(mapa: Node, map_id: String) -> void:
	if not CovisLendarios.NINHOS.has(map_id):
		return
	var dados : Dictionary = CovisLendarios.NINHOS[map_id]
	var especie : int = int(dados["especie"])

	# Já foi derrotado nesta partida? Então o ninho fica vazio — de propósito.
	if _ja_derrotado(especie):
		return

	var spawn_mgr := mapa.get_node_or_null("SpawnManager")
	if spawn_mgr == null or not spawn_mgr.has_method("spawn_specific"):
		return

	var tm : TileMap = mapa.get_node_or_null("TileMap")
	var onde := CovisLendarios.centro_andavel(tm)
	if onde == Vector2i(-9999, -9999):
		push_warning("NinhoLendario: %s não tem chão livre pro lendário" % map_id)
		return

	var pos := Vector2((onde.x + 0.5) * 128.0, (onde.y + 0.5) * 128.0)
	var inst = spawn_mgr.spawn_specific(especie, NIVEL_LENDARIO, pos)
	if inst == null:
		return
	# Lendário não foge e não patrulha pra longe: ele ESPERA. Quem se moveu foi
	# o jogador, por quinze andares.
	if "behavior" in inst:
		inst.behavior = "neutral"
	if "_spawn_pos" in inst:
		inst._spawn_pos = pos
	EventBus.legendary_encountered.emit(especie, str(dados["nome"]))

static func _ja_derrotado(especie: int) -> bool:
	var mundo : Dictionary = SaveManager.save_data.get("world", {})
	var lista : Array = mundo.get("lendarios_derrotados", [])
	return especie in lista

## Marca o lendário como gasto. Chamado quando ele é derrotado SEM captura.
static func marcar_derrotado(especie: int) -> void:
	if not CovisLendarios.NINHOS.values().any(func(d): return int(d["especie"]) == especie):
		return
	var mundo : Dictionary = SaveManager.save_data.get("world", {})
	var lista : Array = mundo.get("lendarios_derrotados", [])
	if not (especie in lista):
		lista.append(especie)
	mundo["lendarios_derrotados"] = lista
	SaveManager.save_data["world"] = mundo
