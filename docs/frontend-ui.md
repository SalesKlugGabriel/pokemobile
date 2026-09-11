# UI e contrato do gameplay

Responsável: Codex. Fonte conferida: `EventBus.gd` e `FollowerPokemon.gd` em 11/09.

| Evento real no EventBus | O que a apresentação recebe |
|---|---|
| `follower_changed(pokemon_data: Dictionary)` | Mudança do líder; atualizar referências/estado inicial |
| `follower_hp_changed(current: int, maximum: int)` | HP real; desenhar barra, sem ler save a cada golpe |
| `follower_fainted(pokemon_data: Dictionary)` | Desmaio do líder |
| `follower_skill_used(slot: int, move_id: String)` | Slot usado, índice começando em zero |
| `follower_skill_cooldown_updated(slot: int, progress: float)` | Progresso de recarga: 1 significa completa |
| `wild_pokemon_selected(pokemon: Node)` | Alvo selecionado |
| `wild_pokemon_hp_changed(pokemon: Node, current: int, maximum: int)` | HP do alvo |
| `damage_dealt(target: Node, amount: int, is_critical: bool, attacker: Node)` | Feedback do dano já resolvido |
| `status_applied(target: Node, status_id: String)` | Aplicação de status; não implica contrato de remoção |
| `pokemon_level_up(pokemon_data: Dictionary, new_level: int)` | Nível ganho |
| `pokemon_evolved(from_id: int, into_id: int)` | Evolução |

Os nomes `pokemon_hp_changed`, `skill_cooldown_changed` e `target_changed` do
exemplo de planejamento NÃO foram verificados como APIs existentes; não os usar.
Para dados sem evento suficiente (remoção de status, estado de boss, troca de kit),
registrar a lacuna no handoff e combinar contrato, sem inventar sinal silenciosamente.

## Requisitos

- Barra dinâmica de 4–8 slots a partir de `move_slots`, espaços vazios/desabilitados,
  recarga, alvo, HP, nível, status e estado de boss quando exposto pelo gameplay.
- Inicializar com estado real ao abrir tela; depois atualizar incrementalmente por
  sinais. Não inferir HP vivo do save nem reexecutar a fórmula de capacidade.
- Desconectar sinais/liberar referências quando o alvo ou líder sair da cena.
- Touch targets legíveis, menus sem cortes em portrait/landscape e desktop;
  manter ponte de toque do export e remapeamento de teclas existentes.
- Não reconstruir a HUD a cada frame. Meta de 60 FPS; medir antes de afirmar.
- 11/09: `OverworldHUD.gd` está sendo editado pela sessão de gameplay anterior à
  divisão. Codex aguardará commit/integração antes de editar o mesmo arquivo.
