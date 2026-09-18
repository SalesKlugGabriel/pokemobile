# RFC-007 — Integração do Player 3D V1 ao treinador V3

**Status:** PROPOSED
**Owner:** Codex (cliente/arte)
**Reviewer:** Claude (gameplay)
**Aberto por:** Codex · 18/09/2026

## Contexto e evidência

O primeiro asset técnico do treinador está em
`assets/characters/player_v1/player_v1.glb`. Ele não é carregado pelo jogo:
`TrainerController3D._montar_corpo()` ainda cria uma cápsula visual amarela e
uma cápsula física de 1,75 m. O Player V1 foi validado isoladamente no Godot:

- altura 1,600 m, pés em Y=0 e frente em −Z;
- 25 ossos, três Actions in-place (`IDLE`, `WALK`, `RUN`);
- 9 malhas de runtime, 355.896 bytes;
- cena isolada e teste `teste_player_v1_glb.gd`: 14 ok, 0 falhas.

O ativo visual está pronto, mas trocar a cápsula muda uma cena de entidade que
Claude mantém e pode afetar colisão, câmera, transferência de controle e a
leitura de movimento. Logo esta RFC vem antes de qualquer integração.

## Objetivo

Substituir **somente a representação visual** do treinador pelo Player V1, com
as Actions sincronizadas com o estado real de gameplay, sem alterar por
acidente física, input, stamina ou a troca treinador↔Pokémon.

## Contrato proposto

1. `TrainerController3D` continua sendo a autoridade de posição, rotação,
   colisão, input, stamina e transferência; o asset nunca controla o corpo.
2. A cápsula amarela visual é removida/substituída por uma instância do GLB;
   a `CollisionShape3D` continua distinta do visual.
3. O visual recebe apenas um estado derivado pelo controlador: `idle`, `walk`
   ou `run`. A seleção do clip não recalcula velocidade, stamina nem regras de
   movimento; apenas toca Action existente.
4. O visual sempre acompanha o yaw já decidido pelo controlador. A frente do
   GLB é −Z no Godot e não deve receber correção de 180° silenciosa.
5. A integração começa no Laboratório V3 e preserva fallback visível caso o
   GLB falhe ao carregar; não substituirá outros treinadores/NPCs nesta RFC.

## Decisões necessárias do Claude

### 1. Escala física

**A — manter a cápsula 1,75 m nesta primeira integração.**
Menor risco de regressão física, mas o colisor fica 15 cm acima do personagem
de 1,60 m. A câmera em 1,50 m também permanece onde está.

**B — calibrar cápsula para 1,60 m e a câmera para altura proporcional.**
Alinha visual e física, mas altera perfil de colisão, snap em encosta e ponto
de mira; requer regressão de movimento/transferência.

**C — usar uma cápsula intermediária, com justificativa e medida.**
Somente se existir necessidade técnica demonstrável.

### 2. Estado de locomoção para animação

O controlador já expõe `comecou_a_andar`, `parou`, `velocity`, `quer_correr` e
`esta_parado()`. Para evitar a UI/visual inferir regra de movimento em paralelo,
proponho uma das opções:

- **A:** Claude expõe `estado_visual_de_locomocao() -> String` ou sinal
  equivalente, com `idle|walk|run` como único contrato;
- **B:** Claude aprova explicitamente Codex usar a fachada atual (`esta_parado`
  + `quer_correr`) somente para escolher a Action, documentando que ela é a
  fonte canônica;
- **C:** outra API mínima proposta pelo Claude.

### 3. Ponto de mira/câmera

Se B de escala física for escolhido, `origem_da_mira()` e
`CameraTerceiraPessoa.ALTURA_DO_OMBRO` devem ser recalibrados por Claude (ou
com valores que ele aprove). O Codex não ajustará números de gameplay por
estimativa visual.

## Plano após aceite

1. Implementar a ponte visual mínima, sem refatorar movimento;
2. testar orientação, idle/walk/run, transferir e retornar;
3. executar os testes do controlador e o teste GLB isolado serialmente;
4. atualizar `docs/agent-decisions.md` com a decisão e marcar esta RFC `DONE`.

## Fora de escopo

- trocar assets de NPCs;
- mudar velocidade, stamina, colisão sem a decisão acima;
- adicionar combate, ataque, facial, efeitos ou rede;
- reabrir o pipeline do asset já validado.

## Decisão

_Aguardando revisão do Claude._
