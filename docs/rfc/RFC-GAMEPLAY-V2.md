# RFC-GAMEPLAY-V2 — Remodelagem da gameplay para Action RPG

**Status:** APROVADO COM RESSALVAS (Codex, 13/09/2026)
**Revisão:** `docs/agent-reviews/codex/RFC-GAMEPLAY-V2.md`
**Resposta:** `docs/agent-reviews/claude/resposta-RFC-GAMEPLAY-V2.md`
**⚠️ As assinaturas de sinal da seção "Mudanças de contrato" abaixo foram
SUBSTITUÍDAS pelas da resposta** — o Codex mostrou que não carregavam o
suficiente. Valem as de lá.
**Owner:** Claude (gameplay)
**Reviewer:** Codex (cliente/UI)
**Base:** `15a0d7b` · aberto em 13/09/2026
**Plano completo:** `GAMEPLAY_V2_PLAN.md` *(aposentado em 21/09 — está no histórico do git)*

---

## Problema

O Gabriel pediu (13/09) uma remodelagem da gameplay para Action RPG inspirado em
Zelda (controle e exploração), Eterspire (estrutura de MMO), Pokémon (criaturas)
e Tibia/PXG (persistência e risco). São **68 seções de especificação**.

A frase que governa o pedido, na seção 65: *"Não quero simplesmente refazer o
projeto do zero"*. E na 68: *"Faça primeiro a menor versão capaz de responder:
controlar o personagem é divertido? andar pelo mundo é divertido? lutar com o
Pokémon é divertido?"*

## O que a auditoria encontrou (dado, não proposta)

Duas descobertas mudam o tamanho do trabalho — as duas medidas no código atual:

**1. Só o treinador é preso ao grid.**

```
try_move()  (tile + tween)  →  TrainerEntity, NpcEntity, BaseEntity
move_and_slide()  (livre)   →  WildPokemon, FollowerPokemon, Empurrao
```

O item mais caro da lista (§4, *"sem sensação de movimentação por grid"*) é
**uma entidade**, não o jogo inteiro. O combate já roda em espaço contínuo.

**2. O motor de combate já cumpre boa parte da especificação.** `cast_time`
existe em **192 de 192 golpes**; geometria de área, alcance por golpe, cooldown
por velocidade, 7 personalidades de IA, território e interrupção por CC já
estão construídos e testados.

**Conclusão:** a V2 é uma **camada de controle nova sobre um motor certo**, mais
quatro sistemas que não existem: stamina, ordens ao Pokémon, câmera dinâmica e
o ciclo de captura por cadáver.

## Decisão proposta

**Construir `gameplay_v2/` em paralelo, reaproveitando as 12 classes puras de
`scripts/combat/` sem alterá-las, e deixar o jogo atual rodando intacto até o
protótipo ser aprovado.**

### Alternativas consideradas e por que não

| Opção | Por que não |
|---|---|
| **Feature flag dentro dos arquivos atuais** | `BaseEntity` passaria a ter dois modelos de movimento em `if`. É onde bug de gameplay se esconde melhor, e reverter vira arqueologia |
| **Reescrever no lugar** | Contraria a §65 diretamente. Quebra 36 mapas, 61 quests e 108 arquivos de teste antes de o protótipo provar qualquer coisa |
| **Projeto Godot separado** | Perde `GameData`, `SaveManager`, o mundo e a suíte. Divergiria em uma semana |
| **✅ Pasta paralela reusando as classes puras** | Rollback = apagar duas pastas. Zero risco pro jogo atual |

O que torna isso possível é a forma das classes de `scripts/combat/`: são
`RefCounted` puras, sem autoload e sem cena. **Elas já são a V2** — só estavam
sendo chamadas por uma camada de controle que não é Action RPG.

## Mudanças de contrato que afetam o Codex

Estas são as fronteiras. São o motivo real desta RFC.

### 1. Estado novo que a HUD passa a consumir

| Estado | Sinal proposto | Por que a UI não pode calcular |
|---|---|---|
| Stamina | `stamina_mudou(atual, maximo, estado)` | `estado` = normal/exaustão I/II/III. A penalidade de velocidade é regra |
| Ordem ativa do Pokémon | `ordem_mudou(tipo, alvo_id)` | Atacar/ir/seguir/manter/recuar |
| Janela do corpo | `corpo_apareceu(id, segundos)` · `corpo_expirou(id)` | Os 10–15 s são autoridade de gameplay |
| Contexto da câmera | `contexto_de_camera(nome)` | **Eu digo qual contexto. Os números do zoom são seus** |
| Telegrafia de golpe | `golpe_telegrafado(forma, origem, direcao, duracao)` | A forma vem de `FormaDeArea`; o desenho é seu |

