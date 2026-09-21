## RegraDeGuardarCaptura.gd — O que acontece DEPOIS de a bola fechar (Fase 21b).
##
## ── O buraco que isto fecha ─────────────────────────────────────────────────
##
## A Fase 21 fez a captura funcionar: a bola voa, acerta, `RegrasDeCorpo` decide,
## o corpo some e `tentar_capturar()` devolve `{pegou: true, species_id, nivel}`.
##
## 🔴 E **ninguém escutava**. Conferido: nenhum arquivo fora do próprio
## `PokebolaLancada3D` se conectava a `resolveu`. O jogador capturava e o
## Pokémon **evaporava** — a mecânica inteira terminava num sinal sem ouvinte.
##
## É a quarta vez no mês que a peça existe, não dá erro e não faz nada (kit
## vazio na 17, Alpha que nunca nascia na 18, tecla `pokeball` sem leitor na 21).
## Já não é acidente: é o formato de defeito deste projeto.
##
## ── O que esta classe decide, e o que ela não decide ────────────────────────
##
## **Não decide** como um Pokémon é montado (`SaveManager._make_pokemon_data`),
## nem onde ele cabe (`add_pokemon` já escolhe time ou PC), nem o que é a
## Pokédex (`mark_caught`). Tudo isso existe e está em uso desde a V1.
##
## **Decide** só o que ninguém tinha decidido ainda: o que contar ao jogador. E
## a resposta muda conforme o destino — "entrou no time" e "foi pro PC" são
## coisas diferentes pra quem está jogando, e um texto só pras duas esconderia
## exatamente o momento em que o time encheu.
##
## Classe pura: nenhum autoload citado — a regra da Fase 11.
class_name RegraDeGuardarCaptura
extends RefCounted

const TIME := "team"
const PC   := "pc"

## O tamanho do time. ⚠️ Espelha `SaveManager.add_pokemon`, que compara com 6 —
## e espelhar é o que eu quero evitar. Existe aqui **só** para a mensagem poder
## dizer "o time está cheio" sem perguntar ao save; quem de fato decide o
## destino continua sendo o `add_pokemon`, e o destino REAL é o que a mensagem
## usa. Se os dois discordarem, o teste reprova.
const TIME_CHEIO : int = 6

## A frase que o jogador lê. O nome vem de quem chama porque quem tem o catálogo
## de espécies é o jogo, não esta regra.
static func mensagem(destino: String, nome: String) -> String:
	if destino == PC:
		return "%s foi capturado! O time está cheio, então ele foi pro PC." % nome
	return "%s foi capturado e entrou no time!" % nome

## O relatório completo de uma captura bem-sucedida, pronto pra HUD.
##
## `destino` é o que o `SaveManager.add_pokemon` **devolveu** — não um palpite
## sobre quantos estavam no time. Guardar e depois adivinhar onde guardou é
## exatamente como as duas contas passam a discordar.
static func relatorio(species_id: int, nivel: int, nome: String,
		destino: String) -> Dictionary:
	return {
		"species_id": species_id,
		"nivel": nivel,
		"nome": nome,
		"destino": destino,
		"foi_pro_pc": destino == PC,
		"mensagem": mensagem(destino, nome),
	}

## Vale a pena guardar? Recusa o que não é captura, e recusa espécie inválida.
##
## Falha fechada de propósito: um `species_id` 0 viraria um Pokémon inexistente
## no time do jogador, e isso é pior que perder a captura — é save corrompido.
static func deve_guardar(resultado: Dictionary) -> Dictionary:
	if not bool(resultado.get("pegou", false)):
		return {"guardar": false, "motivo": "não foi captura"}
	if int(resultado.get("species_id", 0)) <= 0:
		return {"guardar": false, "motivo": "espécie inválida no resultado"}
	if int(resultado.get("nivel", 0)) <= 0:
		return {"guardar": false, "motivo": "nível inválido no resultado"}
	return {"guardar": true, "motivo": ""}
