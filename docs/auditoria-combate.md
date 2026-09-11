# Auditoria do sistema de combate — FASE 1

> Pedido do Gabriel (11/09/2026): reengenharia completa do combate em tempo real.
> A regra dele foi explícita — **auditar antes de alterar**, e não criar sistema
> duplicado. Este arquivo é o relatório dessa auditoria: o que existe, o que está
> quebrado, o que se preserva e o que muda.
>
> **Nenhuma linha de código foi alterada até aqui.**

---

## 1. Arquitetura atual — o mapa do que já existe

O combate em tempo real **já existe e é razoavelmente bem estruturado**. Não é um
começar do zero: é um motor com peças boas e um miolo matemático quebrado.

### Quem faz o quê, hoje

| Arquivo | Papel | Estado |
|---|---|---|
| `scripts/combat/DamageCalculator.gd` | Fórmula central de dano + tabela de tipos + stat/HP por nível | 🔴 **o miolo do problema** |
| `scripts/entities/FollowerPokemon.gd` (38 KB) | O Pokémon do jogador no mapa: 4 slots de golpe, cooldowns, status, alvo, área | 🟡 bom esqueleto, sem sp_atk/nature |
| `scripts/entities/WildPokemon.gd` (44 KB) | O selvagem: IA (PATROL/CHASE/ATTACK/DEAD), barra de vida, nome+nível, status, coleira | 🟡 bom esqueleto, **1 golpe só** |
| `scripts/combat/AreaTargeting.gd` | Busca alvos num raio | 🟡 funciona, mas varre grupo inteiro |
| `scripts/combat/TelegraphDeArea.gd` | O aviso no chão antes do golpe de área cair | ✅ preservar |
| `scripts/combat/StatusEffectController.gd` | BURN/POISON/PARALYSIS/SLEEP/FREEZE/CONFUSION | ✅ preservar |
| `scripts/combat/FeedbackDeImpacto.gd` | Hitstop, flash, tremor — a "sensação" do golpe | ✅ preservar |
| `scripts/combat/BattleResolver.gd` | Fim de combate: XP, level-up, loot, Pokédex, quest | ✅ preservar |
| `scripts/combat/CaptureSystem.gd` | Captura em tempo real | ✅ preservar |
| `scripts/combat/ChefeLendario.gd` | **Já é uma arquitetura de boss**: repertório de funções, cooldown por timestamp, enrage, escudo, fases | ✅ preservar e generalizar |
| `scripts/combat/ProjectileBase.gd` | Projétil | 🟡 existe, mas o Follower nunca o usa de verdade |
| `scripts/battle/BattlePokemon.gd` | Classe do motor POR TURNO (apagado em 06/09). Sobrou viva só pra captura/save/Pokédex | 🟡 **é aqui que moram IVs, EVs, nature e sp_atk — e o combate real não a usa** |
| `scripts/world/systems/SpawnManager.gd` | Quem nasce, onde, em que nível | 🟡 faixa de nível do terreno é fixa 3–8 |
| `scripts/ui/OverworldHUD.gd` | Os 4 botões de skill + barra de recarga | ✅ já suporta 4 |
| `data/moves/moves.json` | 169 golpes com tipo/categoria/power/cooldown/raio | ✅ já é data-driven |
| `data/pokemon/species.json` | 151 espécies com **hp/attack/defense/sp_atk/sp_def/speed** | ✅ os 6 stats já existem |
| `data/world/zones.json` | 741 entradas de fauna, todas com `level_min`/`level_max` (2 a 55) | ✅ preservar |

### O que já funciona e NÃO vai ser refeito

- **4 slots de golpe já existem** no `FollowerPokemon` (`move_slots`, `_cooldowns`),
  com botão na tela, atalho de teclado rebindável e barra de recarga.
- **Barra de vida do selvagem já acompanha o HP real** (`_update_health_bar()` lê
  `current_hp/max_hp`), com nome + nível por cima e cor verde→amarelo→vermelho.
- **Telegraph de área** já avisa antes do golpe cair, e o dano mira quem está
  dentro do círculo **no momento do impacto** — quem saiu a tempo escapa.
- **Status persistente** (queimadura, veneno, paralisia, sono, congelamento,
  confusão) já existe dos dois lados.
- **Coleira já existe** (`LEASH_RADIUS_TILES = 6`), mas só na patrulha.
- **As 25 natures já existem** em `GameData.NATURES`, e todo Pokémon salvo já tem
  uma sorteada.
- **Boss já tem arquitetura** (`ChefeLendario`), inclusive cooldown por timestamp.

---

## 2. Os problemas — cada um medido, não achado

Rodei as fórmulas reais do jogo contra os dados reais (`species.json` +
`moves.json`). Os números abaixo são o que o jogo faz hoje.

### 🔴 P1 — A fórmula de dano não tem nível no denominador (causa raiz dos OHKO)

A fórmula de hoje é:

```
dano = power × (atk / 50) × (100 / (100 + def)) × tipo × crit
```

