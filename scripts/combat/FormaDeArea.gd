## FormaDeArea.gd — A geometria de um golpe de área.
##
## Item 20 do pedido do Gabriel: "sistema genérico de AoE". Antes de 11/09/2026
## o jogo só sabia fazer CÍRCULO — `AreaTargeting.find_targets_in_radius()` era
## a única forma existente, e todo golpe de área do jogo era um círculo, do
## Earthquake ao Surf. Um Surf que deveria varrer uma LINHA de inimigos batia
## igual pros lados.
##
## Agora a forma vem do DADO (`area_type` em `moves.json`), nunca de uma
## comparação de nome de golpe cravada no código:
##
##   single      um alvo só, o mais próximo dentro do alcance
##   circle      tudo num raio a partir do centro          (Earthquake, Blizzard)
##   cone        um leque na direção que o Pokémon olha    (Tornado)
##   line        uma faixa reta na direção da mira         (Surf)
##   rectangle   igual a `line`, com largura declarada
##   ring        anel: pega o de fora, poupa quem está colado
##   global      todo mundo na cena (reservado pra chefe)
##
## As 8 etapas que o item 20 exige acontecem todas em `alvos()`, nesta ordem:
## centro → área → detectar → filtrar aliado → limitar → (dano é de quem chama)
## → resistência (é do DamageCalculator) → nunca repetir alvo no mesmo golpe.
##
## Classe pura de propósito: a geometria é o tipo de coisa que precisa ser
## provada por teste headless, e autoload não é identificador em teste headless.
class_name FormaDeArea
extends RefCounted

## Abertura do leque do cone, em graus (o ângulo TOTAL, não a metade).
const ANGULO_DO_CONE_GRAUS : float = 70.0

## Largura padrão de uma linha/retângulo quando o golpe não declara `largura`.
## 2 tiles: larga o bastante pra pegar quem está ao lado do alvo mirado, sem
## virar um círculo disfarçado.
const LARGURA_PADRAO_PX : float = 256.0

## Fração do raio que o anel deixa livre no meio.
const FRACAO_VAZIA_DO_ANEL : float = 0.45

# ──────────────────────────────────────────────────────────────────────────────
# A porta de entrada
# ──────────────────────────────────────────────────────────────────────────────

## Quem este golpe acerta, agora.
##
## `origem`     de onde o golpe sai (a posição de quem ataca)
## `direcao`    pra onde ele aponta — só importa em cone/line/rectangle
## `golpe`      a entrada de `moves.json` (lê area_type, radius, range,
##              largura, max_targets)
## `grupos`     um nome de grupo ou uma lista deles ("wild_pokemon",
##              ["follower_pokemon","player"])
## `excluir`    quem nunca pode entrar (o próprio atacante, aliados)
##
## Devolve os alvos JÁ ordenados do mais perto pro mais longe e JÁ limitados
## por `max_targets` — quem chama só precisa aplicar o dano. A lista nunca
## repete um alvo, que é a exigência "impedir dano duplicado no mesmo cast".
static func alvos(origem: Vector2, direcao: Vector2, golpe: Dictionary,
		grupos, excluir: Array = []) -> Array:
	var forma : String = str(golpe.get("area_type", "single"))
	var raio : float = float(golpe.get("radius", 0.0))
	if raio <= 0.0:
		raio = float(golpe.get("range", CombatBalance.ALCANCE_PADRAO_TILES)) * CombatBalance.TILE_PX
	var largura : float = float(golpe.get("largura", LARGURA_PADRAO_PX))
	var teto : int = int(golpe.get("max_targets", CombatBalance.MAX_ALVOS_PADRAO))

	var dir : Vector2 = direcao.normalized() if direcao.length_squared() > 0.0 else Vector2.RIGHT

	var candidatos : Array = _candidatos(grupos, excluir)
	var dentro : Array = []
	for no in candidatos:
		if _esta_dentro(forma, origem, dir, no.global_position, raio, largura):
			dentro.append(no)

	# Mais perto primeiro: quando o teto corta, quem fica de fora é quem estava
	# na borda — é o que o jogador espera ver. Com 0 ou 1 alvo não há o que
	# ordenar, e o `sort_custom` com lambda tem custo de montagem por chamada.
	if dentro.size() > 1:
		dentro.sort_custom(func(a, b):
			return origem.distance_squared_to(a.global_position) < origem.distance_squared_to(b.global_position))

	if forma == "single":
		return dentro.slice(0, 1)
	if teto > 0 and dentro.size() > teto:
		dentro = dentro.slice(0, teto)
	return dentro