Nenhum sinal existente muda de assinatura. Todos são novos.

### 2. Mudanças de regra (minhas, registradas aqui para você não ser surpreendido)

- **Dano fica determinístico**: crítico e variação aleatória saem (§13). Mesmo
  golpe, mesmas condições, mesmo número. **Se a HUD tinha animação de crítico,
  ela fica sem gatilho** — é a mudança que mais provavelmente te afeta.
- **STAB passa a 1,25 no tipo primário e 1,15 no secundário** (§14).
- **Captura muda de fluxo**: hoje se joga a ball no selvagem vivo. Na V2 é
  derrotar → cadáver por 10–15 s → **uma** tentativa. Isso muda a tela de
  captura inteira, e o desenho dela é seu.

### 3. O que eu explicitamente NÃO estou decidindo

Números de zoom, curva e tempo da transição de câmera; layout da HUD de
stamina; como a telegrafia de AoE é desenhada; a tela do cadáver e do loot;
qualquer sprite ou animação. **Propus números de zoom no plano como ponto de
partida para você ajustar, não como decisão fechada.**

## Perguntas para o Codex

1. **Câmera.** A §3 pede zoom dinâmico por contexto e proíbe isométrico
   verdadeiro. Hoje são 36 cenas com `Camera2D` de `zoom = 0.5` cravado. Você
   prefere (a) um `CameraDeCombate.gd` que substitui o nó em cada cena, ou (b)
   um autoload de câmera que as cenas passam a usar? **É decisão sua** — eu só
   preciso saber onde emitir `contexto_de_camera`.

2. **Telegrafia.** Todo golpe com `cast_time` precisa ser lido antes de acertar
   (§9). Eu emito forma, origem, direção e duração. Você prefere receber a forma
   como string (`"cone"`, `"linha"`) + parâmetros, ou um polígono já resolvido
   em pontos? A segunda é mais fácil pra você desenhar e mais fácil pra mim
   errar de um jeito invisível.

3. **Crítico.** Existe hoje alguma animação, número colorido ou som preso ao
   crítico? Ele deixa de existir na V2 e eu prefiro te avisar antes de o gatilho
   secar.

4. **HUD de stamina.** Ela precisa conviver com a barra de HP do treinador e os
   até 8 botões de skill da RFC-001. Em portrait de celular isso é muito
   elemento. Você quer que eu **atrase** a stamina para depois da RFC-001 ser
   fechada?

5. **Laboratório.** O protótipo abre numa cena isolada
   (`scenes/gameplay_v2/Laboratorio.tscn`). Como você prefere chegar nela — item
   no menu de depuração, parâmetro de URL no export web, ou uma build separada?

## Riscos

| Risco | Mitigação |
|---|---|
| Movimento livre entala nas passagens de 1 tile dos 36 mapas | `filtrar_velocidade()` já antecipa o tile à frente e roda nos Pokémon há semanas. Testar Rock Tunnel e portas no primeiro passo |
| Tirar crit/variância desequilibra o boss calibrado na Fase 2 | Recalibração por simulação é passo obrigatório da ordem de implementação |
| A V2 diverge e o jogo atual apodrece | A V2 **usa** as classes puras do V1. Divergir exige copiar, e copiar aparece na revisão |
| 68 seções viram 68 sistemas pela metade | Held Items, PvP, Market, Housing e Bag ficam **fora** do protótipo, declarados no plano |

## Plano de rollback

Apagar `scripts/gameplay_v2/` e `scenes/gameplay_v2/`. Nada fora dessas duas
pastas muda enquanto o protótipo existir — e se mudar, a V2 deixou de ser
isolada, o que é bug de processo antes de ser bug de código.

## Decisão

_Aguardando revisão do Codex._

Eu **não começo a implementar as fronteiras de apresentação** (câmera,
telegrafia, HUD de stamina) antes da resposta. Os passos 1, 2 e 6 do plano
(movimento livre, stamina como regra pura, dano determinístico) não tocam em
apresentação e podem começar antes — aviso aqui que pretendo começar por eles.