O problema não é "o dano é alto demais". É que **o dano vive na escala do `power`
(40–120) enquanto o HP vive na escala do `base_hp` (40–100)** — e nada faz as duas
escalas se encontrarem. A fórmula clássica da série divide por 50 usando o NÍVEL;
esta divide por 50 usando uma constante.

Pikachu usando Thunderbolt num Spearow **do mesmo nível**:

| Nível | Dano | HP do alvo | Golpes pra matar |
|---:|---:|---:|---:|
| 10 | 170 | 60 | **1** |
| 20 | 187 | 80 | **1** |
| 30 | 203 | 100 | **1** |
| 50 | 232 | 140 | **1** |
| 75 | 265 | 190 | **1** |
| 100 | 292 | 240 | **1** |

OHKO em 100% dos níveis. Não é sorte nem crítico — é a fórmula.

### 🔴 P2 — O nível quase não importa (é o "não sinto progressão")

Mesmo golpe (Tackle), mesmo alvo fixo no nível 30:

| Nível do atacante | ATK | Dano |
|---:|---:|---:|
| 10 | 64 | 33 |
| 30 | 82 | 43 |
| 50 | 100 | 52 |

**40 níveis de diferença dão +58% de dano.** Enquanto isso o HP cresce 2,5×. O
resultado é o inverso do esperado: quanto mais alto o nível, **mais longa** a
briga, e um Pokémon 20 níveis abaixo ainda machuca quase igual.

A causa é o formato de `calculate_stat`: `base + floor(base × nível/60)`. No nível
100 a stat é só **2,67× a base**. Na série, a mesma stat chega a ~6×.

### 🔴 P3 — sp_atk e sp_def existem nos dados e nunca são usados

`DamageCalculator.calculate_damage()` só lê `atk` e `def`. A categoria do golpe
(`physical`/`special`) só é consultada pra queimadura e habilidade.

Consequência medida: **Alakazam** (attack 50, sp_atk **135**) ataca com 50.
Psychic (power 90) no nível 50 dá 99 de dano — menos que um Tackle de um Machop.
Todo Pokémon especial do jogo está quebrado.

### 🔴 P4 — Três fórmulas de stat diferentes no mesmo jogo

| Onde | Fórmula | Pikachu Lv20 (IV 15): HP / ATK |
|---|---|---|
| `DamageCalculator` (combate real) | `base + floor(base×lvl/60)` | **72 / 73** |
| `SaveManager._calc_stat` (menu, save) | Gen 3 com IV | **47 / 30** |
| `BattlePokemon._calc_stat` (captura, Pokédex) | Gen 3 com IV + EV + nature | próxima do save |

O HP que o menu mostra **não é** o HP com que o Pokémon luta. É literalmente isso
que o item 4 do pedido ("as estatísticas não têm impacto consistente") descreve.

### 🔴 P5 — O Pokémon do jogador tem 2 golpes porque os DADOS dão 2

A arquitetura já tem 4 slots. `_load_move_slots()` pega os **4 últimos golpes
aprendíveis** — e no começo do jogo simplesmente não existem 4.

| Nível | Espécies com 4 slots cheios | Espécies com **1 só** golpe de dano |
|---:|---:|---:|
| 5 | 20 de 151 | 82 |
| 10 | 38 | 70 |
| 20 | 89 | 52 |
| 30 | 120 | 44 |

Pior: o slot pode ser preenchido por golpe de **status** (Growl, Tail Whip), que
não causa dano nenhum. No nível 5, **8 espécies não têm golpe de dano nenhum**.

### 🔴 P6 — O Pokémon selvagem tem exatamente 1 golpe, sempre o primeiro da lista

`WildPokemon._load_species()`: `default_move = primeiro golpe aprendível`. Isso é
quase sempre Tackle ou Scratch de nível 1. Um Alakazam selvagem de nível 50 ataca
com Teleport/Confusion nível 1. Não há variedade, não há leitura de padrão, não há
IA de escolha de golpe.

### 🔴 P7 — O Alpha multiplica ataque por 3 em cima de uma fórmula já quebrada

`ALPHA_ATK_MULT = 3.0`. Um Rhyhorn Alpha Lv30 usando Earthquake num Charmander
Lv30: **929 de dano contra 98 de HP** (1393 no crítico). É o hit-kill mais
grosseiro do jogo.

### 🟡 P8 — Sem STAB, sem variação de dano, sem cast time, sem alcance

- **STAB** não existe em lugar nenhum.
- **Variação** (0,90–1,10) não existe: o dano é sempre idêntico.
- **`cast_time`** não existe nos dados nem no código.
- **`range`** não existe: um golpe corpo-a-corpo e um golpe de 6 tiles usam o
  mesmo `WILD_ATTACK_RADIUS = 384` (3 tiles) fixo.
- **`max_targets`** não existe: Earthquake pega quantos estiverem no raio.

### 🟡 P9 — IA pobre e sem as personalidades pedidas

