## teste_rfc010_estado_visual.gd — O Pokémon diz o que está fazendo (RFC-010).
##
## ── O pedido do Codex, e por que ele estava certo ───────────────────────────
##
## Os GLBs dos Pokémon entram no jogo e **ficam na pose de repouso**: não há
## contrato público de estado visual em `PokemonInstance3D`. O Codex pediu um —
## e pediu citando a razão certa, que é minha e foi medida no treinador: ler
## `quer_correr` anima CORRIDA num corpo que, exausto, anda a 4,00 m/s contra
## 4,50 de caminhada.
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **A animação que mente.** O estado sai do que o corpo FAZ, nunca de
##      intenção (`intencao`, `quer_correr`) nem de estado interno de IA.
##   2. **A fronteira do treinador aplicada a todo bicho.** Um Snorlax é lento
##      por arquétipo: se a régua fosse fixa, ele nunca chegaria a `run`.
##   3. **O bicho de pé em cima do mar.** Nadar e voar vêm do MEIO, não da
##      velocidade — um Gyarados parado na água continua nadando.
##   4. **A velocidade inflada pelo LOD.** A Fase 20 multiplica `velocity` pra
##      compensar quadros pulados; usar isso faria o bicho distante "correr".
##   5. **A animação que promete.** Ataque, dano e queda só são pedidos depois
##      de o motor confirmar o evento.
extends SceneTree

const CONFERENCIAS_ESPERADAS : int = 18

var ok : int = 0
var fail : int = 0

func _conf(nome: String, cond: bool, detalhe: String = "") -> void:
	if cond:
		ok += 1
		print("  OK   ", nome)
	else:
		fail += 1
		print("  FALHOU ", nome, "  ", detalhe)

var _quadro : int = 0
var _mundo : Node3D = null
var _terra : Node3D = null
var _agua : Node3D = null
var _ar : Node3D = null

func _initialize() -> void:
	print("== RFC-010: o Pokémon diz o que está fazendo ==")

func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro == 1:
		_montar()
		return false
	if _quadro < 3:
		return false

	_locomocao()
	_papeis()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)
	return true

## ⚠️ Monta no quadro 1 e confere no 2: nó adicionado em `_initialize` não entra
## na árvore, e `_ready` só dispara no quadro seguinte. As duas lições estão na
## disciplina de teste do QUADRO, e as duas já me custaram meia fase.
func _montar() -> void:
	var P : GDScript = load("res://scripts/gameplay_v3/entidades/PokemonInstance3D.gd")
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_terra = P.nascer(_mundo, 25, 30, Vector3(0, 0, 0), "ground_biped")
	_agua = P.nascer(_mundo, 130, 30, Vector3(0, 0, 0), "aquatic")
	_ar = P.nascer(_mundo, 18, 30, Vector3(0, 0, 0), "flying")

# ──────────────────────────────────────────────────────────────────────────────

