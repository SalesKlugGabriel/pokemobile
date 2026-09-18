## teste_rfc007_treinador_1m60.gd — As três decisões da RFC-007, travadas.
##
## ── O que este arquivo impede ───────────────────────────────────────────────
##
##   1. **O chapéu invisível.** A cápsula física voltar a discordar da altura do
##      personagem. São 1,60 m dos dois lados, e é uma constante só.
##   2. **A animação que mente.** O visual escolher CORRIDA num corpo que anda
##      mais devagar que um passo. Isto não é hipótese: a exaustão nível 3 corta
##      50%, e correr exausto dá 4,0 m/s contra 4,5 m/s de caminhada. O teste
##      **reproduz esse cenário** e prova que a opção B da RFC (ler `quer_correr`)
##      teria errado ali.
##   3. **A câmera recalibrada no olho.** O ombro acompanhar a altura por
##      proporção, não por um número novo escolhido a gosto.
##   4. **A segunda cópia.** `origem_da_mira()` tinha um 1,5 cravado, copiado da
##      câmera. Agora lê a constante — se alguém recravar, este teste reprova.
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

## ⚠️ O `_ready` de um nó só dispara no quadro SEGUINTE ao `add_child` num teste
## `--script` — conferir os filhos dentro do `_initialize` encontra zero e
## reprova um código correto. Foi o que aconteceu ao escrever este arquivo. Por
## isso as conferências moram no `_process`, como o `teste_gameplay_v3_fase3`.
var _rodou : bool = false

