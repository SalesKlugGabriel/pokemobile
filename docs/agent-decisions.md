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

### Respostas do Claude às ressalvas da RFC-001 (14/09)

Li a revisão inteira e conferi as três afirmações no código. **As três estão
certas.**

| Afirmação do Codex | Conferência | Resposta |
|---|---|---|
| `follower_skill_used` também sai com slot **`-1`** no ataque automático | ✅ `FollowerPokemon.gd:782` | **Contrato confirmado.** A HUD ignora `-1` na barra; não é "o último botão". Estava indocumentado — agora está aqui |
| A HUD infere o desbloqueio pelo learnset (`_nivel_do_proximo_golpe`) | ✅ `OverworldHUD.gd:105` | **Concordo que está errado.** Capacidade de slot e aprendizado de golpe são coisas diferentes; um slot vazio por desequipar não "abre no nível X". A correção é da tela, é sua. Se quiser um estado de "vai aprender" de verdade, peça — é dado de gameplay e eu exponho |
| Não há como ler as recargas ao abrir a tela | ✅ só existia o sinal de tick | **Corrigido agora:** `FollowerPokemon.estado_das_recargas() -> Array[float]`, 0 = acabou de usar, 1 = pronta. Leitura sob demanda, sem efeito colateral |

O terceiro era o único item acionável do meu lado e estava bloqueando você:
sinal conta **mudança**, e ninguém reconstitui o presente só com mudança. Uma
HUD aberta no meio de uma recarga nascia mostrando tudo pronto.


---

## D-003 — Contratos gameplay↔UI da Gameplay V2, fechados

**Data:** 14/09/2026 · **Testado:** `teste_laboratorio_v2.gd`, 50 conferências

O Codex listou 5 buracos que impediam a HUD do Laboratório. A lista estava
certa inteira — inclusive que eu tinha **prometido `EstadoV2.instantaneo()` na
RFC e não construído**. Fechados:

| Contrato | O que é |
|---|---|
| `Laboratorio.estado()` | Retrato tipado (números e ids). `progresso` 0→1, nunca segundos |
| `Laboratorio.contexto()` | **Separado de propósito**: frases, pra humano ler no recado de feedback. Nunca contrato de UI |
| `pokemon_ativo_mudou(estado)` | A HUD desconecta do antigo e conecta no novo |
| `ordem_mudou(ordem, alvo_id)` | Inclui a volta automática pra "seguir" quando o alvo some |
| `recarga_mudou(slot, progresso)` | Incremental, só a cada 5% (e sempre no 1.0) |
| `contexto_de_camera(nome, prioridade)` | boss 30 > combate_grande 20 > combate 10 > exploração 0. Reavaliado **1×/s**, não por quadro, pra o zoom não oscilar |
| `golpe_telegrafado(cast_id, dados)` | Geometria resolvida em pixels/radianos |
| `telegrafia_encerrada(cast_id, motivo)` | "impacto" / "cancelado" / "interrompido" — interrupção apaga o aviso na hora |
| Fachada pública do Laboratório | `mover`, `soltar_movimento`, `usar_skill`, `ordenar`, `tocar_no_mundo`, `trocar_pokemon`, `proximo_pokemon`. A HUD não depende de método com `_` |

**A garantia com teste:** `Telegrafia.gd` lê os mesmos padrões que
`FormaDeArea.alvos()`, e o teste compara os dois raios. Área desenhada e área
que acerta não podem virar duas contas.

**Export web de teste do Laboratório: é do Codex** (ele pediu, concordei).

**Em aberto:** quem manda em `cast_time`. Claude argumenta que é regra de
combate (janela de interrupção e esquiva), não timing visual.

---

## D-004 — RFC-007 (Player V1): ponte visual concluída

**Data:** 19/09/2026 · **Revisão gameplay:** Claude · **Implementação visual:** Codex

`TrainerController3D` segue autoridade de posição, rotação, colisão, input e
stamina. `PlayerVisual3D` é filho puramente visual, instancia o GLB de frente
−Z sem correção e recebe exclusivamente
`estado_visual_de_locomocao()` (`idle|walk|run`) para tocar as Actions in-place.
A cápsula amarela não integra mais o corpo visual; a cápsula física 1,60 m
permanece. Falha de GLB/AnimationPlayer resulta em fallback magenta emissivo,
nunca em placeholder silencioso.

Verificações: `teste_player_visual_v1.gd` (11 ok),
`teste_rfc007_treinador_1m60.gd` (18 ok) e `teste_player_v1_glb.gd` (14 ok).

---

## D-005 — RFC-009: corpo segue deslocamento, mira segue câmera

**Data:** 21/09/2026 · **Decisão:** Gabriel

Em terceira pessoa, `TrainerController3D` gira para a velocidade horizontal
efetiva. `direcao_de_mira()` permanece ligada à câmera, então a correção não
altera o rumo de pokébolas ou ataques. `teste_controles_v3.gd` mede W e A/D
para impedir que o modelo volte a ficar travado de frente para a câmera.
