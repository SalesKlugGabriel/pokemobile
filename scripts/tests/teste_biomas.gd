## teste_biomas.gd — As 10 regras de bioma do Gabriel (Fase 1, 05/09).
##
## Contexto: o jogo tinha TRÊS fontes de verdade sobre onde cada Pokémon vive, e
## a única ligada era uma tabela com 17 espécies cravadas no código. 134 dos 151
## existiam nos dados e nunca apareciam. Agora o caminho é um só —
## tile → bioma → species.json — e é este arquivo que impede a volta do atalho.
##
## As regras, como o Gabriel escreveu:
##   Veneno -> pântano · Água -> costa e submerso · Planta/Inseto -> floresta
##   Pedra/Terra -> montanha · Voador -> floresta e montanha
##   Psíquico -> deserto e ruínas · Fantasma -> assombrado · Fogo -> vulcão
##   Elétrico -> usina · Fada -> floresta fechada
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_biomas.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

var GameData : Node

## Bioma que a regra exige, por tipo. Uma espécie satisfaz a regra se PELO MENOS
## UM dos biomas exigidos estiver na lista dela — Bulbasaur é Planta/Veneno e
## mora em floresta E pântano, os dois estão certos.
const REGRA := {
	"Poison": "swamp", "Grass": "forest", "Bug": "forest",
	"Rock": "mountain", "Ground": "mountain",
	"Psychic": "ruins", "Ghost": "haunted", "Fire": "volcanic",
	"Electric": "power_plant", "Fairy": "deep_forest",
}
## Tipos cuja regra aceita mais de um destino.
const REGRA_MULTIPLA := {
	"Water": ["beach", "underwater"],
	"Flying": ["forest", "mountain"],
	"Psychic": ["desert", "ruins"],
}

## Quando dois tipos da mesma espécie puxam pra biomas diferentes, quem manda é
## o tipo MAIS ESPECÍFICO. Achado ao rodar este teste pela primeira vez: a linha
## do Gastly é Fantasma/Veneno — a regra do Fantasma pede casa assombrada, a do
## Veneno pede pântano, e as duas não podem valer ao mesmo tempo. Gengar num
## pântano seria errado; a casa assombrada é a razão de aquele bioma existir.
## Escrito como precedência (e não como três exceções) porque vale pra qualquer
## Pokémon Fantasma/Veneno que entre no jogo depois.
const PRECEDENCIA := {
	"Ghost": ["Poison"],       # Fantasma manda sobre Veneno
	"Fairy": ["Normal"],       # Fada manda sobre Normal (Clefairy, Jigglypuff)
	"Ice":   ["Water"],        # Gelo manda sobre Água (Lapras, Dewgong)
}

## Exceções conscientes, com o motivo. Uma exceção sem motivo escrito é um bug
## disfarçado de decisão — por isso a lista mora aqui e não some no silêncio.
const EXCECOES_ACEITAS := {
	41: "Zubat: Veneno/Voador, mas morcego mora em caverna",
	42: "Golbat: idem",
	50: "Diglett: Terra, mas o lugar dele é a Caverna do Diglett",
	51: "Dugtrio: idem",
	27: "Sandshrew: Terra do deserto, não da montanha",
	28: "Sandslash: idem",
	54: "Psyduck: Água antes de Psíquico",
	55: "Golduck: idem",
	79: "Slowpoke: Água antes de Psíquico",
	80: "Slowbro: idem",
	13: "Weedle: Inseto/Veneno que mora na mata, não no pântano",
	14: "Kakuna: idem",
	15: "Beedrill: idem",
	12: "Butterfree: Inseto/Voador da floresta",
	16: "Pidgey: Normal/Voador que vive perto das cidades",
	17: "Pidgeotto: idem",
	18: "Pidgeot: idem",
	25: "Pikachu: a Floresta de Viridian é o lugar dele",
	35: "Clefairy: Fada da mata fechada (era Normal na 1ª geração)",
	36: "Clefable: idem",
	39: "Jigglypuff: idem",
	40: "Wigglytuff: idem",
	131: "Lapras: Água/Gelo — o gelo manda",
	143: "Snorlax: dorme na estrada da montanha",
	144: "Articuno: lendária do gelo",
	145: "Zapdos: lendária da usina",
	146: "Moltres: lendária do vulcão",
	150: "Mewtwo: nas ruínas",
	151: "Mew: escondido na mata fechada",
	132: "Ditto: imita, aparece onde há gente",
	95:  "Onix: atravessa a rocha por dentro e por fora",
}

