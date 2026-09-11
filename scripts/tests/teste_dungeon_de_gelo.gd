## teste_dungeon_de_gelo.gd — A Etapa 2 das Dungeons Elementais (06/09).
##
## A primeira dungeon inteira: cinco anéis, teto de nível, as três travas de
## cura, o chefe com repertório e as recompensas. O que este arquivo pergunta,
## conferência por conferência, é sempre a mesma coisa: **o risco é real e é
## justo?** Difícil sem ser injusto significa que o jogador sempre podia ter
## feito diferente — e cada regra abaixo existe pra garantir isso.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_dungeon_de_gelo.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _initialize() -> void:
	print("=== Teste: a Dungeon de Gelo, ponta a ponta (06/09) ===")

func _process(_delta: float) -> bool:
	_aneis()
	_teto_de_nivel()
	_travas_de_cura()
	_cura_de_campo()
	_hp_que_persiste()
	_chefe()
	_recompensas()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# 1. Os cinco anéis
# ──────────────────────────────────────────────────────────────────────────
func _aneis() -> void:
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_entrada") == 1, "a Entrada é o anel 1")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_vestibulo") == 2, "o Vestíbulo é o anel 2")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_f1") == 3, "os andares de subida são a fazenda (anel 3)")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_f10") == 3, "o 10º andar também")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_b1") == 4, "a descida é a elite (anel 4)")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida_b5") == 5, "o ninho é a arena (anel 5)")
	_assert(RegrasDeCovil.anel_do_mapa("world_map") == 0, "o mundo aberto não é dungeon")
	_assert(RegrasDeCovil.anel_do_mapa("ilha_gelida") == 0, "nem a ilha na superfície")

	_assert(RegrasDeCovil.e_seguro("ilha_gelida_entrada"), "só a Entrada é lugar seguro")
	_assert(not RegrasDeCovil.e_seguro("ilha_gelida_f1"), "a fazenda não é segura")
	_assert(RegrasDeCovil.e_arena("ilha_gelida_b5"), "a arena é reconhecida como tal")

	# Os 15 andares que já existiam foram RECLASSIFICADOS, não redesenhados:
	# nenhum pode ter ficado de fora dos anéis.
	var sem_anel : Array = []
	for i in range(1, 11):
		if RegrasDeCovil.anel_do_mapa("ilha_gelida_f%d" % i) == 0:
			sem_anel.append("f%d" % i)
	for i in range(1, 6):
		if RegrasDeCovil.anel_do_mapa("ilha_gelida_b%d" % i) == 0:
			sem_anel.append("b%d" % i)
	_assert(sem_anel.is_empty(), "os 15 andares que já existiam entraram nos anéis (%s)" % str(sem_anel))

	# A Entrada tem que ser SEM GELO: pisar em algo que não escorrega é como o
	# jogo diz "aqui você está seguro" sem escrever isso.
	var entrada : Array = CovisLendarios.gerar_entrada_gelo()
	var tem_gelo := false
	for linha in entrada:
		if str(linha).contains(CovisLendarios._char_gelo()):
			tem_gelo = true
	_assert(not tem_gelo, "a Entrada não tem chão escorregadio")

	# O Vestíbulo tem que ter gelo (é a aula) — e pouco.
	var vest : Array = CovisLendarios.gerar_vestibulo_gelo()
	var celulas_gelo := 0
	var celulas := 0
	for linha in vest:
		for ch in str(linha):
			celulas += 1
			if ch == CovisLendarios._char_gelo():
				celulas_gelo += 1
	_assert(celulas_gelo > 0, "o Vestíbulo tem uma pista de gelo (a aula)")
	_assert(float(celulas_gelo) / float(maxi(1, celulas)) < 0.25,
		"e a pista é curta — %d de %d tiles (uma aula, não um quebra-cabeça)" % [celulas_gelo, celulas])

