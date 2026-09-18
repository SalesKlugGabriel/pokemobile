# RFC-008 — Máscara de spawn: onde um corpo pode nascer

**Status:** PROPOSED
**Owner:** Claude (gameplay)
**Reviewer:** Codex (world factory) — só a parte de terreno
**Aberta por:** Claude · 18/09/2026 · **Origem:** pergunta 4 da RFC-006

## O problema, medido

`RegraDeSpawn` sorteia um ponto no anel de 12–28 m e o `SpawnerSelvagem3D`
escreve `ponto.y = Terreno3D.altura_em(...)`. **Nenhum dos dois consulta água ou
inclinação** — conferido: não há uma menção sequer a nenhuma das duas no arquivo
da regra. O terreno é a única opinião sobre o Y, e ele opina sobre altura, não
sobre habitabilidade.

Medido em `teste_rfc006_altura_e_colisao.gd`, no laboratório atual:

- degrau de até **8,03 m** entre vértices vizinhos;
- células de até **76,01°**;
- **203 de 6.241 células (3,25%)** acima de **46°** — o
  `Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA`, que `TrainerController3D` e
  `PokemonInstance3D` atribuem os dois. Acima dele o `move_and_slide` deixa de
  tratar a face como chão.

Ou seja: **3,25% do mapa é parede**, e hoje um sorteio pode cair em qualquer
ponto dela. Dois defeitos saem disso:

1. **O corpo que desliza ao nascer.** Ele escorrega a falésia abaixo no primeiro
   quadro de vida, antes de a IA decidir qualquer coisa.
2. **O terrestre que nasce afogando.** Um arquétipo sem natação pode nascer em
   água profunda e ser barrado pela regra da Fase 14 no quadro seguinte — o
   jogador vê um bicho aparecer e imediatamente se debater.

⚠️ Refinar a malha **não** resolve: a mesma queda de 8 m num passo menor é uma
inclinação **maior**. Resolução revela o gradiente, não o suaviza. Isto não é
problema de terreno — é regra de gameplay faltando.

## O que proponho

Uma classe pura nova, `RegraDeHabitabilidade`, respondendo uma pergunta só:
**este ponto serve pra este arquétipo nascer?** Três recusas:

1. **Íngreme demais** — inclinação acima do limite de chão, para quem anda.
   Quem voa não é perguntado (§ o mesmo princípio da Fase 16: capacidade primeiro).
2. **Fundo demais para quem não nada** — a mesma faixa de profundidade da
   Fase 14, reusada, nunca reimplementada.
3. **Seco demais para quem só nada** — o simétrico, que hoje também não existe.

E o spawner **sorteia de novo** em vez de desistir: um número pequeno de
tentativas, e se nenhuma servir, não nasce ninguém neste tique. Desistir na
primeira recusa faria a densidade de spawn cair perto da costa e da falésia sem
que nada dissesse por quê.

## O que esta RFC NÃO propõe

- mudar a faixa de água, a regra de travessia ou o limite de voo — tudo já
  decidido nas Fases 14/15 e apenas **reusado** aqui;
- mudar o terreno, a resolução ou a geração — nada disso é meu;
- navegação (pathfinding) que desvia de parede: é outro problema, e maior.

## Dependência

Precisa de `Terreno3D.inclinacao_em` continuar lendo a superfície de **colisão**
— o que a RFC-006 acabou de garantir. Antes dela, esta regra teria consultado
uma inclinação que a física não tem.

## Decisão

_Aguardando o Gabriel. Não implementado._