Existem 3 comportamentos (`aggressive`/`neutral`/`flee`) contra os 7 pedidos.
Faltam DEFENSIVE, TERRITORIAL, PACK, PREDATOR. Não há bando, não há propagação de
aggro (nem o limite dela), a coleira só age na patrulha (um selvagem em CHASE
persegue até o fim do mapa) e o alvo é sempre "o primeiro Follower vivo que eu
achar" — sem prioridade, sem distância.

### 🟡 P10 — Performance: busca global por golpe

`AreaTargeting.find_targets_in_radius()` percorre **todos** os nós do grupo e mede
distância um a um, a cada golpe de área. Com o teto de 60 selvagens ativos e vários
golpes por segundo, isso escala mal. A IA roda inteira em `_physics_process` (60×
por segundo) por entidade.

### 🟡 P11 — Sem ferramenta de depuração de dano

Não existe nada que responda "por que esse golpe deu 929?". Cada investigação hoje
é ler o código e recalcular na mão — foi o que tive de fazer nesta auditoria.

---

## 3. Nova arquitetura proposta

A regra que guia tudo: **preservar o que funciona, corrigir o miolo, centralizar o
que está espalhado.** Nada de sistema paralelo.

### Arquivos NOVOS (5)

| Arquivo | Por que precisa existir |
|---|---|
| `scripts/combat/CombatBalance.gd` | Todos os números de balanceamento num lugar só. Hoje estão espalhados por 6 arquivos. É o que permite balancear sem editar código. |
| `scripts/combat/StatsDePokemon.gd` | **Uma** fórmula de stat/HP para o jogo inteiro, com IV, EV e nature. Substitui as 3 de hoje. Classe pura (testável headless). |
| `scripts/combat/FormaDeArea.gd` | Geometria de área: CIRCLE / CONE / LINE / RECTANGLE / RING. Hoje só existe círculo. |
| `scripts/combat/CombateDebug.gd` | O relatório de dano linha a linha pedido no item 44. |
| `scripts/combat/ComportamentoSelvagem.gd` | As 7 personalidades + aggro + bando + coleira, como regra pura, fora do `WildPokemon` de 44 KB. |

### Arquivos REESCRITOS por dentro (3)

| Arquivo | O que muda |
|---|---|
| `DamageCalculator.gd` | Fórmula nova com nível, sp_atk/sp_def, STAB, variação. **A tabela de tipos e a de habilidades ficam como estão.** |
| `WildPokemon.gd` | 4 golpes em vez de 1, escolha de golpe por IA, personalidades, coleira em CHASE, aggro de bando |
| `FollowerPokemon.gd` | Stats pelos 6 atributos + nature, alcance e cast time por golpe, formas de área |

### Arquivos com ajuste pontual

`SaveManager.gd` (passa a usar `StatsDePokemon`), `BattlePokemon.gd` (idem —
elimina a 3ª fórmula), `SpawnManager.gd` (personalidade e bando ao nascer),
`moves.json` (campos novos), `species.json` (personalidade por espécie).

### A fórmula nova

```
dano = ( (2×nível/5 + 2) × power × (ataque/defesa) / 50 + 2 )
       × STAB × tipo × crítico × variação × status
```

É a fórmula da série, que resolve P1 e P2 de uma vez: o nível entra multiplicando
**e** a razão ataque/defesa substitui a mitigação separada. `ataque` é ATK ou
SP_ATK conforme a categoria do golpe; `defesa` é DEF ou SP_DEF.

E a de HP, unificada (Gen 3, que o save já usa):

```
HP = floor((2×base + IV + floor(EV/4)) × nível / 100) + nível + 10
```

---

## 4. Riscos — o que pode quebrar

| Risco | Gravidade | Como trato |
|---|---|---|
| **Os Pokémon já salvos do Gabriel mudam de HP** ao unificar a fórmula | 🔴 alta | O HP gravado é migrado proporcionalmente (quem estava com 50% continua com 50%), não zerado |
| Testes existentes travam os números antigos | 🟡 média | 102 arquivos de teste; os que checam dano serão reescritos junto, não desligados |
| Dar 4 golpes ao selvagem deixa o jogo muito mais difícil | 🟡 média | Vem junto do TTK novo (6–12 golpes pra matar). Mensurável pela simulação da Fase 12 |
| Boss (`ChefeLendario`) usa multiplicadores em cima da fórmula velha | 🟡 média | Recalibrado na mesma fase, com a luta medida |
| Regressão de performance com IA mais rica | 🟡 média | Fase 14 mede antes/depois |

## 5. Ordem de execução

Segue as 14 fases do pedido. Depois de cada uma: rodar a suíte inteira, corrigir,
só então a próxima. **Nenhuma fase avança deixando erro conhecido pra trás.**

---

---

# COMBAT SYSTEM REWORK COMPLETE

> As 14 fases foram executadas. Abaixo, o resultado medido — não a intenção.
> Suíte: **102 arquivos, 0 falhas**. Publicado (carimbo 1789127779).

## 1. Arquivos criados (7)

