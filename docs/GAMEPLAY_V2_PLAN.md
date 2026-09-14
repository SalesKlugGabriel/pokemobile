# GAMEPLAY V2 — Plano

**Status:** proposta, nada implementado
**Autor:** Claude (gameplay) · **Revisor:** Codex (cliente/UI)
**Base auditada:** commit `15a0d7b`, 13/09/2026
**Pedido do Gabriel:** 68 seções de especificação, 13/09/2026

> Este documento é a **primeira entrega** pedida na seção 67. Ele diagnostica,
> decide e roteiriza. Nenhum arquivo de gameplay foi alterado para escrevê-lo.
> A decisão arquitetural formal está em `docs/rfc/RFC-GAMEPLAY-V2.md`.

---

## 0. Os dois achados que mudaram o plano

Eu esperava concluir que a gameplay V2 exigia reescrever quase tudo. **A medição
disse outra coisa**, e vale abrir por ela porque muda o tamanho do trabalho.

### Achado 1 — os Pokémon JÁ se movem livremente. Só o treinador é preso ao grid.

```
usa try_move()  (grid + tween)   →  TrainerEntity, NpcEntity, BaseEntity
usa move_and_slide() (livre)     →  WildPokemon, FollowerPokemon, Empurrao
```

O item mais caro da lista do Gabriel — *"sem sensação de movimentação por
grid"* — **não é uma reescrita do jogo inteiro. É uma entidade.** O combate
inteiro já roda em espaço contínuo, com colisão real
(`WorldManager.filtrar_velocidade()`), aceleração e empurrão.

### Achado 2 — o motor de combate já cumpre boa parte da especificação

Não por sorte: a reengenharia de 11/09 construiu exatamente estas peças.

| Pedido do Gabriel | Situação real |
|---|---|
| Cast time / leitura de ataque (§9) | ⚠️ o campo existe nos 192 golpes, **mas 108 deles valem `0.0`** — ver correção abaixo |
| Geometria de skill (§10) | ✅ `FormaDeArea.gd`: círculo, cone, linha, retângulo, anel, global |
| Alcance real por golpe (§10) | ✅ `FormaDeArea.no_alcance()`, já bloqueia com aviso na tela |
| Cooldown afetado por Speed (§12) | ✅ `CombatBalance.recarga()`, com teto |
| IA com personalidade (§26) | ✅ `ComportamentoSelvagem.gd`, 7 personalidades |
| Território / aggro / bando (§27) | ✅ existe, com retorno ao ninho e regen na coleira |
| Interrupção por CC (§11) | ✅ `StatusEffectController.is_incapacitated()` |
| Alpha +stats, não capturável (§30) | ✅ `CombatBalance.ALPHA_*`, medido por simulação |
| Lendário Lv.100 → nível 1 (§29) | ✅ `RegrasDeLendario.gd` |

**Conclusão honesta:** a V2 não é um jogo novo. É **uma camada de controle nova
sobre um motor que já está certo**, mais quatro sistemas que não existem
(stamina, comandos, câmera dinâmica, câmbio de captura).

### 🔴 Correção — achado do Codex na revisão, conferido e aceito

Escrevi acima, na primeira versão deste plano, que *"192 de 192 golpes têm
`cast_time`"*. **É verdade e é enganoso, e eu já tinha sido avisado sobre
exatamente este erro.**

```
cast_time = 0.0   →  108 golpes   (56%)  ← sem janela de leitura nenhuma
cast_time = 0.3   →   24 golpes
cast_time = 0.4   →    2 golpes
cast_time = 0.5   →   35 golpes
cast_time = 0.8   →    6 golpes
cast_time = 1.0   →   17 golpes
```

**O campo estar preenchido não é o mesmo que o valor servir.** Mais da metade
dos golpes sai instantâneo, sem nada pra ler. A §9 do pedido do Gabriel diz
*"ataques precisam ser visíveis"* — hoje, para 56% dos golpes, não são.

