## teste_gameplay_v3_fase9.gd — O ataque básico em 1ª pessoa (§18, §22).
##
## Duas metades, de propósito:
##
##   1. **Geometria pura** — `AtaqueBasico` é classe sem nó, então alcance, arco
##      e cooldown se provam sem subir mundo nenhum. É rápido e é exato.
##   2. **Com física** — achar quem está na frente depende do espaço de colisão
##      de verdade. Essa parte não dá pra provar na aritmética, e é onde os erros
##      de combate 3D moram: o golpe que passa raspando e não conecta.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
## Um ataque que **parece** funcionar: sai a animação, sai o som, e a vida do
## alvo não muda. É o zero silencioso na sua forma mais frustrante pro jogador,
## e esta VPS já o encontrou em seis formas diferentes. Por isso nenhuma
## conferência aqui aceita "não deu erro" — todas exigem que a vida MUDE, ou que
## ela explicitamente NÃO mude.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _mundo : Node3D = null
var _atacante = null
var _alvo = null
var _relatorios : Array = []

var EventBus : Node
var GameData : Node

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

func _initialize() -> void:
	print("=== Fase 9: ataque básico ===")
	_geometria()

# ──────────────────────────────────────────────────────────────────────────────
# 1. Geometria e cooldown — sem nó, sem mundo
# ──────────────────────────────────────────────────────────────────────────────

func _geometria() -> void:
	print("\n-- regras puras --")
	var AB = load("res://scripts/gameplay_v3/combate/AtaqueBasico.gd")

	# O golpe sai no formato de moves.json, senão DanoV2 e o relatório precisariam
	# de um caminho especial pro básico — e caminho especial é o que diverge.
	var g : Dictionary = AB.golpe()
	for chave in ["id", "name", "type", "category", "power", "contact", "area_type", "cast_time"]:
		_conf("o golpe básico declara '%s'" % chave, g.has(chave))
	_conf("o básico é Normal (decisão registrada: não ganha STAB de graça)",
		str(g["type"]) == "Normal", str(g["type"]))
	_conf("e é mais fraco que a skill mais fraca de moves.json (40)",
		float(g["power"]) < 40.0, "poder %.0f" % float(g["power"]))

	# Cooldown. O caso do "nunca usou" é o que mais importa: sem ele, o Pokémon
	# recém-assumido fica meio segundo sem atacar e o jogador acha que travou.
	_conf("nunca usado = pronto", AB.pronto(0.0, -1.0))
	_conf("acabou de usar = não está pronto", not AB.pronto(10.0, 10.0))
	_conf("passou o cooldown = pronto", AB.pronto(10.0 + AB.COOLDOWN + 0.01, 10.0))
	_conf("faltando metade, esfriando devolve ~metade",
		absf(AB.esfriando(10.0 + AB.COOLDOWN * 0.5, 10.0) - AB.COOLDOWN * 0.5) < 0.001,
		"%.3f" % AB.esfriando(10.0 + AB.COOLDOWN * 0.5, 10.0))
	_conf("pronto = esfriando zero", is_zero_approx(AB.esfriando(100.0, 0.0)))

	# Alcance. O raio do alvo entra: bicho grande é acertado antes, porque o
	# corpo dele começa antes.
	_conf("dentro do alcance acerta", AB.dentro_do_alcance(1.0, 2.0))
	_conf("fora do alcance não acerta", not AB.dentro_do_alcance(3.0, 2.0))
	_conf("o raio do alvo estende o alcance", AB.dentro_do_alcance(3.0, 2.0, 1.5))
	_conf("exatamente na borda acerta (não é erro por um epsilon)",
		AB.dentro_do_alcance(2.0, 2.0))

	# Arco. Só o plano horizontal — incluir altura faria errar um Diglett aos pés.
	var frente := Vector3(0, 0, -1)
	_conf("alvo exatamente à frente está no arco", AB.dentro_do_arco(frente, Vector3(0, 0, -5)))
	_conf("alvo às costas NÃO está no arco", not AB.dentro_do_arco(frente, Vector3(0, 0, 5)))
	_conf("alvo a 90° NÃO está no arco", not AB.dentro_do_arco(frente, Vector3(5, 0, 0)))
	_conf("alvo a 30° está no arco (perdoa mira imprecisa)",
		AB.dentro_do_arco(frente, Vector3(-2.9, 0, -5)))
	_conf("altura não tira do arco: alvo muito acima, à frente, acerta",
		AB.dentro_do_arco(frente, Vector3(0, 40, -5)))
	_conf("vetor nulo não acerta nada (não vira arco de 360°)",
		not AB.dentro_do_arco(frente, Vector3.ZERO))

	# `acertou` junta as duas — e é ela que o jogo usa, então é ela que precisa
	# concordar com as partes.
	_conf("acertou: à frente e no alcance",
		AB.acertou(frente, Vector3.ZERO, Vector3(0, 0, -1.5), 2.0))
	_conf("acertou: à frente mas longe, não",
		not AB.acertou(frente, Vector3.ZERO, Vector3(0, 0, -9.0), 2.0))
	_conf("acertou: perto mas atrás, não",
		not AB.acertou(frente, Vector3.ZERO, Vector3(0, 0, 1.0), 2.0))

