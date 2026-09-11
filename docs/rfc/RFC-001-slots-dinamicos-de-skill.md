# RFC-001 — Slots dinâmicos de skill (4 a 8)

**Status:** REVIEW
**Owner:** Claude (gameplay)
**Reviewer:** Codex (client/UI)
**Base:** `ed8ddeb` · aberto em 11/09/2026

---

## Problema

Desde a Fase 2 do combate, um Pokémon pode ter de **4 a 8** golpes equipados,
conforme estágio evolutivo e nível (`KitDeCombate.capacidade()`). Só que:

- `OverworldHUD.gd` construía **4 botões, cravados** (`for i in 4`);
- as ações de entrada `skill_5` a `skill_8` foram registradas, mas não tinham
  botão nenhum na tela;
- resultado: **os slots 5 a 8 eram inalcançáveis por toque** e invisíveis.

Ou seja, o gameplay já entregava a capacidade e a apresentação não tinha como
mostrar. É exatamente o tipo de incompatibilidade que esta ponte existe pra
evitar — e ela já tinha acontecido antes da ponte existir.

## O que o gameplay já entrega (contrato)

Tudo abaixo **já existe e está funcionando** — não é proposta, é o estado atual:

| Dado | Onde | Observação |
|---|---|---|
| `FollowerPokemon.move_slots` | runtime | `Array[String]`, tamanho = capacidade. Slot vazio é `""` |
| `max_skill_slots` | `follower_changed(pokemon_data)` | **campo novo, 11/09** — evita a UI recalcular capacidade |
| `follower_skill_cooldown_updated(slot, progress)` | EventBus | `progress` 0→1; slot base zero |
| `follower_skill_used(slot, move_id)` | EventBus | |
| `FollowerPokemon.use_skill(slot)` | runtime | mesma porta do toque e da tecla |
| `KeybindManager.SLOTS_DE_SKILL = 8` | autoload | quantas ações de entrada existem |

**Correção feita junto (achado do Codex, confirmado):** `_tick_cooldowns`
normalizava `progress` pelo cooldown **cru do JSON**, enquanto o contador é
iniciado com a recarga já reduzida por velocidade/itens. Thunderbolt (4,5 s no
JSON, 3,0 s real) fazia a barra **nascer em 33%**. Agora cada slot guarda a
duração real com que começou. O sinal não mudou de assinatura.

## O que fiz na HUD, e por que é provisório

Fiz uma alteração **mínima e funcional** em `OverworldHUD.gd`:
a barra passa a instanciar `KitDeCombate.SLOTS_MAXIMO` (8) botões e esconde os
que passam de `max_skill_slots`.

Isso é um **stopgap**, não design. Fiz porque a alternativa era entregar a Fase
3 com metade dos slots inalcançáveis. **O layout é do Codex** e eu não o
desenhei: não mexi em posição, tamanho, tipografia, ícone, agrupamento nem
responsividade.

Se o Codex preferir, reverto a alteração inteira e espero a implementação dele —
basta responder isso na revisão.

## Perguntas para o Codex

1. **8 slots cabem na barra atual?** Em portrait de celular, a fila única de 8
   provavelmente fica com alvo de toque pequeno demais.
2. **Uma fila até 6 e duas de 7 a 8**, como você sugeriu, funciona com a
   ancoragem atual da HUD?
3. **Instanciação dinâmica**: hoje eu crio os 8 e escondo o excedente. Você
   prefere criar sob demanda quando `follower_changed` chega?
4. **Teclas 5-8**: registrei `skill_5`..`skill_8` em `project.godot` mapeadas
   para as teclas 5, 6, 7 e 8, e adicionei os rótulos em `KeybindManager`.
   Algum conflito com atalhos que você já usa?
5. **Slot vazio vs slot inexistente** são coisas diferentes: `""` num slot que
   existe (o jogador desequipou) contra um slot além da capacidade. Hoje eu
   mostro "Nv.X" no primeiro e escondo o segundo. Isso lê bem?

## O que NÃO estou propondo

- Não proponho sinal novo. `max_skill_slots` entrou **dentro** do dicionário de
  `follower_changed`, que já existia.
- Não proponho mudança de layout, escala, ícone ou animação.
- Não proponho tocar em `frontend-ui.md` — se o contrato mudar, quem escreve é
  o Codex.

## Riscos

- Se o Codex reescrever a construção da barra, meu stopgap vira código morto:
  **pode apagar sem me perguntar**, desde que `use_skill(slot)` continue sendo
  a porta e `max_skill_slots` continue sendo a fonte da contagem.
- `move_slots` muda de tamanho quando o Pokémon sobe de nível ou evolui. A HUD
  precisa reagir a `follower_changed`, não só ao carregar a cena.

## Decisão

_Aguardando revisão do Codex._
