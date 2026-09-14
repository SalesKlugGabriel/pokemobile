# Travessia — Surf e Fly

> Parte da [Gameplay V3](GAMEPLAY_V3.md). Estado: **proposta**, nada implementado.

## O princípio

Travessia é **movimento**, não teletransporte (§27). Entrar na água precisa ser
uma mudança de como o corpo se move, não uma tela de carregamento com outro
tileset.

## Surf (Fase 14)

`SurfProfile`: entrar na água, flutuar, acelerar, desacelerar, girar, navegar.

O que já existe e sobrevive: `Mergulho.gd` da V2 é **regra pura** — oxigênio (90
s), três profundidades com consumo diferente (1,0 / 1,6 / 2,4), a penalidade de
velocidade sem a roupa, os respiradouros e a quest da roupa de mergulho. Nada
disso é 2D. Adapta-se trocando tile por volume.

🔴 **Um bug corrigido em 14/09 que vale carregar como lição:**
`profundidade_atual()` lia `GameData.zones`, propriedade que **nunca existiu**.
Resultado: o abismo cobrava oxigênio de água rasa, invisível desde 11/09. Ao
adaptar, conferir que a profundidade sai da zona de verdade.

## Fly (Fase 15)

`FlightProfile`: horizontal, vertical, aceleração, desaceleração, pitch, yaw,
altitude.

**Controle agradável acima de física realista** (§28). Voo com inércia fiel é
difícil de pilotar e frustra — o objetivo é exploração, não simulador.

## Zonas de voo (§29)

`FLY_ALLOWED` · `FLY_RESTRICTED` · `NO_FLY`, por **volume configurável** na
zona, nunca cravado por mapa. Voar por cima de uma dungeon inteira precisa ser
uma decisão de design declarada no dado, não um esquecimento.

## HM (§30)

HM pode afetar combate, travessia ou os dois. **Não presumir que faz sempre as
duas coisas.** Surf desbloqueia travessia aquática; Fly desbloqueia a aérea.

A regra dos 25 níveis (§33) é preservada e **configurável**: vale para alteração
de kit ligada a HM, **não** para qualquer troca de skill. `TrocaDeKit.gd` já
implementa exatamente assim — `CUSTO_EM_NIVEIS` é constante e editável.

## Arquétipos de movimento (§15)

`GROUND_BIPED` · `GROUND_QUADRUPED` · `GROUND_HEAVY` · `SERPENTINE` · `FLYING` ·
`AQUATIC` · `AMPHIBIOUS` · `HOVERING`.

**Não implementar todos.** A arquitetura aceita todos; a ordem é GROUND primeiro,
depois AQUATIC, depois FLYING. Um Pokémon por arquétipo basta pra provar (§16) —
e placeholders servem.
