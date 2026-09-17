## Sorteio.gd — O RNG do jogo, alcançável de uma classe pura.
##
## ── Por que isto existe ─────────────────────────────────────────────────────
##
## `RNGManager` é autoload, e autoload **não é identificador** quando um script é
## compilado num teste `--script`. Uma classe de regra que o cita direto imprime
## `Compile Error: Identifier not found: RNGManager` ao ser carregada fora do
## jogo — **e o teste passa mesmo assim**, porque ainda produz a linha de
## resultado. Erro de compilação que não reprova é o pior tipo: ensina a ignorar
## vermelho.
##
## Achado em 17/09, quando a Fase 11 da V3 virou o primeiro teste a carregar
## `ComportamentoSelvagem` fora do jogo. A corrente era
## `ComportamentoSelvagem → DamageCalculator → StatsDePokemon`, e cada arquivo
## dela se declara classe pura justamente pra ser testável.
##
## ── O que NÃO muda ──────────────────────────────────────────────────────────
##
## **A sequência do RNG do jogo.** Dentro do jogo o nó existe, é encontrado, e é
## o mesmo objeto de sempre — mesma sequência, mesmo save, mesma reprodução de
## bug a partir de uma semente. O `randf` solto só entra onde não há jogo, ou
## seja, em teste.
##
## ⚠️ **Não use isto pra fugir do `RNGManager` dentro do jogo.** Ele existe pra
## que uma partida seja reproduzível; sortear por fora quebraria isso em
## silêncio. Este arquivo é uma ponte pra classes puras, não uma alternativa.
class_name Sorteio
extends RefCounted

## O nó do RNG, ou `null` quando não há jogo em volta.
static func gerenciador() -> Node:
	var laco := Engine.get_main_loop()
	if laco is SceneTree:
		return (laco as SceneTree).root.get_node_or_null("RNGManager")
	return null

static func randf() -> float:
	var r := gerenciador()
	return r.randf() if r != null else randf_puro()

static func randf_range(minimo: float, maximo: float) -> float:
	var r := gerenciador()
	return r.randf_range(minimo, maximo) if r != null else \
		minimo + randf_puro() * (maximo - minimo)

static func randi_range(minimo: int, maximo: int) -> int:
	var r := gerenciador()
	if r != null:
		return r.randi_range(minimo, maximo)
	return minimo + int(floor(randf_puro() * float(maximo - minimo + 1)))

## `true` com probabilidade `p` (0→1).
static func chance(p: float) -> bool:
	var r := gerenciador()
	return r.chance(p) if r != null else (randf_puro() < p)

## O estado do RNG, pra quem precisa **preservar a sequência**.
##
## `DanoV2` usa isto: `detalhar()` sorteia crítico e variação por dentro e a V2
## descarta os dois, então sem preservar o estado cada golpe empurrava de lado os
## sorteios de status, captura e loot (achado do Codex, 14/09).
##
## Sem jogo em volta não há sequência a preservar — devolve 0 e o `definir` não
## faz nada. **Isso não silencia bug nenhum**: o que se estaria protegendo é
## justamente a reprodutibilidade de uma partida, e em teste não há partida.
static func get_state() -> int:
	var r := gerenciador()
	return r.get_state() if r != null else 0

static func set_state(estado: int) -> void:
	var r := gerenciador()
	if r != null:
		r.set_state(estado)

## O sorteio global do Godot. Separado num nome próprio pra ficar óbvio, ao ler,
## quando o jogo NÃO está por perto — e pra ninguém confundir isto com o RNG
## reproduzível da partida.
static func randf_puro() -> float:
	return randf()
