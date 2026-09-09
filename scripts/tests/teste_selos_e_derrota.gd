## teste_selos_e_derrota.gd — Etapa 3 das Dungeons Elementais (09/09).
##
## Item 05 da fila. Três peças, e todas são sobre RISCO:
##   · cair dentro da dungeon devolve à ENTRADA com custo, não ao Centro Pokémon;
##   · três selos (Bronze/Prata/Ouro) — um mapa, três desafios;
##   · ~24 golpes marcados como área (eram 6),
##     porque telegraph e desvio só importam se houver golpe de área pra desviar.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_selos_e_derrota.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _process(_delta: float) -> bool:
	print("=== Teste: selos, derrota com custo e golpes de área (09/09) ===")

	# ── 1. Os três selos ───────────────────────────────────────────────────
	var selos : Dictionary = RegrasDeCovil.SELOS
	for esperado in ["bronze", "prata", "ouro"]:
		_assert(selos.has(esperado), "existe o selo %s" % esperado)
	_assert(RegrasDeCovil.SELO_PADRAO == "bronze",
		"o padrão é o mais brando — quem não escolher nada não é punido")

	# Cada selo tem que MUDAR alguma coisa, senão são três nomes pro mesmo jogo.
	var tetos := {}
	var densidades := {}
	var chefes := {}
	for chave in selos:
		tetos[int(selos[chave].get("teto_extra", 0))] = true
		densidades[float(selos[chave].get("densidade", 1.0))] = true
		chefes[float(selos[chave].get("hp_do_chefe", 1.0))] = true
	_assert(tetos.size() == 3, "os três mexem no teto de nível de formas diferentes")
	_assert(densidades.size() == 3, "e na densidade de inimigos")
	_assert(chefes.size() == 3, "e em quanto do chefe é preciso tirar")

	# Ouro tem que ser o mais duro nas três frentes.
	_assert(int(selos["ouro"]["teto_extra"]) < int(selos["bronze"]["teto_extra"]),
		"no Ouro você luta mais fraco (teto menor)")
	_assert(float(selos["ouro"]["densidade"]) > float(selos["bronze"]["densidade"]),
		"e com mais inimigos")
	_assert(float(selos["ouro"]["hp_do_chefe"]) > float(selos["bronze"]["hp_do_chefe"]),
		"e precisa tirar mais vida do chefe")

	# O selo aperta o teto de verdade, não só na tabela.
	RegrasDeCovil.escolher_selo("bronze")
	var teto_bronze := RegrasDeCovil.nivel_efetivo(99, "ilha_gelida_f1")
	RegrasDeCovil.escolher_selo("ouro")
	var teto_ouro := RegrasDeCovil.nivel_efetivo(99, "ilha_gelida_f1")
	_assert(teto_ouro < teto_bronze,
		"o mesmo Pokémon entra mais fraco no Ouro (%d) que no Bronze (%d)" % [teto_ouro, teto_bronze])
	RegrasDeCovil.escolher_selo("bronze")

	_assert(not RegrasDeCovil.escolher_selo("impossivel"),
		"um selo que não existe é recusado, não vira estado inválido")

	# ── 2. Dá pra ESCOLHER o selo (senão são números que ninguém vê) ───────
	var recompensas := FileAccess.get_file_as_string("res://scripts/world/systems/RecompensasDeCovil.gd")
	_assert(recompensas.contains("_oferecer_selo("),
		"a Entrada oferece a escolha do selo")
	_assert(recompensas.contains("teto nv") and recompensas.contains("do chefe"),
		"e o painel diz o que MUDA, não só o nome do selo")

	# ── 3. Cair na dungeon: volta pra Entrada, com custo ───────────────────
	var regras := FileAccess.get_file_as_string("res://scripts/world/systems/RegrasDeCovil.gd")
	_assert(regras.contains("func ao_cair("), "existe a regra de queda dentro do covil")
	_assert(regras.contains("int(dinheiro / 2)"), "que cobra metade do dinheiro")
	var i_dinheiro := regras.find("save_data[\"money\"]")
	var i_pokemon := regras.find("remove_pokemon")
	_assert(i_dinheiro > 0 and i_pokemon < 0,
		"e NÃO tira Pokémon nem EXP — o custo tem que doer sem apagar progresso")

	var treinador := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(treinador.contains("RegrasDeCovil.ao_cair("),
		"a queda do jogador passa por essa regra")
	var i_covil := treinador.find("RegrasDeCovil.ao_cair(")
	var i_centro := treinador.find("warp_to_remembered_return()", i_covil)
	_assert(i_covil > 0 and i_centro > i_covil,
		"e só cai no Centro Pokémon quando NÃO estava numa dungeon")
	_assert(RegrasDeCovil.ao_cair("world_map") == "",
		"fora da dungeon a regra normal do jogo continua valendo")

	# ── 4. A densidade do selo chega ao spawn ──────────────────────────────
	var spawn := FileAccess.get_file_as_string("res://scripts/world/systems/SpawnManager.gd")
	_assert(spawn.contains("multiplicador_de_densidade()"),
		"o selo muda quantos inimigos nascem")

	# ── 5. O objetivo do chefe muda com o selo ─────────────────────────────
	var chefe := FileAccess.get_file_as_string("res://scripts/combat/ChefeLendario.gd")
	_assert(chefe.contains("fracao_do_chefe()"),
		"o chefe sabe quanto de vida basta tirar neste selo")
	_assert(chefe.contains("RecompensasDeCovil.ao_vencer_chefe(especie)"),
		"e vencer pelo objetivo do selo paga recompensa — é vitória, só que menor")

	# ── 6. Golpes de área: eram 6, e telegraph sem área é enfeite ──────────
	var golpes = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves/moves.json"))
	var de_area : Array = []
	var por_tipo := {}
	if golpes is Dictionary:
		for id in golpes:
			var m : Dictionary = golpes[id]
			if float(m.get("radius", 0.0)) > 0.0:
				de_area.append(id)
				var tipo : String = str(m.get("type", "?"))
				por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
	_assert(de_area.size() >= 20,
		"há golpes de área suficientes pro telegraph importar (%d)" % de_area.size())
	_assert(por_tipo.size() >= 12,
		"e espalhados por tipo, não concentrados num só (%d tipos)" % por_tipo.size())
	var sem_alvo : Array = []
	for id in de_area:
		if str(golpes[id].get("target_type", "")) != "area":
			sem_alvo.append(id)
	_assert(sem_alvo.is_empty(),
		"todo golpe com raio está marcado como área (%s)" % str(sem_alvo))

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
