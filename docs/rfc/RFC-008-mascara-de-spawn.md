# RFC-008 — Máscara de spawn: onde um corpo pode nascer

**Status:** IMPLEMENTED · autorizada pelo Gabriel em 19/09/2026
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

**Autorizada pelo Gabriel em 19/09/2026** (*"pode seguir com a rfc 8"*) e
implementada no mesmo dia.

- `scripts/gameplay_v3/mundo/RegraDeHabitabilidade.gd` — classe pura, nenhum
  autoload citado. A metade molhada é **delegada** a
  `RegraDeTravessia.pode_estar_em`, nunca recopiada; o teste compara as duas em
  toda combinação de arquétipo × superfície molhada e reprova se divergirem.
- `SpawnerSelvagem3D.tentar_nascer()` passou a sortear até
  `RegraDeHabitabilidade.TENTATIVAS` pontos e a guardar
  `ultimo_motivo_de_recusa` — "o spawn falhou" sem motivo é a mesma classe de
  silêncio que este projeto passou o mês caçando.
- `scripts/tests/teste_rfc008_mascara_de_spawn.gd` — **29 conferências, 0
  falhas.**

### 🔴 A medição corrigiu o meu próprio número

Escrevi `TENTATIVAS = 6`, raciocinando a partir dos 3,25% de parede da RFC-006.
Estava errado **por uma ordem de grandeza**: medido no laboratório, um
terrestre é recusado em **38,7% dos pontos** — e o que domina não é a falésia
(278 recusas) e sim a **água** (2.390). Um mapa com costa recusa muito mais que
um com morro.

Com 38,7%, seis tentativas falhariam todas em 1 a cada ~300 tiques, o bastante
pra ralear o mundo perto da praia em silêncio. **10** leva isso a 1 em ~14.000.

### 🔴 Segundo achado, e ele não é desta regra

`HOVERING` **não está em `MovementProfile.IMPLEMENTADOS`** — `obter()` devolve o
perfil de `ground_biped` com aviso, então `voa` vira `false` e quem paira é
tratado hoje como quem anda, inclusive aqui. O teste afirma **o que é verdade**,
não o que eu gostaria: quando a §15 for implementada, aquela linha reprova,
avisando que o comportamento mudou sozinho.

### O que continua fora

Navegação que desvia de parede (pathfinding) — outro problema, e maior. E a
regra de água/penhasco em si não foi tocada: é reuso das Fases 14/15.
