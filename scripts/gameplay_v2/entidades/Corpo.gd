## Corpo.gd — O cadáver que se pode saquear ou capturar (§28, §35).
##
## É o nó que faltava pra `RegrasDeCorpo` sair do papel. As regras já estavam
## escritas e provadas; ninguém as chamava.
##
## ── O que ele é, em uma frase ────────────────────────────────────────────────
##
## Uma janela de 10 a 15 segundos em que o jogador decide: pegar o loot, tentar
## a captura, ou os dois — sabendo que a captura é **uma só** e que o relógio
## está correndo.
##
## ── Por que o relógio importa mais que a chance ──────────────────────────────
##
## A tensão da §28 não está no número escondido da captura; está em ter que
## escolher **enquanto o resto da briga continua**. Um Alpha ainda vindo pra
## cima enquanto o corpo some é o momento que essa mecânica existe pra criar.
extends Node2D
class_name Corpo

signal mudou(id: int, estado: Dictionary)
signal removido(id: int, motivo: String)

var dados : Dictionary = {}
var _restante : float = 0.0
var _avisou : bool = false

## Monta o corpo a partir de quem caiu. Tudo que a captura precisa saber é
## copiado AGORA — o selvagem vai embora da cena, e depender dele seria depender
## de um nó que pode não existir mais quando o jogador clicar.
func montar(de_quem: CombatenteV2, capturavel: bool, sorteio_de_duracao: float) -> void:
	global_position = de_quem.global_position
	var esp : Dictionary = GameData.get_species(de_quem.species_id)
	_restante = RegrasDeCorpo.duracao(sorteio_de_duracao)
	dados = {
		"id": get_instance_id(),
		"species_id": de_quem.species_id,
		"nome": de_quem.nome_exibido,
		"nivel": de_quem.nivel,
		"catch_rate": int(esp.get("catch_rate", 45)),
		"shiny": false,
		"lendario": de_quem.species_id in RegrasDeLendario.ESPECIES,
		"capturavel": capturavel,
		"tentativa_usada": false,
		"restante": _restante,
		"loot": [],
	}

func _ready() -> void:
	add_to_group("corpo_v2")
	# O loot nasce junto do corpo, não no momento de pegar: se fosse sorteado na
	# hora do clique, dois cliques dariam dois resultados diferentes pro mesmo
	# cadáver — e o jogador aprenderia a clicar de novo.
	dados["loot"] = RegrasDeCorpo.loot(
		int(dados["nivel"]), not bool(dados["capturavel"]), _sorte_do_treinador(),
		[RNGManager.randf(), RNGManager.randf(), RNGManager.randf()])
	mudou.emit(int(dados["id"]), estado())

func _process(delta: float) -> void:
	_restante = maxf(0.0, _restante - delta)
	dados["restante"] = _restante

	if not _avisou and _restante <= RegrasDeCorpo.AVISO_EM:
		_avisou = true
		PonteDeFeedback.anotar("o corpo de %s vai sumir" % str(dados["nome"]))
		mudou.emit(int(dados["id"]), estado())

	if _restante <= 0.0:
		_sumir("expirou")

func _sumir(motivo: String) -> void:
	removido.emit(int(dados["id"]), motivo)
	queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# O que o jogador pode fazer
# ──────────────────────────────────────────────────────────────────────────────

## §28: uma tentativa por corpo. Devolve o resultado com motivo em português.
##
## A chance NÃO vai no retorno: ela é decidida aqui e fica aqui. Expor o número
## seria transformar a decisão em planilha, que é o oposto do que a §28 pede.
func tentar_capturar(ball: String, sorte: int = 0) -> Dictionary:
	var r : Dictionary = RegrasDeCorpo.tentar(dados, ball, RNGManager.randf(), sorte)
	if str(r.get("motivo", "")) != "" and not bool(r["pegou"]) \
			and bool(dados["tentativa_usada"]):
		# Recusa por já ter tentado / não ser capturável: não gasta nada.
		return {"pegou": false, "motivo": str(r["motivo"])}

	if not bool(RegrasDeCorpo.pode_tentar(dados)["pode"]):
		return {"pegou": false, "motivo": str(RegrasDeCorpo.pode_tentar(dados)["motivo"])}

	dados["tentativa_usada"] = true
	mudou.emit(int(dados["id"]), estado())
	PonteDeFeedback.anotar("tentou capturar %s com %s: %s"
		% [str(dados["nome"]), ball, "pegou" if bool(r["pegou"]) else "falhou"])

	if bool(r["pegou"]):
		_sumir("capturado")
		return {"pegou": true, "motivo": "", "species_id": int(dados["species_id"]),
				"nivel": int(dados["nivel"])}
	# §28: falhou, perdeu. O corpo some na hora — insistir não é uma opção.
	_sumir("fugiu")
	return {"pegou": false, "motivo": str(r["motivo"])}

## Pega UM item do chão. §35: não existe "pegar tudo"; cada item é um ato.
func pegar(indice: int) -> Dictionary:
	var loot : Array = dados["loot"]
	if indice < 0 or indice >= loot.size():
		return {}
	var item : Dictionary = loot[indice]
	loot.remove_at(indice)
	dados["loot"] = loot
	mudou.emit(int(dados["id"]), estado())
	PonteDeFeedback.anotar("pegou %s" % str(item.get("item", "?")))
	return item

# ──────────────────────────────────────────────────────────────────────────────
# Leitura
# ──────────────────────────────────────────────────────────────────────────────

## O estado pra HUD. **Sem a chance de captura**, de propósito (§28).
func estado() -> Dictionary:
	return {
		"id": int(dados["id"]),
		"nome": str(dados["nome"]),
		"nivel": int(dados["nivel"]),
		"pos": global_position,
		"segundos_restantes": _restante,
		"acabando": _restante <= RegrasDeCorpo.AVISO_EM,
		"capturavel": bool(dados["capturavel"]),
		"tentativa_usada": bool(dados["tentativa_usada"]),
		"loot": (dados["loot"] as Array).duplicate(true),
	}

func _sorte_do_treinador() -> int:
	var t := get_tree().get_nodes_in_group("treinador_v2")
	if t.is_empty():
		return 0
	var n : Node = t[0]
	return int(n.get("sorte")) if n.get("sorte") != null else 0