Isso derruba o critério que eu tinha escrito na seção 15 (*"telegrafia ≥0,4 s em
todo golpe com cast"*): dos 84 golpes com cast acima de zero, só 60 alcançam
0,4 s. **Critério corrigido na seção 15.** E vira trabalho novo: revisar os 108
golpes instantâneos é um item de balanceamento próprio, não um detalhe.

*(É a segunda vez em duas sessões que eu confundo "o campo existe" com "o dado
serve". A primeira foi a régua de densidade. Anotado como padrão, não como
tropeço isolado.)*

---

## 1. Diagnóstico do sistema atual

### 1.1 O que está sólido

| Camada | Arquivos | Por que aguenta a V2 |
|---|---|---|
| Regras puras de combate | `scripts/combat/*.gd` (12 classes `RefCounted`) | Sem dependência de cena ou autoload. Testáveis headless. **É o ativo mais valioso do projeto.** |
| Dados | `data/pokemon/species.json`, `data/moves/moves.json` (192), `data/world/zones.json` | Já data-driven, como a §63 exige |
| Persistência | `SaveManager.gd` (1.203 linhas) | Já guarda IV, nature, shiny, golpes conhecidos vs equipados |
| Eventos | `EventBus.gd` | Já é a ponte gameplay→UI que a §64 descreve |
| Colisão contínua | `WorldManager.filtrar_velocidade()` | Antecipa o tile à frente; serve igual pro treinador |
| Suíte de testes | 108 arquivos, 0 falhas | Rede de segurança real pra migração |

### 1.2 O que está incompatível com a V2, e por quê

| # | Sistema | Hoje | A V2 exige | Gravidade |
|---|---|---|---|---|
| 1 | Movimento do treinador | `try_move()` — tile + tween de 0,18 s, **entrada travada durante o passo** | Movimento contínuo, virar no meio do passo, esquiva | 🔴 estrutural |
| 2 | Câmera | `zoom = 0.5` cravado, um `Camera2D` por cena (36 cenas) | Zoom dinâmico por contexto, transição suave | 🔴 estrutural |
| 3 | Determinismo do dano | tem **crítico (5%)** e **variação aleatória** | §13: *"sem crit, sem variance, mesmas condições = mesmo dano"* | 🔴 regra |
| 4 | STAB | 1,25 fixo, ignora tipo secundário | §14: 1,25 primário / **1,15 secundário** | 🟡 regra |
| 5 | Controle do Pokémon | 100% autônomo (guarda-costas) | §7: ordens do jogador — atacar, ir, seguir, manter, recuar | 🔴 gameplay |
| 6 | Stamina | **não existe** (0 ocorrências no código) | §5 inteira: 3 linhas de progressão + 3 níveis de exaustão | 🔴 sistema novo |
| 7 | Captura | funciona com o selvagem **vivo**; HP baixo só dá bônus | §28: precisa chegar a 0 HP, corpo dura 10–15 s, **uma** tentativa | 🔴 gameplay |
| 8 | Regeneração de HP | só o selvagem regenera, e só voltando ao ninho | §19: todo Pokémon, fora de combate, 5 s sem dano | 🟡 sistema novo |
| 9 | Buff/debuff | **não existe livro-razão** — só status fixos (burn/poison/…) | §16, §17, §23: saldo líquido, excedente virando duração | 🔴 sistema novo |
| 10 | Vulnerabilidade do treinador | tem HP e desmaia, mas não é alvo da IA | §4: sem Pokémon fora, o treinador **é atacado** | 🟡 gameplay |

### 1.3 O que a V2 pede e não existe em lugar nenhum

Held Items (§38–52), Market/Auction (§57), Housing (§58), PvP 6v6 (§53–56),
Bag de 30 slots (§35), Storage temporário (§36), XP dividido entre jogadores (§32).

**Todos ficam fora do protótipo, de propósito** — ver seção 12.

---

## 2. Sistemas reaproveitáveis (não se toca)

As 12 classes puras de `scripts/combat/` entram na V2 **sem uma linha alterada**.

> 🔴 **Correção — achado do Codex, aceito.** A primeira versão deste plano
> prometia duas coisas incompatíveis: *"rollback = apagar duas pastas, nada
> fora delas muda"* **e** *"editar `DamageCalculator` e `CombatBalance`"*. Ele
> está certo: editar a fórmula compartilhada muda o jogo atual, e aí o rollback
> deixa de ser grátis.
>
> **Resolvido invertendo a direção:** a V2 não edita a fórmula — ela a
> **embrulha**. `DanoV2.gd` chama `DamageCalculator.detalhar()` e neutraliza
> crítico e variação **na entrada**; `BalanceV2.gd` lê `CombatBalance` e
> sobrescreve só o que muda. A V1 continua com crítico e variação, intacta.
> O isolamento volta a ser verdade literal.

```
CombatBalance.gd      ← régua central de números (§63)
StatsDePokemon.gd     ← fórmula única de stat e HP
DamageCalculator.gd   ← fórmula de dano
FormaDeArea.gd        ← geometria de skill (§10)
ComportamentoSelvagem.gd ← IA de 7 personalidades (§26)
KitDeCombate.gd       ← slots por nível e evolução
RegrasDeLendario.gd   ← §29 inteira, já pronta
TrocaDeKit.gd         ← troca por HM, 25 níveis
PapelDeGolpe.gd · Sinergia.gd · Empurrao.gd · CombateDebug.gd
StatusEffectController.gd · CaptureSystem.gd
PokemonScale.gd       ← escala por espécie (achado do Codex; eu tinha esquecido)
```

> **Correção do Codex, aceita:** `scripts/combat/PokemonScale.gd` já existe e já
> é usado por `FollowerPokemon` e `WildPokemon`. A §6 (tamanho real relativo,
> compressão de gigantes) **não precisa de sistema novo** — precisa de uso. Não
> criar tabela por nome de espécie em lugar nenhum.

Mais: `GameData`, `SaveManager`, `EventBus`, `RNGManager`, `MapLayouts` e o
mundo inteiro (36 mapas, 61 quests, dungeons, fundo do mar).

**Regra que me imponho:** se um arquivo de `scripts/combat/` precisar mudar pra
V2 funcionar, isso é sinal de que pus lógica de apresentação lá dentro. Revisar
antes de editar.

---

## 3. Sistemas que precisam ser substituídos

Só três, e todos por **cópia paralela**, nunca por edição do original:

| V1 (fica intacto) | V2 (novo) | Motivo |
|---|---|---|
| `BaseEntity.try_move()` | `CorpoLivre.gd` | Grid vs contínuo são incompatíveis no mesmo nó |
| `FollowerPokemon` (autônomo) | `PokemonComandado.gd` | Ordens do jogador mudam a máquina de estados inteira |
| `Camera2D` por cena, zoom fixo | `CameraDeCombate.gd` | Zoom por contexto |

---

## 4. Arquitetura proposta

```
┌─ ENTRADA ────────────────────────────────────────────────┐
│ EntradaV2  →  intenção ("andar ↖", "ordenar skill 2")    │
│               teclado · gamepad · toque, mesma saída     │
└───────────────┬──────────────────────────────────────────┘
                ▼
┌─ SIMULAÇÃO (autoridade) ─────────────────────────────────┐
│ CorpoLivre        movimento contínuo + colisão           │
│ Stamina           reserva, regeneração, exaustão (§5)    │
│ MesaDeComandos    ordens → Pokémon (§7)                  │
│ PokemonComandado  executa ordem, ataque básico auto      │
│ LivroDeEfeitos    buff/debuff/status, saldo líquido(§16) │
│ Corpo             cadáver capturável, 10–15 s (§28)      │
│                                                          │
│ ↕ usa sem alterar: CombatBalance · DamageCalculator ·    │
│   FormaDeArea · ComportamentoSelvagem · StatsDePokemon   │
└───────────────┬──────────────────────────────────────────┘
                ▼  EventBus (só sinais)
┌─ APRESENTAÇÃO (Codex) ───────────────────────────────────┐
│ CameraDeCombate · HUD V2 · barras · telegrafia de AoE    │
│ NUNCA recalcula HP, dano, stamina, cooldown ou alcance   │
└──────────────────────────────────────────────────────────┘
```

O contrato da §64 já é a regra do `AGENTS.md` deste repositório. A V2 não muda
a divisão — ela aumenta a superfície: a HUD passa a consumir **stamina**,
**ordem ativa** e **janela do corpo**, que hoje não existem como estado.

---

## 5. Estrutura de cenas

```
scenes/gameplay_v2/
  Laboratorio.tscn          ← a área de testes da §2, único ponto de entrada
    ├── TileMap             (terreno + obstáculos, reaproveita o atlas atual)
    ├── TreinadorV2         (CorpoLivre + Stamina + CameraDeCombate)
    ├── PokemonAtivo        (PokemonComandado)
    ├── Selvagens           (3 espécies + 1 grupo + 1 Alpha)
    ├── Corpos              (cadáveres e loot no chão)
    └── HudV2               ← Codex
```

O jogo atual **não muda de cena de entrada**. `TitleScreen.tscn` continua sendo
o começo; o Laboratório abre por um item de menu de depuração ou por URL de
export. Ninguém perde o jogo que já existe enquanto o protótipo é construído.

---

## 6. Estrutura de scripts

```
scripts/gameplay_v2/
  movimento/   CorpoLivre.gd · Stamina.gd            ← Stamina é RefCounted puro
  controle/    EntradaV2.gd · MesaDeComandos.gd
  entidades/   TreinadorV2.gd · PokemonComandado.gd · SelvagemV2.gd · Corpo.gd
  efeitos/     LivroDeEfeitos.gd · Efeito.gd         ← puros, testáveis headless
  camera/      CameraDeCombate.gd
  BalanceV2.gd                                       ← estende a régua atual
```

**Regra de teste que vale desde o primeiro arquivo:** toda conta (stamina,
saldo de buff, excedente virando duração, janela do corpo) mora numa classe
`RefCounted` sem autoload, pra poder ser provada sem subir o jogo. Quem tem nó
e `_physics_process` só *chama* essas contas. Foi isso que permitiu os 108
arquivos de teste atuais, e é o que impede a V2 de virar código que só dá pra
conferir olhando.

---

## 7. Fluxo de entrada

```
teclado/gamepad/toque
        │
        ▼
   EntradaV2  ── lê a cada frame ──►  intenção de movimento (Vector2 bruto)
        │
        ├── botão de corrida  ──► pede Stamina.gastar(correr, delta)
        │                          ├─ tem  → velocidade de corrida
        │                          └─ não  → velocidade de caminhada
        │
        └── slots 1..8, ordens  ──► MesaDeComandos
                                    ├─ delay global curto entre ordens manuais
                                    └─ ataque básico automático NÃO usa o delay (§7)
```

Uma fonte só de intenção pros três controles. Hoje o toque tem caminho próprio
(`ControlesDeToque.gd`), e é por isso que uma regra nova precisa ser escrita
duas vezes. Na V2 o toque preenche a mesma intenção que o teclado.

---

## 8. Fluxo de combate

```
ordem do jogador ──► MesaDeComandos.ordenar(skill, alvo/direção)
                          │
                          ├─ cooldown? ──────────────► recusa, avisa na tela
                          ├─ incapacitado (CC)? ─────► recusa (§11)
                          ├─ fora de alcance? ───────► aproxima (TARGET) ou recusa
                          │
                          ▼
                     CAST  (cast_time do golpe — janela de leitura)
                          │  direção TRAVA aqui e não acompanha mais o alvo (§10)
                          │  CC durante o cast → interrompe, MAS entra em cooldown (§11)
                          ▼
                     FormaDeArea.alvos()  ── geometria acertou? ──► é hit. Sem RNG (§10)
                          │
                          ▼
                     DamageCalculator.detalhar()   ← determinístico na V2
                          │
                          ├─ LivroDeEfeitos.aplicar(status/buff)  (§16–18)
                          ├─ drenagem = f(dano REAL causado)      (§20)
                          └─ alvo a 0 HP? ──► vira Corpo (10–15 s)  (§28)
```

### Mudanças de fórmula que a V2 exige

Todas moram em `DanoV2.gd`, **embrulhando** `DamageCalculator` — a V1 não muda.

1. **Sem crítico e sem variação.** §13 é explícita. Hoje o mesmo golpe nas mesmas
   condições dá números diferentes — o que impede o jogador de aprender o próprio
   dano, e impede o teste de afirmar um número.
2. **STAB por posição do tipo:** 1,25 no primário, 1,15 no secundário (§14).
3. **Sem teto de efetividade em boss/Alpha:** 4× continua 4× (§15). *Conferir se
   o teto anti-hit-kill de 90% do HP, criado na Fase 2, contradiz isso — é a única
   regra atual que pode limitar um 4× legítimo.*

> ⚠️ **Isto quebra o equilíbrio medido na Fase 2.** O boss foi calibrado por
> simulação **com** crítico e variação. Tirar os dois muda a média e mata a
> cauda. A recalibração entra como passo obrigatório na ordem de implementação,
> não como "a gente vê depois". Vale **só pra V2** — a V1 fica com o equilíbrio
> que já tem.

> ✅ **Custo visual de tirar o crítico: zero.** Conferido na revisão do Codex e
> no código: `FollowerPokemon`, `WildPokemon` e `TrainerEntity` **já emitem
> `damage_dealt(..., false, ...)` nos três lugares**. O número laranja de
> crítico em `FeedbackDeImpacto.gd` existe mas **nunca dispara hoje**. A
> assinatura do sinal fica como está, passando `false`.

## 8.1 O livro de efeitos (§16, §17, §23)

A parte mais sutil da especificação inteira, e a que mais fácil sai errada:

- efeitos de **skills diferentes** somam de forma aditiva;
- a **mesma skill** reaplicada não empilha: fica a maior intensidade **e** a maior duração;
- opostos se **compensam no saldo**, mas os dois timers continuam correndo —
  quando um acaba, o outro volta a valer sozinho;
- saldo além do limite funcional **trava no limite e o excedente vira duração**:
  cada 10% de excedente = +1 s, **no último efeito que empurrou além do limite**,
  uma vez por instância.

Isso é um livro-razão, não uma variável. Cada efeito é uma linha com autoria,
intensidade, duração e origem; o valor final é sempre uma **soma recalculada**,
nunca um número guardado. Recalcular só nos eventos da §63 (entra, muda, expira,
sobe de nível, evolui, troca item) — jamais por frame.

---

## 9. Fluxo de IA

Reaproveita `ComportamentoSelvagem.gd` inteiro. O que muda é **o que ela
persegue**:

```
                   ┌──────────────┐
   território ────►│   PATRULHA   │◄──── perdeu o alvo, memória expirou
                   └──────┬───────┘
                          │ jogador/Pokémon entrou no raio E o gatilho da
                          │ personalidade disparou (§26)
                          ▼
                   ┌──────────────┐   grita ──► bando acorda com atraso
                   │  PERSEGUIÇÃO │             sorteado (0,4–1,8 s)
                   └──────┬───────┘
                          ▼
                   ┌──────────────┐
                   │   COMBATE    │  escolhe golpe por nota, alvo por nota
                   └──────┬───────┘
                          │ alvo fugiu do território + memória acabou
                          ▼
                   ┌──────────────┐
                   │   RETORNO    │  volta andando, regenera no caminho (§27)
                   └──────────────┘
```

**A regra de alvo da §4 é nova e importante:** com Pokémon fora, a IA foca o
Pokémon e o treinador fica protegido. Sem Pokémon fora, **o treinador vira alvo
válido**. Não é detalhe de conforto — é o que torna a troca uma decisão tensa.

---

## 10. Fluxo de skills

Uma skill na V2 é **dado**, não código (§63). O formato já existe em
`moves.json`; a V2 acrescenta campos, sem quebrar os 192 existentes:

| Campo | Hoje | V2 |
|---|---|---|
| `power`, `type`, `category`, `cooldown`, `cast_time`, `range`, `area_type` | ✅ | mantém |
| `status_chance`, `knockback` | ✅ | mantém |
| `area_type` | ✅ existe (⚠️ **não** se chama `shape` — correção do Codex) | acrescentar os valores que faltam da §10: BEAM, PROJECTILE, CONTACT |
| `drenagem` | ausente | fração do dano **real**, teto 100% (§20) |
| `dispel` | ausente | remove efeitos temporários, **nunca** de Held (§21) |
| `efeitos[]` | status único | lista de linhas do livro-razão (§16) |

Campo ausente assume o padrão de hoje. **Nenhum dos 192 golpes precisa ser
reescrito pra V2 rodar** — essa é a régua de que o formato está certo.

---

## 11. Sistema de câmera

| Contexto | Zoom | Como se detecta |
|---|---|---|
| Exploração | média (referência: 1,4× mais perto que hoje) | padrão |
| Combate normal | igual à exploração | ≥1 inimigo em aggro |
| Combate grande | afasta ~15% | ≥3 inimigos em aggro |
| Boss / Alpha | afasta ~30% | inimigo marcado como boss |
| Interior pequeno | aproxima ~15% | mapa marcado como interior |

Transição por interpolação com tempo fixo — nunca salto. Alvo da câmera é o
**ponto médio entre treinador e Pokémon ativo**, limitado, pra os dois caberem.

> 🔵 **Fronteira com o Codex.** O *quando* (qual contexto está ativo) é estado de
> gameplay e sai por sinal. O *quanto* (números de zoom, curva, tempo da
> transição, enquadramento) é apresentação e é dele. Eu proponho os números
> acima como ponto de partida para ele ajustar, não como decisão fechada.

---

## 12. Ordem de implementação

**Regra que governa tudo:** cada passo termina jogável e testado. Nada de
"quando os 6 estiverem prontos aparece alguma coisa".

### Protótipo vertical — o que a §2 pede

| # | Passo | Prova que termina o passo |
|---|---|---|
| 1 | `CorpoLivre` + `Laboratorio.tscn` | Andar, correr, bater em obstáculo. **Só isso já responde à pergunta 1 da §68** |
| 2 | `Stamina` + exaustão | Correr até zerar, sentir os 3 degraus, parar 1 s pra voltar |
| 3 | `CameraDeCombate` | Zoom muda de contexto sem salto |
| 4 | Pokémon ativo + ataque básico automático | Sai da ball, segue sem flutuar, bate em alvo escolhido |
| 5 | `MesaDeComandos` + 4 skills | Status, AoE, drenagem, ataque comum — as 4 da §2 |
| 6 | `DamageCalculator` determinístico + STAB 1,25/1,15 | Mesmo golpe = mesmo número, provado em teste |
| 7 | **Recalibrar boss/Alpha por simulação** | Sem crit/variância os números da Fase 2 não valem mais |
| 8 | `LivroDeEfeitos` | Os 4 casos da §16/§17/§23 provados em teste headless |
| 9 | Selvagens: 3 espécies + grupo + 1 Alpha | Aggro, bando, território, retorno |
| 10 | `Corpo`: derrota → cadáver → loot → **uma** captura | Falhou = perdeu. Testado. |
| 11 | Troca de Pokémon (§8) | Instantânea, custa stamina, cooldowns seguem correndo |
| 12 | Treinador vulnerável sem Pokémon (§4) | Recolher a ball e apanhar de verdade |
| 13 | HUD mínima | **Codex** |
| 14 | **Playtest em navegador real** | A única prova que vale pras 3 perguntas da §68 |

### Deliberadamente FORA do protótipo

Held Items (§38–52 — 15 seções, sozinho é um projeto), PvP (§53–56), Market
(§57), Housing (§58), Bag de 30 slots (§35), Storage (§36), XP multi-jogador
(§32), networking.

**Motivo, na régua do próprio Gabriel (§68):** nenhum deles ajuda a responder
*"controlar o personagem é divertido?"*. Held Item num protótipo de um jogador
é planilha, não gameplay.

---

## 13. Riscos

| # | Risco | Probabilidade | Mitigação |
|---|---|---|---|
| 1 | **Movimento livre atravessa o mundo do grid.** 36 mapas foram desenhados com passagens de 1 tile. Um corpo contínuo pode entalar ou passar na diagonal | **Alta** | `filtrar_velocidade()` já antecipa o tile à frente e é usada pelos Pokémon há semanas. Testar as passagens estreitas conhecidas (Rock Tunnel, portas) no passo 1 |
| 2 | **Tirar crit/variância desequilibra o que foi calibrado** | **Certa** | Passo 7 é obrigatório, não opcional |
| 3 | Warps, pesca, surf e mergulho dependem de `grid_pos` | Alta | `CorpoLivre` continua publicando `grid_pos` derivado da posição. Nada disso é reescrito |
| 4 | Pokémon grande bloqueia passagem e tranca o jogador (§61) | Média | Compressão de escala + o Pokémon atravessa o corpo do próprio treinador |
| 5 | O protótipo fica bom e o jogo antigo apodrece em paralelo | Média | A V2 **usa** as classes puras do V1. Divergir exige copiar, e copiar é visível na revisão |
| 6 | 68 seções viram 68 sistemas meia-boca | **Alta** | A seção 12 acima existe exatamente contra isso |
| 7 | **Não sei se é divertido.** Nenhuma linha deste plano mede diversão | Certa | Passo 14. Só o Gabriel jogando responde |

---

## 14. Plano de rollback

Rollback aqui é barato **por construção**, e essa é a razão principal de a V2
ser paralela em vez de uma migração no lugar:

| Situação | O que fazer | Custo |
|---|---|---|
| Protótipo reprovado | apagar `scripts/gameplay_v2/` e `scenes/gameplay_v2/` | **zero** — nada fora dessas pastas mudou |
| Reprovado só o movimento livre | manter combate/stamina, voltar `try_move` | baixo |
| Uma mudança de fórmula quebrou o jogo atual | `git revert` do commit da fórmula | baixo — cada mudança de regra vai em commit próprio |
| Tudo publicado e ruim | `builds/` guarda o export anterior | um deploy |

**Invariante que torna isso verdade:** enquanto o protótipo existir, o jogo
atual roda sem tocar em nenhum arquivo de `gameplay_v2/`. Se um dia precisar,
a V2 deixou de ser isolada — e isso é bug de processo, não de código.

---

## 15. Critérios objetivos — quando o protótipo está pronto

A §68 dá três perguntas. Elas são subjetivas; abaixo é o mais perto de objetivo
que consigo chegar sem mentir sobre o que dá pra medir.

### Mensurável por teste automatizado

| Critério | Régua |
|---|---|
| Determinismo | 1.000 execuções do mesmo golpe nas mesmas condições → **desvio zero** |
| Livro de efeitos | os 4 casos da §16/§17/§23 batem o número esperado |
| Stamina | zerar → 3 degraus nos tempos certos → 1 s parado → volta a regenerar |
| Captura | corpo dura 10–15 s; **segunda** tentativa é recusada; falha perde o Pokémon |
| Troca | cooldowns continuam correndo com o Pokémon guardado; DoT mantém autoria |
| Sem regressão | os 108 arquivos de teste atuais continuam passando |

### Mensurável em navegador real

| Critério | Régua |
|---|---|
| FPS, gameplay normal | **≥60 FPS** — 1 Pokémon, poucos selvagens. É a meta real (ressalva do Codex, aceita) |
| FPS, pior caso | **≥50 FPS** com 8 selvagens + 1 Alpha + AoE na tela |
| Onde medir | navegador real, desktop **e** celular em pé e deitado, com resolução e carga declaradas. **Nunca alegado a partir de teste headless** |
| Latência do comando | ordem → primeiro frame de animação em **≤100 ms** |
| Leitura do ataque | ⚠️ **critério reescrito.** O original (*"≥0,4 s em todo golpe com cast"*) era impossível: 108 golpes têm cast `0.0` e 24 têm `0.3`. Novo critério: **todo golpe que tira mais de 25% do HP do alvo precisa de janela ≥0,4 s**. Os instantâneos leves seguem instantâneos — e é assim que a leitura vira informação, e não neblina em cima de tudo |

### Só o Gabriel responde

1. **Andar é gostoso** sem nada acontecendo na tela?
2. Numa luta perdida, dá pra apontar **o que você fez de errado**?
3. Você **quer** lutar de novo, ou está conferindo se funciona?

> Se as três primeiras réguas passarem e as três perguntas derem "não", **o
> protótipo falhou** — e falhou barato, que é o ponto de ele ser um protótipo.

---

## Próximo passo

`docs/rfc/RFC-GAMEPLAY-V2.md` fecha a decisão arquitetural e pede a revisão do
Codex nas fronteiras (câmera, HUD, telegrafia). **Nenhum arquivo de gameplay
muda antes disso.**
