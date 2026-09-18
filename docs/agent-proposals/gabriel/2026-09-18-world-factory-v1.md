# TAREFA PARA O CODEX — WORLD / TERRAIN / BIOME FACTORY V1

> **Origem:** pedido do Gabriel, 18/09/2026, a partir de uma consulta externa.
> **Filtrado e anotado pelo Claude**, como ele pediu: *"filtre o que é útil,
> melhore o que ficou meio ruim"*.
>
> O documento original tem 54 seções. O que está aqui é o que **sobrevive ao
> projeto real** — com os números que já foram medidos nesta VPS no lugar dos
> "investigue", e com as contradições apontadas em vez de repassadas.

---

## O que eu mantive, o que cortei, e por quê

**Mantive inteiro, porque está certo e é o coração do pedido:**

| Ideia | Por que ela vale |
|---|---|
| **Blender é fábrica de PEÇAS; Godot multiplica** | É o ponto mais forte do texto. Exportar 80 mil tufos de grama num `.glb` mataria o build web — que já tem **55,5 MB** |
| **Determinismo por seed** | Sem isso não há "regenerar só o chunk 4,7". É o que separa fábrica de sorteio |
| **Geração em CAMADAS, não `height = noise(x,y)`** | Ruído puro produz montanha que parece ruído. Correto |
| **GAMEPLAY > PROCEDURAL, com masks de prioridade** | Este projeto tem **61 quests com `location_tile`** e ~30 NPCs posicionados. Um gerador que ignore isso apaga meses de trabalho |
| **Auditoria ANTES de gerar asset** | A §53 é a melhor parte do pedido. Mantida, e com perguntas específicas (ver abaixo) |
| **WORLD_LAB 256×256 primeiro** | Não construir Kanto inteiro. Certo |
| **Separar procedural de manual (ownership)** | Ver acima: o gerador não pode apagar trabalho humano |

**Cortei do V1, e digo por quê:**

| Cortado | Motivo |
|---|---|
| **Cavernas inteiras** (§26 a §31 do original: cave factory, cave graph, salas, navegação) | É uma **segunda fábrica**, do tamanho da primeira. Misturar as duas no V1 é como se constroem dois sistemas pela metade. A entrada de caverna do WORLD_LAB entra como **placeholder** (um buraco na rocha que não leva a lugar nenhum), só pra provar que o terreno aceita uma |
| **CLI completa** (§39) | *Arquitetar* pensando nela: sim. *Construir* as 8 subcomandos agora: não. Uma CLI que ninguém usa ainda é código pra manter sem retorno |
| **LOD implementado** (§37) | Manter a arquitetura aberta pra ele: sim. Implementar: não — o piso medido é 67 FPS com 20 mil instâncias, então LOD ainda não é o gargalo |
| **Hierarquia de Kanto inteira** (a parte final da consulta) | Boa, e é o passo DEPOIS. Já existe um plano aprovado pro mapa-múndi de Kanto na escala 1 km = 1.000 tiles — a fábrica precisa existir antes de servir a ele |

---

## 🔴 Uma contradição que precisa ser resolvida ANTES da FASE 1

**Qual é a altura do player?**

| Fonte | Diz |
|---|---|
| A folha de concept art do Gabriel (18/09) | **1,60 m** |
| O corpo do treinador no código (`TrainerController3D`) | **1,75 m** (cápsula e malha) |
| O `player.glb` que o Codex gerou em 14–15/09 | **1,750 m**, medido |
| A mesma folha, no NPC adulto | 1,75 m |

O texto do Gabriel diz que **"este ponto é CRÍTICO"** e que *"a concept art anterior errou a escala"*. Ele tem razão — e a divergência está aqui, entre a folha nova e o código.

**Isto não pode ser adivinhado.** A altura do player é o denominador de tudo: árvore de 8 m, pedra de 50 cm, largura de caminho, altura de caverna, enquadramento de câmera. Escolher errado obriga a refazer a fábrica inteira.

➡️ **Pergunte ao Gabriel** antes de escrever a primeira linha. E, decidido, **o código muda junto** — hoje o treinador é 1,75 m e ninguém notou a divergência até agora.

---

## Os números desta VPS, medidos — use estes, não "investigue"

O texto original manda investigar várias coisas que **já foram medidas aqui**. Não gaste tempo:

### Render

- **Renderizador: `gl_compatibility`** (`project.godot`), escolhido pelo export web.
  Consequências: **sem SDFGI, sem compute shader, sombras limitadas**. Qualquer
  proposta de "grass shader" ou GI vive dentro disso.
- **Medição real, em navegador, 14/09** — `gl_compatibility`, 1592×720, MultiMesh
  + 40 corpos com física + sombra direcional:

