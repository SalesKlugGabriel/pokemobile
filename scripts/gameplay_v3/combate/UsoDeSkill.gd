## UsoDeSkill.gd — Quando uma skill pode sair, e o que o aviso significa
## (Fase 10, §18/§21/§22).
##
## Classe pura. O estado (qual skill esfriando, qual cast no ar) vive na
## entidade; aqui ficam as **regras**, que é o que precisa ser provável sem cena.
##
## ── Por que cooldown por GOLPE e não por slot ───────────────────────────────
##
## `moves.json` já declara `cooldown` em cada golpe — de 1 s (Absorb) a 5 s
## (Gust, Surf). Guardar o esfriamento por slot faria trocar a ordem das skills
## zerar os cooldowns, o que é exploit de graça. Guardando por ID do golpe, o
## que esfria é o golpe, onde ele estiver.
##
## ── O aviso (`cast_time`) é a decisão de design desta fase ──────────────────
##
## 108 dos 192 golpes têm `cast_time = 0`, e 84 têm aviso. Um golpe com aviso
## **não resolve na hora**: ele anuncia, e resolve depois. É o que dá ao
## adversário a chance de sair — e é a diferença entre combate de ação e troca
## de cliques.
##
## **A direção é travada no INÍCIO do aviso.** Se ela fosse relida na resolução,
## o aviso não custaria nada: dava pra anunciar pra um lado e acertar pro outro,
## e ninguém conseguiria desviar de nada. A POSIÇÃO, essa sim, é a da resolução
## — quem anuncia pode andar, e o golpe sai de onde o corpo está.
class_name UsoDeSkill
extends RefCounted

## Cooldown de um golpe que não declara nenhum. Nenhum dos 192 cai aqui hoje;
## existe pra um golpe novo não nascer com cooldown zero por esquecimento.
const COOLDOWN_PADRAO : float = 2.0

static func cooldown_de(golpe: Dictionary) -> float:
	var c : float = float(golpe.get("cooldown", 0.0))
	return c if c > 0.0 else COOLDOWN_PADRAO

## Quanto tempo o golpe fica anunciado antes de resolver. Zero = instantâneo.
static func tempo_de_aviso(golpe: Dictionary) -> float:
	return maxf(0.0, float(golpe.get("cast_time", 0.0)))

static func tem_aviso(golpe: Dictionary) -> bool:
	return tempo_de_aviso(golpe) > 0.0

## Este golpe esfriou? `ultimo_uso < 0` (ou ausente) = nunca usou, e o primeiro
## uso tem de sair na hora — mesma decisão do básico.
static func pronto(agora: float, ultimo_uso: float, golpe: Dictionary) -> bool:
	if ultimo_uso < 0.0:
		return true
	return (agora - ultimo_uso) >= cooldown_de(golpe)

## Quanto falta esfriar, em segundos. A HUD pergunta isto; ela não recalcula.
static func esfriando(agora: float, ultimo_uso: float, golpe: Dictionary) -> float:
	if pronto(agora, ultimo_uso, golpe):
		return 0.0
	return maxf(0.0, cooldown_de(golpe) - (agora - ultimo_uso))

## O motivo pelo qual a skill NÃO pode sair agora, ou "" quando pode.
##
## Devolve motivo em vez de só `false` de propósito: a tela precisa dizer ao
## jogador *por que* o botão não respondeu. Botão que não faz nada e não explica
## é a mesma frustração do dano sem origem.
static func por_que_nao(agora: float, ultimo_uso: float, golpe: Dictionary,
		derrotado: bool, ja_anunciando: bool) -> String:
	if derrotado:
		return "derrotado"
	if ja_anunciando:
		return "já está usando outra skill"
	if golpe.is_empty():
		return "slot vazio"
	if not pronto(agora, ultimo_uso, golpe):
		return "esfriando (%.1f s)" % esfriando(agora, ultimo_uso, golpe)
	return ""

## O anúncio de um golpe com aviso — o que a tela precisa pra desenhar o
## telegrafe (§22) sem recalcular nada.
static func anuncio(golpe: Dictionary, origem: Vector3, direcao: Vector3,
		agora: float) -> Dictionary:
	return {
		"golpe": str(golpe.get("id", "?")),
		"nome_do_golpe": str(golpe.get("name", golpe.get("id", "?"))),
		"tipo": str(golpe.get("type", "Normal")),
		"area_type": str(golpe.get("area_type", FormaDeArea3D.SINGLE)),
		"origem": origem,
		"direcao": direcao,
		"alcance": FormaDeArea3D.alcance_em_metros(golpe),
		"raio": FormaDeArea3D.raio_em_metros(golpe),
		"largura": FormaDeArea3D.largura_em_metros(golpe),
		"comeca_em": agora,
		"resolve_em": agora + tempo_de_aviso(golpe),
		"duracao_do_aviso": tempo_de_aviso(golpe),
	}
