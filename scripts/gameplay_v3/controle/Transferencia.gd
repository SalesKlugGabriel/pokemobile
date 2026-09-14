## Transferencia.gd — Trocar de corpo (Fase 7, §17).
##
## *"Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
## controle do meu Pokémon."*
##
## É a peça que dá sentido a tudo que foi construído antes dela. E a parte que
## os jogos costumam errar **não é a ida — é a volta**.
##
## ── Por que classe pura ─────────────────────────────────────────────────────
##
## A transferência é uma sequência de decisões: quem perde o input, quem ganha,
## que ângulo a câmera herda, o que é zerado, o que é preservado. Tudo isso é
## regra, e regra que mora fora do nó pode ser provada sem subir o jogo.
##
## Quem executa (mover câmera, ligar controlador) é o `Laboratorio3D`. Quem
## decide **o que** acontece e **em que ordem** é esta classe.
class_name Transferencia
extends RefCounted

## O que precisa ser preservado, na ida. Devolve o estado a guardar.
##
## A intenção do treinador é **zerada** de propósito. Sem isso ele continuaria
## andando pra sempre na última direção que o jogador segurava quando a batalha
## começou — e o jogador voltaria, minutos depois, a quinze metros de onde
## achava que estava.
static func ao_assumir(treinador: Node3D, pokemon: Node3D,
		yaw_do_treinador: float) -> Dictionary:
	return {
		"yaw_herdado": yaw_do_treinador,
		"pos_do_treinador": treinador.global_position if treinador != null else Vector3.ZERO,
		"pokemon_id": pokemon.get_instance_id() if pokemon != null else 0,
		"zerar_intencao_do_treinador": true,
		# §17: o treinador PERMANECE no mundo. Física ligada, vontade desligada.
		"treinador_mantem_fisica": true,
		# O companheiro para de seguir enquanto é o corpo do jogador — senão ele
		# tentaria acompanhar o treinador e obedecer o jogador ao mesmo tempo.
		"parar_de_acompanhar": true,
	}

## E na volta.
##
## `yaw_do_pokemon` é herdado pela câmera do treinador. As três opções e o
## porquê desta estão em `docs/COMBAT_FIRST_PERSON.md`: a luta gira o jogador, e
## devolvê-lo virado pra trás é desorientação gratuita.
static func ao_voltar(yaw_do_pokemon: float) -> Dictionary:
	return {
		"yaw_herdado": yaw_do_pokemon,
		"voltar_a_acompanhar": true,
		"zerar_intencao_do_pokemon": true,
	}

## §4: *"Se o Pokémon desmaiar e nenhum outro for enviado, o treinador volta a
## ficar vulnerável."*
##
## A queda devolve o controle **automaticamente**. Não é escolha do jogador — é
## consequência, e é o que dá peso a estar sem ninguém fora da ball.
static func deve_devolver_controle(pokemon_caiu: bool, tem_outro_em_pe: bool) -> bool:
	return pokemon_caiu and not tem_outro_em_pe

## A troca é permitida agora? Devolve {"pode", "motivo"} — motivo em português,
## porque é ele que aparece na tela.
static func pode_assumir(pokemon: Node3D, modo_atual: String) -> Dictionary:
	if pokemon == null or not is_instance_valid(pokemon):
		return {"pode": false, "motivo": "Você não tem nenhum Pokémon por perto."}
	if pokemon.has_method("esta_derrotado") and pokemon.esta_derrotado():
		return {"pode": false, "motivo": "Ele está desmaiado."}
	if modo_atual != ControlModeManager.WORLD:
		return {"pode": false, "motivo": "Você já está controlando alguém."}
	return {"pode": true, "motivo": ""}
