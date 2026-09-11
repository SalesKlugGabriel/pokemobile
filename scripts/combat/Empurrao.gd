## Empurrao.gd — O knockback (item 9 da Fase 2).
##
## O campo `knockback` existia em `moves.json` desde a Fase 1 e ninguém lia. Um
## Tornado que deveria jogar o inimigo pra trás batia e deixava ele no mesmo
## lugar.
##
## Três exigências do pedido, e como cada uma foi resolvida:
##
##   "respeitar colisão / paredes / água / limites do mapa"
##       O empurrão NÃO teleporta. Ele reaproveita o mesmo caminho que o
##       Pokémon já usa pra andar (`WorldManager.filtrar_velocidade` +
##       `move_and_slide`), então bater numa pedra para o empurrão ali, igual
##       a andar contra ela. Quem não tem esse caminho (um nó qualquer) é
##       simplesmente ignorado, nunca atravessado à força.
##
##   "não criar movimento físico pesado por frame"
##       Não há `_process` nem timer por entidade empurrada. O empurrão é um
##       ESTADO guardado no próprio alvo (`_empurrao_restante` /
##       `_empurrao_direcao`), consumido pelo `_physics_process` que a
##       entidade JÁ roda. Zero nó novo, zero timer novo.
##
##   "a distância deve ser configurável"
##       `knockback` em `moves.json` é medido em TILES (`knockback: 1.5` = um
##       tile e meio), igual ao `range`. A conversão acontece num lugar só.
##
## Classe pura: a regra de "quanto empurrar, e quem resiste" precisa ser
## testável headless.
class_name Empurrao
extends RefCounted

## Quanto tempo o empurrão leva pra percorrer a distância toda. Curto de
## propósito: empurrão longo tira o controle do jogador por tempo demais e
## atrapalha mais do que ajuda.
const DURACAO_SEG : float = 0.18

## Acima deste peso de defesa, o alvo resiste a parte do empurrão. Sem isso um
## Onix voaria igual a um Caterpie — e "peso" no jogo é a defesa, que é o que
## temos.
const DEFESA_DE_REFERENCIA : float = 100.0
const RESISTENCIA_MAXIMA   : float = 0.7   ## no máximo 70% do empurrão absorvido

## Quantos pixels este golpe empurra ESTE alvo.
##
## Devolve 0 quando o golpe não tem knockback — o caso mais comum, e o que
## mantém o custo em zero pra 99% dos golpes.
static func distancia_px(golpe: Dictionary, defesa_do_alvo: int = 0) -> float:
	var tiles : float = float(golpe.get("knockback", 0.0))
	if tiles <= 0.0:
		return 0.0
	var bruto : float = tiles * CombatBalance.TILE_PX
	if defesa_do_alvo <= 0:
		return bruto
	# Quanto mais duro o bicho, menos ele anda. Nunca chega a zero: mesmo o
	# mais pesado sai um pouco do lugar, senão o golpe parece não ter acertado.
	var resistencia : float = clampf(
		float(defesa_do_alvo) / DEFESA_DE_REFERENCIA * 0.5, 0.0, RESISTENCIA_MAXIMA)
	return bruto * (1.0 - resistencia)

## Empurra `alvo` pra longe de `origem`, se o golpe pedir isso.
##
## Silenciosamente não faz nada quando: o golpe não tem knockback, o alvo não
## sabe ser empurrado, ou origem e alvo estão exatamente no mesmo ponto (não há
## direção pra onde empurrar).
static func aplicar(alvo: Node, origem: Vector2, golpe: Dictionary) -> void:
	if float(golpe.get("knockback", 0.0)) <= 0.0:
		return
	if not is_instance_valid(alvo) or not (alvo is Node2D):
		return
	if not alvo.has_method("receber_empurrao"):
		return

	var direcao : Vector2 = alvo.global_position - origem
	if direcao.length_squared() <= 0.01:
		return

	var defesa : int = 0
	if alvo.has_method("get_combat_stats"):
		defesa = int(alvo.get_combat_stats().get("def", 0))
	var px : float = distancia_px(golpe, defesa)
	if px <= 0.0:
		return
	alvo.receber_empurrao(direcao.normalized(), px)
