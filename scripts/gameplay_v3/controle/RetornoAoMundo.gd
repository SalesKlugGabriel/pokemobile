## RetornoAoMundo.gd — Quem executa a volta (Fase 13).
##
## Fecha o laço:
##
## ```
## WORLD (treinador) ──encontro──> COMBAT (Pokémon) ──fim──> WORLD (treinador)
## ```
##
## **Nenhuma regra mora aqui.** Quando voltar é de `RegraDeRetorno`; o que
## preservar na troca é de `Transferencia` (Fase 7); quem liga e desliga input é
## o `ControlModeManager`. Este nó só orquestra — e existir separado é o que
## permite provar cada decisão sem subir o jogo.
##
## ── As duas voltas, e por que são diferentes ────────────────────────────────
##
## **Forçada:** o Pokémon caiu. Não é escolha, é consequência (§4), e deixa o
## treinador **vulnerável** — sem ninguém fora da ball.
##
## **Por vontade:** o jogador aperta `T`. E tem uma condição que não é burocracia:
## **com hostil por perto, não sai.** Sem ela, o corpo do treinador viraria saída
## de emergência — cinco mobs em cima, aperta a tecla, o perigo evapora. Ver o
## porquê inteiro em `RegraDeRetorno.pode_voltar`.
class_name RetornoAoMundo
extends Node

## Voltou. `forcada` diz se foi queda ou escolha; `vulneravel`, se o treinador
## ficou sem ninguém em pé.
signal voltou(forcada: bool, vulneravel: bool, motivo: String)

## Tentou voltar e não deu. `motivo` vem em português, pra tela mostrar.
signal recusou(motivo: String)

var treinador : Node3D = null
var pokemon : Node3D = null
var arbitro : Node = null          ## ControlModeManager
var combate : Node = null          ## Combate1v1 — opcional

## Quem pode ameaçar na hora de sair. O mundo preenche; em geral, `selvagem_v3`.
var vigiar : Callable = _vigiar_padrao

func _ready() -> void:
	if combate != null and is_instance_valid(combate) \
			and not combate.terminou.is_connected(_quando_a_batalha_termina):
		combate.terminou.connect(_quando_a_batalha_termina)

## Liga no combate depois do `_ready` — o mundo às vezes monta nesta ordem.
func escutar(c: Node) -> void:
	combate = c
	if not c.terminou.is_connected(_quando_a_batalha_termina):
		c.terminou.connect(_quando_a_batalha_termina)

# ──────────────────────────────────────────────────────────────────────────────

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("voltar_ao_treinador"):
		tentar_voltar()

## A volta por vontade. Devolve `{"pode", "motivo"}` — o mesmo formato da regra,
## pra quem chamou poder mostrar o motivo sem reinterpretar nada.
func tentar_voltar() -> Dictionary:
	var r := RegraDeRetorno.pode_voltar(
		_pokemon_vivo(), _pokemon_anunciando(), _hostis_por_perto(), _ja_e_o_treinador())
	if not bool(r["pode"]):
		recusou.emit(str(r["motivo"]))
		_anotar("não voltou: %s" % str(r["motivo"]))
		return r
	_executar(false, false, RegraDeRetorno.frase("", false))
	return r

## A volta forçada, escutando o fim da batalha.
func _quando_a_batalha_termina(resultado: String, _defensor: Node3D, _selvagem: Node3D) -> void:
	var tem_outro : bool = _tem_outro_em_pe()
	if not RegraDeRetorno.volta_forcada(resultado, tem_outro):
		# Vencer ou a briga se desfazer **não** devolvem nada: no mundo aberto o
		# jogador continua sendo o Pokémon até decidir o contrário. Forçar a volta
		# a cada vitória transformaria exploração numa sequência de transições.
		return
	var vulneravel := RegraDeRetorno.treinador_vulneravel(resultado, tem_outro)
	_executar(true, vulneravel, RegraDeRetorno.frase(resultado, true))

# ──────────────────────────────────────────────────────────────────────────────

func _executar(forcada: bool, vulneravel: bool, frase: String) -> void:
	if treinador == null or not is_instance_valid(treinador):
		return

	# O ângulo que a câmera do treinador herda. A luta gira o jogador, e
	# devolvê-lo virado pra trás é desorientação gratuita — decisão da Fase 7,
	# mantida aqui de propósito e não por acidente.
	var yaw : float = 0.0
	if pokemon != null and is_instance_valid(pokemon) and pokemon.camera != null:
		yaw = RegraDeRetorno.yaw_de_volta(pokemon.camera.yaw())

	var plano : Dictionary = Transferencia.ao_voltar(yaw)

	if pokemon != null and is_instance_valid(pokemon):
		# Volta a acompanhar o treinador — a menos que tenha caído. Um Pokémon
		# desmaiado não segue ninguém.
		var acompanhar : Node3D = treinador if (bool(plano["voltar_a_acompanhar"])
			and not pokemon.esta_derrotado()) else null
		pokemon.devolver_controle(acompanhar)
		if bool(plano["zerar_intencao_do_pokemon"]):
			pokemon.intencao = Vector2.ZERO

	if treinador.camera != null:
		treinador.camera.definir_yaw(float(plano["yaw_herdado"]))
	if arbitro != null and is_instance_valid(arbitro):
		arbitro.trocar_para(ControlModeManager.WORLD)
	else:
		treinador.ao_assumir_controle()

	_anotar(frase)
	voltou.emit(forcada, vulneravel, frase)

# ──────────────────────────────────────────────────────────────────────────────

func _ja_e_o_treinador() -> bool:
	if arbitro != null and is_instance_valid(arbitro):
		return str(arbitro.modo) == ControlModeManager.WORLD
	return pokemon == null or not pokemon.controlado_pelo_jogador

func _pokemon_vivo() -> bool:
	return pokemon != null and is_instance_valid(pokemon) and not pokemon.esta_derrotado()

func _pokemon_anunciando() -> bool:
	return pokemon != null and is_instance_valid(pokemon) and pokemon.esta_anunciando()

## §4: existe outro Pokémon em pé pra mandar? Enquanto o time não existe na V3,
## a resposta é sempre "não" — e é o que deixa a derrota **pesar**.
##
## Fica como função, e não como `false` cravado, porque o dia em que o time
## entrar (Fase 17) o conserto é aqui, num lugar só.
func _tem_outro_em_pe() -> bool:
	return false

func _hostis_por_perto() -> int:
	if pokemon == null or not is_instance_valid(pokemon):
		return 0
	var candidatos : Array = []
	for no in vigiar.call():
		if no == null or not is_instance_valid(no) or no == pokemon:
			continue
		candidatos.append({
			"posicao": no.global_position,
			"vivo": not no.esta_derrotado(),
			"hostil": bool(no.get("provocado")) or no.get("alvo_hostil") != null,
		})
	return RegraDeRetorno.contar_hostis(pokemon.global_position, candidatos)

func _vigiar_padrao() -> Array:
	return get_tree().get_nodes_in_group("selvagem_v3")

## Ver `ControlModeManager._anotar`: autoload citado direto derruba a carga da
## classe num teste `--script`.
func _anotar(texto: String) -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.anotar(texto)
