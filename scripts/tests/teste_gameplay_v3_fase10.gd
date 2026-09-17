## teste_gameplay_v3_fase10.gd — As 4 skills (§21) e o aviso (§22).
##
## Duas metades, como na Fase 9: geometria e unidades sem cena, depois o ciclo
## de uso com física e tempo de verdade.
##
## ── O que este arquivo existe pra impedir ───────────────────────────────────
##
## Três coisas, todas já vistas neste projeto em outra forma:
##
##   1. **A unidade errada.** `radius: 384` no dado está em PIXELS. Lido como
##      metros, o Gust acerta o mapa inteiro — e não dá erro nenhum.
##   2. **O aviso decorativo.** `cast_time` existir no dado e o golpe resolver na
##      hora. 84 dos 192 golpes têm aviso; se ele não atrasar nada, o combate
##      não tem janela pra desviar e o número é enfeite.
##   3. **A drenagem que não cura.** Ela nunca funcionou nem na V1, porque o
##      código lia um campo que nenhum golpe tem.
extends SceneTree

var ok : int = 0
var fail : int = 0
var _quadros : int = 0
var _atacante = null
var _alvos : Array = []
var _anuncios : Array = []
var _golpes : Array = []
var _t_anuncio : float = 0.0
var _fase : int = 0
var _pos_atacante := Vector3.ZERO

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
	print("=== Fase 10: as 4 skills ===")
	# ⚠️ `_unidades()` NÃO pode rodar aqui: ela lê `GameData`, e autoload não é
	# identificador em teste `--script` — a referência só existe depois do
	# `root.get_node()`, no primeiro `_process`.
	_formas()

# ──────────────────────────────────────────────────────────────────────────────
# 1a. Unidades — onde um erro seria invisível
# ──────────────────────────────────────────────────────────────────────────────

func _unidades() -> void:
	print("\n-- unidades: tile, pixel e metro --")
	var F = load("res://scripts/gameplay_v3/combate/FormaDeArea3D.gd")

	# Gust: range 3 tiles, radius 384 px. Em metros: 3 m e 3 m.
	var gust := {"area_type": "cone", "range": 3.0, "radius": 384.0}
	_conf("range em tiles passa direto pra metros",
		is_equal_approx(F.alcance_em_metros(gust), 3.0),
		"%.2f" % F.alcance_em_metros(gust))
	_conf("radius em PIXELS vira metros dividido por 128",
		is_equal_approx(F.raio_em_metros(gust), 3.0),
		"%.2f m — se vier 384, o golpe acerta o mapa inteiro" % F.raio_em_metros(gust))

	# Surf: largura 256 px = 2 m.
	var surf := {"area_type": "line", "range": 6.0, "radius": 512.0, "largura": 256.0}
	_conf("largura em pixels vira metros", is_equal_approx(F.largura_em_metros(surf), 2.0),
		"%.2f" % F.largura_em_metros(surf))
	_conf("um golpe sem raio declarado usa o próprio alcance",
		is_equal_approx(F.raio_em_metros({"range": 5.0}), 5.0))
	_conf("um golpe sem nada cai no padrão, não em zero",
		F.alcance_em_metros({}) > 0.0, "%.2f" % F.alcance_em_metros({}))

	# E os dados reais: nenhum raio absurdo depois da conversão.
	var pior : float = 0.0
	var pior_id := ""
	for id in GameData.moves:
		var m : Dictionary = GameData.moves[id]
		var r : float = F.raio_em_metros(m)
		if r > pior:
			pior = r
			pior_id = str(id)
	_conf("nenhum golpe real passa de 30 m de raio depois da conversão",
		pior <= 30.0, "o pior é %s com %.1f m" % [pior_id, pior])

# ──────────────────────────────────────────────────────────────────────────────
# 1b. As 4 formas
# ──────────────────────────────────────────────────────────────────────────────

