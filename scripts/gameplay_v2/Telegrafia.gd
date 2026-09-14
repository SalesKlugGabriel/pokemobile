## Telegrafia.gd — A geometria de um golpe, resolvida em números (§9, §10).
##
## Pedido do Gabriel (§9): *"Ataques precisam ser visíveis. Bosses devem ter
## ataques telegrafados."*
##
## Pedido do Codex (revisão da RFC-GAMEPLAY-V2): ele desenha o aviso, mas não
## quer converter tile em pixel nem escolher valor padrão de forma nenhuma —
## *"a forma desenhada precisa corresponder à geometria real, inclusive ao
## centro usado no impacto"*.
##
## ── O risco que esta classe existe pra eliminar ──────────────────────────────
##
## Se eu mandar `area_type` cru e ele resolver raio/largura/alcance do lado dele,
## a área desenhada e a área que acerta viram **duas contas diferentes**. Elas
## vão concordar no dia em que forem escritas e divergir no primeiro ajuste de
## balanceamento — e o jogador vai apanhar fora do círculo vermelho, que é o
## tipo de bug que destrói a confiança no combate inteiro.
##
## Então a resolução acontece **uma vez, aqui**, lendo os MESMOS padrões que
## `FormaDeArea.alvos()` lê. Se eles divergirem um dia, é o teste que grita.
class_name Telegrafia
extends RefCounted

## Um número que identifica este cast. A UI usa pra saber qual aviso apagar
## quando chega `golpe_encerrado` — sem id, dois casts sobrepostos ficam
## impossíveis de distinguir.
static var _proximo_id : int = 1

static func novo_id() -> int:
	_proximo_id += 1
	return _proximo_id

## Tudo que a UI precisa pra desenhar exatamente a área que vai acertar.
##
## Unidades: **pixels de mundo** e **radianos**. Nunca tiles — converter é o que
## eu não quero que ninguém faça duas vezes.
static func dados(golpe: Dictionary, origem: Vector2, direcao: Vector2,
		duracao: float, hostil: bool, autor: Node = null,
		alvo: Node = null) -> Dictionary:
	# Estes dois `get` com estes padrões são a cópia exata do que
	# `FormaDeArea.alvos()` faz. É a linha que precisa ser mantida em sincronia,
	# e `teste_telegrafia.gd` compara as duas.
	var raio : float = float(golpe.get("radius", 0.0))
	if raio <= 0.0:
		raio = float(golpe.get("range", CombatBalance.ALCANCE_PADRAO_TILES)) * CombatBalance.TILE_PX
	var largura : float = float(golpe.get("largura", FormaDeArea.LARGURA_PADRAO_PX))

	var dir : Vector2 = direcao.normalized() if direcao.length_squared() > 0.0 else Vector2.RIGHT

	return {
		"cast_id": novo_id(),
		"area_type": str(golpe.get("area_type", "single")),
		"golpe": str(golpe.get("id", "?")),
		"nome": str(golpe.get("name", golpe.get("id", "?"))),
		"tipo": str(golpe.get("type", "Normal")),
		"origem": origem,
		"direcao": dir,
		"raio": raio,
		"largura": largura,
		"comprimento": raio,      ## linha/retângulo: o alcance é o comprimento
		## Em RADIANOS, já convertido — `FormaDeArea` guarda em graus e converte
		## por dentro. Mandar graus aqui seria entregar a mesma armadilha de
		## unidade que esta classe existe pra evitar.
		"abertura": deg_to_rad(FormaDeArea.ANGULO_DO_CONE_GRAUS),
		## Anel: a fração interna vazia, pra desenhar o buraco do meio.
		"fracao_vazia": FormaDeArea.FRACAO_VAZIA_DO_ANEL,
		"duracao": duracao,
		"hostil": hostil,
		"autor_id": autor.get_instance_id() if autor != null else 0,
		"alvo_id": alvo.get_instance_id() if alvo != null else 0,
	}