| Arquivo | Papel |
|---|---|
| `scripts/combat/CombatBalance.gd` | A régua: todo número que decide equilíbrio, num lugar só |
| `scripts/combat/StatsDePokemon.gd` | A ÚNICA fórmula de stat/HP do jogo (substitui as 3) + as 25 natures |
| `scripts/combat/FormaDeArea.gd` | Geometria de área: círculo, cone, linha, retângulo, anel, global |
| `scripts/combat/ComportamentoSelvagem.gd` | As 7 personalidades + aggro + bando + coleira, como regra pura |
| `scripts/combat/CombateDebug.gd` | O relatório "por que esse golpe deu tanto?" |
| `scripts/tests/teste_reengenharia_combate.gd` | 178 conferências, uma seção por item do pedido |
| `scripts/tests/teste_balanceamento_combate.gd` | A simulação: imprime as tabelas de TTK/DPS e cobra a régua |

## 2. Arquivos modificados (9)

`DamageCalculator.gd` (fórmula nova + `detalhar()`), `WildPokemon.gd` (6 stats, 4
golpes, IA nova), `FollowerPokemon.gd` (6 stats, nature, alcance, cast, formas de
área, preenchimento de slots), `SaveManager.gd` (fórmula única + migração de HP),
`BattlePokemon.gd` (fórmula única), `GameData.gd` (natures delegadas),
`SpawnManager.gd` (nível por zona, personalidade por espécie),
`data/moves/moves.json` (192 golpes, 5 campos novos cada),
`data/pokemon/species.json` (personalidade das 151 espécies).

## 3. Sistemas preservados (não foram tocados)

Telegraph de área, feedback de impacto (hitstop/flash), status persistente,
captura, `BattleResolver` (XP/loot/quest), `ChefeLendario`, a tabela de tipos, a
tabela de habilidades (Overgrow/Blaze/Torrent/Guts), itens equipados, a HUD de 4
botões de skill, a barra de vida do selvagem.

## 4. Fórmula final de dano

```
dano = ( (2×nível/5 + 2) × power × (ataque/defesa) / 50 + 2 ) × 0.55
       × tipo × STAB × crítico × variação
       × habilidade × status × item × bônus-externo
```

`ataque`/`defesa` = ATK/DEF num golpe físico, SP_ATK/SP_DEF num especial.
Depois da conta, duas redes de segurança:

- **Teto**: nenhum golpe tira mais que **90%** da vida máxima de uma vez (não
  vale se o alvo já está abaixo de 15%, senão ficaria imortal).
- **Piso**: todo golpe que acerta tira pelo menos **2%** da vida máxima
  (imunidade de tipo continua sendo 0 de verdade).

## 5. Fórmula de HP

```
HP = floor((2×base + IV + floor(EV/4)) × nível / 100 × 2.5) + nível + 10
```

## 6. Multiplicadores

| | valor |
|---|---|
| STAB | ×1.25 |
| Super efetivo / fraqueza dupla | ×2.0 / ×4.0 |
| Pouco efetivo / resistência dupla | ×0.5 / ×0.25 |
| Imune | ×0 |
| Crítico (5% de chance) | ×1.5 |
| Variação | ×0.90 a ×1.10 |
| Nature | ×1.10 / ×0.90 |
| Queimadura em golpe físico | ×0.5 |
| Alpha | HP ×6.0, ATK ×1.35, DEF ×1.40 |

## 7. Cooldowns

Cada golpe tem o seu (1,0 a 8,0 s nos dados). A velocidade encurta em até **40%**,
item de recarga encurta mais, e o piso absoluto é **0,35 s**. A conta mora em
`CombatBalance.recarga()` — antes estava copiada em dois arquivos.

Todo golpe ganhou também `cast_time` (0 a 1,0 s), `range` (em tiles),
`area_type`, `max_targets` e `knockback`.

## 8. Sistema de AoE

Forma vem do dado (`area_type`), nunca de nome de golpe no código. Ordem:
centro → forma → detectar → excluir aliados → ordenar por distância → cortar em
`max_targets` → aplicar dano uma vez por alvo. **Earthquake** círculo 3 tiles /
10 alvos · **Blizzard** círculo 4 tiles / 8 alvos · **Surf** LINHA 6 tiles /
6 alvos · **Tornado** CONE 3 tiles / 5 alvos · **Petal Dance** círculo
2,5 tiles · **Confusion** alvo único, 5 tiles.

## 9. IA de combate

`PATROL → CHASE → ATTACK` mais dois estados novos: **RETORNAR** (coleira) e
**FUGIR**. A decisão roda a cada **0,2 s** (antes, 60×/s por bicho); o movimento
continua a 60 FPS. O selvagem escolhe golpe pela distância: entre os que estão
prontos e alcançam, usa o mais forte.

## 10-12. Aggro, bando e coleira

| | raio |
|---|---|
| Aggro (agressivo) | 5 tiles |
| Aggro (predador / defensivo) | 10 / 2,25 tiles |
| Passivo | não persegue |
| Bando (raio do grito) | 4 tiles, no máximo 5 respondem, **mesma espécie** |
| Corrente de aggro | 1 salto — quem foi chamado NÃO chama outro |
| Coleira | 12 tiles (territorial 7,2 · predador 19,2) |
| Volta pra casa | recupera 8% da vida por segundo |