func _formas() -> void:
	print("\n-- as 4 formas --")
	var F = load("res://scripts/gameplay_v3/combate/FormaDeArea3D.gd")
	var o := Vector3.ZERO
	var frente := Vector3(0, 0, -1)

	var single := {"area_type": "single", "range": 2.0}
	_conf("single: à frente e perto, acerta", F.dentro(single, o, frente, Vector3(0, 0, -1.5)))
	_conf("single: atrás, não", not F.dentro(single, o, frente, Vector3(0, 0, 1.5)))
	_conf("single: à frente e longe, não", not F.dentro(single, o, frente, Vector3(0, 0, -9)))

	var circle := {"area_type": "circle", "radius": 384.0}
	_conf("circle: à frente, acerta", F.dentro(circle, o, frente, Vector3(0, 0, -2)))
	_conf("circle: ATRÁS também acerta (círculo não tem frente)",
		F.dentro(circle, o, frente, Vector3(0, 0, 2)))
	_conf("circle: do lado acerta", F.dentro(circle, o, frente, Vector3(2, 0, 0)))
	_conf("circle: fora do raio, não", not F.dentro(circle, o, frente, Vector3(0, 0, -4)))

	var cone := {"area_type": "cone", "range": 3.0, "radius": 384.0}
	_conf("cone: no eixo, acerta", F.dentro(cone, o, frente, Vector3(0, 0, -2)))
	_conf("cone: 30° fora do eixo, acerta", F.dentro(cone, o, frente, Vector3(-1.1, 0, -2)))
	_conf("cone: 90° fora, não", not F.dentro(cone, o, frente, Vector3(2, 0, 0)))
	_conf("cone: atrás, não", not F.dentro(cone, o, frente, Vector3(0, 0, 2)))

	var line := {"area_type": "line", "range": 6.0, "largura": 256.0}
	_conf("line: no corredor, acerta", F.dentro(line, o, frente, Vector3(0.5, 0, -5)))
	_conf("line: na ponta do corredor, acerta", F.dentro(line, o, frente, Vector3(0, 0, -6)))
	_conf("line: além do comprimento, não", not F.dentro(line, o, frente, Vector3(0, 0, -7)))
	_conf("line: fora da largura, não", not F.dentro(line, o, frente, Vector3(2.0, 0, -5)))
	_conf("line: ATRÁS, não (linha não é retângulo centrado)",
		not F.dentro(line, o, frente, Vector3(0, 0, 3)))

	# Altura não tira ninguém da forma — a §22 resolve altura pela mira.
	_conf("um Onix muito acima, à frente, continua na forma",
		F.dentro(single, o, frente, Vector3(0, 8, -1.5)))

	# Forma desconhecida cai no caso RESTRITO, não num círculo silencioso.
	var esquisito := {"area_type": "forma_que_nao_existe", "range": 2.0}
	_conf("forma desconhecida não vira círculo: atrás continua fora",
		not F.dentro(esquisito, o, frente, Vector3(0, 0, 1.0)))

	# Ordenação, teto e não repetir alvo.
	var a := Node.new()
	var b := Node.new()
	var c := Node.new()
	var candidatos := [
		{"quem": c, "posicao": Vector3(0, 0, -3.0), "raio": 0.0},
		{"quem": a, "posicao": Vector3(0, 0, -1.0), "raio": 0.0},
		{"quem": b, "posicao": Vector3(0, 0, -2.0), "raio": 0.0},
		{"quem": a, "posicao": Vector3(0, 0, -1.0), "raio": 0.0},   # repetido
	]
	var area := {"area_type": "circle", "radius": 640.0, "max_targets": 6}
	var saida : Array = F.alvos(area, o, frente, candidatos)
	_conf("alvos saem do mais perto pro mais longe",
		saida.size() == 3 and saida[0] == a and saida[1] == b and saida[2] == c,
		"%d alvos" % saida.size())
	_conf("e o mesmo alvo nunca entra duas vezes no mesmo cast", saida.count(a) == 1)

	var com_teto := {"area_type": "circle", "radius": 640.0, "max_targets": 2}
	_conf("max_targets limita", F.alvos(com_teto, o, frente, candidatos).size() == 2)
	a.free(); b.free(); c.free()

# ──────────────────────────────────────────────────────────────────────────────
# 2. O ciclo de uso, com física e tempo
# ──────────────────────────────────────────────────────────────────────────────

func _montar() -> void:
	EventBus.skill_anunciada.connect(func(a): _anuncios.append(a))
	EventBus.golpe_resolvido.connect(func(r): _golpes.append(r))

	var mundo := Node3D.new()
	root.add_child(mundo)
	var chao := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(400, 1, 400)
	f.shape = bx
	chao.add_child(f)
	chao.position.y = -0.5
	mundo.add_child(chao)

	var P = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_atacante = P.new()
	mundo.add_child(_atacante)
	_atacante.montar(6, 50, "ground_biped")
	_atacante.global_position = Vector3.ZERO
	_pos_atacante = Vector3.ZERO
	_atacante.assumir_controle(0.0)
	# Uma de cada tipo de forma: melee, projétil/single de longe, área e drenagem.
	_atacante.kit = ["pound", "gust", "surf", "mega_drain"]

	# Três alvos em fila, à frente.
	for i in 3:
		var alvo = P.new()
		mundo.add_child(alvo)
		alvo.montar(19, 20)   # Rattata: pequeno, morre rápido
		alvo.global_position = Vector3(0, 0, -1.2 - float(i) * 1.2)
		_alvos.append(alvo)