func _initialize() -> void:
	print("=== Teste: as 10 regras de bioma (05/09) ===")
	GameData = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- 1. Toda espécie tem bioma, e nenhum bioma é inventado -------------
	var conhecidos := ["plains", "forest", "deep_forest", "swamp", "mountain",
		"cave", "desert", "ruins", "haunted", "volcanic", "power_plant",
		"beach", "underwater", "glacial"]
	var sem_bioma : Array[String] = []
	var inventados : Array[String] = []
	var total := 0
	for chave in GameData.species:
		total += 1
		var esp : Dictionary = GameData.species[chave]
		var lista : Array = esp.get("biomes", [])
		if lista.is_empty():
			sem_bioma.append(str(esp.get("name", chave)))
		for b in lista:
			if not conhecidos.has(str(b)):
				inventados.append("%s -> %s" % [esp.get("name", chave), b])
	_assert(total >= 151, "as 151 espécies estão carregadas (%d)" % total)
	_assert(sem_bioma.is_empty(), "toda espécie tem pelo menos um bioma — %s" % (
		"ok" if sem_bioma.is_empty() else str(sem_bioma)))
	_assert(inventados.is_empty(), "nenhum bioma fora da lista dos 14 — %s" % (
		"ok" if inventados.is_empty() else str(inventados)))

	# ---- 2. As 10 regras valem, espécie por espécie ------------------------
	var quebradas : Array[String] = []
	for chave in GameData.species:
		var esp : Dictionary = GameData.species[chave]
		var ident : int = int(esp.get("id", 0))
		if EXCECOES_ACEITAS.has(ident):
			continue
		var meus : Array = esp.get("biomes", [])
		var tipos : Array = esp.get("types", [])
		# tipos cuja regra foi vencida por um tipo mais específico da mesma espécie
		var vencidos := {}
		for t in tipos:
			for perdedor in PRECEDENCIA.get(str(t), []):
				vencidos[str(perdedor)] = true
		for t in tipos:
			var tipo := str(t)
			if vencidos.has(tipo):
				continue
			var exigidos : Array = []
			if REGRA_MULTIPLA.has(tipo):
				exigidos = REGRA_MULTIPLA[tipo]
			elif REGRA.has(tipo):
				exigidos = [REGRA[tipo]]
			if exigidos.is_empty():
				continue
			var atende := false
			for b in exigidos:
				if meus.has(b):
					atende = true
			if not atende:
				quebradas.append("%s (%s) mora em %s, mas %s pede %s" % [
					esp.get("name", chave), tipo, str(meus), tipo, str(exigidos)])
	_assert(quebradas.is_empty(), "toda espécie obedece à regra do próprio tipo — %s" % (
		"ok" if quebradas.is_empty() else str(quebradas.slice(0, 5))))

	# ---- 3. Cada regra tem gente de verdade --------------------------------
	# Sem isto, um bioma poderia ficar vazio por um erro de digitação e o teste
	# acima passaria — regra obedecida por ninguém é regra obedecida.
	var por_bioma := {}
	for chave in GameData.species:
		for b in GameData.species[chave].get("biomes", []):
			por_bioma[str(b)] = int(por_bioma.get(str(b), 0)) + 1
	for bioma in ["swamp", "mountain", "desert", "ruins", "haunted", "deep_forest",
			"forest", "volcanic", "power_plant", "beach", "underwater"]:
		_assert(int(por_bioma.get(bioma, 0)) >= 3,
			"bioma '%s' tem moradores (%d)" % [bioma, int(por_bioma.get(bioma, 0))])

	# ---- 4. Quantas espécies o jogador CONSEGUE encontrar hoje -------------
	# O número que importa: 17 antes desta fase. Os biomas sem terreno próprio
	# (deserto, ruínas, assombrado, floresta fechada, glacial) entram na Fase 4
	# do plano — a lista está declarada no SpawnManager, não escondida.
	var mgr_script := load("res://scripts/world/systems/SpawnManager.gd")
	var mgr = mgr_script.new()
	var alcancaveis := {}
	for bioma in mgr.BIOMA_POR_TERRENO.keys():
		for ident in mgr.especies_do_bioma(str(bioma)):
			alcancaveis[ident] = true
	_assert(alcancaveis.size() > 100,
		"o jogador alcança %d das %d espécies (eram 17)" % [alcancaveis.size(), total])

	var sem_terreno : Array[String] = []
	for chave in GameData.species:
		var esp : Dictionary = GameData.species[chave]
		if not alcancaveis.has(int(esp.get("id", 0))):
			sem_terreno.append(str(esp.get("name", chave)))
	print("  ...  %d ainda sem terreno próprio (Fase 4): %s" % [
		sem_terreno.size(), ", ".join(sem_terreno.slice(0, 8)) + (" ..." if sem_terreno.size() > 8 else "")])

	# ---- 5. Nenhuma espécie cravada no código -------------------------------
	var fonte := FileAccess.get_file_as_string("res://scripts/world/systems/SpawnManager.gd")
	_assert(not fonte.contains('"species": ['),
		"o SpawnManager não tem mais lista de espécie cravada no código")
	_assert(fonte.contains("GameData.species"),
		"o SpawnManager lê as espécies do species.json")
	_assert(fonte.contains("GameData.get_spawns"),
		"e usa zones.json como ajuste fino por região")
	mgr.free()

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
