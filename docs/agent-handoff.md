# Passagem de trabalho — 11/09/2026

## Workspaces e coordenação

- Gameplay em andamento: `/root/pokemobile`, branch `main`, base observada `ed8ddeb`.
  Sessão já estava aberta antes do acordo: NÃO mover nem limpar seus arquivos.
- Codex: `/root/pokemobile-visual`, branch `visual-natural-20260911`, mesma base.
- Worktree Claude preparada: `/root/pokemobile-claude`, branch `agent/claude`,
  commit `07eb5fd` (documentação). Ainda NÃO contém alterações da sessão ativa.
- Regra nova: worktrees exclusivas; próxima sessão Claude deve usar `agent/claude`
  após checkpoint da sessão atual. Nomes de diretório não precisam mudar.
- Sincronizar commits completos/revisados; nunca copiar alterações não commitadas
  do outro agente. Nenhuma atualização deste arquivo prova que outra sessão o leu.

## Gameplay observado (Claude)

Commit `ed8ddeb`: Fase 2 do combate, capacidade 4–8, precisão, balanceamento e IA.
O commit registra 103 testes sem falha; Codex não reexecutou essa suíte ainda.

Arquivos modificados na sessão ativa, ainda sem commit na inspeção:
`SaveManager.gd`, `KitDeCombate.gd`, `FollowerPokemon.gd`, `OverworldHUD.gd`.
Codex não alterará esses arquivos enquanto estiverem em uso.

Contrato real: `FollowerPokemon.move_slots`,
`EventBus.follower_hp_changed(current, maximum)`,
`EventBus.follower_skill_cooldown_updated(slot, progress)`; ver frontend-ui.md.
Não há `max_skill_slots` verificado. Nenhum sinal novo foi criado por Codex.

Para Claude revisar: normalização de cooldown em `_tick_cooldowns` usa valor base
do JSON, enquanto início usa recarga modificada por speed/itens. Ver combat.md.

## Visual em preparação (Codex)

Implementado na worktree, **ainda não validado/publicado**:
- `scripts/world/systems/AcabamentoNatural.gd`: bordas naturais e sombra de mata,
  somente no retângulo visível; não escreve células nem gameplay.
- `assets/shaders/ambiente_pixel.gdshader`: reflexos discretos apenas na água azul.
- `scripts/world/BaseMap.gd`: ligação mínima do componente visual após pintar mapa.
- Redesenho das quatro árvores grandes: geração solicitada; asset não integrado ainda.

Documentação criada: AGENTS.md, CLAUDE.md, ARCHITECTURE.md, combat.md,
frontend-ui.md, art-direction.md, world-design.md e este handoff.

Falta: terminar importação Godot na worktree, validar código/efeitos, integrar arte,
comparar screenshots e testar desktop/mobile antes de integrar/publicar.
Nenhuma fórmula, learnset, save ou HUD foi alterado por Codex.

## Revisão cruzada recebida durante o trabalho

Claude acrescentou RFC-001 na sua worktree. Codex leu e aceitou o contrato proposto,
com respostas em `docs/agent-reviews/RFC-001-codex.md` nesta branch. Manter o stopgap
de oito controles reutilizáveis; layout e rótulo de slot vazio serão tratados após
integrar o commit. A resposta não modifica a árvore ativa de Claude.
Proposta do ponto de integração ambiental em `docs/agent-proposals/ambiente-natural-codex.md`.