As 151 espécies foram reclassificadas nas 7 personalidades: 32 bando, 32
defensivo, 22 territorial, 21 predador, 19 agressivo, 17 passivo, 8 fugitivo.

## 13. Testes executados

- `teste_reengenharia_combate.gd` — **178 conferências**, os 17 itens do pedido
- `teste_balanceamento_combate.gd` — **15 conferências** + as tabelas impressas
- Suíte completa — **102 arquivos, 0 falhas**

## 14. Resultados de TTK (medidos, não estimados)

**Mesmo nível, ataque básico** (Quick Attack → Rattata): 11-13 golpes em todo
nível de 10 a 100. Alvo do pedido: 6-12.

**Mesmo nível, golpe forte + super efetivo** (Thunderbolt → Spearow): **3 golpes**
em todo nível. Alvo: 3-7. Nunca 1.

**A escada de potência** (Lv.25): power 35 → 14 golpes · 50 → 10 · 65 → 8 ·
85 → 6 · 110 → 5 · 150 → 4.

**Desnivelado**: Lv.20 → Lv.10 mata em 4 golpes; Lv.10 → Lv.20 precisa de 28.
Lv.21 → Lv.20 ainda precisa de 11 (não apaga). Lv.30 numa área de Lv.50 precisa
de 30 golpes por bicho.

**Tanque × frágil** (Lv.30): Onix aguenta 58 golpes de Quick Attack, Abra
aguenta 8. Com o golpe CERTO (Water Gun no Onix): 3 golpes.

## 15. Problemas encontrados durante a execução

1. **Piso de dano faltando** — a simulação mostrou Quick Attack dando 1,2 de
   dano num Onix: 96 golpes, 100 segundos. Era a "defesa infinita = dano zero"
   proibida pelo item 10. Corrigido com o piso de 2%; caiu pra 58 golpes, e com
   o golpe certo, 3.
2. **24 golpes citados nos learnsets não existiam em `moves.json`** — 40 das 151
   espécies tinham slot morto. 22 golpes criados, 2 eram só divergência de nome
   (`bubble_beam`→`bubblebeam`, `selfdestruct`→`self_destruct`) e foram
   apontados pro id certo.
3. **`_candidatos` era O(n²)** — 3.600 comparações por golpe de área com 60
   selvagens. Corrigido: 110 → 71 µs.
4. **🔴 Uma medição minha de desempenho estava errada** — medi a busca de alvos
   com os 60 bichos espalhados longe demais, quase nenhum dentro do raio, e
   registrei 2 µs. O custo real é 71 µs. O teto do teste foi corrigido pro
   triplo do valor real, com o erro registrado no próprio teste.
5. **Um teste de carregamento de mapa era instável** — 4027 a 5279 ms contra um
   teto de 5000. Falhava sem nada ter piorado. Teto ajustado, com o motivo
   escrito.
6. **A tabela de socorro de golpes dava golpe de STATUS** pra Bug e Ground
   (`string_shot`, `sand_attack`) — um Pokémon desses completaria os 4 slots sem
   conseguir machucar nada. Trocados por `fury_cutter` e `bonemerang`.

## 16. Próximos pontos de balanceamento

- **O tanque ainda é lento de derrubar com o golpe errado** (58 golpes no Onix).
  É de propósito — com o golpe certo são 3 —, mas se em jogo parecer castigo em
  vez de lição, o knob é `DANO_MINIMO_FRACAO_HP` em `CombatBalance`.
- **O ataque básico está em 11-13 golpes**, um pouco acima da faixa de 6-12 no
  topo da curva. Se ficar arrastado, `BASE_DAMAGE_MULTIPLIER` sobe.
- **O chefe lendário (`ChefeLendario`) não foi recalibrado** — os
  multiplicadores dele (HP ×7, ATK ×1.35) foram desenhados sobre a fórmula
  velha. A luta precisa ser jogada e medida.
- **Knockback, `status_chance` e `priority` estão nos dados mas ainda não são
  lidos pelo motor.** Os campos existem para não exigir outra migração depois.
- **Habilidade passiva e ultimate por espécie** (item 4) ainda não existem: a
  arquitetura comporta, o dado não foi escrito.
- **Nada disso foi jogado em navegador ainda** — a validação até aqui é a suíte
  headless e a simulação. Vale o Gabriel andar no mato e sentir o ritmo.

---

*FASE 1 escrita antes de qualquer alteração; o restante registrado após a
execução, com os números medidos.*

---

# COMBAT SYSTEM — PHASE 2 VALIDATION

> Revisão crítica da Fase 1: auditar → corrigir → testar → simular.
> Suíte: **103 arquivos, 0 falhas** (253 conferências novas). Publicado
> (carimbo 1789132999).

## Auditoria da Fase 1 — o que eu mesmo tinha deixado errado

