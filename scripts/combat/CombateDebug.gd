## CombateDebug.gd — "Por que esse golpe deu 929 de dano?"
##
## Itens 43 e 44 do pedido do Gabriel. Antes de 11/09/2026 não existia nada que
## respondesse essa pergunta: para descobrir de onde vinha um hit-kill era
## preciso ler o código e refazer a conta na mão — foi exatamente o que tive de
## fazer na auditoria.
##
## Agora toda conta de dano passa por `DamageCalculator.detalhar()`, que
## devolve o passo a passo, e este arquivo só transforma esse passo a passo em
## texto legível. O relatório NÃO refaz a conta: ele lê o resultado da conta
## que aconteceu de verdade. É o que impede o depurador de mentir.
##
## Como ligar: `CombateDebug.ligado = true` (ou a tecla de debug, se houver).
## Desligado, o custo é uma comparação booleana por golpe.
class_name CombateDebug
extends RefCounted

## Liga/desliga a impressão. Desligado por padrão — num combate com bando de
## 5 Beedrill isso seriam dezenas de linhas por segundo.
static var ligado : bool = false

## Guarda as últimas N linhas mesmo com a impressão desligada, pra dar pra
## perguntar "o que aconteceu agora há pouco?" depois do susto.
static var historico : Array[String] = []
const HISTORICO_MAX : int = 60

## Registra um golpe. `detalhe` é o dicionário que `DamageCalculator.detalhar()`
## devolveu; `atacante`/`defensor` são só pra nomear quem é quem no texto.
static func registrar(detalhe: Dictionary, atacante: String = "?", defensor: String = "?") -> void:
	var linha := formatar(detalhe, atacante, defensor)
	historico.append(linha)
	if historico.size() > HISTORICO_MAX:
		historico.remove_at(0)
	if ligado:
		print(linha)

## O relatório completo, no formato que o Gabriel escreveu no item 44.
static func formatar(d: Dictionary, atacante: String = "?", defensor: String = "?") -> String:
	var partes : Array[String] = []
	partes.append("[%s Nv.%d] usou %s" % [atacante, int(d.get("nivel_atacante", 0)), str(d.get("golpe", "?"))])
	partes.append("  alvo            %s Nv.%d" % [defensor, int(d.get("nivel_defensor", 0))])
	partes.append("  tipo/categoria  %s / %s" % [str(d.get("tipo_do_golpe", "?")), str(d.get("categoria", "?"))])
	partes.append("  power           %d" % int(d.get("power", 0)))
	partes.append("  stat ofensiva   %d" % int(d.get("stat_ofensiva", 0)))
	partes.append("  stat defensiva  %d" % int(d.get("stat_defensiva", 0)))
	partes.append("  base            %.1f" % float(d.get("base", 0.0)))
	partes.append("  tipo            x%.2f  (%s)" % [float(d.get("mult_tipo", 1.0)), _rotulo_de_tipo(float(d.get("mult_tipo", 1.0)))])
	partes.append("  STAB            x%.2f" % float(d.get("mult_stab", 1.0)))
	partes.append("  crítico         x%.2f  (%s)" % [float(d.get("mult_critico", 1.0)), "SIM" if bool(d.get("critico", false)) else "não"])
	partes.append("  variação        x%.2f" % float(d.get("variacao", 1.0)))
	_se_diferente(partes, "habilidade", float(d.get("mult_habilidade", 1.0)))
	_se_diferente(partes, "status", float(d.get("mult_status", 1.0)))
	_se_diferente(partes, "item", float(d.get("mult_item", 1.0)))
	_se_diferente(partes, "bônus externo", float(d.get("mult_externo", 1.0)))
	_se_diferente(partes, "sinergia", float(d.get("mult_sinergia", 1.0)))
	var segurado : int = int(d.get("segurado_pelo_teto", 0))
	if segurado > 0:
		partes.append("  ⚠ TETO         seria %d, cortado pra %d (90%% da vida máxima)" % [segurado, int(d.get("final", 0))])
	partes.append("  DANO FINAL      %d" % int(d.get("final", 0)))
	return "\n".join(partes)

## Só imprime a linha se o multiplicador realmente mudou alguma coisa — um
## relatório com sete linhas "x1.00" esconde a linha que importa.
static func _se_diferente(partes: Array[String], rotulo: String, valor: float) -> void:
	if is_equal_approx(valor, 1.0):
		return
	partes.append("  %-15s x%.2f" % [rotulo, valor])

static func _rotulo_de_tipo(m: float) -> String:
	if m <= 0.0:
		return "imune"
	if m >= 4.0:
		return "fraqueza dupla"
	if m >= 2.0:
		return "super efetivo"
	if m <= 0.25:
		return "resistência dupla"
	if m <= 0.5:
		return "pouco efetivo"
	return "normal"

## As últimas linhas, pra quem quiser despejar depois de uma morte estranha.
static func despejar(quantas: int = 5) -> String:
	var de : int = maxi(0, historico.size() - quantas)
	return "\n\n".join(historico.slice(de))