## 🔴 As posições são REAFIRMADAS a cada quadro, e isso não é preguiça.
##
## Achado ao escrever este teste: dois Pokémon parados a 1,2 m um do outro se
## deslocam sozinhos — o de cima sobe no de baixo, 1,264 m em um quadro, com
## velocidade zero, de forma determinística. Não consegui explicar (as cápsulas
## não se sobrepõem: 0,476 + 0,180 = 0,656 < 1,2) e **não vou inventar causa**.
## Está registrado em `docs/GAMEPLAY_V3.md` como achado aberto, porque a Fase 11
## (Pokémon selvagem) vai bater nele a cada spawn.
##
## Aqui o teste pina as posições pra medir a SKILL, não a física de contato. Sem
## isso ele mediria o deslocamento e chamaria de bug de combate.
func _pinar() -> void:
	if _atacante != null:
		_atacante.global_position = _pos_atacante
	for i in _alvos.size():
		_alvos[i].global_position = Vector3(0, 0, -1.2 - float(i) * 1.2)

func _process(_delta: float) -> bool:
	_quadros += 1
	_pinar()
	match _quadros:
		1:
			EventBus = root.get_node("EventBus")
			GameData = root.get_node("GameData")
			_unidades()
			_montar()
		4:
			_slots()
		6:
			_instantaneo()
		10:
			_recusas()
		14:
			_comeca_aviso()
		16:
			_aviso_nao_resolveu_ainda()
	# ⚠️ Daqui pra frente a espera é por TEMPO DE PAREDE, não por quadro. Em
	# headless o Godot roda o laço o mais rápido que consegue: 44 quadros
	# passaram em poucos milissegundos, e o aviso de 0,4 s não tinha vencido —
	# a primeira versão deste teste reprovou por isso, não por bug no aviso.
	if _quadros > 16 and _fase == 0:
		if (float(Time.get_ticks_msec()) / 1000.0) >= _t_anuncio + 0.6:
			_fase = 1
			_aviso_resolveu()
			_drenagem()
			_cancelamento()
			_terminar()
			return true
	return false

func _slots() -> void:
	print("\n-- os slots leem moves.json --")
	for i in 4:
		var g : Dictionary = _atacante.golpe_do_slot(i)
		_conf("slot %d carregou o golpe do dado" % i, not g.is_empty() and g.has("power"),
			str(g.get("id", "vazio")))
	_conf("slot fora da lista devolve vazio, não estoura",
		_atacante.golpe_do_slot(9).is_empty())
	# As 4 formas que a §21 pede estão representadas.
	var formas : Array = []
	for i in 4:
		formas.append(str(_atacante.golpe_do_slot(i).get("area_type", "?")))
	_conf("o kit cobre mais de uma forma de área (§21)",
		formas.has("single") and (formas.has("cone") or formas.has("line")),
		str(formas))

func _instantaneo() -> void:
	print("\n-- skill instantânea (pound, cast 0) --")
	var vida_antes : int = _alvos[0].vida
	var r : Dictionary = _atacante.usar_skill(0)
	_conf("saiu sem anúncio", r.has("alvos"), str(r))
	if not r.has("alvos"):
		return
	_conf("acertou alguém", (r["alvos"] as Array).size() > 0)
	_conf("e a vida do alvo caiu de verdade", _alvos[0].vida < vida_antes,
		"antes %d, depois %d" % [vida_antes, _alvos[0].vida])
	_conf("nenhum anúncio foi emitido pra golpe instantâneo", _anuncios.is_empty())

func _recusas() -> void:
	print("\n-- por que o botão não respondeu --")
	var r : Dictionary = _atacante.usar_skill(0)
	_conf("repetir na hora é recusado", r.has("recusado"), str(r))
	_conf("e a recusa DIZ o motivo, não só 'não'",
		str(r.get("recusado", "")).contains("esfriando"), str(r.get("recusado", "")))
	_conf("a HUD consegue perguntar quanto falta",
		_atacante.skill_esfriando(0) > 0.0, "%.2f s" % _atacante.skill_esfriando(0))

	# Cooldown é por GOLPE: outra skill, pronta, sai.
	_conf("outra skill continua pronta (cooldown é por golpe, não por slot)",
		is_zero_approx(_atacante.skill_esfriando(1)))

