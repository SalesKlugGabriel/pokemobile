## EstadoV2.gd — O retrato do agora, pra HUD nascer certa.
##
## ── Por que isto existe ──────────────────────────────────────────────────────
##
## Sinal conta **mudança**. Ninguém reconstitui o presente só com mudança: uma
## tela aberta no meio de uma recarga, ou depois de uma troca de Pokémon, não
## recebeu nenhum sinal e nasce achando que está tudo pronto.
##
## Já aconteceu de verdade neste projeto — foi o buraco que o Codex apontou na
## RFC-001, no jogo atual.
##
## ── 🔴 E por que ele existe SÓ AGORA ─────────────────────────────────────────
##
## Eu prometi `EstadoV2.instantaneo()` na minha resposta à revisão da
## RFC-GAMEPLAY-V2 e **não construí**. O Codex foi montar a HUD em cima e achou
## o vazio: *"essa classe/API não existe na base inspecionada"*.
##
## Ele também está certo no segundo ponto: `Laboratorio.contexto()` produz
## **frases** pro recado de feedback ("237 / 237", "atacando Rattata"). Isso é
## pra pessoa ler, não pra tela consumir — deixar virar contrato de UI por
## acidente daria uma HUD que quebra quando eu melhorar uma frase.
##
## Então são dois contratos separados, de propósito:
##
##   `Laboratorio.contexto()`  → texto, pra humano, no recado de feedback
##   `EstadoV2.instantaneo()`  → números e ids, pra máquina, na HUD
class_name EstadoV2
extends RefCounted

## O retrato completo. Sem efeito colateral: pode ser chamado a qualquer hora,
## inclusive com o jogo pausado.
static func instantaneo(treinador: Node, pokemon: Node,
		selvagens: Array = []) -> Dictionary:
	return {
		"treinador": do_treinador(treinador),
		"pokemon": do_pokemon(pokemon),
		"inimigos": inimigos(selvagens),
	}

static func do_treinador(t: Node) -> Dictionary:
	if t == null or not is_instance_valid(t):
		return {}
	return {
		"id": t.get_instance_id(),
		"pos": t.global_position,
		"tile": t.grid_pos,
		"velocidade": t.velocity.length(),
		"parado": t.esta_parado(),
		"vida": t.vida,
		"vida_maxima": t.vida_maxima,
		"caido": t.esta_derrotado(),
		# Números crus. A HUD decide se desenha barra, número ou os dois.
		"stamina": t.stamina.atual,
		"stamina_maxima": t.stamina.maximo(),
		"stamina_estado": t.stamina.estado(),
		"stamina_fator": t.stamina.fator_de_velocidade(),
	}

static func do_pokemon(p: Node) -> Dictionary:
	if p == null or not is_instance_valid(p):
		return {}
	var kit : Array = []
	for i in p.golpes.size():
		var g : Dictionary = p.golpes[i]
		kit.append({
			"slot": i,
			"id": str(g.get("id", "")),
			"nome": str(g.get("name", g.get("id", "?"))),
			"tipo": str(g.get("type", "Normal")),
			"categoria": str(g.get("category", "physical")),
			# Progresso, não segundos: é o mesmo contrato da RFC-001, e existe
			# pra a UI nunca refazer a conta de cooldown pelo valor do JSON.
			"progresso": p.progresso_da_recarga(i),
		})
	var alvo : Node = p.comandos.alvo if p.comandos.alvo_valido() else null
	return {
		"id": p.get_instance_id(),
		"species_id": p.species_id,
		"nome": p.nome_exibido,
		"nivel": p.nivel,
		"tipos": p.tipos,
		"vida": p.vida,
		"vida_maxima": p.vida_maxima,
		"caido": p.esta_derrotado(),
		"castando": p.esta_castando(),
		"ordem": p.comandos.ordem,
		"alvo_id": alvo.get_instance_id() if alvo != null else 0,
		"capacidade": p.golpes.size(),
		"kit": kit,
	}

static func inimigos(lista: Array) -> Array:
	var out : Array = []
	for n in lista:
		if n == null or not is_instance_valid(n):
			continue
		out.append({
			"id": n.get_instance_id(),
			"nome": n.nome_exibido,
			"nivel": n.nivel,
			"vida": n.vida,
			"vida_maxima": n.vida_maxima,
			"caido": n.esta_derrotado(),
			"pos": n.global_position,
		})
	return out
