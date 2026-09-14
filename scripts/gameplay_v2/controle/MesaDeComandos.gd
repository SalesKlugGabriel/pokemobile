## MesaDeComandos.gd — As ordens que o jogador dá ao Pokémon (§7).
##
## Pedido do Gabriel: *"O jogador controla diretamente o treinador e dá ordens
## ao Pokémon: atacar alvo, mover para posição, seguir, manter posição, recuar,
## usar skill. **Não usar fila de comandos.** Skills podem ser usadas
## simultaneamente se suas regras permitirem. Existe pequeno global command
## delay entre comandos manuais, mas ataque básico automático não usa esse
## delay."*
##
## ── A regra que define esta classe ───────────────────────────────────────────
##
## **Sem fila.** Uma ordem nova substitui a anterior na hora. É a diferença
## entre comandar um bicho e programar um robô: se o jogador manda recuar no
## meio de um avanço, ele recua — não termina de avançar primeiro.
##
## Por isso aqui não existe `Array` de comandos. Existe UMA ordem ativa, e ela
## é trocada.
##
## ── Por que o delay global existe, e por que o ataque básico escapa dele ─────
##
## Sem nenhum delay, segurar o botão vira ordem 60 vezes por segundo e o Pokémon
## fica tremendo no lugar sem nunca executar nada. O delay é curto (0,25 s): não
## dá pra sentir jogando, mas impede o tranco.
##
## O ataque básico é automático e não passa por aqui justamente pra o delay
## nunca atrasar o que o Pokémon faz sozinho — senão dar uma ordem qualquer
## faria o dano parar por um instante, sem motivo visível.
class_name MesaDeComandos
extends RefCounted

## As ordens da §7.
const SEGUIR   := "seguir"     ## padrão: anda atrás do treinador
const ATACAR   := "atacar"     ## persegue e bate no alvo
const IR       := "ir"         ## vai até um ponto e para lá
const MANTER   := "manter"     ## fica onde está, mas ainda ataca quem chegar
const RECUAR   := "recuar"     ## volta pro treinador e não engaja

const ORDENS : Array[String] = [SEGUIR, ATACAR, IR, MANTER, RECUAR]

## §7: "pequeno global command delay entre comandos manuais".
const DELAY_ENTRE_ORDENS : float = 0.25

## Ordens em que o Pokémon NÃO deve procurar briga sozinho. Recuar é uma
## retirada — um Pokémon que recua atacando não está recuando.
const ORDENS_PACIFICAS : Array[String] = [RECUAR]

var ordem : String = SEGUIR
var alvo : Node = null          ## em ATACAR
var ponto : Vector2 = Vector2.ZERO   ## em IR
var _espera : float = 0.0

## Quanto falta pra aceitar a próxima ordem manual. A HUD pode mostrar, mas a
## regra é daqui.
func segundos_ate_liberar() -> float:
	return maxf(0.0, _espera)

func pode_ordenar() -> bool:
	return _espera <= 0.0

func passo(delta: float) -> void:
	if _espera > 0.0:
		_espera = maxf(0.0, _espera - delta)

## Dá uma ordem. Devolve false se o delay ainda não passou — e nesse caso NÃO
## guarda pra depois, de propósito (§7: sem fila).
##
## `dados` leva `alvo` (em ATACAR) ou `ponto` (em IR).
func ordenar(nova: String, dados: Dictionary = {}) -> bool:
	if not nova in ORDENS:
		return false
	if not pode_ordenar():
		return false

	# Ordem sem o que ela precisa é ordem impossível: atacar sem alvo e ir sem
	# destino viram "seguir" silenciosamente em muitos jogos, e aí o jogador
	# acha que o comando não funcionou. Aqui é recusa explícita.
	if nova == ATACAR and not (dados.get("alvo") is Node):
		return false
	if nova == IR and not (dados.get("ponto") is Vector2):
		return false

	ordem = nova
	alvo  = dados.get("alvo") if nova == ATACAR else null
	ponto = dados.get("ponto") if nova == IR else Vector2.ZERO
	_espera = DELAY_ENTRE_ORDENS
	return true

## Chamada quando a ordem deixou de fazer sentido sozinha — o alvo morreu, o
## ponto foi alcançado. Volta pra SEGUIR, que é o repouso.
##
## Existe pra o Pokémon nunca ficar parado esperando uma ordem impossível: um
## Pokémon que perdeu o alvo e continua em ATACAR fica olhando pro nada.
func concluir() -> void:
	ordem = SEGUIR
	alvo = null
	ponto = Vector2.ZERO

## O alvo ainda vale? Alvo removido da cena ou desmaiado não é alvo.
func alvo_valido() -> bool:
	if ordem != ATACAR:
		return false
	if alvo == null or not is_instance_valid(alvo):
		return false
	if alvo.has_method("esta_derrotado") and alvo.esta_derrotado():
		return false
	return true

## O Pokémon pode engajar sozinho nesta ordem?
func aceita_engajar() -> bool:
	return not (ordem in ORDENS_PACIFICAS)

## Como isto aparece no recado de feedback e na HUD. Frase, não sigla — quem lê
## um relatório de bug é uma pessoa.
func descricao() -> String:
	match ordem:
		ATACAR: return "atacando %s" % (alvo.name if alvo_valido() else "um alvo que sumiu")
		IR:     return "indo até (%d, %d)" % [ponto.x, ponto.y]
		MANTER: return "mantendo posição"
		RECUAR: return "recuando"
		_:      return "seguindo o treinador"
