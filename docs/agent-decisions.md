# Decisões entre agentes

Registro curto e definitivo das decisões que cruzam gameplay e apresentação.
Uma decisão só entra aqui **depois** de proposta + revisão (ver `docs/rfc/`).

Formato: número, título, o que ficou acordado de cada lado, e quem implementa.
Decisão registrada aqui **vale mais que documentação antiga** de qualquer área.

---

## D-001 — Gameplay V2 nasce paralela, sem tocar na fórmula compartilhada

**Data:** 13/09/2026 · **RFC:** `RFC-GAMEPLAY-V2` · **Veredito:** aprovado com
ressalvas pelo Codex.

**Acordado:**

- A V2 vive em `scripts/gameplay_v2/` + `scenes/gameplay_v2/`. O jogo atual
  continua rodando intacto. Rollback = apagar as duas pastas.
- **A V2 não edita `scripts/combat/`.** `DanoV2.gd` embrulha
  `DamageCalculator`; `BalanceV2.gd` estende `CombatBalance`. A V1 mantém
  crítico e variação; a V2 é determinística.
- **Câmera:** `CameraDeCombate.gd` local ao Laboratório, do Codex. Não migrar as
  36 cenas agora, não criar autoload de câmera. Claude emite
  `contexto_de_camera(nome, prioridade)`; boss 30 > combate_grande 20 >
  interior 10 > exploração 0.
- **Telegrafia:** string + parâmetros já resolvidos em pixels de mundo, com
  `cast_id` e `golpe_encerrado(motivo)`. A UI desenha e nunca converte tile em
  pixel nem decide o fim por timer próprio.
- **`damage_dealt(target, amount, is_critical, attacker)` mantém a assinatura**;
  a V2 passa `false`. Achado conferido: os 3 emissores **já passam `false`** —
  o visual de crítico nunca dispara hoje, então removê-lo custa zero.
- **`EstadoV2.instantaneo()`**: leitura única do estado vivo, pra HUD nascer
  certa ao abrir. Só sinal de mudança não bastava.
- **Stamina não atrasa** pela RFC-001: entra no passo 2, junto do movimento.
- **Laboratório:** build de teste separada, sem mexer na entrada de produção.
- **Fora do protótipo, de propósito:** Held Items, PvP, Market, Housing, Bag de
  30 slots, Storage, XP multi-jogador.

**Em aberto:** quem manda em `cast_time`. Claude argumenta que é regra de
combate (janela de interrupção e esquiva), não timing visual. Esperando o Codex.

**Implementa:** Claude os passos 1, 2 e 6 (movimento, stamina, dano). Codex a
câmera, a HUD e a telegrafia.

---

## D-002 — RFC-001 (slots dinâmicos de skill): contrato aprovado

**Data:** 13/09/2026 · **Revisão:** `docs/agent-reviews/codex/RFC-001.md`

Contrato aceito pelo Codex: `KitDeCombate` calcula a capacidade e a UI não
repete a regra; `use_skill(slot)` continua sendo a porta; a UI não converte
progresso de recarga em segundos pelo cooldown do JSON.

**O stopgap na `OverworldHUD.gd` fica** (o Codex não pediu reversão) até a
substituição visual dele — mantém os slots 5 a 8 alcançáveis. Isso **não** é
aprovação do layout atual para celular.

**Pendência levantada pelo Codex, conferida — real, mas não é bug.** Os dois
emissores de `follower_changed` garantem coisas diferentes:

| Emissor | `moves` | `max_skill_slots` |
|---|---|---|
| `FollowerPokemon:118` | `move_slots` | `move_slots.size()` — **sempre iguais** |
| `SaveManager.trocar_kit():624` | `novo_equipado` | `max_skill_slots(index)` — **contados à parte** |

Ou seja: um Charizard de 8 slots com 5 golpes equipados sai do segundo caminho
com `moves.size() = 5` e `max_skill_slots = 8`. A frase *"`moves` sempre tem
exatamente a capacidade"* é **falsa** por esse caminho.

**Não quebra nada hoje:** `OverworldHUD.gd:100` já trata com
`if i < moves.size() else ""`, e o resultado é o correto — slot que existe e
está vazio aparece vazio. Fica registrado como **contrato a corrigir no texto**,
não como conserto de código: quem escrever uma tela nova não pode assumir a
igualdade.
