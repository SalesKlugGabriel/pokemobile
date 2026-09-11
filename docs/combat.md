# Combate — responsabilidade e interfaces

Responsável pela regra: Claude. Fonte: implementação, não esta descrição.
Referência detalhada: [auditoria-combate.md](auditoria-combate.md), incluindo Fase 2;
a primeira seção descreve o estado ANTERIOR à reengenharia.

- `StatsDePokemon.gd`: stats compartilhados; `DamageCalculator.gd`: dano/tipos.
- `CombatBalance.gd`: constantes e modificadores de balanceamento.
- `KitDeCombate.gd`: capacidade, estágio evolutivo e montagem do repertório.
- `FollowerPokemon.gd`: estado real do líder e uso dos golpes.
- `WildPokemon.gd` / `ComportamentoSelvagem.gd`: selvagens e comportamento.
- `ChefeLendario.gd`, `StatusEffectController.gd`, `BattleResolver.gd`,
  `CaptureSystem.gd`: chefe, status, resolução e captura.

## Slots

`KitDeCombate.capacidade(species_id, nivel, especies)` calcula 4 slots de base,
bônus de nível (50: +1; 100: +2 no total), bônus de estágio evolutivo (0/1/2),
teto 8. Charmander/Charmeleon/Charizard Lv100: 6/7/8. A classificação de estágio
para espécies com cadeias diferentes pertence ao kit, não à HUD.

`FollowerPokemon.move_slots: Array[String]` é a lista no runtime; strings vazias
representam espaço sem golpe. **Não existe propriedade `max_skill_slots` verificada
nesse commit.** Renderizar `move_slots.size()`; não recalcular evolução na tela.

## Limitação observada para handoff

O sinal de cooldown é progresso (0→1), não segundos restantes. No código consultado,
`_tick_cooldowns` divide tempo restante pelo cooldown dos dados, enquanto iniciar
o golpe aplica `CombatBalance.recarga`. Revisar a normalização no gameplay para
velocidade/itens antes de prometer exatidão temporal na UI; Codex não corrige isso
alterando fórmula ou mantendo um cronômetro concorrente.