func _initialize() -> void:
	print("== RFC-007: treinador de 1,60 m e o estado de locomoção ==")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_escala()
	_locomocao()
	_camera()

	print("\n=== Resultado: ", ok, " ok, ", fail, " falhas ===")
	if ok + fail != CONFERENCIAS_ESPERADAS:
		print("FALHOU  guarda de contagem: esperava ", CONFERENCIAS_ESPERADAS,
			" conferências, rodaram ", ok + fail)
		fail += 1
	quit(1 if fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# Decisão 1 — a escala física
# ──────────────────────────────────────────────────────────────────────────────

## A altura do asset, medida pelo Codex e registrada na RFC-007. É a razão de
## 1,60 existir; se o asset mudar, este número muda com ele.
const ALTURA_DO_ASSET_M : float = 1.600

func _escala() -> void:
	print("\n-- Decisão 1: a cápsula concorda com o personagem --")

	var t := TrainerController3D.new()
	root.add_child(t)

	_conf("a altura declarada é a do asset",
		is_equal_approx(TrainerController3D.ALTURA_DO_CORPO, ALTURA_DO_ASSET_M),
		str(TrainerController3D.ALTURA_DO_CORPO) + " m contra "
			+ str(ALTURA_DO_ASSET_M) + " m do GLB")

	# A cápsula de verdade, montada pelo `_ready`. Ler a constante provaria só
	# que eu sei escrever uma constante; o que importa é o que foi construído.
	var forma : CollisionShape3D = null
	for filho in t.get_children():
		if filho is CollisionShape3D:
			forma = filho
	_conf("existe uma cápsula de colisão", forma != null)

	var capsula : CapsuleShape3D = forma.shape as CapsuleShape3D
	_conf("a cápsula tem a altura do personagem",
		is_equal_approx(capsula.height, ALTURA_DO_ASSET_M),
		str(capsula.height) + " m")
	# Pés em Y=0 é o contrato do GLB (RFC-007). A cápsula é centrada, então o
	# centro tem de ficar na metade — senão o personagem nasce meio enterrado
	# ou meio no ar em relação ao próprio colisor.
	_conf("os pés ficam em Y=0",
		is_equal_approx(forma.position.y - capsula.height * 0.5, 0.0),
		"base em " + str(forma.position.y - capsula.height * 0.5))
	_conf("o raio NÃO mudou junto com a altura",
		is_equal_approx(capsula.radius, 0.35),
		str(capsula.radius) + " m — mudar dois de uma vez torna a regressão "
			+ "impossível de atribuir")

	t.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Decisão 2 — o estado de locomoção
# ──────────────────────────────────────────────────────────────────────────────

func _locomocao() -> void:
	print("\n-- Decisão 2: o visual lê o que o corpo FAZ --")

	var t := TrainerController3D.new()
	root.add_child(t)

	t.velocity = Vector3.ZERO
	_conf("parado é idle", t.estado_visual_de_locomocao() == "idle",
		t.estado_visual_de_locomocao())

	t.velocity = Vector3(Locomocao3D.VELOCIDADE_CAMINHADA, 0.0, 0.0)
	_conf("na velocidade de caminhada é walk",
		t.estado_visual_de_locomocao() == "walk", t.estado_visual_de_locomocao())

	t.velocity = Vector3(Locomocao3D.VELOCIDADE_CORRIDA, 0.0, 0.0)
	_conf("na velocidade de corrida é run",
		t.estado_visual_de_locomocao() == "run", t.estado_visual_de_locomocao())

	# Cair não é andar. Sem isto, uma queda livre tocaria corrida no ar.
	t.velocity = Vector3(0.0, -Locomocao3D.VELOCIDADE_TERMINAL, 0.0)
	_conf("cair não vira corrida", t.estado_visual_de_locomocao() == "idle",
		t.estado_visual_de_locomocao())

	# 🔴 O cenário que decidiu a RFC, reproduzido.
	#
	# Exaustão nível 3: `fator_de_velocidade` devolve 0,50. A velocidade que o
	# corpo persegue ao correr vira 8,0 × 0,5 = 4,0 m/s — ABAIXO dos 4,5 m/s de
	# caminhada. É o corpo andando devagar com a tecla de correr apertada.
	var fator : float = 0.50
	var alvo : Vector3 = Locomocao3D.velocidade_alvo(
		Vector2(0.0, -1.0), true, Basis.IDENTITY, fator)
	var v_correndo_exausto : float = Vector2(alvo.x, alvo.z).length()
	print("   correr exausto: ", "%.2f" % v_correndo_exausto,
		" m/s  ·  caminhar pleno: ", Locomocao3D.VELOCIDADE_CAMINHADA, " m/s")
	_conf("correr exausto é mais lento que caminhar",
		v_correndo_exausto < Locomocao3D.VELOCIDADE_CAMINHADA,
		("%.2f" % v_correndo_exausto) + " m/s — o cenário sumiu, rever a RFC")

	t.velocity = alvo
	t.quer_correr = true     # a intenção segue ligada: é esse o ponto
	_conf("o corpo exausto NÃO é animado como corrida",
		t.estado_visual_de_locomocao() != "run",
		"disse " + t.estado_visual_de_locomocao() + " — o contrato virou intenção")
	# E a prova de que a opção B da RFC teria errado aqui: ela leria
	# `quer_correr`, que continua `true`, e tocaria CORRIDA.
	_conf("a opção B (ler quer_correr) teria dito run", t.quer_correr == true,
		"o cenário não reproduz mais a divergência")

	# A fronteira: o meio do caminho entre as duas velocidades. Conferida nos
	# dois lados, porque um `>=` trocado por `>` passaria despercebido.
	var meio : float = (Locomocao3D.VELOCIDADE_CAMINHADA
		+ Locomocao3D.VELOCIDADE_CORRIDA) * 0.5
	t.quer_correr = false
	t.velocity = Vector3(meio + 0.01, 0.0, 0.0)
	_conf("logo acima do meio é run", t.estado_visual_de_locomocao() == "run")
	t.velocity = Vector3(meio - 0.01, 0.0, 0.0)
	_conf("logo abaixo do meio é walk", t.estado_visual_de_locomocao() == "walk")

	t.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Decisão 3 — a câmera
# ──────────────────────────────────────────────────────────────────────────────

func _camera() -> void:
	print("\n-- Decisão 3: o ombro acompanha por proporção --")

	# A proporção que existia antes: 1,5 m de ombro num corpo de 1,75 m.
	var proporcao_antiga : float = 1.5 / 1.75
	var esperado : float = TrainerController3D.ALTURA_DO_CORPO * proporcao_antiga
	print("   proporção preservada: ", "%.4f" % proporcao_antiga,
		"  →  ombro esperado ", "%.4f" % esperado, " m")
	_conf("o ombro preserva a proporção do corpo anterior",
		absf(CameraTerceiraPessoa.ALTURA_DO_OMBRO - esperado) < 0.005,
		str(CameraTerceiraPessoa.ALTURA_DO_OMBRO) + " m contra "
			+ ("%.4f" % esperado) + " m")
	_conf("o ombro fica abaixo do topo da cabeça",
		CameraTerceiraPessoa.ALTURA_DO_OMBRO < TrainerController3D.ALTURA_DO_CORPO)
	_conf("o ombro fica acima da cintura",
		CameraTerceiraPessoa.ALTURA_DO_OMBRO > TrainerController3D.ALTURA_DO_CORPO * 0.5)

	# A segunda cópia. Sem câmera, `origem_da_mira` cai no fallback — e ele tem
	# de sair da MESMA constante, não de um número copiado.
	var t := TrainerController3D.new()
	t.camera = null
	t.global_position = Vector3(3.0, 10.0, -7.0)
	var origem : Vector3 = t.origem_da_mira()
	_conf("o fallback da mira lê a constante da câmera",
		is_equal_approx(origem.y - t.global_position.y,
			CameraTerceiraPessoa.ALTURA_DO_OMBRO),
		"altura do fallback: " + str(origem.y - t.global_position.y))
	t.queue_free()
