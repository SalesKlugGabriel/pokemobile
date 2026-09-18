## RegraDeTravessia.gd — Onde cada corpo pode ir (Fases 14 e 15).
##
## Classe pura. Quem executa é o controlador do Pokémon; aqui só se decide.
##
## ── O princípio, e ele decide o desenho inteiro ─────────────────────────────
##
## §27: **travessia é movimento, não teletransporte.** Entrar na água precisa ser
## uma mudança de *como o corpo se move*, não uma tela de carregamento com outro
## tileset.
##
## Na V3 isso ganha uma consequência elegante que a V2 não tinha: **surfar é
## assumir um Pokémon que nada.** Não existe "o treinador em cima de um bicho" —
## existe o jogador *sendo* o bicho, com o `MovementProfile` dele. A mesma
## transferência da Fase 7, o mesmo corpo, as mesmas regras. Voar é o mesmo, com
## o arquétipo `FLYING`.
##
## Então esta classe não inventa modo de locomoção nenhum: ela responde **quem
## pode estar onde**, e deixa o resto pro perfil que já existe.
class_name RegraDeTravessia
extends RefCounted

# ── O que o terreno diz (`Terreno3D.superficie_em`) ──────────────────────────

const TERRA          := "terra"
const AREIA          := "areia"
const ROCHA          := "rocha"
const AGUA_RASA      := "agua_rasa"
const AGUA_PROFUNDA  := "agua_profunda"

const SUPERFICIES_DE_AGUA : Array[String] = [AGUA_RASA, AGUA_PROFUNDA]

static func e_agua(superficie: String) -> bool:
	return superficie in SUPERFICIES_DE_AGUA

# ──────────────────────────────────────────────────────────────────────────────
# Fase 14 — água
# ──────────────────────────────────────────────────────────────────────────────

## Este corpo pode estar nesta superfície?
##
## ── As três respostas, e o porquê de cada uma ──────────────────────────────
##
## **Terrestre em água rasa: pode.** Andar com água no joelho é normal, e barrar
## isso criaria uma parede invisível exatamente na borda da praia — o lugar onde
## o jogador mais anda.
##
## **Terrestre em água profunda: não.** É o limite que dá sentido ao Surf. Sem
## ele, a água deixa de ser obstáculo e a travessia vira enfeite.
##
## **Quem nada: vai a qualquer lugar molhado.** E também em terra — `nada` não é
## o mesmo que "só serve pra água"; o anfíbio existe justamente pra isso.
##
## ⚠️ O voador **também passa** por cima de água profunda, e isso não é exceção:
## ele não está *na* água, está acima dela. Tratar voo como caso de água foi a
## primeira coisa que eu escrevi errado aqui.
static func pode_estar_em(arquetipo: String, superficie: String) -> bool:
	if not e_agua(superficie):
		return true
	var p := MovementProfile.obter(arquetipo)
	if bool(p.get("voa", false)):
		return true
	if superficie == AGUA_RASA:
		return true
	return bool(p.get("nada", false))

## Precisa de Surf pra atravessar daqui pra lá?
##
## É a pergunta que a tela faz pra mostrar "você precisa de um Pokémon que nade".
static func precisa_de_surf(arquetipo: String, superficie_de_destino: String) -> bool:
	return superficie_de_destino == AGUA_PROFUNDA \
		and not pode_estar_em(arquetipo, AGUA_PROFUNDA)