| Achado | Gravidade |
|---|---|
| **`accuracy` nunca era lido.** Os 192 golpes têm precisão nos dados e nenhum código consultava. Blizzard, com 70, nunca errava | 🔴 |
| **Status aplicava mesmo na imunidade.** Thunderbolt num Pokémon de Terra causava 0 de dano e ainda podia paralisar | 🔴 |
| **O chefe batia FORA da fórmula** (`atk_stat × 0.35`): ignorava defesa, tipo, STAB e — o mais grave — o teto anti-hit-kill | 🔴 |
| **`status_chance` e `knockback` existiam nos dados e ninguém lia** | 🟡 |
| **`knockback` do Tornado estava em PIXELS (96.0)**; a unidade correta é tile, então valeria 96 tiles | 🟡 |
| `_usar_golpe(default_move)` sombreava a variável de membro de mesmo nome | 🟡 |
| `ChefeLendario` ainda usava `AreaTargeting` (só círculo) em vez de `FormaDeArea` | 🟡 |
| Itens 2 e 3 do pedido (`BASE_DAMAGE_MULTIPLIER`, `HP_SCALE`) **já estavam feitos** na Fase 1 — nada hardcoded | ✅ |

## 1. Fórmula final

```
dano = ( (2×nível/5 + 2) × power × (ataque/defesa) / 50 + 2 )
       × BASE_DAMAGE_MULTIPLIER
       × tipo × STAB × crítico × variação
       × habilidade × status × item × bônus-externo
```

Teto: 90% da vida máxima por golpe (não vale abaixo de 15% de vida).
Piso: **1** — o piso proporcional de 2% foi **removido** (item 4).

## 2. HP final

```
HP = floor((2×base + IV + floor(EV/4)) × nível / 100 × HP_SCALE) + nível + 10
```

## 3. Stats por nível (Charizard, IV 31, nature neutra)

| Nv | HP | ATK | DEF | SP_ATK | SP_DEF | SPEED |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | 66 | 24 | 23 | 29 | 25 | 28 |
| 20 | 123 | 44 | 42 | 54 | 45 | 51 |
| 30 | 180 | 64 | 61 | 79 | 65 | 74 |
| 50 | 293 | 104 | 98 | 129 | 105 | 120 |
| 75 | 435 | 154 | 145 | 191 | 155 | 178 |
| 100 | 577 | 204 | 192 | 254 | 206 | 236 |

Todos os 6 stats crescem em todo degrau. **Um nível a mais nunca dá mais que
+8% num stat** (medido de 20 a 41, todos os stats). Contra alvo fixo Lv.30:
dano 2,5 → 97,0 e sobrevivência 3,9 → 192,3 golpes, ambos monotônicos.

## 4. Tabela de dano (Thunderbolt, média de 300 golpes)

| Atacante | Nv | Alvo | Nv | Dano |
|---|---:|---|---:|---:|
| Pikachu | 10 | Rattata | 10 | 9,9 |
| Pikachu | 20 | Rattata | 20 | 16,7 |
| Pikachu | 30 | Rattata | 30 | 23,3 |
| Pikachu | 50 | Rattata | 50 | 36,1 |
| Pikachu | 75 | Rattata | 75 | 53,1 |
| Pikachu | 100 | Rattata | 100 | 69,6 |
| Pikachu | 20 | Rattata | 10 | 26,9 |
| Pikachu | 10 | Rattata | 20 | 6,5 |
| Pikachu | 30 | Rattata | 50 | 15,2 |
| Pikachu | 50 | Rattata | 30 | 57,1 |
| Pikachu | 50 | Rattata | 100 | 19,3 |
| Pikachu | 100 | Rattata | 50 | 129,9 |

## 5. TTK por tipo de ataque (Lv.30 × Lv.30)

| Situação | Dano mín/médio/máx | Golpes | DPS | TTK |
|---|---|---:|---:|---:|
| básico (Quick Attack) | 8 / 9,1 / 15 | 12 | 5,3 | 20,7 s |
| médio (Swift) | 11 / 12,5 / 20 | 9 | 4,3 | 26,0 s |
| forte (Thunderbolt) | 20 / 23,3 / 37 | 5 | 5,3 | 21,9 s |
| super efetivo | 45 / 51,0 / 82 | 3 | 11,6 | 13,2 s |
| resistido (×0,5) | 7 / 7,6 / 12 | 18 | 1,7 | 79,0 s |
| imune (×0) | 0 | — | — | **nunca mata** |
| crítico garantido | 30 / 35,4 / 56 | 4 | 8,1 | 17,6 s |
| tanque (Onix) | 1 / 1,2 / 3 | 96 | 0,7 | 165,9 s |
| frágil (Abra) | 15 / 17,7 / 28 | 6 | 4,0 | 26,3 s |

**TTK por nível, ataque básico**: 11 a 13 golpes do Lv.10 ao Lv.100.
**Escada de potência (Lv.25)**: 35 → 14 golpes · 50 → 10 · 65 → 8 · 85 → 6 ·
110 → 5 · 150 → 4.

