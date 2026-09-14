## RegraDeAcompanhar.gd — Onde o Pokémon companheiro deve estar (§6).
##
## Pedido do Gabriel:
##
##   *"O Pokémon acompanha o treinador; navega de forma natural; **não deve
##   parecer flutuar**; deve respeitar obstáculos; deve manter distância
##   natural; deve **evitar ficar em cima do treinador**; deve respeitar o
##   tamanho real relativo da espécie."*
##
## ── Por que classe pura ─────────────────────────────────────────────────────
##
## "Onde ele deveria estar" é conta: dado o treinador, o tamanho do bicho e o
## que já aconteceu, sai um ponto. Ficando aqui, os casos difíceis viram teste
## com número esperado — e o caso difícil aqui é justamente o que a V2 errou.
##
## ── A lição que a V2 deixou ─────────────────────────────────────────────────
##
## Na V2 a distância de repouso era uma **constante** (190 px). Funcionava,
## porque todo sprite tinha o mesmo tamanho na tela. Em 3D isso quebra: um Onix
## de 5,6 m parado a 1,9 m do treinador **está em cima dele**, e um Diglett de
## 0,2 m a 1,9 m parece abandonado.
##
## Então a distância é **derivada do tamanho dos dois**, não escolhida. É o §6
## ("respeitar o tamanho real relativo") virando número em vez de virar comentário.
class_name RegraDeAcompanhar
extends RefCounted

## Distância de repouso = raio do treinador + raio do bicho + esta folga.
## A folga é o espaço social: o suficiente pra não encostar, pouco o bastante
## pra parecer companhia e não escolta.
const FOLGA : float = 1.1

## Abaixo desta fração da distância de repouso, ele está perto demais e recua.
## Existe porque um companheiro que só sabe se aproximar acaba empurrando o
## jogador — o §6 diz "evitar ficar em cima do treinador" com todas as letras.
const FRACAO_PERTO_DEMAIS : float = 0.55

## Acima disto, corre pra alcançar em vez de andar.
const FATOR_DE_CORRIDA : float = 2.6

## Zona morta: dentro dela ele não corrige posição. Sem isso o Pokémon fica
## tremendo em volta do ponto ideal, que é o defeito mais visível de um
## companheiro em qualquer jogo.
const ZONA_MORTA : float = 0.35

## A distância em que ele deve ficar parado, dados os dois tamanhos.
static func distancia_de_repouso(raio_treinador: float, raio_pokemon: float) -> float:
	return raio_treinador + raio_pokemon + FOLGA

## O ponto onde ele deveria estar: atrás do treinador, na direção oposta à que
## o treinador olha.
##
## **Atrás**, e não ao lado, por um motivo prático: ao lado, ele entra na frente
## da câmera de 3ª pessoa toda vez que o jogador gira. Atrás, ele some do
## enquadramento quando não importa e aparece quando o jogador olha pra trás.
static func ponto_ideal(pos_treinador: Vector3, olhar_treinador: Vector3,
		raio_treinador: float, raio_pokemon: float) -> Vector3:
	var atras := -olhar_treinador
	atras.y = 0.0
	if atras.length_squared() < 0.001:
		atras = Vector3.BACK
	atras = atras.normalized()
	return pos_treinador + atras * distancia_de_repouso(raio_treinador, raio_pokemon)

## O que ele deve fazer agora: `"parado"`, `"andar"`, `"correr"` ou `"recuar"`.
##
## Devolver uma PALAVRA, e não um vetor, é de propósito: quem decide o estado é
## esta regra, e quem executa é a entidade. Assim o teste prova a decisão sem
## precisar de física, e a animação sabe o que tocar sem recalcular nada.
static func estado(distancia_atual: float, distancia_de_repouso_m: float) -> String:
	if distancia_atual < distancia_de_repouso_m * FRACAO_PERTO_DEMAIS:
		return "recuar"
	if distancia_atual > distancia_de_repouso_m * FATOR_DE_CORRIDA:
		return "correr"
	if absf(distancia_atual - distancia_de_repouso_m) <= ZONA_MORTA:
		return "parado"
	return "andar"

## §6: *"não deve parecer flutuar"*.
##
## Um companheiro que persegue o ponto ideal em linha reta atravessa o relevo e
## fica no ar em qualquer desnível. A altura dele sai do **terreno**, não da
## trajetória — e é isso que separa "andando" de "deslizando no ar".
static func altura_no_terreno(x: float, z: float) -> float:
	return Terreno3D.altura_em(x, z)

## Está longe demais pra valer a pena andar? Nesse caso o teleporte curto é
## melhor que uma corrida de 40 segundos atravessando o mapa.
##
## O limite é alto de propósito: teletransportar um companheiro que o jogador
## está vendo quebra a ilusão inteira. Só vale quando ele já sumiu de vista.
const DISTANCIA_PARA_TELEPORTE : float = 45.0

static func deve_teleportar(distancia: float, visivel: bool) -> bool:
	return distancia > DISTANCIA_PARA_TELEPORTE and not visivel