## Qual profundidade de mergulho corresponde a esta altura de terreno?
##
## 🔴 **A lição de 14/09, carregada de propósito.** A versão 2D lia
## `GameData.zones` — uma propriedade que **nunca existiu**. O abismo cobrava
## oxigênio de água rasa, e ninguém viu por três dias, porque não dava erro: só
## devolvia o padrão.
##
## Aqui a profundidade sai da **altura do terreno**, que é a fonte única de
## verdade da geografia (`Terreno3D.altura_em`) — o mesmo número que desenha o
## chão e resolve a colisão. Não há segunda fonte pra divergir.
##
## 🔴 **E os degraus saem do TERRENO, não de números inventados.** Na primeira
## versão eu cravei −4 m e −12 m. Medi depois: o terreno vai a **−7,27 m** no
## ponto mais fundo, e ele mesmo considera água profunda a partir de **−1,5 m**
## (`AGUA_RASA_ATE`). Ou seja, o abismo era **inalcançável** e quase tudo caía
## em "meio" — duas definições de "fundo" discordando, que é a mesma classe de
## erro do bug que esta função existe pra não repetir.
##
## Agora: raso até onde o terreno chama de raso; o que sobra se divide em meio e
## abismo. Os parâmetros continuam existindo pra a regra ser testável sem o
## terreno e pro dia em que uma zona tiver mar próprio.
static func profundidade_em(altura_do_terreno: float,
		nivel_do_mar: float = Terreno3D.NIVEL_DO_MAR,
		fim_do_raso: float = Terreno3D.AGUA_RASA_ATE,
		fundo_do_abisso: float = Terreno3D.AGUA_RASA_ATE * 3.0) -> String:
	if altura_do_terreno >= nivel_do_mar:
		return ""    # não é água
	if altura_do_terreno > fim_do_raso:
		return Mergulho.RASO
	if altura_do_terreno > fundo_do_abisso:
		return Mergulho.MEIO
	return Mergulho.ABISSO

## Dá pra mergulhar aqui? Só onde a água tem fundo de verdade — mergulhar em
## água rasa seria raspar a barriga na areia.
static func pode_mergulhar(arquetipo: String, altura_do_terreno: float,
		nivel_do_mar: float = 0.0) -> bool:
	var prof := profundidade_em(altura_do_terreno, nivel_do_mar)
	if prof == "" or prof == Mergulho.RASO:
		return false
	return bool(MovementProfile.obter(arquetipo).get("nada", false))

# ──────────────────────────────────────────────────────────────────────────────
# Fase 15 — ar
# ──────────────────────────────────────────────────────────────────────────────

## §29: as três zonas de voo. **Por volume configurável na zona, nunca cravado
## por mapa** — voar por cima de uma dungeon inteira precisa ser uma decisão de
## design declarada no dado, não um esquecimento.
const VOO_LIVRE      := "fly_allowed"
const VOO_RESTRITO   := "fly_restricted"
const VOO_PROIBIDO   := "no_fly"

## Teto de voo em metros acima do terreno, por zona.
##
## O restrito existe pro caso comum: uma área onde voar é permitido mas voar
## *por cima de tudo* mataria o desenho — um desfiladeiro, um vale de rota.
const TETO_LIVRE    : float = 120.0
const TETO_RESTRITO : float = 18.0

static func regra_de_voo_da_zona(zona: Dictionary) -> String:
	var v := str(zona.get("voo", VOO_LIVRE))
	return v if v in [VOO_LIVRE, VOO_RESTRITO, VOO_PROIBIDO] else VOO_LIVRE

## Pode decolar aqui?
##
## Devolve `{"pode", "motivo"}` — motivo em português, porque é o que a tela
## mostra. Recusa sem explicação é a mesma frustração do dano sem origem.
static func pode_voar(arquetipo: String, zona: Dictionary) -> Dictionary:
	if not bool(MovementProfile.obter(arquetipo).get("voa", false)):
		return {"pode": false, "motivo": "Este Pokémon não voa."}
	var regra := regra_de_voo_da_zona(zona)
	if regra == VOO_PROIBIDO:
		return {"pode": false, "motivo": "Não dá pra voar aqui."}
	return {"pode": true, "motivo": ""}

## O teto, em metros ACIMA do terreno — não altitude absoluta.
##
## Relativo de propósito: um teto absoluto faria o jogador esbarrar num limite
## invisível ao subir uma montanha, e conseguir voar mais alto no vale do que no
## pico. Relativo, a sensação é a mesma em qualquer lugar do mapa.
static func teto_de_voo(zona: Dictionary) -> float:
	match regra_de_voo_da_zona(zona):
		VOO_PROIBIDO: return 0.0
		VOO_RESTRITO: return TETO_RESTRITO
		_:            return TETO_LIVRE

## A altitude permitida, dada a do terreno logo abaixo.
static func altitude_maxima(altura_do_terreno: float, zona: Dictionary) -> float:
	return altura_do_terreno + teto_de_voo(zona)

## Já passou do teto?
static func acima_do_teto(altura_atual: float, altura_do_terreno: float,
		zona: Dictionary) -> bool:
	return altura_atual > altitude_maxima(altura_do_terreno, zona) + 0.01