func _locomocao() -> void:
	print("\n-- Locomoção: do que o corpo faz --")

	_conf("os três arquétipos nasceram",
		_terra != null and _agua != null and _ar != null)

	# Parado é parado.
	_terra.velocity = Vector3.ZERO
	_terra.ultimo_avanco = Vector3.ZERO
	_conf("parado é idle", _terra.estado_visual_de_locomocao() == "idle",
		_terra.estado_visual_de_locomocao())

	var maxima : float = MovementProfile.velocidade(
		"ground_biped", int(_terra.stats.get("spe", 50)))
	print("   velocidade máxima deste corpo: ", "%.2f" % maxima, " m/s")

	_terra.velocity = Vector3(maxima * 0.25, 0, 0)
	_terra.ultimo_avanco = _terra.velocity
	_conf("devagar é walk", _terra.estado_visual_de_locomocao() == "walk",
		_terra.estado_visual_de_locomocao())

	_terra.velocity = Vector3(maxima, 0, 0)
	_terra.ultimo_avanco = _terra.velocity
	_conf("na velocidade máxima é run",
		_terra.estado_visual_de_locomocao() == "run",
		_terra.estado_visual_de_locomocao())

	# 🔴 A régua é POR ARQUÉTIPO. Se fosse a do treinador, um corpo lento nunca
	# chegaria a `run` e um rápido estaria sempre correndo.
	var max_pesado : float = MovementProfile.velocidade(
		"ground_heavy", int(_terra.stats.get("spe", 50)))
	print("   um arquétipo pesado teria máxima ", "%.2f" % max_pesado, " m/s")
	_conf("a régua muda com o arquétipo", max_pesado < maxima,
		"pesado %.2f x bípede %.2f" % [max_pesado, maxima])

	# Cair não é andar.
	_terra.velocity = Vector3(0, -30, 0)
	_terra.ultimo_avanco = _terra.velocity
	_conf("cair não vira corrida", _terra.estado_visual_de_locomocao() == "idle",
		_terra.estado_visual_de_locomocao())

	# ⚠️ O LOD da Fase 20 infla `velocity` pra compensar quadros pulados. O
	# estado tem de ler o avanço ENTREGUE, senão o bicho longe "corre".
	_terra.velocity = Vector3(maxima * 4.0, 0, 0)     # como se tivesse pulado 3
	_terra.ultimo_avanco = Vector3(maxima * 0.25, 0, 0)  # o que de fato andou
	_conf("o LOD não faz o bicho distante correr",
		_terra.estado_visual_de_locomocao() == "walk",
		_terra.estado_visual_de_locomocao()
			+ " — está lendo velocity cru, não ultimo_avanco")
	_conf("e a velocidade relatada é a entregue",
		is_equal_approx(_terra.velocidade_horizontal(), maxima * 0.25),
		"%.3f" % _terra.velocidade_horizontal())

	# Nadar e voar vêm do MEIO.
	_agua.velocity = Vector3.ZERO
	_agua.ultimo_avanco = Vector3.ZERO
	_agua.global_position = _ponto_de_agua()
	var e_agua : String = _agua.estado_visual_de_locomocao()
	print("   aquático parado sobre ", _agua.superficie_atual(), " → ", e_agua)
	_conf("aquático parado na água continua nadando", e_agua == "swim",
		e_agua + " — um Gyarados parado viraria 'idle' de pé sobre o mar")

	_ar.velocity = Vector3.ZERO
	_ar.ultimo_avanco = Vector3.ZERO
	_ar.global_position = Vector3(0, 40, 0)
	_conf("voador no ar continua voando",
		_ar.estado_visual_de_locomocao() == "fly",
		_ar.estado_visual_de_locomocao())

	# E os cinco valores são os que a RFC pediu — nem mais, nem menos.
	var vistos : Dictionary = {}
	for e in ["idle", "walk", "run", "swim", "fly"]:
		vistos[e] = true
	_conf("o contrato só devolve os valores canônicos",
		vistos.has(_terra.estado_visual_de_locomocao())
			and vistos.has(_agua.estado_visual_de_locomocao())
			and vistos.has(_ar.estado_visual_de_locomocao()))

	# 🔴 A prova de que não lê intenção: mexer no estado interno da IA não pode
	# mudar o que o visual vê.
	_terra.velocity = Vector3.ZERO
	_terra.ultimo_avanco = Vector3.ZERO
	_terra.estado_selvagem = IASelvagem3D.PERSEGUIR
	_terra.provocado = true
	_conf("estado interno de IA NÃO muda o visual",
		_terra.estado_visual_de_locomocao() == "idle",
		"perseguir parado virou " + _terra.estado_visual_de_locomocao())

func _ponto_de_agua() -> Vector3:
	# Procura um ponto de água de verdade no terreno, em vez de supor onde ela
	# está: a geografia é do `Terreno3D`, não minha.
	for x in range(-70, 71, 3):
		for z in range(-70, 71, 3):
			if RegraDeTravessia.e_agua(Terreno3D.superficie_em(float(x), float(z))):
				return Terreno3D.ponto_em(float(x), float(z), 0.0)
	return Vector3.ZERO

# ──────────────────────────────────────────────────────────────────────────────

func _papeis() -> void:
	print("\n-- Os papéis transitórios: só depois do evento --")

	var pedidos : Array = []
	_terra.animacao_visual_solicitada.connect(func(p): pedidos.append(p))

	# Dano confirmado → pede `hit`.
	_terra.vida = _terra.vida_maxima
	_terra.sofrer(1, null)
	_conf("dano pede a animação de dano",
		pedidos.has(_terra.PAPEL_DANO), str(pedidos))
	_conf("e NÃO pede queda por um arranhão",
		not pedidos.has(_terra.PAPEL_QUEDA), str(pedidos))

	# Derrota → pede `faint`, e só então.
	pedidos.clear()
	_terra.sofrer(_terra.vida_maxima * 10, null)
	_conf("a queda é pedida quando o corpo cai",
		pedidos.has(_terra.PAPEL_QUEDA), str(pedidos))
	_conf("e o corpo está mesmo derrotado", _terra.esta_derrotado())

	# Dano em quem já caiu não pede nada: `sofrer` sai cedo.
	pedidos.clear()
	_terra.sofrer(10, null)
	_conf("bater em quem já caiu não pede animação nenhuma",
		pedidos.is_empty(), str(pedidos))

	# Ataque: segue o cooldown, não o acerto — golpear o ar tem de parecer
	# golpear o ar, senão errar fica invisível e ninguém aprende a mirar.
	var pedidos2 : Array = []
	_ar.animacao_visual_solicitada.connect(func(p): pedidos2.append(p))
	_ar.atacar()
	_conf("atacar o vazio ainda pede a animação de ataque",
		pedidos2.has(_ar.PAPEL_ATAQUE), str(pedidos2))
