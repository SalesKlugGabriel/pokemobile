## teste_quest_manager.gd — Teste headless do motor de Quests (Fase 0).
## Roda com: godot4 --headless --script res://scripts/tests/teste_quest_manager.gd
## Não faz parte do jogo em si (nenhuma cena carrega isto) — é só ferramenta
## de conferência, no mesmo espírito dos teste-*.js dos outros projetos.
extends SceneTree

var _ok    := 0
var _fail  := 0

# Rodando via --script, os autoloads não ficam disponíveis como identificador
# global de compilação (só quando o jogo sobe pela cena normal) — por isso
# aqui eles são buscados por caminho (/root/NomeDoAutoload) em vez do nome
# solto usado no resto do projeto.
var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

var _rodou := false

func _initialize() -> void:
	print("=== Teste QuestManager (Fase 0) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")
	# Os autoloads já EXISTEM na árvore aqui, mas o próprio _ready() deles
	# (que carrega JSON, conecta sinais etc.) só roda no primeiro _process —
	# depois de _initialize() retornar. Testar direto aqui pegaria tudo vazio.

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteQA", 1)
	QuestManager.reload_from_save()

	_teste_geral()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true


func _assert(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % label)
	else:
		_fail += 1
		print("  FALHA - %s" % label)


func _teste_geral() -> void:
	# ---- 1. GameData.get_species_id_by_name ----
	var geodude_id = GameData.get_species_id_by_name("geodude")
	_assert(geodude_id > 0, "get_species_id_by_name('geodude') acha um ID válido (%d)" % geodude_id)
	_assert(GameData.get_species(geodude_id).get("name", "").to_lower() == "geodude",
		"o ID achado bate com a espécie certa")
	_assert(GameData.get_species_id_by_name("não-existe-isso") == -1,
		"nome desconhecido devolve -1")

	# ---- 2. Quest simples (ROCKET-01): defeat de treinador + reward de item/exp ----
	QuestManager.start_quest("ROCKET-01")
	_assert("ROCKET-01" in QuestManager.get_active_quests(), "ROCKET-01 inicia e fica ativa")

	var exp_antes := int(SaveManager.get_trainer().get("exp", 0))
	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "Agente Sombra", "enemy_species_name": "Zubat", "enemy_level": 16,
	})
	_assert(QuestManager.is_quest_complete("ROCKET-01"),
		"derrotar 'Agente Sombra' completa ROCKET-01 (target 'agente_sombra')")
	_assert(int(SaveManager.get_trainer().get("exp", 0)) == exp_antes + 200,
		"recompensa exp_trainer=200 foi creditada")
	_assert(SaveManager.get_inventory().get("documento_fratura_parcial", 0) == 1,
		"recompensa de item foi creditada")
	_assert("ROCKET-02" in QuestManager.get_active_quests(),
		"unlocks=[ROCKET-02] iniciou a próxima quest sozinho")

	# ---- 3. Quest com defeat_count + defeat + badge (GYM-01) ----
	QuestManager.start_quest("GYM-01")
	for i in 5:
		EventBus.battle_ended.emit({
			"result": "win", "player_won": true, "is_wild": true,
			"enemy_species_name": "Geodude", "enemy_level": 12,
		})
	_assert(QuestManager.get_objective_progress("GYM-01", 0) == 5,
		"5 vitórias contra Geodude preenchem o defeat_count (alvo era 5)")
	_assert(not QuestManager.is_quest_complete("GYM-01"),
		"GYM-01 ainda não fecha — falta o 2º objetivo (derrotar Brock)")

	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "Brock", "enemy_species_name": "Onix", "enemy_level": 20,
	})
	_assert(QuestManager.is_quest_complete("GYM-01"), "derrotar Brock fecha GYM-01")
	_assert(SaveManager.has_badge("boulder_badge"), "insígnia boulder_badge foi concedida")
	# tm_rock_slide era um ID fantasma (nunca existiu em items.json) — corrigido
	# em 03/09/2026 pra tm13, o TM real criado pra esse golpe.
	_assert(SaveManager.get_inventory().get("tm13", 0) == 1,
		"recompensa de TM (tms[]) virou item no inventário")

	SaveManager.award_badge("boulder_badge")
	_assert(SaveManager.get_badges().count("boulder_badge") == 1,
		"conceder a mesma insígnia 2x não duplica")

	# ---- 4. Quest parcialmente progredida sobrevive a salvar/recarregar ----
	QuestManager.start_quest("UTIL-11")  # defeat_count target=water_pokemon, count=10
	for i in 4:
		EventBus.battle_ended.emit({
			"result": "win", "player_won": true, "is_wild": true,
			"enemy_species_name": "water_pokemon", "enemy_level": 10,
		})
	var progresso_antes = QuestManager.get_objective_progress("UTIL-11", 0)
	_assert(progresso_antes == 4, "4 vitórias avançam o progresso de UTIL-11 pra 4")

	SaveManager.save_game()
	SaveManager.load_game()
	QuestManager.reload_from_save()

	_assert(QuestManager.is_quest_complete("ROCKET-01"),
		"ROCKET-01 continua completa depois de salvar/recarregar")
	_assert(QuestManager.is_quest_complete("GYM-01"),
		"GYM-01 continua completa depois de salvar/recarregar")
	_assert(QuestManager.get_objective_progress("UTIL-11", 0) == 4,
		"progresso PARCIAL (4/10) de UTIL-11 sobrevive ao salvar/recarregar")
	_assert(SaveManager.has_badge("boulder_badge"),
		"insígnia continua concedida depois de recarregar")

	# ---- 5. XP e skill points do Treinador ----
	# Nota: chegando aqui o Treinador já ganhou exp de sobra das quests de
	# cima (ROCKET-01 + GYM-01) e pode já ter subido vários níveis sozinho —
	# por isso os cálculos abaixo são relativos ao estado ATUAL, nunca a um
	# nível 1 fixo.
	var trainer_antes  : Dictionary = SaveManager.get_trainer()
	var nivel_antes     = int(trainer_antes.get("level", 1))
	var exp_atual        = int(trainer_antes.get("exp", 0))
	var exp_pra_subir    = int(pow(nivel_antes + 1, 3)) - exp_atual
	SaveManager.add_trainer_exp(exp_pra_subir)
	_assert(int(SaveManager.get_trainer().get("level", 1)) == nivel_antes + 1,
		"add_trainer_exp() com o exato que falta sobe exatamente 1 nível (%d → %d)" % [nivel_antes, nivel_antes + 1])

	var ts = SaveManager.get_trainer_stats()
	var disponivel_normal = ts.get_available_points()
	_assert(disponivel_normal == nivel_antes,
		"nível novo (%d) dá %d pontos de skill disponíveis, sem bônus ainda" % [nivel_antes + 1, nivel_antes])

	SaveManager.add_skill_points(3)
	ts = SaveManager.get_trainer_stats()
	_assert(ts.get_available_points() == disponivel_normal + 3,
		"add_skill_points(3) soma 3 aos pontos que já existiam")

	var gastou = SaveManager.spend_skill_point("agilidade")
	_assert(gastou, "spend_skill_point('agilidade') funciona com ponto disponível")
	ts = SaveManager.get_trainer_stats()
	_assert(ts.get_available_points() == disponivel_normal + 3 - 1,
		"gastar 1 ponto tira exatamente 1 do total disponível")
	_assert(ts.get_attribute("agilidade") == 1, "o ponto foi pro atributo certo")

	# ---- 6. Título ----
	SaveManager.unlock_title("Caçador de Rocket")
	_assert(SaveManager.has_title("Caçador de Rocket"), "título desbloqueado fica salvo")