| Vegetação (instâncias) | FPS |
|---:|---:|
| 0 | 83,5 |
| 2.000 | 83,5 |
| 8.000 | 76,0 |
| **20.000** | **67,0** |

  **Piso de 67 FPS com 20 mil instâncias** — o MultiMesh aguenta. ⚠️ **Isso é
  desktop.** O celular é o aparelho fraco e é ele que decide.
  ⚠️ **Ruído de ~3 FPS**: 500 plantas mediu *mais* que 0. Diferença abaixo disso
  não é real e não vale conclusão.

### Build

- O `.pck` do build web tem **55,5 MB** hoje. Um `.glb` de mundo inteiro entra
  aqui. É o teto que torna "Blender gera peças, Godot multiplica" obrigatório, e
  não uma preferência de estilo.

### Máquina

- 2 núcleos, ~7,8 GB, **sem GPU**, compartilhados com n8n, Postgres, Evolution e
  os apps no ar. **Concorrência 1.** E a decisão de 11/09 continua: **Workbench,
  nunca EEVEE/Cycles** para validação automática.

---

## 🔗 O contrato que NÃO pode ser quebrado

Esta é a parte que o pedido original não sabia, e é onde um gerador novo
quebraria o jogo em silêncio.

### 1. `Terreno3D.altura_em(x, z)` é a única fonte de verdade da geografia

```gdscript
## A altura do terreno num ponto. **A única fonte de verdade da geografia.**
## Visual e colisão leem esta mesma função, então nunca podem discordar — é o
## tipo de divergência que produz o jogador andando no ar ou afundando no chão.
static func altura_em(x: float, z: float) -> float:
```

**Quatro sistemas já dependem dela:** `Laboratorio3D`, `RegraDeAcompanhar` (o
companheiro), `SpawnerSelvagem3D` (todo nascimento de selvagem) e o teste da
Fase 3.

➡️ A fábrica pode **substituir a implementação**, mas **a função tem de continuar
existindo e respondendo**. Se o terreno virar malha exportada sem consulta de
altura, o spawn de selvagem passa a nascer dentro da montanha ou flutuando — e
não dá erro nenhum.

### 2. Escala: 1 unidade = 1 metro, e **1 tile = 1 metro**

A régua do mapa-múndi já está decidida e aprovada: **1 km = 1.000 tiles**. A
fábrica herda isso. `FormaDeArea3D` e `RegraDeSpawn` já convertem o dado legado
(que vem em pixels, tiles × 128) com essa régua.

### 3. Modelos: origem nos pés, frente no **−Z**

Mesmo contrato dos Pokémon (`docs/POKEMON_MODEL_PIPELINE.md`). O primeiro
Charizard veio deitado por Z-up não convertido e o `ValidadorDeModelo` pegou —
vale a pena um validador equivalente pros assets de mundo.

### 4. Seed do mundo ≠ RNG do jogo

O `RNGManager` existe pra **uma partida ser reproduzível**. Se a geração do mundo
consumir sorteios dele, gerar terreno passa a empurrar de lado os sorteios de
captura, status e loot — exatamente o bug que o Codex achou em 14/09 e que o
`DanoV2` corrige preservando o estado.

➡️ **A fábrica usa um gerador próprio, semeado pela `world_seed`.** Nunca o
`RNGManager`, nunca `randf()` global.

### 5. O trabalho manual que já existe, e que o gerador não pode apagar

- `data/world/zones.json` — `tile_rect` e `wild_pokemon` por zona
- `data/quests/quests.json` — **61 quests**, cada uma com `location_tile`
- `scenes/world/maps/` — ~30 NPCs de treinador posicionados
- `MapLayouts.gd` — **2.923 linhas** de pintura procedural por região, com as
  primitivas orgânicas (`ondular_costa`, `costurar_costa`, `amaciar_bordas`,
  `_mancha_de_mato`) que já resolvem costa e borda

A §44 do pedido (ownership: separar procedural de manual) **não é teórica aqui**.
É o que impede a fábrica de órfãos: uma quest apontando pra um tile que virou
oceano.

---

## O pedido, filtrado

### FASE 0 — a auditoria, e ela é a primeira entrega

Produza **`docs/WORLD_PIPELINE_AUDIT.md`** antes de gerar qualquer asset. O texto
original pede 10 tópicos genéricos; estas são as perguntas que **este projeto**
precisa que sejam respondidas:

1. `Terreno3D.altura_em` sobrevive à sua proposta? Como?
2. O que de `MapLayouts.gd` (2.923 linhas) se aproveita, e o que fica como legado
   2D? As primitivas de costa orgânica valem a pena portar?
3. Onde moram hoje colisão e navegação do 3D, e o que muda?
4. Qual tamanho de chunk, **com benchmark nesta máquina** — não escolhido no papel?
5. Como o `zones.json` (que tem `tile_rect` em tiles) se liga a chunks em metros?
6. Como um `regenerate chunk 4,7` **não** apaga quest, NPC e landmark manual?
7. Quantos MB de `.glb` e de `.pck` a sua arquitetura acrescenta — dado que já
   estamos em 55,5 MB?
