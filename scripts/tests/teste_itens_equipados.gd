## teste_itens_equipados.gd — Os dois encaixes de item (09/09).
##
## Item 03 da fila. A regra que veio do PokeXGames e que faz held ser uma
## ESCOLHA: dois encaixes por Pokémon, um de COMBATE e um de UTILIDADE, um item
## em cada. Bater mais forte custa abrir mão de ganhar mais EXP, achar mais
## loot ou se curar sozinho.
##
## 🔴 O que este lote consertou: `SaveManager.equip_held_item()` existia desde
## sempre e **a Mochila nunca soube chamá-lo** — a categoria "held" caía no "só
## pode ser usado numa batalha". Equipar item era impossível na prática. É o
## terceiro sistema "pronto" que era fachada (os outros dois: remédio fora de
## batalha, e o HP do Pokémon que nunca era gravado).
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_itens_equipados.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _process(_delta: float) -> bool:
	print("=== Teste: itens equipados (09/09) ===")
	var itens = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	_assert(itens is Dictionary, "os itens carregam")

	# ── 1. Os dois encaixes existem, e cada held pertence a um ─────────────
	var por_encaixe := {"combate": 0, "utilidade": 0}
	var sem_encaixe : Array = []
	var sem_efeito : Array = []
	var efeitos := {}
	for id in itens:
		var item : Dictionary = itens[id]
		if str(item.get("category", "")) != "held":
			continue
		var encaixe : String = str(item.get("held_slot", ""))
		if not por_encaixe.has(encaixe):
			sem_encaixe.append(id)
			continue
		por_encaixe[encaixe] += 1
		var efeito : String = str(item.get("held_effect", ""))
		if efeito == "":
			sem_efeito.append(id)
		else:
			efeitos[efeito] = true
	_assert(sem_encaixe.is_empty(), "todo item equipável declara o encaixe (%s)" % str(sem_encaixe))
	_assert(sem_efeito.is_empty(), "e o efeito (%s)" % str(sem_efeito))
	_assert(por_encaixe["combate"] > 0 and por_encaixe["utilidade"] > 0,
		"existem itens dos dois encaixes (combate %d · utilidade %d)" % [
			por_encaixe["combate"], por_encaixe["utilidade"]])
	_assert(efeitos.size() >= 6,
		"há variedade de efeitos, não um bônus só repetido (%d)" % efeitos.size())

	# ── 2. Tiers e fusão: o destino do held repetido ───────────────────────
	var com_fusao := 0
	var fusao_quebrada : Array = []
	for id in itens:
		var item : Dictionary = itens[id]
		if str(item.get("category", "")) != "held":
			continue
		var alvo : String = str(item.get("fuses_into", ""))
		if alvo == "":
			continue
		com_fusao += 1
		if not itens.has(alvo):
			fusao_quebrada.append("%s -> %s" % [id, alvo])
		elif int(itens[alvo].get("tier", 0)) <= int(item.get("tier", 0)):
			fusao_quebrada.append("%s não sobe de tier" % id)
	_assert(com_fusao > 0, "existem itens que fundem (%d)" % com_fusao)
	_assert(fusao_quebrada.is_empty(),
		"e toda fusão aponta pra um item de tier MAIOR (%s)" % str(fusao_quebrada))
	_assert(ItensEquipados.QUANTIDADE_FUSAO == 3, "fusão é de 3 iguais, como no PXG")

	# ── 3. Efeito de dano é POR TIPO — um item não resolve o jogo todo ─────
	var poke_com_fogo := {"held_combate": "held_dano_tipo_brasa_t3"}
	_assert(ItensEquipados.valor(poke_com_fogo, "dano_tipo", "Fire") > 0.0,
		"o item de Fogo aumenta golpe de Fogo")
	_assert(ItensEquipados.valor(poke_com_fogo, "dano_tipo", "Water") == 0.0,
		"e não faz nada num golpe de Água")

	# ── 4. Um item em cada encaixe, e os dois valem ao mesmo tempo ─────────
	var completo := {"held_combate": "held_recarga_t2", "held_utilidade": "held_sorte_t2"}
	_assert(ItensEquipados.valor(completo, "recarga") > 0.0, "o de combate vale")
	_assert(ItensEquipados.valor(completo, "sorte") > 0.0, "o de utilidade também")
	_assert(ItensEquipados.valor(completo, "experiencia") == 0.0,
		"e um efeito que ninguém equipou vale zero")

	# ── 5. Save antigo não perde item ──────────────────────────────────────
	var antigo := {"held_item": "charcoal"}
	_assert(ItensEquipados.equipado(antigo, "combate") == "charcoal",
		"um save antigo (campo held_item) continua com o item, no encaixe de combate")
	_assert(ItensEquipados.equipado(antigo, "utilidade") == "",
		"e o encaixe de utilidade nasce vazio")

	# ── 6. Os sete efeitos estão LIGADOS onde o motor já media ─────────────
	var ligacoes := {
		"dano_tipo": ["res://scripts/combat/DamageCalculator.gd", "dano_tipo"],
		"recarga": ["res://scripts/entities/FollowerPokemon.gd", "\"recarga\""],
		"retorno": ["res://scripts/entities/FollowerPokemon.gd", "\"retorno\""],
		"regeneracao": ["res://scripts/entities/FollowerPokemon.gd", "\"regeneracao\""],
		"cura_status": ["res://scripts/entities/FollowerPokemon.gd", "\"cura_status\""],
		"sorte": ["res://scripts/systems/LootTable.gd", "\"sorte\""],
		"experiencia": ["res://scripts/combat/BattleResolver.gd", "\"experiencia\""],
	}
	for efeito in ligacoes:
		var arquivo : String = ligacoes[efeito][0]
		var marca : String = ligacoes[efeito][1]
		var fonte := FileAccess.get_file_as_string(arquivo)
		_assert(fonte.contains("ItensEquipados") and fonte.contains(marca),
			"o efeito '%s' está ligado em %s" % [efeito, arquivo.get_file()])

	# Regenerar só FORA de combate: regenerar apanhando faria o item vencer a
	# luta no lugar do jogador.
	var follower := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(follower.contains("_fora_de_combate()"),
		"a regeneração só acontece fora de combate")
	# O retorno não pode ANULAR o dano, só devolver.
	var i_dano := follower.find("current_hp = max(0, current_hp - amount)")
	var i_retorno := follower.find("\"retorno\"")
	_assert(i_dano > 0 and i_retorno > i_dano,
		"o retorno devolve dano, mas não anula o que você levou")

	# ── 7. A Mochila finalmente sabe equipar (era o buraco) ────────────────
	var menu := FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd")
	_assert(menu.contains('"held":'), "a Mochila trata a categoria 'held'")
	_assert(menu.contains("ItensEquipados.equipar("), "e equipa de verdade")
	_assert(menu.contains("ItensEquipados.fundir("), "e funde quando há 3 iguais")

	# ── 8. Held cai SÓ de dungeon/chefe ────────────────────────────────────
	var recompensas := FileAccess.get_file_as_string("res://scripts/world/systems/RecompensasDeCovil.gd")
	_assert(recompensas.contains("_pagar_held("),
		"a dungeon paga item equipável (elite e chefe)")
	var arq_especies = JSON.parse_string(FileAccess.get_file_as_string("res://data/pokemon/species.json"))
	var vazando : Array = []
	if arq_especies is Dictionary:
		for chave in arq_especies:
			var e : Dictionary = arq_especies[chave]
			for d in e.get("drops", []):
				var id : String = str(d.get("id", ""))
				if itens.has(id) and str(itens[id].get("category", "")) == "held":
					vazando.append("%s -> %s" % [e.get("name", "?"), id])
	_assert(vazando.is_empty(),
		"e NENHUM selvagem comum larga held — senão vira farm, não preparação (%s)" % str(vazando))

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
