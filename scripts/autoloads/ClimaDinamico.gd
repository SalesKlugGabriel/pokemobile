## ClimaDinamico.gd — clima dinâmico no mundo aberto (09/09, item da lista de
## imersão "clima dinâmico"). Autoload, mesmo molde do CicloDoDia.gd: guarda
## só o ESTADO (chovendo ou não) e o relógio de troca; quem desenha é
## ChuvaOverlay.gd, registrado/desregistrado por BaseMap igual o
## CanvasModulate do dia/noite já faz.
##
## Por que só chuva por enquanto: "clima dinâmico" foi pedido de forma
## genérica, mas sol/nublado não mudam nada visível além do que o ciclo de
## dia/noite já cobre — chuva é o primeiro estado que faz diferença real na
## tela sem precisar de asset novo (partícula usa o quad branco padrão do
## motor). Sol forte/nublado ficam fáceis de somar depois (mesmo `enum`).
extends Node

signal clima_mudou(chovendo: bool)

const MIN_SEGUNDOS_LIMPO : float = 90.0
const MAX_SEGUNDOS_LIMPO : float = 240.0
const MIN_SEGUNDOS_CHUVA : float = 60.0
const MAX_SEGUNDOS_CHUVA : float = 150.0

var chovendo : bool = false
var _tempo_restante : float = 0.0
## Só avança o relógio (e só existe visualmente) enquanto o jogador está no
## mundo aberto — igual ao CicloDoDia, dungeon/interior não tem céu.
var _ativo : bool = false

func _ready() -> void:
	_sortear_proxima_troca()

func _process(delta: float) -> void:
	if not _ativo:
		return
	_tempo_restante -= delta
	if _tempo_restante <= 0.0:
		chovendo = not chovendo
		_sortear_proxima_troca()
		clima_mudou.emit(chovendo)

func _sortear_proxima_troca() -> void:
	if chovendo:
		_tempo_restante = randf_range(MIN_SEGUNDOS_CHUVA, MAX_SEGUNDOS_CHUVA)
	else:
		_tempo_restante = randf_range(MIN_SEGUNDOS_LIMPO, MAX_SEGUNDOS_LIMPO)

## Chamado por BaseMap ao entrar/sair do mundo aberto. Sair sempre volta pro
## limpo — ninguém quer voltar de uma dungeon e a chuva "continuar" tocando
## sem o overlay pra mostrar.
func ativar(ativo: bool) -> void:
	_ativo = ativo
	if not ativo and chovendo:
		chovendo = false
		clima_mudou.emit(false)
