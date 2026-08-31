## teste_fase2_pesca.gd — Teste headless da Fase 2 (Pesca + bônus de skill do
## Treinador ligados a captura/loot). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase2_pesca.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node
var GameData    : Node

func _initialize() -> void:
	print("=== Teste Fase 2 (Pesca + skills do Treinador) ===")
	SaveManager = root.get_node("SaveManager")
	GameData    = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
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
	# ---- 1. O lago existe de verdade no mapa ----
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	var achou_agua := false
	for r in range(55, 61):
		var row : String = tiles[r]
		for c in range(63, 71):
			if row[c] == "~":
				achou_agua = true
	_assert(achou_agua, "existe pelo menos 1 tile de água (~) no lago da Rota 1 (cols 63-70, rows 55-60)")
	_assert(tiles[58][66] == "~", "o centro do lago (col 66, row 58) é água")
	_assert(tiles[61][66] != "~", "logo abaixo do lago (row 61) já não é mais água (onde o Pescador fica)")

	# ---- 2. FishingSystem: distribuição e faixas ----
	var fs := FishingSystem.new()
	var mordidas := 0
	var especies := {}
	for i in 300:
		var catch_data := fs.attempt("fish_common")
		if not catch_data.is_empty():
			mordidas += 1
			especies[catch_data["species_id"]] = true
			_assert(catch_data["species_id"] == 129, "vara comum só fisga Magikarp (129)")
			_assert(catch_data["level"] >= 5 and catch_data["level"] <= 15,
				"nível do Magikarp fisgado está na faixa 5-15 (veio %d)" % catch_data["level"])
			break  # 1 conferência de faixa já basta, o resto é só taxa de mordida
	var taxa := 0
	for i in 300:
		if not fs.attempt("fish_common").is_empty():
			taxa += 1
	_assert(taxa > 60 and taxa < 180, "taxa de mordida da vara comum (~40%%) plausível em 300 tentativas (%d)" % taxa)

	var achou_gyarados := false
	for i in 2000:
		var c2 := fs.attempt("fish_rare")
		if not c2.is_empty() and c2["species_id"] == 130:
			achou_gyarados = true
			_assert(c2["level"] >= 20 and c2["level"] <= 30, "Gyarados fisgado respeita a faixa de nível 20-30")
			break
	_assert(achou_gyarados, "vara super, em 2000 tentativas, eventualmente fisga o raro Gyarados (peso 5/100)")

	# ---- 3. Item "held" novo tem o efeito certo de vara pra achar via GameData ----
	_assert(GameData.get_item("old_rod").get("effect", "") == "fish_common",
		"old_rod aponta pro efeito certo (fish_common)")
	_assert(GameData.get_item("super_rod").get("effect", "") == "fish_rare",
		"super_rod aponta pro efeito certo (fish_rare)")

	# ---- 4. Presente do Pescador (dado só 1 vez) ----
	SaveManager.new_game("TesteFase2", 4)
	_assert(not SaveManager.has_item("old_rod", 1), "novo jogo começa sem vara nenhuma")
	SaveManager.add_item("old_rod", 1)
	_assert(SaveManager.has_item("old_rod", 1), "conseguir a vara via presente do NPC funciona (simulado aqui)")

	# ---- 5. Bônus de captura e loot do Treinador agora afetam número real ----
	# (a fiação em si já foi testada indiretamente na Fase 0/1; aqui confere
	# que os getters que a batalha passou a usar continuam corretos)
	var pontos_antes = SaveManager.get_trainer_stats().get_capture_bonus()
	SaveManager.add_skill_points(1)  # garante 1 ponto disponível, não depende do nível
	var gastou = SaveManager.spend_skill_point("mestre_captura")
	_assert(gastou, "spend_skill_point('mestre_captura') funciona com ponto de bônus disponível")
	var pontos_depois = SaveManager.get_trainer_stats().get_capture_bonus()
	_assert(pontos_depois > pontos_antes,
		"gastar ponto em mestre_captura sobe o bônus que a captura real agora lê (%.3f -> %.3f)" % [pontos_antes, pontos_depois])
