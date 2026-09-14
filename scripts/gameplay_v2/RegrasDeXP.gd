## RegrasDeXP.gd — Quem ganha experiência, e quanto (§32, §33, §34).
##
## Pedido do Gabriel:
##
##   §32: *"XP recebido por jogador: 60% treinador, 40% Pokémon. Final blow não
##   ganha XP adicional — mas recebe direito exclusivo ao corpo, loot e
##   tentativa de captura."*
##   §33: *"Pokémon que recebe os 40%: preferencialmente o ativo que causou
##   dano e ainda está consciente quando o inimigo morreu. Pokémon já desmaiado
##   antes da morte não recebe. Lv100 não recebe XP adicional."*
##
## ── A separação que essas duas seções fazem, e que é o coração delas ─────────
##
## **XP vai por dano causado. O corpo vai por quem deu o último golpe.**
##
## São duas moedas diferentes, e separá-las resolve os dois vícios clássicos de
## MMO de uma vez: ninguém ganha XP só por encostar, e ninguém rouba a
## experiência de uma luta longa roubando o último golpe. Quem quer o Pokémon
## precisa acertar o golpe final; quem quer o nível precisa ter lutado.
class_name RegrasDeXP
extends RefCounted

## §32: a divisão entre treinador e Pokémon.
const FRACAO_DO_TREINADOR : float = 0.60
const FRACAO_DO_POKEMON   : float = 0.40

const NIVEL_MAXIMO : int = 100

## Quanto um inimigo vale. Cresce com o nível dele e com o quanto ele era
## difícil — um Alpha vale mais que o mesmo bicho comum, porque custou mais.
const XP_BASE : float = 12.0

static func xp_do_inimigo(nivel: int, alpha: bool) -> int:
	var x : float = XP_BASE * float(maxi(1, nivel)) * (1.6 if alpha else 1.0)
	return maxi(1, int(round(x)))

# ──────────────────────────────────────────────────────────────────────────────
# A divisão entre jogadores (§32)
# ──────────────────────────────────────────────────────────────────────────────

## Divide o XP entre quem bateu, **na proporção do dano de cada um**.
##
## `dano_por_jogador` é {id → dano}. Devolve {id → xp}.
##
## Quem não causou dano não entra: estar por perto não é participar. É a regra
## que impede o clássico "ficar atrás do grupo pra pegar XP".
static func dividir(total: int, dano_por_jogador: Dictionary) -> Dictionary:
	var soma : float = 0.0
	for id in dano_por_jogador.keys():
		soma += maxf(0.0, float(dano_por_jogador[id]))
	if soma <= 0.0:
		return {}

	var out : Dictionary = {}
	for id in dano_por_jogador.keys():
		var d : float = maxf(0.0, float(dano_por_jogador[id]))
		if d <= 0.0:
			continue
		out[id] = maxi(1, int(round(float(total) * (d / soma))))
	return out

## §33: qual Pokémon fica com os 40%.
##
## Ordem: o **ativo** que causou dano e está consciente; se ele não serve, o que
## causou mais dano entre os elegíveis. Desmaiado antes da morte não recebe —
## quem caiu não terminou a luta.
##
## `candidatos` = [{id, dano, consciente, ativo, nivel}]. Devolve o id, ou 0.
static func pokemon_que_recebe(candidatos: Array) -> int:
	var elegiveis : Array = []
	for c in candidatos:
		if float(c.get("dano", 0)) <= 0.0:
			continue
		if not bool(c.get("consciente", false)):
			continue
		if int(c.get("nivel", 1)) >= NIVEL_MAXIMO:
			continue   # §33: Lv100 não recebe XP adicional
		elegiveis.append(c)
	if elegiveis.is_empty():
		return 0

	for c in elegiveis:
		if bool(c.get("ativo", false)):
			return int(c.get("id", 0))

	var melhor : Dictionary = elegiveis[0]
	for c in elegiveis:
		if float(c.get("dano", 0)) > float(melhor.get("dano", 0)):
			melhor = c
	return int(melhor.get("id", 0))

## Quem tem direito ao corpo: quem deu o último golpe (§32). Separado do XP de
## propósito — ver o cabeçalho.
static func dono_do_corpo(id_do_ultimo_golpe: int) -> int:
	return id_do_ultimo_golpe

# ──────────────────────────────────────────────────────────────────────────────
# Subir de nível
# ──────────────────────────────────────────────────────────────────────────────

## Quanto falta pra sair do nível `n`. Curva simples e previsível: o jogador
## consegue estimar o próximo nível sem tabela.
static func xp_para_subir(nivel: int) -> int:
	var n : int = clampi(nivel, 1, NIVEL_MAXIMO)
	return maxi(1, int(round(30.0 * pow(float(n), 1.45))))

## Aplica XP e devolve {"nivel", "xp", "subiu"} — `subiu` é quantos níveis.
##
## Sobe em laço porque um inimigo muito acima pode dar vários níveis de uma vez,
## e travar em um só faria o XP excedente sumir sem explicação.
static func ganhar(nivel: int, xp_atual: int, ganho: int) -> Dictionary:
	var n : int = clampi(nivel, 1, NIVEL_MAXIMO)
	if n >= NIVEL_MAXIMO:
		return {"nivel": NIVEL_MAXIMO, "xp": 0, "subiu": 0}

	var xp : int = maxi(0, xp_atual) + maxi(0, ganho)
	var subiu : int = 0
	while n < NIVEL_MAXIMO and xp >= xp_para_subir(n):
		xp -= xp_para_subir(n)
		n += 1
		subiu += 1
	if n >= NIVEL_MAXIMO:
		xp = 0
	return {"nivel": n, "xp": xp, "subiu": subiu}

# ──────────────────────────────────────────────────────────────────────────────
# Derrota (§34)
# ──────────────────────────────────────────────────────────────────────────────

## *"Ao treinador chegar a 0 HP: perde XP; retorna ao último Pokémon Center.
## Não perde Pokémon, itens nem dinheiro. Valor exato: configurável."*
##
## Fração do XP do nível atual, e **nunca desce de nível**: perder progresso é
## punição; perder um nível inteiro é desfazer uma conquista, e faz o jogador
## parar de arriscar — o oposto do que um mundo perigoso quer.
const FRACAO_DE_XP_PERDIDA : float = 0.25

static func perder_por_derrota(nivel: int, xp_atual: int) -> int:
	var perde : int = int(round(float(xp_para_subir(nivel)) * FRACAO_DE_XP_PERDIDA))
	return maxi(0, xp_atual - perde)
