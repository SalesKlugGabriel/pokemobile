## RegraDeHabitabilidade.gd — Este ponto serve pra este corpo NASCER? (RFC-008)
##
## ── De onde isto veio ───────────────────────────────────────────────────────
##
## Da pergunta 4 da RFC-006, e de uma medição: `teste_rfc006_altura_e_colisao`
## achou **203 das 6.241 células do laboratório (3,25%) acima de 46°** — o
## `Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA`, o ponto em que o `move_and_slide`
## deixa de tratar a face como chão. Um corpo que nasce ali **escorrega a
## falésia abaixo no primeiro quadro de vida**, antes de a IA decidir nada.
##
## E o simétrico já existia sem regra nenhuma: `RegraDeSpawn` não consulta água.
## Um terrestre podia nascer em água profunda e ser barrado pela Fase 14 no
## quadro seguinte — o jogador vê o bicho aparecer e imediatamente se debater.
##
## ── O que esta classe NÃO faz, e é o ponto ──────────────────────────────────
##
## Ela **não reimplementa nada**. A pergunta da água já estava resolvida em
## `RegraDeTravessia.pode_estar_em`, com as três respostas certas (terrestre em
## água rasa pode, em profunda não, quem nada vai a qualquer lugar molhado) —
## aqui ela é **chamada**, nunca copiada. Duas cópias da regra de água é
## exatamente como elas passariam a discordar.
##
## O que é novo é só a inclinação, e a recusa de nascer em seco pra quem só vive
## na água.
##
## ⚠️ **Isto vale pra NASCER, não pra andar.** Um aquático que já está vivo pode
## sair da água (a regra de movimento permite, e tirar isso seria mudar a Fase
## 14 por tabela). O que esta classe diz é que ele não **começa** em terra seca.
## Nascer é escolha do jogo; andar é escolha do corpo.
##
## Classe pura: nenhum autoload citado — a regra da Fase 11.
class_name RegraDeHabitabilidade
extends RefCounted

## Quantas vezes o spawner tenta outro ponto antes de desistir do tique.
##
## Não é 1 de propósito: desistir na primeira recusa faria a densidade de spawn
## **cair perto da costa e da falésia** sem que nada dissesse por quê — o
## jogador andaria pra praia e o mundo esvaziaria em silêncio.
##
## ⚠️ **10, e o número saiu de medição, não de gosto.** Escrevi 6 primeiro,
## raciocinando a partir dos 3,25% de parede da RFC-006 — e estava errado por
## uma ordem de grandeza: medido no laboratório, um terrestre é recusado em
## **38,7% dos pontos**, porque o que domina não é a falésia (278 recusas) e sim
## a **água** (2.390). Um mapa com costa recusa muito mais do que um com morro.
##
## Com 38,7%, seis tentativas falhariam todas em 1 a cada ~300 tiques — o
## bastante pra ralear o mundo perto da praia. Dez leva isso a 1 em ~14.000, e
## dez contas de altura por tique não são nada perto de um `move_and_slide`.
const TENTATIVAS : int = 10

const OK                 := ""
const INGREME            := "ingreme"
const FUNDO_DEMAIS       := "fundo_demais"
const SECO_DEMAIS        := "seco_demais"

# ──────────────────────────────────────────────────────────────────────────────

## A inclinação barra este arquétipo?
##
## Quem voa não é perguntado — e isso não é exceção de conveniência, é o mesmo
## princípio da Fase 16: a capacidade do corpo vem antes da permissão. Um
## Pidgeot não escorrega numa parede porque nunca encostou nela.
##
## `limite_graus` é parâmetro, não constante local: quem sabe qual é o limite de
## chão é `Locomocao3D`, e copiar o número pra cá criaria a segunda cópia que
## esta classe inteira existe pra evitar.
static func ingreme_demais(arquetipo: String, inclinacao_graus: float,
		limite_graus: float) -> bool:
	if MovementProfile.voa(arquetipo):
		return false
	return inclinacao_graus >= limite_graus

## Este corpo pode começar a vida nesta superfície?
##
## A metade molhada é delegada inteira a `RegraDeTravessia.pode_estar_em`. A
## metade seca é nova: quem **só** nada (nada e não voa e não anda por escolha
## de perfil) não nasce em terra.
static func superficie_serve(arquetipo: String, superficie: String) -> bool:
	if not RegraDeTravessia.pode_estar_em(arquetipo, superficie):
		return false
	if RegraDeTravessia.e_agua(superficie):
		return true
	# Terra seca. Só recusa quem é exclusivamente aquático: o anfíbio nada E
	# anda, e barrá-lo aqui apagaria a razão de o arquétipo existir.
	return not so_vive_na_agua(arquetipo)

## Só vive na água? Nada, não voa, e o perfil o trata como aquático de verdade —
## gravidade reduzida é a assinatura de quem flutua num meio, não anda nele.
##
## Lido do PERFIL, nunca de uma lista de espécies: uma lista precisaria ser
## mantida em paralelo, e listas paralelas envelhecem.
static func so_vive_na_agua(arquetipo: String) -> bool:
	return arquetipo == MovementProfile.AQUATIC

# ──────────────────────────────────────────────────────────────────────────────

## A pergunta inteira, com o motivo junto.
##
## Devolve `{"pode": bool, "motivo": String}`. O motivo existe pra medição e
## pra depuração: "o spawn falhou" sem motivo é a mesma classe de silêncio que
## este projeto passou o mês caçando. Vazio quando pode.
static func pode_nascer(arquetipo: String, superficie: String,
		inclinacao_graus: float, limite_graus: float) -> Dictionary:
	if ingreme_demais(arquetipo, inclinacao_graus, limite_graus):
		return {"pode": false, "motivo": INGREME}
	if not RegraDeTravessia.pode_estar_em(arquetipo, superficie):
		return {"pode": false, "motivo": FUNDO_DEMAIS}
	if not superficie_serve(arquetipo, superficie):
		return {"pode": false, "motivo": SECO_DEMAIS}
	return {"pode": true, "motivo": OK}

## O motivo em português, pra quando isto aparecer em log ou em tela.
static func explicar(motivo: String) -> String:
	match motivo:
		INGREME:
			return "a encosta é íngreme demais — ele escorregaria"
		FUNDO_DEMAIS:
			return "a água é funda demais pra quem não nada"
		SECO_DEMAIS:
			return "é terra seca, e ele só vive na água"
		_:
			return "o ponto serve"