## 6. O piso de 2% — por que saiu

| | com piso | sem piso |
|---|---:|---:|
| Onix, Quick Attack | 58 golpes | 93 golpes |
| Rhyhorn, idem | 61 | 89 |
| Golem, idem | 61 | 102 |
| Geodude / Cloyster / Abra / Rattata | sem diferença | sem diferença |

O piso não resolvia nada (58 golpes continua injogável) e distorcia o dano
contra alvos de vida alta. Regra atual: **imune = 0, qualquer outro = mínimo 1**.
Golpe errado contra tanque **deve** doer — com o golpe certo o mesmo Onix cai
em **3 golpes** (Water Gun), contra 96 do Quick Attack.

## 7. Alpha — três modelos medidos (Lv.30, kit real)

| Modelo | Vida | Luta do jogador | Dano devolvido |
|---|---:|---|---|
| A (era) HP×6 ATK×1,35 | 1098 | 69 golpes, 265 s | 8% da vida/golpe |
| B (sugerido) HP×3 ATK×1,20 | 549 | 30 golpes, 115 s | 8% |
| **C (adotado) HP×3 ATK×1,60 DEF×1,25** | **549** | **31 golpes, 119 s** | **10%** |

O modelo A era literalmente o "saco de HP": 4½ minutos batendo em algo que mal
machuca. O C corta a duração pela metade e aumenta a ameaça.

## 8. Chefe — recalibrado por medição

O dano do chefe passou a percorrer o `DamageCalculator`. `MULT_HP` 7,0 → **5,0**.

| Nível | Pressão | Área | Área enfurecida (pior caso) | Luta |
|---:|---|---|---|---|
| 30 | 21% da vida | 37% | 71% (**90%**) | 43 golpes, 186 s |
| 50 | 20% | 36% | 70% (**90%**) | 46 golpes, 180 s |
| 75 | 20% | 35% | 69% (**90%**) | 48 golpes, 163 s |
| 100 | 19% | 34% | 68% (**90%**) | 49 golpes, 157 s |

O "pior caso 90%" é o teto anti-hit-kill agindo: **nada mata de um golpe**, nem
o chefe enfurecido. Com ×7 a luta durava 218-265 s e **sempre** alcançava o
enrage (240 s) — a fase de fúria era o final garantido de toda luta. Com ×5,
volta a ser o preço de demorar.

## 9. AoE

Testados **Earthquake, Blizzard, Surf, Tornado e Petal Dance** em 1, 2, 5,
máximo e máximo+4 alvos; alvo fora da área; alvo na borda de dentro e de fora;
alvo que sai durante o cast; alvo morto antes do impacto. Em todos:
**cada entidade recebe dano no máximo uma vez por cast**.
A precisão é sorteada **por alvo** — um Blizzard de 70% pode pegar dois e errar
o terceiro.

## 10. IA — escolha de golpe por pontuação

```
nota = power × efetividade × adequação-de-alcance
       × potencial-de-alvos × valor-tático × fator-aleatório
```

Medido: contra alvo imune ao golpe forte, usa o fraco que funciona · a ultimate
vale 65% menos contra alvo com 10% de vida · golpe de área vale 1,7× mais com 5
alvos juntos · golpe fora de alcance ou em recarga nunca entra · com tudo
recarregando devolve "não ataco" em vez de inventar. Custo: **14,5 µs** por
decisão.

## 11. Prioridade de alvo

```
nota = 100 / (1 + distância) × (3,0 se me atacou) × (bônus por vida baixa)
       × (invasão de território) × (0,45 se for o treinador)
```

Antes era "o primeiro Follower vivo da lista" — a ordem da árvore de cena
decidia a briga.

## 12. Aggro, bando e coleira

| | valor |
|---|---|
| Aggro (agressivo / predador / defensivo) | 5 / 10 / 2,25 tiles |
| Bando | 4 tiles, máx. 5, **mesma espécie** |
| Corrente de aggro | 1 salto |
| **Atraso de entrada no bando (novo)** | **0,4 a 1,8 s** |
| Coleira | 12 tiles (territorial 7,2 · predador 19,2) |

**Bando contra Wartortle Lv.25** (confronto neutro):

| Tamanho | DPS do grupo | Jogador cai em |
|---:|---:|---:|
| 1 | 5,0 | 25,4 s |
| 2 | 10,1 | 12,7 s |
| 3 | 15,1 | 8,5 s |
| 4 | 20,1 | 6,4 s |
| 5 | 25,2 | 5,1 s |

Cinco atacantes dão cinco vezes o dano — isso é aritmética. O que se corrigiu
não foi o dano: foi a **simultaneidade**. Quem responde ao grito entra com
atraso sorteado, então o bando chega em onda e o jogador vê os primeiros antes
de estar cercado.

## 13. Status e precisão

`status_chance` é lido dos dados (aceita 0.20 e 20, sem diferença de 100×),
com três fontes em ordem: o campo → o número embutido no nome do efeito
(`burn_10`) → 100% para golpe puro de status. **Imunidade barra o status junto
com o dano.** 32 golpes declaram chance. Precisão medida: um golpe de 70 acerta
70% (±6%).

