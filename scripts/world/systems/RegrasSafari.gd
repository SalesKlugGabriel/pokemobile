## RegrasSafari.gd — A Zona Safari em TEMPO REAL (06/09).
##
## Pedido direto do Gabriel: *"não quero esse modo de batalha em nenhum lugar do
## jogo, 100% player vs npc/Pokémon duelando sem turnos"*. A Zona Safari era o
## último lugar que ainda abria a tela de combate por turno — ela existia porque
## isca/pedra/bolas limitadas nunca tinham sido portadas. Aqui elas são.
##
## O que a Safari é, em qualquer versão de Pokémon: **o lugar onde você não
## luta.** Não é uma tela diferente — é uma regra diferente. Então em tempo real
## ela vira exatamente isso:
##
##   · Seu Pokémon NÃO ATACA aqui. Nem no automático, nem por botão.
##   · Você tem 30 Bolas Safari por visita, e só elas funcionam.
##   · ISCA deixa o Pokémon mais calmo (foge menos) e mais difícil de capturar.
##   · PEDRA deixa ele nervoso (foge mais) e mais fácil de capturar.
##   · Ele pode ir embora sozinho a qualquer momento — o relógio corre contra
##     você, e é isso que substitui o "turno" sem trazer o turno de volta.
##
## A tensão da Safari clássica vinha de gastar turnos decidindo entre isca e
## pedra. Aqui vem de gastar TEMPO — o Pokémon está fugindo enquanto você pensa.
## É a mesma decisão, medida por um relógio em vez de por rodadas.
class_name RegrasSafari
extends RefCounted

const ZONA              : String = "safari_zone"
const BOLAS_POR_VISITA  : int    = 30
const CHANCE_FUGA_BASE  : float  = 0.20   ## por janela de decisão (ver INTERVALO)
const INTERVALO_FUGA    : float  = 6.0    ## segundos entre cada chance de fuga

## Isca: mais fácil ficar, mais difícil capturar. Pedra: o contrário.
## Mesmos números do sistema por turno que isto substitui — a mecânica foi
## portada, não reinventada.
const ISCA_CAPTURA   : float = 0.5
const ISCA_FUGA      : float = 0.5
const PEDRA_CAPTURA  : float = 1.5
const PEDRA_FUGA     : float = 1.5

## Teto pros multiplicadores não empilharem até o absurdo (jogar 10 pedras não
## pode virar captura garantida).
const MULT_MIN : float = 0.25
const MULT_MAX : float = 4.0

# ──────────────────────────────────────────────────────────────────────────
# Estado da visita
# ──────────────────────────────────────────────────────────────────────────
static var bolas : int = BOLAS_POR_VISITA
static var _mult_captura : Dictionary = {}   ## id da instância -> multiplicador
static var _mult_fuga : Dictionary = {}

static func e_safari(zone_id: String) -> bool:
	return zone_id == ZONA

## Chamado ao entrar na zona: cada visita repõe as 30 bolas, igual ao original.
static func ao_entrar_na_zona() -> void:
	bolas = BOLAS_POR_VISITA
	_mult_captura.clear()
	_mult_fuga.clear()

static func ao_sair_da_zona() -> void:
	_mult_captura.clear()
	_mult_fuga.clear()

## Aqui não se luta. É a regra que define o lugar — consultada pelo Follower
## antes de qualquer golpe, e pelo selvagem antes de atacar.
static func pode_lutar(zone_id: String) -> bool:
	return not e_safari(zone_id)

# ──────────────────────────────────────────────────────────────────────────
# Isca e pedra
# ──────────────────────────────────────────────────────────────────────────
static func jogar_isca(alvo: Node) -> void:
	_ajustar(alvo, ISCA_CAPTURA, ISCA_FUGA)

static func jogar_pedra(alvo: Node) -> void:
	_ajustar(alvo, PEDRA_CAPTURA, PEDRA_FUGA)

static func _ajustar(alvo: Node, captura: float, fuga: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var chave := alvo.get_instance_id()
	_mult_captura[chave] = clampf(float(_mult_captura.get(chave, 1.0)) * captura, MULT_MIN, MULT_MAX)
	_mult_fuga[chave] = clampf(float(_mult_fuga.get(chave, 1.0)) * fuga, MULT_MIN, MULT_MAX)

static func mult_captura(alvo: Node) -> float:
	if alvo == null or not is_instance_valid(alvo):
		return 1.0
	return float(_mult_captura.get(alvo.get_instance_id(), 1.0))

static func mult_fuga(alvo: Node) -> float:
	if alvo == null or not is_instance_valid(alvo):
		return 1.0
	return float(_mult_fuga.get(alvo.get_instance_id(), 1.0))

## Chance de este Pokémon ir embora nesta janela.
static func chance_de_fuga(alvo: Node) -> float:
	return clampf(CHANCE_FUGA_BASE * mult_fuga(alvo), 0.0, 1.0)

static func esquecer(alvo: Node) -> void:
	if alvo == null:
		return
	var chave := alvo.get_instance_id()
	_mult_captura.erase(chave)
	_mult_fuga.erase(chave)

# ──────────────────────────────────────────────────────────────────────────
# Bolas
# ──────────────────────────────────────────────────────────────────────────
static func tem_bola() -> bool:
	return bolas > 0

static func gastar_bola() -> bool:
	if bolas <= 0:
		return false
	bolas -= 1
	return true
