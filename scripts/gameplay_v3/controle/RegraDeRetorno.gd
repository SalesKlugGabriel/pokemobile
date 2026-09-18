## RegraDeRetorno.gd — Voltar a ser o treinador (Fase 13, §17).
##
## É a fase que **fecha o laço da fantasia**:
##
## > *"Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
## > controle do meu Pokémon."*
##
## A ida já existia desde a Fase 7. O que faltava era a volta ter regra — e a
## `COMBAT_FIRST_PERSON.md` já avisava qual é o risco:
##
## > *"A transferência e a volta são o que precisa ser provado primeiro. Um
## > combate bom que não devolve o controle direito quebra a fantasia inteira."*
##
## Classe pura: quem executa é o `RetornoAoMundo`.
class_name RegraDeRetorno
extends RefCounted

## Quantos metros em volta contam como "hostil por perto" na hora de sair.
##
## Um pouco maior que a distância de engajamento (3,5 m), porque sair no
## milímetro antes de apanhar seria a mesma esquiva que a regra abaixo impede.
const RAIO_DE_AMEACA : float = 6.0

# ──────────────────────────────────────────────────────────────────────────────
# A volta FORÇADA
# ──────────────────────────────────────────────────────────────────────────────

## O fim desta batalha obriga a voltar?
##
## **Só a derrota.** É a §4: *"Se o Pokémon desmaiar e nenhum outro for enviado,
## o treinador volta a ficar vulnerável."* Cair não é escolha — é consequência,
## e é o que dá peso a estar sem ninguém fora da ball.
##
## Vencer e a briga se desfazer **não** devolvem nada: no mundo aberto, o jogador
## continua sendo o Pokémon até decidir o contrário. Forçar a volta a cada
## vitória transformaria exploração numa sequência de telas de transição.
static func volta_forcada(resultado: String, tem_outro_em_pe: bool = false) -> bool:
	if resultado != RegraDeCombate.DERROTA:
		return false
	return not tem_outro_em_pe

## Depois de uma volta forçada, o treinador está **vulnerável** — sem ninguém
## fora da ball. A tela precisa dizer isso; é o estado que dá medo.
static func treinador_vulneravel(resultado: String, tem_outro_em_pe: bool) -> bool:
	return resultado == RegraDeCombate.DERROTA and not tem_outro_em_pe

# ──────────────────────────────────────────────────────────────────────────────
# A volta POR VONTADE
# ──────────────────────────────────────────────────────────────────────────────

## O jogador pode voltar a ser o treinador agora?
##
## Devolve `{"pode", "motivo"}` — motivo **em português**, porque é ele que
## aparece na tela. Botão que não responde e não explica é a mesma frustração do
## dano sem origem.
##
## ── 🔴 A regra que impede o corpo do treinador de virar esconderijo ─────────
##
## Se desse pra voltar a qualquer momento, o treinador seria uma **saída de
## emergência**: cinco mobs em cima, aperta a tecla, e o perigo evapora. Isso
## esvaziaria o terceiro pilar do projeto — *"mundo perigoso, em que entrar
## despreparado em determinadas regiões pode terminar muito mal"*.
##
## E o Gabriel acabou de reforçar que **1v5 e 1v10 acontecem**. Justamente aí é
## que a saída de emergência seria mais tentadora, e mais destrutiva.
##
## Então: **com hostil por perto, não sai.** A saída existe pra quando a poeira
## baixou — não pra escapar da poeira.
static func pode_voltar(pokemon_vivo: bool, esta_anunciando: bool,
		hostis_por_perto: int, ja_e_o_treinador: bool) -> Dictionary:
	if ja_e_o_treinador:
		return {"pode": false, "motivo": "Você já está no controle do treinador."}
	if not pokemon_vivo:
		# Não é recusa: é que a volta já aconteceu sozinha (volta_forcada).
		return {"pode": false, "motivo": "Seu Pokémon desmaiou — o controle já voltou."}
	if esta_anunciando:
		return {"pode": false, "motivo": "Termine o golpe antes de trocar."}
	if hostis_por_perto > 0:
		return {"pode": false, "motivo": "Perigoso demais — há %d por perto." % hostis_por_perto}
	return {"pode": true, "motivo": ""}

## Quantos hostis contam, dada a lista de candidatos.
##
## `candidatos` é `[{ "posicao": Vector3, "hostil": bool, "vivo": bool }]`. Fica
## aqui, e não no nó, porque "quem ameaça" é regra — e regra que mora fora do nó
## se prova sem subir o mundo.
static func contar_hostis(centro: Vector3, candidatos: Array,
		raio: float = RAIO_DE_AMEACA) -> int:
	var n : int = 0
	for c in candidatos:
		if not bool(c.get("vivo", true)) or not bool(c.get("hostil", false)):
			continue
		var p : Vector3 = c.get("posicao", Vector3.ZERO)
		if Vector3(p.x - centro.x, 0.0, p.z - centro.z).length() <= raio:
			n += 1
	return n

# ──────────────────────────────────────────────────────────────────────────────
# Onde o treinador reaparece
# ──────────────────────────────────────────────────────────────────────────────

## O treinador **nunca foi embora** (§17: ele fica no mundo enquanto você luta),
## então "voltar" não é reaparecer — é reassumir o corpo que estava lá.
##
## Mas a câmera precisa de um ângulo, e a escolha aqui é herdar o yaw do Pokémon:
## a luta gira o jogador, e devolvê-lo virado pra trás é desorientação gratuita.
## Isso já estava decidido na Fase 7 (`Transferencia.ao_voltar`) e continua
## valendo — esta função existe só pra dizer que a decisão é consciente e não se
## perdeu no caminho.
static func yaw_de_volta(yaw_do_pokemon: float) -> float:
	return yaw_do_pokemon

## A frase do que aconteceu, pra tela e pra linha do tempo do feedback.
static func frase(resultado: String, forcada: bool) -> String:
	if forcada:
		return "seu Pokémon caiu — você voltou a ser o treinador, e está sozinho"
	match resultado:
		RegraDeCombate.VITORIA: return "batalha vencida — você continua no controle"
		RegraDeCombate.FUGA:    return "a batalha se desfez — você continua no controle"
		_: return "você voltou a ser o treinador"
