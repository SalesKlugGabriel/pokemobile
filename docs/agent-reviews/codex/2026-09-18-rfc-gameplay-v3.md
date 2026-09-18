# Revisão Codex — RFC-GAMEPLAY-V3-3D após a implementação

**Data:** 18/09/2026  
**Papel:** cliente, apresentação e assets 3D  
**Base verificada:** `be72e95` (`agent/claude-v3`) e `fa0f818` (`agent/codex-v3`)

## Veredito

**A arquitetura visual é compatível com a V3 entregue até a Fase 18.** Não há
pedido de mudança de fórmula, input ou contrato de gameplay nesta revisão.

A RFC original é útil como justificativa do pivô, mas não deve ser tratada como
estado operacional: ela ainda afirma que não havia código/cena 3D, zero modelos
e que a decisão billboard × modelo estava aberta. Esses fatos foram superados
pela implementação. O documento de estado é o `docs/QUADRO.md`.

## Evidências verificadas

| Item da RFC | Estado atual | Evidência |
|---|---|---|
| Mundo e combate isolados da V2 | Preservado | `scripts/gameplay_v3/` e `scenes/gameplay_v3/Laboratorio3D.tscn` coexistem com V2 |
| Um árbitro de input por modo | Implementado | `controle/ControlModeManager.gd` troca o dono do input antes de ativar o próximo |
| Terreno consultável | Implementado, com contrato pendente para fábrica | `mundo/Terreno3D.gd::altura_em(x, z)` |
| Retorno COMBAT → WORLD | Implementado | commit `7a17d25`, Fase 13 |
| Surf e voo | Implementados | commit `3160d20`, Fases 14–15 |
| Modelos 3D | Decidido e iniciado | `assets/models/pokemon/{6,18,130}.glb`; `PokemonInstance3D.gd` + `ValidadorDeModelo.gd` |
| Sinais para apresentação de skill | Implementados | `EventBus.skill_anunciada`, `skill_cancelada` e `golpe_resolvido` |

## Decisões de apresentação que ficam confirmadas

1. A escolha para o vertical slice é **modelo 3D**, não billboard. Charizard,
   Pidgeot e Gyarados são a prova inicial; o fallback para espécies sem modelo
   deve continuar explícito e não silencioso.
2. O contrato de asset continua: GLB, 1 unidade = 1 metro, origem nos pés e
   frente no eixo −Z. O `ValidadorDeModelo` é a proteção de integração, não um
   substituto para export correto.
3. A HUD de combate deve consumir os sinais e dados já calculados. Não pode
   reconstruir geometria de telegraph, dano, recarga ou efetividade.
4. A World Factory permanece bloqueada pela RFC-006: não criar terreno/bioma
   novo até que a altura consultada e a malha de colisão tenham a mesma fonte de
   verdade.

## Riscos visuais ainda abertos

| Risco | Estado | Próximo responsável |
|---|---|---|
| Treinador V1 ainda parece blockout | Não aprovado; sem GLB/rig/animação V1 | Codex |
| Cápsula de gameplay mede 1,75 m enquanto o asset-alvo mede 1,60 m | Integração requer revisão cruzada | Codex + Claude |
| HUD V3 para cooldown/telegrafia ainda não existe | Dados estão prontos, apresentação não | Codex |
| `Terreno3D.altura_em` diverge da colisão em até 1,7922 m | RFC-006 proposta | Claude decide contrato; Codex implementa só depois |
| FPS web/mobile do art pass não foi medido | Benchmark existente é desktop e não certifica mobile | Codex após cena integrada |

## Delimitação

Esta revisão não muda o status da RFC-GAMEPLAY-V3-3D: o revisor formal indicado
nela é Gabriel. Ela também não declara a V3 validada visualmente nem aprova o
treinador V1. Serve para que próximas tarefas não reconstruam um plano já
executado nem voltem à decisão de billboard sem uma nova RFC.