func _comeca_aviso() -> void:
	print("\n-- skill com aviso (gust, cast 0,4 s) --")
	_t_anuncio = float(Time.get_ticks_msec()) / 1000.0
	var r : Dictionary = _atacante.usar_skill(1)
	_conf("a skill com aviso ANUNCIA em vez de resolver", r.has("anuncio"), str(r))
	if not r.has("anuncio"):
		return
	var a : Dictionary = r["anuncio"]
	_conf("o anúncio chegou no EventBus pra tela desenhar", _anuncios.size() == 1)
	_conf("o anúncio traz a forma", str(a.get("area_type", "")) == "cone", str(a.get("area_type")))
	_conf("traz raio e alcance em METROS, prontos",
		float(a["raio"]) < 30.0 and float(a["alcance"]) < 30.0,
		"raio %.1f, alcance %.1f" % [float(a["raio"]), float(a["alcance"])])
	_conf("traz a direção travada", typeof(a["direcao"]) == TYPE_VECTOR3)
	_conf("e diz quando vai resolver",
		float(a["resolve_em"]) > float(a["comeca_em"]),
		"%.2f -> %.2f" % [float(a["comeca_em"]), float(a["resolve_em"])])
	_conf("o Pokémon está anunciando", _atacante.esta_anunciando())

func _aviso_nao_resolveu_ainda() -> void:
	# A conferência que separa aviso de verdade de aviso decorativo.
	var golpes_de_gust : int = 0
	for g in _golpes:
		if str(g.get("golpe", "")) == "gust":
			golpes_de_gust += 1
	_conf("o aviso ATRASOU o golpe — nada resolveu ainda", golpes_de_gust == 0,
		"%d golpes de gust já saíram" % golpes_de_gust)
	var r : Dictionary = _atacante.usar_skill(2)
	_conf("e no meio do aviso nenhuma outra skill sai",
		str(r.get("recusado", "")).contains("outra skill"), str(r))

func _aviso_resolveu() -> void:
	print("\n-- o aviso venceu --")
	var golpes_de_gust : int = 0
	for g in _golpes:
		if str(g.get("golpe", "")) == "gust":
			golpes_de_gust += 1
	_conf("depois do aviso, o golpe resolveu", golpes_de_gust > 0,
		"%d golpes de gust" % golpes_de_gust)
	_conf("um cone pegou mais de um alvo em fila", golpes_de_gust > 1,
		"%d alvos" % golpes_de_gust)
	_conf("o Pokémon não está mais anunciando", not _atacante.esta_anunciando())
	var esperado : float = _t_anuncio + 0.4
	_conf("e resolveu depois do tempo declarado, não antes",
		(float(Time.get_ticks_msec()) / 1000.0) >= esperado)

func _drenagem() -> void:
	print("\n-- drenagem cura pelo dano REAL --")
	# Machuca o atacante primeiro, senão a cura não tem pra onde ir.
	_atacante.sofrer(int(_atacante.vida_maxima * 0.6), null)
	var vida_antes : int = _atacante.vida
	var alvo_vida_antes : int = _alvos[0].vida
	if _alvos[0].esta_derrotado():
		_conf("o alvo da drenagem ainda está vivo", false, "já estava derrotado")
		return
	var r : Dictionary = _atacante.usar_skill(3)   # mega_drain
	_conf("a skill de drenagem saiu", r.has("alvos"), str(r))
	var causou : int = alvo_vida_antes - _alvos[0].vida
	_conf("ela causou dano", causou > 0, "%d" % causou)
	_conf("e CUROU quem usou (a drenagem nunca funcionou na V1)",
		_atacante.vida > vida_antes,
		"antes %d, depois %d, dano causado %d" % [vida_antes, _atacante.vida, causou])
	_conf("a cura nunca passa do dano causado (§20)",
		(_atacante.vida - vida_antes) <= causou,
		"curou %d, causou %d" % [_atacante.vida - vida_antes, causou])

func _cancelamento() -> void:
	print("\n-- cair no meio do aviso cancela --")
	var cancelados : Array = []
	EventBus.skill_cancelada.connect(func(id): cancelados.append(id))
	_atacante.vida = _atacante.vida_maxima
	_atacante._cooldowns.clear()
	var r : Dictionary = _atacante.usar_skill(1)
	_conf("anunciou de novo", r.has("anuncio"), str(r))
	_atacante.sofrer(999999, null)
	# O cancelamento acontece no próximo tick do aviso. Chamado à mão aqui porque
	# o teste vai terminar no mesmo quadro e não haveria próximo tick.
	_atacante._tick_cast()
	_conf("o aviso foi cancelado", not _atacante.esta_anunciando())
	_conf("e a tela foi avisada pra apagar o telegrafe", cancelados.size() == 1,
		"%d cancelamentos" % cancelados.size())

func _terminar() -> void:
	print("\n=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)