# ──────────────────────────────────────────────────────────────────────────────
# 2. Com física — quem está na frente de verdade
# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	EventBus = root.get_node("EventBus")
	GameData = root.get_node("GameData")
	EventBus.golpe_resolvido.connect(func(r): _relatorios.append(r))

	_mundo = Node3D.new()
	root.add_child(_mundo)

	var chao := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(200, 1, 200)
	f.shape = b
	chao.add_child(f)
	chao.position.y = -0.5
	_mundo.add_child(chao)

	var Pokemon3D = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_atacante = Pokemon3D.new()
	_mundo.add_child(_atacante)
	_atacante.montar(6, 30, "ground_biped")     # Charizard
	_atacante.global_position = Vector3.ZERO
	_atacante.assumir_controle(0.0)             # olhando pra −Z

	_alvo = Pokemon3D.new()
	_mundo.add_child(_alvo)
	_alvo.montar(95, 30)                        # Onix
	# Bem na frente, dentro do alcance.
	_alvo.global_position = Vector3(0, 0, -1.0)

func _process(_delta: float) -> bool:
	_quadros += 1
	if _quadros == 1:
		_montar()
		return false
	if _quadros == 4:
		_conferir_acerto()
		return false
	if _quadros == 8:
		_conferir_cooldown()
		return false
	if _quadros == 12:
		_conferir_costas()
		return false
	if _quadros == 16:
		_conferir_longe()
		return false
	if _quadros == 20:
		_conferir_derrotado()
		_terminar()
		return true
	return false