## 14. Knockback

`knockback` em **TILES**. Empurra pra longe de quem bateu, com resistência por
defesa (até −70%, nunca zero). Usa o mesmo caminho de andar
(`WorldManager.filtrar_velocidade` + `move_and_slide`), então **parede, água,
pedra e limite de mapa param o empurrão** — nada atravessa nada. **Sem timer e
sem nó novo**: é estado consumido pelo `_physics_process` que já rodava. 17
golpes têm empurrão; os outros 175 custam uma comparação.

## 15. Kit por evolução e nível — a ideia do Gabriel

```
slots = 4 (base) + estágio evolutivo (0-2) + bônus de nível (0-2, em Lv.40 e Lv.80)
```

| | Lv.5 | Lv.25 | Lv.50 | Lv.100 |
|---|---:|---:|---:|---:|
| Charmander (estágio 0) | 4 | 4 | 5 | **6** |
| Charmeleon (estágio 1) | 5 | 5 | 6 | **7** |
| Charizard (estágio 2) | 6 | 6 | 7 | **8** |

O caso que motivou a ideia, resolvido **sem nenhuma regra especial**:

- **Magikarp Lv.100**: 6 slots, mas o learnset dele só tem 3 golpes → kit
  `[flail, tackle, splash]`.
- **Gyarados Lv.100**: 7 slots e learnset pra encher → `[hyper_beam,
  hydro_pump, bite, water_gun, tackle, leer, dragon_rage]`.

Evoluir passou a mudar **como se joga**, não só os números.

🔴 **Um bug que quase matou a ideia**: `evolution_to` é `null` nas formas finais
e `int(null)` lança erro, interrompendo o laço — **todas as 151 espécies saíam
como estágio 0** e a escada não existia. Achado porque a primeira medição
mostrou Charizard e Charmander com a mesma capacidade.

Loadout por faixa (item 13): iniciante 1-2 ofensivos, intermediário 2-3,
avançado 3-4+. Média medida: **1,9 → 2,4 → 3,2** golpes ofensivos (Lv.5 → 25 →
60). Nenhuma das 151 espécies fica sem golpe de dano, e nenhuma fica com kit só
de status. **Selvagem comum: 3 golpes. Alpha: 4.** Um Charizard *selvagem*
Lv.100 tem 3, não 8.

## 16. Performance

Cenário: 60 selvagens + jogador + 4 do time, um segundo de jogo cheio
(300 decisões de IA, 30 golpes simples, 6 de área com alvos múltiplos, 65
tiques de status):

| | custo |
|---|---:|
| IA (300 decisões) | 4.362 µs |
| Golpes (30 + 6 de área) | 1.034 µs |
| Status (65 tiques) | 32 µs |
| **Total por segundo** | **5.428 µs** |

0,54% de um núcleo. Busca de alvo de área: 71 µs. Conta de dano: 14,6 µs.
Decisão de IA: 14,5 µs.

⚠️ **Limitação declarada**: o ambiente é headless, sem renderização — o que foi
medido é o **custo de CPU da lógica de combate**, não FPS real. FPS depende de
desenho de sprite, TileMap e shader, que este ambiente não executa. A meta de
60 FPS **não foi verificada**; só se sabe que a lógica de combate consome uma
fração pequena do orçamento.

## 17. Testes executados

| Arquivo | Conferências |
|---|---:|
| `teste_fase2_combate.gd` (novo) | 223 |
| `teste_balanceamento_combate.gd` (ampliado) | 30 + 6 tabelas impressas |
| `teste_reengenharia_combate.gd` | 179 |
| **Suíte completa** | **103 arquivos, 0 falhas** |

## 18. Problemas restantes

1. **FPS real não medido** (ver limitação acima). Só um teste em navegador
   responde isso.
2. **Tanque com golpe errado leva 96 golpes** (165 s). É de propósito — com o
   golpe certo são 3 —, mas se em jogo parecer castigo, o knob é
   `BASE_DAMAGE_MULTIPLIER` ou uma compressão da razão ataque/defesa.
3. **Traits combináveis (item 17) não foram migrados** — a arquitetura permite
   (cada regra é uma função isolada que recebe a personalidade), mas a
   personalidade continua sendo um rótulo único. Migrar quando houver
   necessidade real.
4. **`priority` dos golpes ainda não é lido** — o campo existe, o motor de
   tempo real não tem fila de turnos onde ele faria sentido. Precisa de
   desenho antes de código.
5. **Passiva e ultimate por espécie** continuam sem dado escrito.
6. **O chefe usa um repertório fixo de 6 funções**, não o `KitDeCombate`. São
   sistemas diferentes de propósito, mas vale unificar se o repertório crescer.
7. **Nada foi jogado em navegador ainda.** Toda a validação até aqui é
   headless: fórmula, simulação e regra. O playtest é o próximo passo.

---

*Fase 2 registrada após a execução, com os números medidos.*