8. O que é gerado no Blender e o que é multiplicado no Godot, arquivo por arquivo?
9. Riscos, e qual deles você acha mais provável de dar errado.

### Depois da auditoria aprovada — o MVP, e só ele

**WORLD_LAB, ~256 × 256 m**, contendo **uma** de cada coisa:

```
1 terreno · 1 colina · 1 aclive · 1 declive · 1 penhasco pequeno
1 praia   · 1 trecho de água    · 1 caminho · 1 floresta
3 árvores base · 3 rochas base  · grama     · 1 entrada de caverna (PLACEHOLDER)
```

**Nada além disso.** A entrada de caverna é uma boca na rocha que não leva a
lugar nenhum — a Cave Factory é outro épico.

### A ordem, e a regra que a torna útil

```
FASE 1  auditoria                          → PARAR, Gabriel aprova
FASE 2  world spec + seed + masks
FASE 3  terrain generator
FASE 4  WORLD_LAB sem vegetação            → PARAR, testar o PLAYER no terreno
FASE 5  Rock Factory (3 famílias)
FASE 6  Tree Factory (3 famílias)          → PARAR, olhar no jogo
FASE 7  grama (MultiMesh no Godot)
FASE 8  regras de bioma (data-driven)
FASE 9  caminhos (spline)
FASE 10 água e costa
FASE 11 entrada de caverna (placeholder)
FASE 12 chunks + benchmark
FASE 13 integração no Godot + screenshots + relatório de performance
```

> **Se o terreno estiver ruim, NÃO construa floresta em cima dele.**
> Se as árvores estiverem ruins, não gere 500. Corrija a base.
>
> Essa frase é do Gabriel e é a mais importante do pedido inteiro — é
> exatamente o erro que produziu o primeiro lote de assets "brutos".

### O que o mundo precisa ser, visualmente

**Stylized low-poly open world.** Formas orgânicas, geometria limpa, leitura clara
à distância, silhuetas interessantes, caminhos legíveis.

**Não:** voxel, Minecraft, blocos, ruído procedural puro, fotorrealismo, terreno
plano com objetos jogados por cima, vegetação espalhada por `random`.

**LOW-POLY NÃO É BAIXA QUALIDADE.**

### As regras de conteúdo que eu manteria palavra por palavra

- **Camadas, não ruído:** landmass → elevação macro → cristas/vales → elevação
  local → erosão → costa → caminhos → masks de gameplay → biomas → vegetação → props.
- **Slope classificado** (`FLAT / GENTLE / MEDIUM / STEEP / CLIFF`) alimentando
  vegetação, material, colisão e navegação. **Sem escolher números sem testar o
  movimento real do player** — e o ângulo máximo de subida já existe em
  `Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA` (46°). Comece dele.
- **Transição de bioma nunca é uma linha.** Floresta → floresta rala → campo →
  campo seco → deserto.
- **Densidade não uniforme:** clareiras, prados, formações de pedra, lagoas.
- **Landmarks manuais têm prioridade** sobre scatter procedural. Um mundo todo
  igual não é navegável.
- **Scatter por regra, não por sorteio:** bioma × slope × altitude × mask de
  floresta × distância do caminho × seed.
- **Colisão ≠ malha visual.** Árvore colide pelo tronco; pedra por convexo
  simples; copa não colide.
- **Costura entre chunks é crítica** — nada de rachadura, buraco, salto de altura
  ou normal incompatível. Com **validação automática de borda**.
- **Biomas em JSON**, nunca no gerador. `data/world/biomes/*.json`.
- **Validadores automáticos**, crescendo com o tempo: árvore flutuando, pedra
  enterrada, árvore no caminho, objeto submerso, material faltando, colisão
  faltando, escala anômala.

### AI-first, que é o objetivo real

O ponto não é "a IA gera mapas". É **"a IA opera uma fábrica determinística de
mundos"** — mudando **dados**, não vértices:

> *"floresta 20% mais densa"* → `forest_density: 0.45 → 0.65`, e regenerar **só
> os chunks afetados**. Não editar 5.000 árvores.

### A entrega, e como ela é julgada

Screenshots **dentro do Godot**, no WORLD_LAB, com o **player real** e Pokémon
**pequeno, médio e grande** na escala de cada espécie (`PokemonScale.gd` já tem
as 151 alturas reais — **não redimensione Pokémon** pra combinar com o player).

A pergunta que decide não é "o Blender gerou?", é:

> **"Esse mundo parece pertencer ao nosso jogo, e dá pra entender onde eu posso andar?"**

E ao terminar: **atualize `docs/QUADRO.md` na mesma sessão** (regra do Gabriel,
17/09).