# ──────────────────────────────────────────────────────────────────────────
# 2. Teto de nível
# ──────────────────────────────────────────────────────────────────────────
func _teto_de_nivel() -> void:
	var teto := RegrasDeCovil.teto_de_nivel("ilha_gelida_f1")
	_assert(teto > 0, "a dungeon de gelo tem teto de nível (%d)" % teto)
	_assert(RegrasDeCovil.nivel_efetivo(80, "ilha_gelida_f1") == teto,
		"um Pokémon nível 80 entra rebaixado ao teto")
	_assert(RegrasDeCovil.nivel_efetivo(20, "ilha_gelida_f1") == 20,
		"quem está abaixo do teto não é mexido")
	_assert(RegrasDeCovil.nivel_efetivo(80, "world_map") == 80,
		"fora da dungeon não existe rebaixamento")
	_assert(RegrasDeCovil.foi_rebaixado(80, "ilha_gelida_f1"),
		"e o jogo sabe dizer que rebaixou (a tela precisa mostrar isso)")
	# Piso: avisa, não bloqueia. É respeito — o jogador pode escolher apanhar.
	_assert(RegrasDeCovil.abaixo_do_piso(10, "ilha_gelida_f1"),
		"nível 10 é avisado de que está abaixo do piso")
	var fonte := FileAccess.get_file_as_string("res://scripts/world/systems/RegrasDeCovil.gd")
	_assert(not fonte.contains("bloquear_entrada"),
		"e o piso não bloqueia a porta — só avisa")

	# O rebaixamento tem que chegar ao Follower, senão é um número que não
	# muda nada. É no spawn que ele acontece.
	var treinador := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(treinador.contains("RegrasDeCovil.nivel_efetivo("),
		"o Follower nasce já com o nível rebaixado")
	_assert(treinador.contains("f.nivel_real"),
		"e guarda o nível verdadeiro, pra tela poder mostrar os dois")

# ──────────────────────────────────────────────────────────────────────────
# 3. As três travas de cura
# ──────────────────────────────────────────────────────────────────────────
func _travas_de_cura() -> void:
	_assert(RegrasDeCovil.espera_de_cura("world_map") == 0.0,
		"fora da dungeon a cura é livre (lá o teste é economia, não execução)")
	_assert(RegrasDeCovil.espera_de_cura("ilha_gelida_f1") == RegrasDeCovil.ESPERA_COVIL,
		"dentro da dungeon existe espera de %.0fs entre curativos" % RegrasDeCovil.ESPERA_COVIL)
	_assert(RegrasDeCovil.espera_de_cura("ilha_gelida_b5") > RegrasDeCovil.espera_de_cura("ilha_gelida_f1"),
		"e na arena do chefe a espera é maior ainda")
	_assert(RegrasDeCovil.USOS_NA_ARENA > 0 and RegrasDeCovil.USOS_NA_ARENA <= 5,
		"a arena tem um teto de curas na luta inteira (%d)" % RegrasDeCovil.USOS_NA_ARENA)

	# Fora da dungeon nada trava, aconteça o que acontecer.
	RegrasDeCovil._lacre.clear()
	RegrasDeCovil._proxima_cura_msec = Time.get_ticks_msec() + 999999
	_assert(bool(RegrasDeCovil.pode_curar("potion", "world_map").get("ok", false)),
		"nenhuma trava vale no mundo aberto")

	# Mochila lacrada: item que não entrou não pode ser usado.
	RegrasDeCovil._proxima_cura_msec = 0
	RegrasDeCovil._curas_na_arena = 0
	RegrasDeCovil._lacre = {"potion": 1}
	_assert(bool(RegrasDeCovil.pode_curar("potion", "ilha_gelida_f1").get("ok", false)),
		"o que entrou na mochila pode ser usado")
	_assert(not bool(RegrasDeCovil.pode_curar("hyper_potion", "ilha_gelida_f1").get("ok", true)),
		"o que NÃO entrou não pode — é isso que faz preparação valer")

	# A espera começa depois do uso, e vale pra QUALQUER curativo (compartilhada
	# de propósito: duas poções seguidas deixam de existir).
	RegrasDeCovil._lacre = {"potion": 5, "super_potion": 5}
	RegrasDeCovil.registrar_cura("potion", "ilha_gelida_f1")
	var r := RegrasDeCovil.pode_curar("super_potion", "ilha_gelida_f1")
	_assert(not bool(r.get("ok", true)), "usar uma poção segura TODOS os curativos, não só aquele")
	_assert(float(r.get("espera", 0.0)) > 0.0, "e o jogo diz quanto falta (%s)" % str(r.get("motivo", "")))

	# Arena: 3 usos e acabou.
	RegrasDeCovil._proxima_cura_msec = 0
	RegrasDeCovil._curas_na_arena = RegrasDeCovil.USOS_NA_ARENA
	RegrasDeCovil._lacre = {"potion": 99}
	_assert(not bool(RegrasDeCovil.pode_curar("potion", "ilha_gelida_b5").get("ok", true)),
		"esgotadas as curas da arena, não dá mais — mesmo com poção sobrando")
	_assert(RegrasDeCovil.curas_restantes_na_arena() == 0, "e a conta bate")
	# Entrar de novo na arena é uma tentativa NOVA.
	RegrasDeCovil._arena_anterior = ""
	RegrasDeCovil.atualizar("ilha_gelida_b5")
	_assert(RegrasDeCovil.curas_restantes_na_arena() == RegrasDeCovil.USOS_NA_ARENA,
		"voltar pra arena zera as curas — a luta é uma tentativa nova")
	RegrasDeCovil._proxima_cura_msec = 0
	RegrasDeCovil._lacre.clear()

