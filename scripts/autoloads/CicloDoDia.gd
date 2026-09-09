## CicloDoDia.gd — ciclo de dia e noite (09/09/2026, primeiro item da lista de
## imersão pedida pelo Gabriel depois do tutorial). Não é ligado ao relógio
## do sistema (como os jogos Pokémon antigos faziam) — é um ciclo PRÓPRIO do
## jogo, contínuo, que não depende de que horas são no mundo real: mais
## previsível pra testar e pra jogar em qualquer horário sem "perder" o dia.
##
## Só afeta o MUNDO ABERTO (WorldMap.tscn, via BaseMap.ciclo_dia_noite = true
## no próprio .tscn) — dungeon/interior tem luz própria, não muda com o
## relógio de fora. Tingimento por CanvasModulate (nó do próprio Godot feito
## pra isso: multiplica a cor de tudo que está no mesmo Node2D/CanvasLayer,
## sem precisar tocar em nenhum sprite) — a HUD fica numa CanvasLayer
## separada, então não escurece com a noite.
extends Node

## 1 dia de jogo = 18 minutos reais. Escolha arbitrária (não existe "correto"
## aqui) — rápido o bastante pra o jogador VER o ciclo numa sessão de jogo
## normal, devagar o bastante pra não virar estroboscópio.
const SEGUNDOS_POR_DIA : float = 18.0 * 60.0

# Cada parada é (hora, cor). Interpolado linearmente entre as duas mais
# próximas. Hora 0 = meia-noite, 12 = meio-dia.
const PARADAS := [
	[0.0,  Color(0.22, 0.24, 0.42)],   # madrugada — azul escuro
	[5.0,  Color(0.35, 0.32, 0.45)],   # começo do amanhecer
	[6.5,  Color(0.85, 0.65, 0.55)],   # amanhecer — rosa/laranja suave
	[8.0,  Color(1.0, 1.0, 1.0)],      # manhã — sem tingimento
	[17.0, Color(1.0, 1.0, 1.0)],      # tarde — sem tingimento
	[18.5, Color(0.95, 0.55, 0.35)],   # entardecer — laranja
	[20.0, Color(0.35, 0.32, 0.5)],    # começo da noite
	[21.5, Color(0.22, 0.24, 0.42)],   # noite fechada
	[24.0, Color(0.22, 0.24, 0.42)],   # meia-noite de novo (fecha o ciclo)
]

var _tempo_acumulado_seg : float = 0.0
var _periodo_atual : String = ""
var _modulate_atual : CanvasModulate = null

func _process(delta: float) -> void:
	_tempo_acumulado_seg = fmod(_tempo_acumulado_seg + delta, SEGUNDOS_POR_DIA)
	if _modulate_atual and is_instance_valid(_modulate_atual):
		_modulate_atual.color = _cor_para_hora(hora_atual())
	_atualizar_periodo()

func hora_atual() -> float:
	return (_tempo_acumulado_seg / SEGUNDOS_POR_DIA) * 24.0

func _cor_para_hora(hora: float) -> Color:
	for i in range(PARADAS.size() - 1):
		var h1 : float = PARADAS[i][0]
		var h2 : float = PARADAS[i + 1][0]
		if hora >= h1 and hora <= h2:
			var t : float = 0.0 if h2 == h1 else (hora - h1) / (h2 - h1)
			return PARADAS[i][1].lerp(PARADAS[i + 1][1], t)
	return Color(1, 1, 1)

func periodo_de(hora: float) -> String:
	if hora < 5.0 or hora >= 21.5:
		return "noite"
	if hora < 8.0:
		return "amanhecer"
	if hora < 18.5:
		return "dia"
	return "entardecer"

func _atualizar_periodo() -> void:
	var novo := periodo_de(hora_atual())
	if novo != _periodo_atual:
		_periodo_atual = novo
		EventBus.periodo_do_dia_mudou.emit(novo)

## Chamado por BaseMap._ready()/_exit_tree() do mapa que tem
## `ciclo_dia_noite = true` — só um mapa está carregado por vez, então um
## único ponteiro basta (sem lista, sem gerente de múltiplos mapas).
func registrar_modulate(modulate: CanvasModulate) -> void:
	_modulate_atual = modulate
	if _modulate_atual:
		_modulate_atual.color = _cor_para_hora(hora_atual())

func desregistrar_modulate(modulate: CanvasModulate) -> void:
	if _modulate_atual == modulate:
		_modulate_atual = null
