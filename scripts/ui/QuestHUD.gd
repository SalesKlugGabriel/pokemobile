## QuestHUD.gd — Overlay de quest ativa no canto superior direito do overworld.
## Exibe a quest principal ativa com título e passo atual.
extends CanvasLayer

@onready var quest_panel : PanelContainer = $QuestPanel
@onready var title_label : Label          = $QuestPanel/VBox/Title
@onready var step_label  : Label          = $QuestPanel/VBox/Step

const MAIN_QUEST_ID := "MAIN-01"

func _ready() -> void:
	layer = 45
	EventBus.map_changed.connect(func(_f, _t): _refresh())
	EventBus.battle_ended.connect(func(_r): _refresh())
	_refresh()

func _refresh() -> void:
	if not SaveManager.has_save():
		quest_panel.hide()
		return

	var quest_state := SaveManager.get_quest_state(MAIN_QUEST_ID)
	if quest_state.is_empty() or quest_state.get("completed", false):
		quest_panel.hide()
		return

	var quest_data := GameData.get_quest(MAIN_QUEST_ID)
	if quest_data.is_empty():
		quest_panel.hide()
		return

	title_label.text = quest_data.get("title", "Quest")

	# Encontra o passo atual
	var current_step_id : String = quest_state.get("current_step", "")
	var steps : Array = quest_data.get("steps", [])
	var step_desc := ""
	for step in steps:
		if step.get("id", "") == current_step_id:
			step_desc = step.get("description", "")
			break
	if step_desc.is_empty() and not steps.is_empty():
		step_desc = steps[0].get("description", "")

	step_label.text = step_desc
	quest_panel.show()