# ──────────────────────────────────────────────────────────────────────────
# 4. 🔴 O buraco que este lote achou: remédio não funcionava fora de batalha
# ──────────────────────────────────────────────────────────────────────────
func _cura_de_campo() -> void:
	var menu := FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd")
	_assert(menu.contains('"medicine":'),
		"a Mochila tem tratamento pra remédio (antes caía em 'só numa batalha')")

	var cura := FileAccess.get_file_as_string("res://scripts/systems/CuraDeCampo.gd")
	# 09/09: o fluxo (trava do covil + efeito + inventário/save + som) virou
	# CuraDeCampo.usar_remedio_de_campo() — um lugar só, porque a barra de
	# ação rápida do mundo (clique no item, clique no alvo) precisa do MESMO
	# fluxo, e a Mochila (PauseMenu) agora só CHAMA essa função.
	_assert(menu.contains("CuraDeCampo.usar_remedio_de_campo("),
		"a Mochila usa o fluxo completo de cura, não só aplicar() cru")
	_assert(cura.contains("RegrasDeCovil.pode_curar("),
		"passando pelas travas do covil antes")
	_assert(cura.contains("RegrasDeCovil.registrar_cura("),
		"e registrando o uso depois, senão a espera nunca começa")
	_assert(cura.contains("revive_hp"), "Reviver é tratado")
	_assert(cura.contains("heal_hp"), "curar HP é tratado")
	_assert(cura.contains("cures"), "curar status é tratado")
	_assert(cura.contains("restore_pp"), "restaurar PP é tratado")
	_assert(cura.contains("sincronizar_follower"),
		"e curar no save também cura quem está lutando no mapa")
	# As regras clássicas: poção não ressuscita, reviver só em desmaiado.
	_assert(cura.contains("use um Reviver"), "poção não funciona em Pokémon desmaiado")
	_assert(cura.contains("não está desmaiado"), "e Reviver não funciona em Pokémon de pé")

# ──────────────────────────────────────────────────────────────────────────
# 5. 🔴 O outro buraco: o dano do Follower sumia sozinho
# ──────────────────────────────────────────────────────────────────────────
func _hp_que_persiste() -> void:
	var f := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(f.contains("hp_inicial"), "o Follower nasce com o HP que o save diz")
	_assert(f.contains("_gravar_hp_no_save"), "e grava o HP de volta no save")
	var i_dano := f.find("func take_damage")
	var i_grava := f.find("_gravar_hp_no_save()", i_dano)
	_assert(i_dano > 0 and i_grava > i_dano, "levar dano grava — não só desmaiar")
	_assert(f.contains("if int(lider.get(\"species_id\", -1)) != pokemon_species_id:"),
		"e um Follower de teste nunca sobrescreve o Pokémon de verdade do jogador")
	var t := FileAccess.get_file_as_string("res://scripts/entities/TrainerEntity.gd")
	_assert(t.contains("f.hp_inicial"), "o treinador passa o HP salvo ao criar o Follower")

