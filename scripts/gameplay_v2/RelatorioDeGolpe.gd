## RelatorioDeGolpe.gd — O que aconteceu, em dado, pra a tela poder contar.
##
## Pedido do Gabriel (14/09):
##
##   *"tem golpe que pode dar até 4x de dano e isso simplesmente baixar a barra
##   de HP sem nenhum feedback visual vai frustrar muito a gameplay"*
##
## ── O buraco, exato ──────────────────────────────────────────────────────────
##
## O sinal que a apresentação escuta hoje é:
##
##     damage_dealt(target, amount, is_critical, attacker)
##
## Ele não diz **qual golpe**, **de que tipo**, nem **se foi super-efetivo**. A
## única coisa que o `FeedbackDeImpacto` consegue deduzir é a fração da vida —
## por isso um 4× e um golpe neutro grande produzem exatamente a mesma coisa na
## tela. Não é falta de capricho da apresentação: **a informação nunca chegava
## lá**.
##
## ── O que muda, e o que NÃO muda ─────────────────────────────────────────────
##
## `damage_dealt` fica como está (contrato aceito na D-001 — o Codex pediu pra
## preservar a assinatura). Este relatório vai num sinal **novo**, ao lado.
##
## E ele é só DADO. A escolha de cor, tamanho do número, tremor, congelamento
## de quadro, partícula — tudo isso é do Codex. Eu digo *o que aconteceu*; ele
## decide *como se vê*.
class_name RelatorioDeGolpe
extends RefCounted

## Os degraus de efetividade, com nome. Existe pra a tela não precisar comparar
## `float` com `0.25` e acertar o arredondamento: quem sabe classificar é quem
## calculou.
const IMUNE          := "imune"            ## 0×
const MUITO_FRACO    := "muito_fraco"      ## 0,25×
const FRACO          := "fraco"            ## 0,5×
const NEUTRO         := "neutro"           ## 1×
const FORTE          := "forte"            ## 2×
const MUITO_FORTE    := "muito_forte"      ## 4×

## Classifica o multiplicador de tipo. As faixas são generosas de propósito:
## um Held pode empurrar 2× pra 2,2× (§46), e isso continua sendo "forte".
static func classificar(mult: float) -> String:
	if mult <= 0.0:
		return IMUNE
	if mult < 0.4:
		return MUITO_FRACO
	if mult < 0.9:
		return FRACO
	if mult < 1.6:
		return NEUTRO
	if mult < 3.0:
		return FORTE
	return MUITO_FORTE

## A frase pro jogador. É o texto que explica de onde veio o dano — e é o
## motivo deste arquivo existir.
static func frase(efetividade: String) -> String:
	match efetividade:
		IMUNE:       return "Não afeta!"
		MUITO_FRACO: return "Quase não machuca..."
		FRACO:       return "Pouco eficaz..."
		FORTE:       return "É super eficaz!"
		MUITO_FORTE: return "É devastador!"
		_:           return ""

## Monta o relatório de um acerto.
##
## Tudo em unidades de mundo e números prontos: a tela não converte, não
## recalcula e não classifica nada por conta própria (AGENTS.md).
static func montar(golpe: Dictionary, atacante: Node2D, alvo: Node2D,
		dano: int, detalhe: Dictionary, vida_depois: int, vida_maxima: int) -> Dictionary:
	var origem : Vector2 = atacante.global_position if atacante != null else Vector2.ZERO
	var destino : Vector2 = alvo.global_position if alvo != null else Vector2.ZERO
	var direcao : Vector2 = (destino - origem).normalized() if destino != origem else Vector2.RIGHT
	var r := _significado(golpe, atacante, alvo, dano, detalhe, vida_depois, vida_maxima)
	r["origem"] = origem
	r["destino"] = destino
	r["direcao"] = direcao
	return r

## A mesma coisa em 3D (Fase 9 da V3). Só a geometria muda — `Vector3` em vez de
## `Vector2`; tipo, efetividade, frase e fração da vida são idênticos, e é por
## isso que as duas versões dividem `_significado`.
##
## ⚠️ Duas cópias do dicionário inteiro era o caminho fácil aqui, e seria a
## receita pra a V2 e a V3 discordarem sobre o que "muito_forte" quer dizer no
## primeiro ajuste que alguém fizesse num dos lados.
static func montar_3d(golpe: Dictionary, atacante: Node3D, alvo: Node3D,
		dano: int, detalhe: Dictionary, vida_depois: int, vida_maxima: int) -> Dictionary:
	var origem : Vector3 = atacante.global_position if atacante != null else Vector3.ZERO
	var destino : Vector3 = alvo.global_position if alvo != null else Vector3.ZERO
	var direcao : Vector3 = (destino - origem).normalized() if destino != origem else Vector3.FORWARD
	var r := _significado(golpe, atacante, alvo, dano, detalhe, vida_depois, vida_maxima)
	r["origem"] = origem
	r["destino"] = destino
	r["direcao"] = direcao
	return r

## Tudo que NÃO depende de o mundo ser 2D ou 3D.
static func _significado(golpe: Dictionary, atacante: Node, alvo: Node,
		dano: int, detalhe: Dictionary, vida_depois: int, vida_maxima: int) -> Dictionary:
	var mult : float = float(detalhe.get("mult_tipo", 1.0))
	var efet := classificar(mult)

	return {
		# Quem e o quê
		"golpe": str(golpe.get("id", "?")),
		"nome_do_golpe": str(golpe.get("name", golpe.get("id", "?"))),
		"tipo": str(golpe.get("type", "Normal")),
		"categoria": str(golpe.get("category", "physical")),
		"area_type": str(golpe.get("area_type", "single")),
		"contato": bool(golpe.get("contact", false)),
		"atacante_id": atacante.get_instance_id() if atacante != null else 0,
		"alvo_id": alvo.get_instance_id() if alvo != null else 0,

		# Quanto, e o que isso significa
		"dano": dano,
		"fracao_da_vida": (float(dano) / float(vida_maxima)) if vida_maxima > 0 else 0.0,
		"vida_depois": vida_depois,
		"vida_maxima": vida_maxima,
		"mult_tipo": mult,
		"efetividade": efet,
		"frase": frase(efet),
		"stab": float(detalhe.get("mult_stab", 1.0)) > 1.0,
		"derrotou": vida_depois <= 0,

		# Quanto tempo a tela tem pra mostrar. Golpe instantâneo não tem janela
		# ANTES — então a leitura precisa acontecer toda no impacto.
		"teve_aviso": float(golpe.get("cast_time", 0.0)) > 0.0,
	}

## O relatório de um STATUS aplicado. Um Pokémon que fica paralisado e não sabe
## por quê é a mesma frustração do dano sem origem, em outra forma.
static func de_status(nome_do_status: String, golpe: Dictionary,
		atacante: Node2D, alvo: Node2D) -> Dictionary:
	return {
		"status": nome_do_status,
		"golpe": str(golpe.get("id", "?")),
		"nome_do_golpe": str(golpe.get("name", golpe.get("id", "?"))),
		"tipo": str(golpe.get("type", "Normal")),
		"atacante_id": atacante.get_instance_id() if atacante != null else 0,
		"alvo_id": alvo.get_instance_id() if alvo != null else 0,
		"origem": atacante.global_position if atacante != null else Vector2.ZERO,
		"destino": alvo.global_position if alvo != null else Vector2.ZERO,
	}
