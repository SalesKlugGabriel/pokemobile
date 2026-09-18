## PerigoDaZona.gd — Densidade e raridade de encontro por lugar.
##
## Pedido do Gabriel, quando perguntei se a densidade de spawn devia variar:
## **"Sim, e também mais raro"**.
##
## ── A inversão que essa frase pede ───────────────────────────────────────────
##
## O reflexo seria "lugar perigoso, mais bicho". Mas ele pediu **mais raro**, e
## isso é o contrário: lugar perigoso tem **menos** encontros, e cada um pesa
## mais. É a diferença entre um corredor cheio de lixo e uma caverna silenciosa
## onde você encontra uma coisa só — e ela é assustadora.
##
## Também é o que faz o terceiro pilar do projeto existir de verdade: *"mundo
## perigoso, em que entrar despreparado em determinadas regiões pode terminar
## muito mal"*. Um lugar que te joga 10 bichos fracos é cansativo; um que te
## joga 1 bicho forte é perigoso.
##
## ── De onde vem o "perigo" ───────────────────────────────────────────────────
##
## **Do próprio `zones.json`**, do nível dos Pokémon que já estão cadastrados
## ali. Não existe uma segunda lista de "zonas perigosas" pra alguém manter em
## sincronia — regra 7 dos padrões de construção: fonte de verdade única.
##
## Consequência prática: mexer no nível de uma zona já ajusta a densidade dela
## junto, sem ninguém precisar lembrar.
class_name PerigoDaZona
extends RefCounted

## O nível a partir do qual uma zona começa a contar como perigosa, e o nível
## em que ela já é o máximo. Pallet (2–5) fica em 0; Cerulean Cave (55) em 1.
const NIVEL_SEGURO   : float = 8.0
const NIVEL_EXTREMO  : float = 55.0

## Quanto o intervalo entre spawns estica no lugar mais perigoso. 2,2 = mais
## que o dobro de tempo entre encontros.
const ESTICA_ATE : float = 2.2

## Chance de um encontro ser **elite** (o mais raro da tabela, no topo da faixa
## de nível) no lugar mais perigoso. Em lugar seguro é zero.
##
## 🔴 18/09: era **0,35**. O Gabriel fixou a régua em **2%**: *"taxa de
## aparecimento de um elite: 2%"*. Um em cada três encontros nunca foi raridade
## — era o tipo de número que eu tinha escolhido sem fonte e ninguém tinha
## conferido.
##
## É **teto**, não taxa fixa: a conta continua sendo `MAX × perigo(zona)`, então
## Pallet segue em 0% e Cerulean Cave chega aos 2%. Proposto assim pra não
## apagar o gradiente de perigo por zona, e **CONFIRMADO pelo Gabriel** no mesmo
## dia — *"mantenha como você propôs"*.
const CHANCE_DE_ELITE_MAX : float = 0.02

## Quantos níveis a mais um elite ganha por cima do topo da faixa da zona.
const NIVEIS_EXTRA_DO_ELITE : int = 3

# ──────────────────────────────────────────────────────────────────────────────
# O perigo
# ──────────────────────────────────────────────────────────────────────────────

## O nível médio dos Pokémon cadastrados na zona. É o dado que já existe.
static func nivel_medio(zona: Dictionary) -> float:
	var tabela : Array = zona.get("wild_pokemon", [])
	if tabela.is_empty():
		return 0.0
	var soma : float = 0.0
	for e in tabela:
		soma += (float(e.get("level_min", 1)) + float(e.get("level_max", 1))) * 0.5
	return soma / float(tabela.size())

## 0,0 = seguro (rota inicial) · 1,0 = o mais perigoso do jogo.
static func perigo(zona: Dictionary) -> float:
	var m := nivel_medio(zona)
	if m <= NIVEL_SEGURO:
		return 0.0
	return clampf((m - NIVEL_SEGURO) / (NIVEL_EXTREMO - NIVEL_SEGURO), 0.0, 1.0)

# ──────────────────────────────────────────────────────────────────────────────
# O que o perigo muda
# ──────────────────────────────────────────────────────────────────────────────

## Multiplicador do intervalo entre spawns. **Cresce** com o perigo: lugar
## perigoso tem MENOS encontros, não mais.
static func multiplicador_de_intervalo(zona: Dictionary) -> float:
	return lerpf(1.0, ESTICA_ATE, perigo(zona))

## Chance de o próximo encontro ser elite.
static func chance_de_elite(zona: Dictionary) -> float:
	return CHANCE_DE_ELITE_MAX * perigo(zona)

## O peso de sorteio de uma entrada, já corrigido pelo perigo.
##
## Em lugar seguro, o peso é o do arquivo. Em lugar perigoso, os **raros**
## (peso baixo) sobem: é o "mais raro" que o Gabriel pediu. A raiz quadrada
## comprime a diferença sem invertê-la — o comum continua sendo o mais provável,
## só deixa de ser esmagador.
static func peso_corrigido(peso: float, zona: Dictionary) -> float:
	var p := perigo(zona)
	if p <= 0.0 or peso <= 0.0:
		return maxf(0.0, peso)
	return lerpf(peso, sqrt(peso), p)

## O nível de um encontro. `elite` empurra pro topo da faixa e acrescenta
## alguns níveis — é o "mais forte" que acompanha o "mais raro".
##
## `sorteio` 0→1 vem de fora, pra o teste poder forçar os dois extremos.
static func nivel_do_encontro(entrada: Dictionary, elite: bool, sorteio: float) -> int:
	var minimo : int = int(entrada.get("level_min", 1))
	var maximo : int = int(entrada.get("level_max", minimo))
	if elite:
		return maxi(minimo, maximo + NIVEIS_EXTRA_DO_ELITE)
	return minimo + int(floor(clampf(sorteio, 0.0, 0.999) * float(maximo - minimo + 1)))

# ──────────────────────────────────────────────────────────────────────────────
# Leitura
# ──────────────────────────────────────────────────────────────────────────────

## Como a zona se descreve, pra log e pro recado de feedback. Frase, não sigla.
static func descrever(zona: Dictionary) -> String:
	var p := perigo(zona)
	var rotulo := "segura"
	if p >= 0.75:
		rotulo = "muito perigosa"
	elif p >= 0.45:
		rotulo = "perigosa"
	elif p >= 0.15:
		rotulo = "arriscada"
	return "%s (nível médio %.0f, perigo %.0f%%, encontros %.1f× mais espaçados, %.0f%% de elite)" % [
		rotulo, nivel_medio(zona), p * 100.0,
		multiplicador_de_intervalo(zona), chance_de_elite(zona) * 100.0]
