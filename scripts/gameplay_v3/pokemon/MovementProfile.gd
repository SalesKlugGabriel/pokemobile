## MovementProfile.gd — Como um Pokémon se move (§15).
##
## Os arquétipos que o pedido lista: `GROUND_BIPED`, `GROUND_QUADRUPED`,
## `GROUND_HEAVY`, `SERPENTINE`, `FLYING`, `AQUATIC`, `AMPHIBIOUS`, `HOVERING`.
##
## ── A instrução que define este arquivo ─────────────────────────────────────
##
## *"Não implementar todos agora. Criar arquitetura que permita adicionar.
## Primeiro implementar apenas GROUND. Depois AQUATIC. Depois FLYING."*
##
## Então os oito **existem como dado** e três **funcionam**. Um arquétipo que
## ainda não funciona cai no terrestre e **avisa** — nunca finge que funciona,
## que é como um Gyarados sairia andando no chão sem ninguém entender por quê.
##
## ── Por que perfil, e não subclasse por espécie ─────────────────────────────
##
## §14: *"Não colocar comportamento inteiro dentro de scripts específicos de
## espécie."* Um `Charizard.gd` seria 151 arquivos que divergem sozinhos. Aqui a
## espécie **escolhe** um perfil, e o perfil é dado — trocar Charizard de
## terrestre pra voador é mudar uma linha de JSON, não escrever classe nova.
class_name MovementProfile
extends RefCounted

const GROUND_BIPED     := "ground_biped"
const GROUND_QUADRUPED := "ground_quadruped"
const GROUND_HEAVY     := "ground_heavy"
const SERPENTINE       := "serpentine"
const FLYING           := "flying"
const AQUATIC          := "aquatic"
const AMPHIBIOUS       := "amphibious"
const HOVERING         := "hovering"

const TODOS : Array[String] = [GROUND_BIPED, GROUND_QUADRUPED, GROUND_HEAVY,
	SERPENTINE, FLYING, AQUATIC, AMPHIBIOUS, HOVERING]

## Os que já se movem de verdade. A lista é curta de propósito (§15).
const IMPLEMENTADOS : Array[String] = [GROUND_BIPED, GROUND_QUADRUPED,
	GROUND_HEAVY, AQUATIC, FLYING]

## Os números de cada arquétipo. `velocidade` é um MULTIPLICADOR sobre a
## velocidade derivada do Speed da espécie — o perfil diz o *jeito* de andar, e
## a stat diz o *quanto*. Misturar os dois faria um Onix rápido andar como um
## Rattata rápido.
const PERFIS : Dictionary = {
	GROUND_BIPED:     {"velocidade": 1.00, "giro": 540.0, "voa": false, "nada": false, "gravidade": 1.0},
	GROUND_QUADRUPED: {"velocidade": 1.15, "giro": 420.0, "voa": false, "nada": false, "gravidade": 1.0},
	# Pesado: mais lento e vira devagar. É o que faz um Snorlax PARECER pesado
	# sem precisar de animação — peso se lê no controle antes de se ver.
	GROUND_HEAVY:     {"velocidade": 0.75, "giro": 220.0, "voa": false, "nada": false, "gravidade": 1.2},
	SERPENTINE:       {"velocidade": 0.95, "giro": 300.0, "voa": false, "nada": false, "gravidade": 1.0},
	FLYING:           {"velocidade": 1.30, "giro": 480.0, "voa": true,  "nada": true,  "gravidade": 0.0},
	AQUATIC:          {"velocidade": 1.10, "giro": 380.0, "voa": false, "nada": true,  "gravidade": 0.35},
	AMPHIBIOUS:       {"velocidade": 1.00, "giro": 440.0, "voa": false, "nada": true,  "gravidade": 1.0},
	HOVERING:         {"velocidade": 1.05, "giro": 600.0, "voa": true,  "nada": true,  "gravidade": 0.0},
}

## §6: *"Pokémon gigantes continuam visualmente grandes; podem receber
## compressão inteligente de escala para não destruir câmera, colisão e
## navegação."*
##
## Onix tem 8,8 m de verdade. Sem compressão, ele não passa por lugar nenhum do
## laboratório e a câmera de 1ª pessoa fica a 9 m do chão. Comprimir acima de
## 3 m preserva "é enorme" e devolve "dá pra jogar".
const ALTURA_SEM_COMPRESSAO : float = 3.0
const COMPRESSAO : float = 0.45

static func altura_jogavel(altura_real: float) -> float:
	if altura_real <= ALTURA_SEM_COMPRESSAO:
		return altura_real
	return ALTURA_SEM_COMPRESSAO + (altura_real - ALTURA_SEM_COMPRESSAO) * COMPRESSAO

## O perfil, sempre com resposta. Arquétipo desconhecido ou ainda não
## implementado cai no bípede **e avisa** — silêncio aqui é um Gyarados andando.
static func obter(nome: String) -> Dictionary:
	if nome in IMPLEMENTADOS:
		return PERFIS[nome]
	if nome in TODOS:
		push_warning("arquétipo '%s' ainda não implementado (§15); usando %s"
			% [nome, GROUND_BIPED])
	elif nome != "":
		push_warning("arquétipo desconhecido: '%s'" % nome)
	return PERFIS[GROUND_BIPED]

static func implementado(nome: String) -> bool:
	return nome in IMPLEMENTADOS

## Velocidade em m/s, do perfil e do Speed da espécie.
##
## O peso do Speed é baixo (0,35) pelo mesmo motivo da V2: velocidade importa,
## mas se ela dominasse, escolher time viraria "pegue o mais rápido".
const VELOCIDADE_BASE : float = 5.5

static func velocidade(nome: String, speed_stat: int) -> float:
	var p := obter(nome)
	var por_stat : float = 1.0 + (float(speed_stat) - 50.0) / 100.0 * 0.35
	return VELOCIDADE_BASE * float(p["velocidade"]) * maxf(0.2, por_stat)

## Este arquétipo entra na água? (§27)
static func nada(nome: String) -> bool:
	return bool(obter(nome)["nada"])

static func voa(nome: String) -> bool:
	return bool(obter(nome)["voa"])

## Quanto da gravidade age nele. Voador não cai; aquático afunda devagar.
static func gravidade(nome: String) -> float:
	return float(obter(nome)["gravidade"])