# ──────────────────────────────────────────────────────────────────────────
# 6. O chefe — o que o diferencia não é o nível, é o repertório
# ──────────────────────────────────────────────────────────────────────────
func _chefe() -> void:
	_assert(ChefeLendario.NIVEL == 100, "lendário é sempre nível 100 (pedido do Gabriel)")
	# 🔴 Fase 2: o limite era ×6. Medido, ×7 fazia a luta durar 218-265s e
	# SEMPRE alcançar o enrage (que dispara aos 240s) — a fase de fúria deixava
	# de ser punição por demorar e virava o final garantido de toda luta. Com
	# ×5 a luta bem jogada fecha em ~160s. O que o teste cobra continua sendo o
	# mesmo: o chefe tem que durar MUITO mais que um selvagem comum.
	_assert(ChefeLendario.MULT_HP >= 4.0,
		"e tem HP muito acima do normal (×%.0f) — a luta precisa durar o repertório inteiro" % ChefeLendario.MULT_HP)
	_assert(ChefeLendario.MULT_HP * 30.0 < ChefeLendario.ENRAGE_SEG,
		"...e não tanto que o enrage vire o final obrigatório de toda luta")
	_assert(ChefeLendario.MULT_DEFESA > 1.0, "defesa acima do normal, pra não morrer antes de jogar")

	# As SEIS funções, e cada uma existe pra punir um erro diferente. É a
	# diferença entre um chefe e uma parede de HP.
	for especie in [144, 145, 146]:
		var r : Dictionary = ChefeLendario.REPERTORIO.get(especie, {})
		_assert(not r.is_empty(), "o lendário %d tem repertório" % especie)
		for funcao in ["pressao", "area", "controle", "punicao", "percentual", "ambiente"]:
			_assert(r.has(funcao), "  %s tem a função '%s'" % [str(r.get("nome", especie)), funcao])
		# A pressão é o golpe de tapa-buraco: tem que ser o mais frequente.
		var mais_rapido := true
		for funcao in ["area", "controle", "punicao", "percentual", "ambiente"]:
			if float(r[funcao].get("espera", 99.0)) <= float(r["pressao"].get("espera", 0.0)):
				mais_rapido = false
		_assert(mais_rapido, "  e a pressão é a função mais frequente (pune ficar parado)")

	_assert(ChefeLendario.FRACAO_PERCENTUAL > 0.0 and ChefeLendario.FRACAO_PERCENTUAL < 0.5,
		"o golpe percentual tira uma fatia grande mas não metade da vida")
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/ChefeLendario.gd")
	_assert(fonte.contains("maxi(0, int(alvo.current_hp) - 1)"),
		"e nunca mata — morrer por percentual é azar, e azar não ensina nada")
	_assert(fonte.contains("TelegraphDeArea.ATE_O_DANO"),
		"a área do chefe avisa antes de cair, igual à de qualquer outro")

	# Enrage: impede vencer por atrito.
	_assert(ChefeLendario.ENRAGE_SEG >= 120.0 and ChefeLendario.ENRAGE_SEG <= 600.0,
		"o enrage vem aos %.0f minutos" % (ChefeLendario.ENRAGE_SEG / 60.0))
	_assert(ChefeLendario.ENRAGE_DANO > 1.0 and ChefeLendario.ENRAGE_ESPERA < 1.0,
		"e ele bate mais forte e mais rápido")
	# 09/09: a música também "esquenta" no enrage — item da lista de imersão.
	_assert(fonte.contains("intensificar_bgm"),
		"e a trilha acelera junto (transição de música no combate de chefe)")
	var audio_src := FileAccess.get_file_as_string("res://scripts/autoloads/AudioManager.gd")
	_assert(audio_src.contains("func intensificar_bgm"),
		"o AudioManager sabe acelerar a trilha atual sem trocar de faixa")
	_assert(audio_src.contains('next.pitch_scale = 1.0'),
		"e zera o pitch ao trocar de música — senão o enrage vazaria pra próxima trilha")

	# O ninho tem que instalar o chefe — senão o lendário continua sendo só um
	# Pokémon selvagem forte.
	var ninho := FileAccess.get_file_as_string("res://scripts/world/systems/NinhoLendario.gd")
	_assert(ninho.contains("ChefeLendario.instalar("), "o ninho instala o chefe no lendário")
	# 🔴 11/09: o nível saiu de `ChefeLendario.NIVEL` e foi pra
	# `RegrasDeLendario.NIVEL_SELVAGEM`. Motivo: "lendário selvagem é sempre
	# nível 100" é regra da ESPÉCIE, não do encontro de chefe — vale pro Mewtwo
	# e pro Mew, que não têm covil. O que o teste cobra continua o mesmo: o
	# número não é repetido aqui, vem de uma régua.
	_assert(ninho.contains("RegrasDeLendario.NIVEL_SELVAGEM"),
		"e usa o nível da régua de lendário, sem repetir o número")
	_assert(ChefeLendario.NIVEL == RegrasDeLendario.NIVEL_SELVAGEM,
		"as duas réguas concordam (%d)" % ChefeLendario.NIVEL)

	# 🔴 A regra "nasce uma vez só por partida" existia e ninguém a acionava.
	var selvagem := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(selvagem.contains("NinhoLendario.marcar_derrotado("),
		"derrotar o lendário sem capturar gasta a chance de verdade")

