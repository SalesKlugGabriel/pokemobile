## KeybindManager.gd — Autoload: permite ao jogador reatribuir teclas às
## ações do jogo e guarda a escolha em disco (user://keybinds.cfg), pra não
## perder a configuração ao fechar o navegador.
## Pedido do Gabriel (2026-08-31): "atalhos que o player consiga atribuir
## botões a funções" — pra experiência ficar fluida sem depender só do WASD.
extends Node

const SAVE_PATH := "user://keybinds.cfg"

## Só essas ações aparecem na tela de Controles. As demais definidas no
## project.godot (fullscreen, menu_map) nunca foram ligadas a nenhuma função
## no jogo — expor elas pra reatribuir confundiria o jogador com um atalho
## que não faz nada. skill_1-4/pokeball SAÍRAM dessa lista de exclusão no
## motor de combate em tempo real (Fase 9, 02/09) — agora comandam de
## verdade o Follower/a captura, e o Gabriel pediu shortcut configurável.
const REBINDABLE_ACTIONS : Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"run", "interact", "pause", "menu_bag", "menu_team", "open_pokedex",
	"skill_1", "skill_2", "skill_3", "skill_4", "pokeball",
]

const ACTION_LABELS := {
	"move_up":      "Andar pra cima",
	"move_down":    "Andar pra baixo",
	"move_left":    "Andar pra esquerda",
	"move_right":   "Andar pra direita",
	"run":          "Correr (segurar)",
	"interact":     "Interagir / Confirmar",
	"pause":        "Menu de Pausa",
	"menu_bag":     "Abrir Mochila",
	"menu_team":    "Abrir Time",
	"open_pokedex": "Abrir Pokédex",
	"skill_1":      "Skill 1 do Pokémon",
	"skill_2":      "Skill 2 do Pokémon",
	"skill_3":      "Skill 3 do Pokémon",
	"skill_4":      "Skill 4 do Pokémon",
	"pokeball":     "Jogar Pokébola",
}

func _ready() -> void:
	_load_from_disk()

## Troca a tecla de uma ação pelo evento de teclado recebido (substitui
## qualquer tecla anterior — mantém só 1 tecla por ação pra ficar simples de
## mostrar/editar na tela). Se outra ação já usava essa tecla, ela perde a
## tecla (senão as duas disparariam juntas ao apertar — mais confuso que
## útil pra quem tá configurando pela primeira vez).
func rebind(action: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	var conflict := find_conflict(event.physical_keycode, action)
	if conflict != "":
		InputMap.action_erase_events(conflict)
	InputMap.action_erase_events(action)
	var clean := InputEventKey.new()
	clean.physical_keycode = event.physical_keycode
	InputMap.action_add_event(action, clean)
	_save_to_disk()

## Descobre se `physical_keycode` já está em uso por outra ação reatribuível
## (pra avisar o jogador antes de duplicar sem querer).
func find_conflict(physical_keycode: int, ignore_action: String) -> String:
	for action in REBINDABLE_ACTIONS:
		if action == ignore_action:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == physical_keycode:
				return action
	return ""

## Restaura todas as teclas pro padrão original do jogo (o que está salvo
## no project.godot) e apaga a configuração salva em disco.
func reset_all_to_default() -> void:
	InputMap.load_from_project_settings()
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())

## Nome legível da tecla atualmente ligada à ação (ex: "W", "Espaço", "Shift").
func key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "—"

func _save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for action in REBINDABLE_ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				cfg.set_value("keybinds", action, event.physical_keycode)
				break
	cfg.save(SAVE_PATH)

func _load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action in REBINDABLE_ACTIONS:
		if not cfg.has_section_key("keybinds", action):
			continue
		var keycode : int = int(cfg.get_value("keybinds", action))
		if keycode <= 0 or not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)
