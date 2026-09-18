## ControlModeManager.gd — Quem recebe o input, agora (§12).
##
## Pedido do Gabriel, literal:
##
##   *"Nunca permitir dois controladores processarem input principal
##   simultaneamente."*
##
## ── Por que isto vem ANTES de qualquer controlador ──────────────────────────
##
## A fantasia da V3 é trocar de corpo no meio do jogo: treinador → Pokémon →
## treinador. Toda troca de corpo é uma troca de dono do input, e é exatamente
## aí que nasce o bug clássico: o treinador continua ouvindo o WASD enquanto o
## Pokémon também ouve, e o jogador vê os dois se mexerem.
##
## Construir os controladores primeiro e o árbitro depois seria fazer esse bug
## acontecer antes de ter como evitá-lo.
##
## ── A decisão que importa: desligar, não ignorar ────────────────────────────
##
## O jeito fácil seria cada controlador começar com `if modo != meu: return`.
## Funciona até alguém esquecer o `return` num caminho novo — e aí o bug volta,
## silencioso, meses depois.
##
## Aqui o controlador que não está ativo tem `set_process_input(false)` e
## `set_process_unhandled_input(false)`. **Ele não recebe o evento.** Não
## depende de ninguém lembrar de checar.
class_name ControlModeManager
extends Node

signal modo_mudou(anterior: String, novo: String)

const WORLD  := "world"    ## treinador, 3ª pessoa
const COMBAT := "combat"   ## Pokémon, 1ª pessoa
const SURF   := "surf"
const FLY    := "fly"

const MODOS : Array[String] = [WORLD, COMBAT, SURF, FLY]

var modo : String = WORLD

## nome do modo → o nó controlador. Registrado por quem monta a cena.
var _controladores : Dictionary = {}

## Registra o controlador de um modo. Registrar não ativa: quem ativa é
## `trocar_para()`, e todo registro nasce desligado.
func registrar(nome_do_modo: String, controlador: Node) -> void:
	if not nome_do_modo in MODOS:
		push_warning("modo desconhecido: %s" % nome_do_modo)
		return
	_controladores[nome_do_modo] = controlador
	_desligar(controlador)
	if nome_do_modo == modo:
		_ligar(controlador)

func controlador_ativo() -> Node:
	return _controladores.get(modo)

## Troca de modo. Devolve false se o modo não existe ou já é o atual.
##
## A ordem aqui não é decorativa: **desliga todo mundo primeiro, liga o novo
## depois.** Ligar antes de desligar deixa uma janela de um quadro com dois
## donos do input — e um quadro basta pra um passo duplo aparecer na tela.
func trocar_para(novo: String) -> bool:
	if not novo in MODOS or novo == modo:
		return false
	var anterior := modo
	for nome in _controladores.keys():
		_desligar(_controladores[nome])
	modo = novo
	var c : Node = _controladores.get(novo)
	if c != null:
		_ligar(c)
	_anotar("modo de controle: %s → %s" % [anterior, novo])
	modo_mudou.emit(anterior, novo)
	return true

func _ligar(c: Node) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.set_process_input(true)
	c.set_process_unhandled_input(true)
	c.set_physics_process(true)
	if c.has_method("ao_assumir_controle"):
		c.ao_assumir_controle()

func _desligar(c: Node) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.set_process_input(false)
	c.set_process_unhandled_input(false)
	# A física continua rodando de propósito: o treinador ainda cai, ainda é
	# empurrado e ainda existe no mundo enquanto o jogador está no Pokémon
	# (§17: "o treinador permanece no mundo"). O que ele perde é a VONTADE.
	if c.has_method("ao_perder_controle"):
		c.ao_perder_controle()

## Quantos controladores estão recebendo input agora. Existe pro teste poder
## provar a regra da §12 — e a resposta certa é sempre 0 ou 1.
func quantos_ativos() -> int:
	var n : int = 0
	for nome in _controladores.keys():
		var c : Node = _controladores[nome]
		if c != null and is_instance_valid(c) and c.is_processing_input():
			n += 1
	return n

## Recado pra linha do tempo do feedback, resolvido em tempo de CHAMADA.
##
## 🔴 Citar `PonteDeFeedback` direto quebra a carga deste script num teste
## `--script`: autoload não é identificador ali, e o erro de compilação derruba
## a classe inteira — `ControlModeManager.new()` passa a responder "função
## inexistente". Mesma lição do `RNGManager` na Fase 11, em outro autoload.
func _anotar(texto: String) -> void:
	var ponte := get_node_or_null("/root/PonteDeFeedback")
	if ponte != null:
		ponte.anotar(texto)