# ──────────────────────────────────────────────────────────────────────────
# 7. Recompensas — só o que não se consegue de outro jeito
# ──────────────────────────────────────────────────────────────────────────
func _recompensas() -> void:
	var d : Dictionary = RegrasDeCovil.DUNGEONS["ilha_gelida"]
	_assert(str(d.get("pedra", "")) != "", "a dungeon paga uma pedra de evolução")
	var itens = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	_assert(itens is Dictionary and itens.has(str(d["pedra"])),
		"e a pedra existe de verdade no jogo (%s)" % str(d["pedra"]))

	var mt : String = str(RecompensasDeCovil.MT_DO_COVIL.get("ilha_gelida", ""))
	_assert(mt != "" and itens.has(mt), "existe uma MT exclusiva do covil (%s)" % mt)
	if itens.has(mt):
		var dados_mt : Dictionary = itens[mt]
		_assert(int(dados_mt.get("price", 1)) == 0,
			"e ela não se compra em lugar nenhum — é o que a torna exclusiva")
		var golpe : String = str(dados_mt.get("teaches", ""))
		var golpes = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves/moves.json"))
		_assert(golpes is Dictionary and golpes.has(golpe),
			"o golpe que ela ensina existe (%s)" % golpe)
		if golpes is Dictionary and golpes.has(golpe):
			_assert(str(golpes[golpe].get("type", "")).to_lower() == str(d.get("tipo", "")),
				"e é do tipo da dungeon")

	var rec := FileAccess.get_file_as_string("res://scripts/world/systems/RecompensasDeCovil.gd")
	_assert(rec.contains("heal_team()"), "o santuário cura o time por completo antes do chefe")
	_assert(rec.contains("sincronizar_follower"),
		"e cura também quem está no mapa, não só o número no save")
	_assert(rec.contains("CHANCE_PEDRA_REPETIDA"),
		"repetir a dungeon paga menos — decrescente, não bloqueado")
	var captura := FileAccess.get_file_as_string("res://scripts/combat/CaptureSystem.gd")
	_assert(captura.contains("RecompensasDeCovil.ao_vencer_chefe("),
		"capturar o chefe conta como vitória (senão o caminho difícil pagaria menos)")

	# E o aviso na tela: recompensa em silêncio é o mesmo que não acontecer.
	var barramento := FileAccess.get_file_as_string("res://scripts/autoloads/EventBus.gd")
	_assert(barramento.contains("signal notification_requested"),
		"existe um canal de aviso na tela fora de batalha")
	var hud := FileAccess.get_file_as_string("res://scripts/ui/OverworldHUD.gd")
	_assert(hud.contains("notification_requested.connect"), "e a HUD escuta esse canal")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)