func _conferir_acerto() -> void:
	print("\n-- com física: o alvo está na frente --")
	var vida_antes : int = _alvo.vida
	var r : Dictionary = _atacante.atacar()

	_conf("o ataque devolveu relatório", not r.is_empty(),
		"vazio — não achou alvo, ou estava esfriando")
	if r.is_empty():
		return

	# A conferência que importa: a VIDA MUDOU. Relatório bonito com vida intacta
	# é exatamente o ataque que "parece" funcionar.
	_conf("a vida do alvo caiu de verdade", _alvo.vida < vida_antes,
		"antes %d, depois %d" % [vida_antes, _alvo.vida])
	# ⚠️ As duas conferências abaixo têm de existir juntas. "relatório == vida
	# perdida" passa quando os DOIS são zero — foi assim que a primeira rodada
	# deste teste mostrou 'OK' pra essa linha com dano 0 (a chave lida era
	# `dano` e o contrato de DanoV2 é `final`).
	_conf("o dano foi maior que zero", int(r["dano"]) > 0, "dano %d" % int(r["dano"]))
	_conf("o dano do relatório bate com o que saiu da vida",
		int(r["dano"]) == vida_antes - _alvo.vida,
		"relatório %d, vida perdeu %d" % [int(r["dano"]), vida_antes - _alvo.vida])
	_conf("o relatório diz de quem foi o golpe",
		int(r["atacante_id"]) == _atacante.get_instance_id())
	_conf("e em quem bateu", int(r["alvo_id"]) == _alvo.get_instance_id())
	_conf("traz a efetividade como PALAVRA, não só o multiplicador",
		str(r["efetividade"]).length() > 0 and r.has("frase"), str(r["efetividade"]))
	_conf("traz a geometria em 3D (Vector3, não Vector2)",
		typeof(r["origem"]) == TYPE_VECTOR3 and typeof(r["direcao"]) == TYPE_VECTOR3)
	_conf("a direção aponta do atacante pro alvo",
		Vector3(r["direcao"]).dot(Vector3(0, 0, -1)) > 0.9,
		str(r["direcao"]))
	_conf("avisa que foi instantâneo (a tela tem de ler no impacto)",
		not bool(r["teve_aviso"]))
	_conf("o sinal do EventBus chegou pra tela",
		_relatorios.size() == 1, "%d relatórios" % _relatorios.size())

func _conferir_cooldown() -> void:
	print("\n-- o cooldown vale --")
	var vida_antes : int = _alvo.vida
	var r : Dictionary = _atacante.atacar()
	_conf("bater de novo na hora não sai", r.is_empty())
	_conf("e a vida do alvo não mudou", _alvo.vida == vida_antes)
	_conf("o básico está esfriando, e a HUD consegue perguntar quanto",
		not _atacante.basico_pronto() and _atacante.basico_esfriando() > 0.0,
		"%.3f s" % _atacante.basico_esfriando())

func _conferir_costas() -> void:
	print("\n-- alvo às costas --")
	# Força o cooldown a ter passado e põe o alvo atrás.
	_atacante._ultimo_basico = -1.0
	_alvo.global_position = Vector3(0, 0, 1.0)
	var vida_antes : int = _alvo.vida
	var r : Dictionary = _atacante.atacar()
	_conf("bater com o alvo atrás não acerta", r.is_empty())
	_conf("e a vida dele fica intacta", _alvo.vida == vida_antes,
		"antes %d, depois %d" % [vida_antes, _alvo.vida])
	# ⚠️ E o cooldown CONTOU mesmo tendo errado: errar tem de custar, senão o
	# jogador aperta o botão sem parar sem risco nenhum.
	_conf("mas o cooldown contou a tentativa (errar custa)",
		not _atacante.basico_pronto())

func _conferir_longe() -> void:
	print("\n-- alvo à frente, mas longe --")
	_atacante._ultimo_basico = -1.0
	_alvo.global_position = Vector3(0, 0, -60.0)
	var vida_antes : int = _alvo.vida
	var r : Dictionary = _atacante.atacar()
	_conf("alvo fora do alcance não é acertado", r.is_empty())
	_conf("e a vida dele fica intacta", _alvo.vida == vida_antes)

func _conferir_derrotado() -> void:
	print("\n-- alvo derrotado não é alvo --")
	_atacante._ultimo_basico = -1.0
	_alvo.global_position = Vector3(0, 0, -1.0)
	_alvo.sofrer(999999, null)
	_conf("o alvo está derrotado", _alvo.esta_derrotado())
	var r : Dictionary = _atacante.atacar()
	_conf("bater num alvo já derrotado não produz golpe", r.is_empty())

	# E o próprio atacante derrotado não bate.
	_atacante._ultimo_basico = -1.0
	_atacante.sofrer(999999, null)
	_conf("atacante derrotado não ataca", _atacante.atacar().is_empty())

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
