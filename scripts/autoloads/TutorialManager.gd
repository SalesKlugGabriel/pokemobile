## TutorialManager.gd — dicas contextuais na PRIMEIRA vez que algo acontece de
## verdade (09/09/2026, pedido do Gabriel: "siga com o tutorial"). Não é uma
## cutscene nem uma tela de abertura — cada dica só aparece uma vez na vida do
## save, no momento em que o jogador realmente encontra aquela situação
## (primeiro encontro selvagem, primeiro Pokémon caído, primeira cura...).
##
## Zero UI nova: reaproveita o mesmo aviso no topo da tela que os covis já
## usam (EventBus.notification_requested → OverworldHUD._mostrar_aviso, que já
## tem fila e autodesaparece) — regra 2.1, uma peça de UI, não duas.
extends Node

# Cada dica é ["gatilho já visto?", texto]. O texto é escrito pra quem NUNCA
# jogou nada de Pokémon — não assume que "PP" ou "follower" já fazem sentido.
const DICAS := {
	"movimento": "Use as setas ou WASD pra andar. Aperte [interagir] perto de alguém ou de algo pra falar/usar.",
	"combate": "Combate é em TEMPO REAL — sem turnos. Clique no Pokémon selvagem pra mirar nele, depois aperte 1-4 (ou clique no golpe na tela) pra atacar com seu Pokémon líder. Desviar de golpes de área funciona de verdade: saia da marcação no chão antes do impacto.",
	"desmaiado": "Esse Pokémon caiu, não sumiu — agora dá pra tentar capturar. Escolha uma Pokébola e clique nele.",
	"pos_captura": "Capturado! Ele entra no seu time (ou no PC, se o time já tiver 6). Veja o time e os golpes dele no menu de Pausa.",
	"cura": "Seu Pokémon líder tomou dano. Use uma Poção quando puder — sem cura, ele pode desmaiar em combate.",
	"level_up": "Subir de nível deixa seu Pokémon mais forte e pode destravar evolução. Fique de olho no HP máximo crescendo.",
	"pokedex_clique": "O ícone Pokédex funciona em 2 cliques: aperte ele, depois clique em qualquer Pokémon (seu ou selvagem) pra ver a ficha completa.",
	"loja": "Fale com o vendedor e escolha Comprar ou Vender — são telas separadas. Vender itens de loot dá dinheiro pra comprar o que precisar.",
	"pesca": "Você ganhou uma vara de pescar! Fique de frente pra água (bem na beira) e aperte [interagir] — não precisa escolher a vara na Mochila, é automático.",
}

func _ready() -> void:
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.wild_pokemon_engaged.connect(_on_engaged)
	EventBus.wild_pokemon_desmaiado.connect(_on_desmaiado)
	EventBus.capture_success.connect(_on_capture_success)
	EventBus.follower_hp_changed.connect(_on_follower_hp_changed)
	EventBus.pokemon_level_up.connect(_on_level_up)

func _vistos() -> Array:
	if not SaveManager.save_data.has("tutorial_seen"):
		SaveManager.save_data["tutorial_seen"] = []
	return SaveManager.save_data["tutorial_seen"]

## Mostra a dica `id` só se nunca foi mostrada neste save. Chamado pelos
## handlers abaixo E pelas telas novas (loja/captura/cura/Pokédex) que
## precisam avisar sobre o próprio fluxo assim que o jogador chega nelas.
func mostrar(id: String) -> void:
	var vistos := _vistos()
	if id in vistos:
		return
	if not DICAS.has(id):
		return
	vistos.append(id)
	EventBus.notification_requested.emit(DICAS[id])

func _on_map_changed(_de: String, _para: String) -> void:
	mostrar("movimento")

func _on_engaged(_pokemon: Node) -> void:
	mostrar("combate")

func _on_desmaiado(_pokemon: Node) -> void:
	mostrar("desmaiado")

func _on_capture_success(_dados: Dictionary) -> void:
	mostrar("pos_captura")

func _on_follower_hp_changed(current: int, maximum: int) -> void:
	if maximum > 0 and current < maximum:
		mostrar("cura")

func _on_level_up(_dados: Dictionary, _novo_nivel: int) -> void:
	mostrar("level_up")
