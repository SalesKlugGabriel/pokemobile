## CutsceneLendario.gd — entrada curta ao encontrar o lendário do covil (09/09,
## item da lista de imersão: "cutscene de entrada de lendário"). Chamado direto
## de `NinhoLendario.povoar()`, no mesmo instante que já emitia
## `EventBus.legendary_encountered` sem ninguém escutar — sistema-fachada
## clássico deste projeto (sinal existia, zero listener).
##
## Sem cena nova, sem arte nova: trava o jogador por um instante (mesmo
## lock_input()/unlock_input() que diálogo já usa), a câmera empurra um pouco
## pra perto (Camera2D.zoom sobe e volta, igual TrainerEntity._ajustar_camera()
## já configura o padrão), um aviso no HUD (EventBus.notification_requested,
## a mesma barra de toast do tutorial) e o jingle "encounter" que todo
## selvagem já usa. ~1,6s do toque ao jogador recuperar o controle.
class_name CutsceneLendario
extends RefCounted

const FATOR_ZOOM_PERTO : float = 1.35
const DURACAO_APROXIMAR : float = 0.45
const DURACAO_SEGURAR   : float = 0.7
const DURACAO_AFASTAR   : float = 0.45

## `mapa` é o BaseMap que acabou de nascer (self, de dentro de _ready()) —
## tipado Node aqui só pra não criar dependência circular de class_name, o
## mesmo motivo por trás de `NinhoLendario.povoar(mapa: Node, ...)`. Devolve
## o Tween criado (ou null) só pra dar pro teste headless algo síncrono pra
## conferir — em produção, ninguém usa o retorno.
static func tocar(mapa: Node, nome: String) -> Tween:
	if mapa == null or not ("player" in mapa):
		return null
	var jogador = mapa.player
	if jogador == null or not is_instance_valid(jogador):
		return null

	if jogador.has_method("lock_input"):
		jogador.lock_input()

	var raiz = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var barramento = raiz.get_node_or_null("EventBus") if raiz else null
	var audio = raiz.get_node_or_null("AudioManager") if raiz else null
	if barramento != null:
		barramento.notification_requested.emit("Um %s selvagem desperta..." % nome)
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("encounter")

	var cam : Camera2D = jogador.get_node_or_null("Camera2D") as Camera2D
	var destravar := func():
		if jogador and is_instance_valid(jogador) and jogador.has_method("unlock_input"):
			jogador.unlock_input()

	if cam == null:
		# Sem câmera achável: não deixa o jogador travado esperando um tween
		# que nunca vai rodar.
		destravar.call()
		return null

	var zoom_normal : Vector2 = cam.zoom
	var zoom_perto : Vector2 = zoom_normal * FATOR_ZOOM_PERTO
	var tw : Tween = jogador.create_tween()
	tw.tween_property(cam, "zoom", zoom_perto, DURACAO_APROXIMAR)
	tw.tween_interval(DURACAO_SEGURAR)
	tw.tween_property(cam, "zoom", zoom_normal, DURACAO_AFASTAR)
	tw.tween_callback(destravar)
	return tw
