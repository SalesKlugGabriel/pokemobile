# Fila de execução Codex — V3 3D

**Atualizada em 18/09/2026.** Fonte de estado: `docs/QUADRO.md`, propostas do
Gabriel e contratos do Claude. Esta fila é da camada visual; não autoriza mudar
gameplay, dados, spawn, colisão ou controles sem RFC aceita.

## Ordem de trabalho

| Prioridade | Entrega | Estado | Dependência / gate | Próxima ação objetiva |
|---:|---|---|---|---|
| P0 | PLAYER 3D V1 | em execução; blockout reprovado visualmente | folha de referência disponível; escala decidida em 1,60 m | refinar malha e comparar os cinco ângulos; só então rig, GLB e cena isolada |
| P0 | Revisões cruzadas pendentes | pendente | RFC-001 e RFC-GAMEPLAY-V3 estão em `REVIEW` para Codex | revisar contrato e registrar decisão/questões separadamente do trabalho visual |
| P1 | Contrato World Factory | auditoria concluída; implementação bloqueada | RFC-006 precisa de decisão do Claude sobre altura/colisão e reservas | não gerar WORLD_LAB nem alterar `Terreno3D` até decisão; preparar apenas documentação/validador isolado |
| P1 | HUD 3D de combate | pronto para consumo | API da Fase 10–12 já expõe cooldowns, recusa e telegrafia | desenhar integração incremental em componente visual, sem recalcular regra |
| P2 | VFX de combate | pronto para consumo | Fase 10 concluída; usar sinais reais do `EventBus` | protótipo limitado para aviso e acerto, com orçamento e limpeza garantida |
| P2 | Modelos de Pokémon seguintes | contínuo | #6, #18 e #130 aprovados; contrato de GLB e animações | escolher espécie que aparece no slice após confirmar dado/uso, um modelo por vez |
| P3 | Qualidade do mundo | depende da World Factory | WORLD_LAB precisa passar terreno antes de vegetação | rochas → árvores → grama → água/costa, nunca expandir o mapa antes do laboratório |
| P3 | Polimento Fase 19 | posterior | fases de gameplay 14–18 e integrações visuais | screenshots real desktop e celular, acessibilidade e desempenho |

## Regras de bloqueio

- `RFC-006`: a divergência medida entre altura consultada e colisão alcança 1,7922 m.
  Não mascarar o problema com offset de mesh ou colocar entidades por uma fonte de
  altura diferente.
- O asset do treinador continua em `BLOCKOUT_NOT_READY`; não exportar nem trocar
  a cápsula de `TrainerController3D` enquanto o gate visual, rig e Godot não
  tiverem passado.
- A Fase 14–15 do Claude está em trabalho na outra worktree. Não executar a suíte
  completa enquanto houver processo Godot dele e não editar os arquivos de gameplay.
- O mundo usa seed própria e mantém landmarks, quests, NPCs e warps acima do
  scatter visual. Instância procedural não é autorização para deslocar geografia.

## Critério para mover cada item

1. **Treinador:** silhueta, roupa e mochila reconhecíveis contra a folha nos cinco
   ângulos; depois deformação, animações in-place, GLB e cena Godot isolada.
2. **World Factory:** RFC aceita; contrato de altura testado; WORLD_LAB sem
   vegetação aprovado antes de qualquer lote de árvores/grama.
3. **HUD/VFX:** consumir somente sinais e métodos de gameplay existentes; um teste
   visual não pode alterar cooldown, dano, alcance ou timing de combate.
4. **Modelo Pokémon:** validar altura, origem nos pés, frente -Z, materiais,
   animações por papel e importação Godot antes de declarar pronto.