## A conta de "este ponto está dentro da forma?", isolada pra poder ser testada
## sem precisar de nó nenhum na cena.
static func _esta_dentro(forma: String, origem: Vector2, dir: Vector2, ponto: Vector2,
		raio: float, largura: float) -> bool:
	var ate : Vector2 = ponto - origem
	var dist : float = ate.length()

	match forma:
		"global":
			return true
		"circle", "single":
			return dist <= raio
		"ring":
			return dist <= raio and dist >= raio * FRACAO_VAZIA_DO_ANEL
		"cone":
			if dist > raio:
				return false
			if dist <= 1.0:
				return true   # colado no centro: sempre dentro, sem ângulo pra medir
			var graus : float = rad_to_deg(dir.angle_to(ate.normalized()))
			return absf(graus) <= ANGULO_DO_CONE_GRAUS * 0.5
		"line", "rectangle":
			var ao_longo : float = ate.dot(dir)          # quanto avançou na direção
			if ao_longo < 0.0 or ao_longo > raio:
				return false
			var de_lado : float = absf(ate.dot(Vector2(-dir.y, dir.x)))
			return de_lado <= largura * 0.5
	# Forma desconhecida vira círculo — nunca deixa um golpe sem acertar nada
	# só porque alguém escreveu errado no JSON.
	return dist <= raio

# ──────────────────────────────────────────────────────────────────────────────
# Quem entra na conta
# ──────────────────────────────────────────────────────────────────────────────

## Junta os nós dos grupos pedidos, sem repetir e sem os excluídos.
##
## Performance (item 40): o descarte grosso vem primeiro — o nó precisa ser
## Node2D —, e a conta de forma (a cara, com ângulo e produto escalar) só roda
## em quem passou. Medido com 60 selvagens vivos: ~71 us por golpe de área,
## 0,4% de um quadro a 60 FPS.
static func _candidatos(grupos, excluir: Array) -> Array:
	var lista : Array = grupos if grupos is Array else [grupos]
	var loop := Engine.get_main_loop()
	if loop == null:
		return []

	# 🔴 Medido em 11/09: a versão com `no in saida` dentro do laço era O(n²) —
	# com 60 selvagens vivos (o teto do SpawnManager) davam 3.600 comparações
	# por golpe. Duas correções, as duas óbvias depois de medir:
	#   · um nó não pode estar DUAS VEZES no mesmo grupo, então a checagem de
	#     repetido só é necessária quando há mais de um grupo;
	#   · quando é necessária, um dicionário resolve em tempo constante.
	var um_grupo_so : bool = lista.size() <= 1
	var ja_vistos : Dictionary = {}
	var saida : Array = []
	for grupo in lista:
		for no in loop.get_nodes_in_group(grupo):
			if not (no is Node2D):
				continue
			if not um_grupo_so:
				if ja_vistos.has(no):
					continue
				ja_vistos[no] = true
			if no in excluir:
				continue
			saida.append(no)
	return saida

# ──────────────────────────────────────────────────────────────────────────────
# Alcance
# ──────────────────────────────────────────────────────────────────────────────

## O alcance do golpe em pixels (item 31). `range` está em TILES no JSON
## porque é assim que o Gabriel escreveu o pedido ("Tackle: 1 tile,
## Thunderbolt: 6 tiles") — a conversão acontece aqui, num lugar só.
static func alcance_px(golpe: Dictionary) -> float:
	return float(golpe.get("range", CombatBalance.ALCANCE_PADRAO_TILES)) * CombatBalance.TILE_PX

## O alvo ainda está no alcance? Usado duas vezes: antes de começar o golpe e
## de novo quando o `cast_time` termina — se o alvo saiu correndo durante a
## conjuração, o golpe falha (item 31).
static func no_alcance(de: Vector2, alvo: Node2D, golpe: Dictionary) -> bool:
	if alvo == null or not is_instance_valid(alvo):
		return false
	return de.distance_to(alvo.global_position) <= alcance_px(golpe)
