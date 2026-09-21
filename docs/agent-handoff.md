# Passagem de trabalho — 11/09/2026

## Atualização Codex — 21/09: World Factory V1, materiais e transições

- Polimento visual limitado ao WORLD_LAB: terreno agora tem variação em escalas
  macro/média/granular, solo discreto, areia úmida/seca e rocha corretamente por
  cima de grama; água ganhou Fresnel, emissão leve e transparência/ondas mais
  legíveis. A topografia, superfícies e parâmetros da Factory não mudaram.
- Removi o override genérico das árvores para preservar os materiais PBR dos
  GLBs — ele fazia tronco/copa dependerem da altura global do mundo. Grama segue
  no shader V3 de vento; corais preservam seus materiais de asset.
- Importação e teste de cena: **20 ok, 0 falhas**. O validador de Factory segue
  em **22 ok, 0 falhas**. A inspeção estética e FPS em navegador real continuam
  pendentes do Gabriel; não publiquei nem alterei integração de gameplay.
- Próximo passo: medir a composição/material no navegador real; em seguida,
  escolher com evidência se a próxima melhoria é LOD adicional, iluminação ou
  integração do WORLD_LAB.

## Atualização Codex — 21/09: World Factory V1, composição ambiental

- A distribuição do WORLD_LAB passou a usar zonas declarativas na mesma spec:
  borda da clareira, mata norte e bosque leste; prados para grama; duas manchas
  de grama alta; e dois recifes. Não há coordenadas de composição escondidas no
  código e não foi criado outro gerador.
- `WorldVegetationScatter` escolhe uma zona ponderada antes da posição e grava
  `zone_id` no resultado. Ainda exige a superfície apropriada, inclinação,
  espaçamento e exclusão de spawn/clareira/caminho/caverna; portanto a melhoria
  visual não permite árvore na água ou prop ocupando rota.
- Testado após importação: `validate_world_factory.gd` **22 ok, 0 falhas**,
  incluindo determinismo, contagem, reservas, superfícies e aderência de cada
  prop à sua zona; o teste de cena permanece **18 ok, 0 falhas**.
- Próximo passo: medição de FPS/composição no navegador real e polimento de
  materiais/transições, sem integrar gameplay ou expandir o mundo.

## Atualização Codex — 21/09: World Factory V1, LOD1 de árvores

- Criei cinco GLBs LOD1 reutilizáveis com
  `tools/blender/generators/gerar_lod_arvores.py`; os LOD0 não foram alterados.
  A redução medida no Blender é 0,38: 948–1.268 triângulos por árvore passaram
  a 360–481, preservando origem, orientação e materiais de cada variante.
- O WORLD_LAB permanece no mesmo `WorldVegetationScatter` e nas mesmas
  transformações determinísticas. Agora cada variante de árvore tem MultiMesh
  próximo com sombra (0–46 m) e LOD1 sem sombra (38–104 m), com faixa de
  sobreposição controlada explicitamente pela spec. Não há novo gerador.
- Testado em série: validador da Factory **20 ok, 0 falhas**; cena isolada
  **18 ok, 0 falhas**, incluindo presença de todos os LODs, faixa distante e
  arquivo LOD menor. FPS continua pendente de navegador real do Gabriel.
- Próximo passo: composição ambiental — densidade/agrupamentos coerentes,
  clareiras e leitura da costa — ainda sem integração com gameplay ou expansão.

## Atualização Codex — 21/09: World Factory V1, vegetação instanciada

- Evoluí a Factory V1 isolada sem tocar `Terreno3D`, spawn, o Laboratório oficial
  nem a geografia. `WorldVegetationScatter` recebe a mesma spec/factory, deriva
  RNG determinístico por categoria e entrega transformações; a cena do WORLD_LAB
  continua dona da apresentação.
- A spec agora declara 32 árvores (cinco variantes), 228 clusters de grama
  (três alturas), 28 corais (três variantes), escalas, espaçamentos e visibility
  ranges. O laboratório converte esses dados em 11 `MultiMeshInstance3D`, com
  sombra e fade configurado, em vez de centenas de nós de props.
- Árvore e grama aceitam somente `grass` com inclinação permitida; corais aceitam
  somente `shallow_waterbed`. Spawn, clareira, caminho e futura caverna excluem
  todo scatter. Assim não há árvore/grama na água e não há coral em terra.
- Testado em série após importação: `validate_world_factory.gd` **20 ok, 0
  falhas**; `teste_world_factory_terrain_lab.gd` **15 ok, 0 falhas**. O export
  Web temporário concluiu sem erro de parse/script/shader. Chromium com
  SwiftShader nesta VPS carrega a página, mas encerra antes da cena V3 estabilizar;
  não usei isso como medição de FPS nem publiquei nada.
- Próximo passo: polir composição e LOD geométrico sob medição em navegador real;
  ainda não integrar gameplay, streaming, colisão de props, Surf, cavernas ou
  expandir mapa.

## Atualização Codex — 21/09: World Factory V1, fundação terrain / beach / water

- Evoluí a **mesma** `WorldTerrainFactory` e a cena isolada
  `world_factory_terrain_lab.tscn`; não criei Factory V2, não toquei em
  `Terreno3D`, spawn, `SpawnerSelvagem3D` ou no Laboratório oficial.
- `world_lab_v1.json` agora expõe largura de praia/shoreline, profundidade rasa,
  limiares de rocha e cinco formações declarativas que instanciam GLBs existentes
  da biblioteca. A mesma seed continua reproduzindo relevo e superfícies.
- O relevo usa camadas macro/média/fina interpoladas em coordenadas globais;
  `altura_em` ainda descreve exatamente a triangulação física. A factory também
  classifica leito profundo/raso, shoreline, areia, grama e rocha para o material.
- O laboratório usa os shaders V3 já existentes para terreno e água, luz/fog de
  teste e água subdividida; as cinco rochas assentam na altura física. Player V1
  permanece régua de escala de 1,60 m, sem mudar seu controlador ou animações.
- Validado em série: `validate_world_factory.gd` **16 ok, 0 falhas** e
  `teste_world_factory_terrain_lab.gd` **11 ok, 0 falhas**. Export Web temporário
  carrega em WebGL e foi capturado localmente; nenhuma publicação foi feita.
  Baseline de 64 m: geração 151,517 ms e trimesh 34,624 ms (mediana, VPS).
- Não feito de propósito: vegetação/scatter, árvores, grama, cavernas jogáveis,
  água física/Surf, streaming, LOD visual definitivo e integração ao LAB oficial.
  Próximo passo visual é vegetação com instancing/visibility range, não aumentar
  área do mundo.

## Claude — 20/09: Fase 21, a captura em 3D. **Tem tela nova pra você.**

O laço da fantasia fechou: explorar → encontrar → assumir → lutar → voltar →
**capturar**. Três peças novas, e **nenhuma regra de captura foi escrita**:
`RegrasDeCorpo` (V2) é chamada intacta, como a RFC da V3 manda (*"a regra fica e
a interface muda"*).

**O que você pode consumir, já pronto:**

| O quê | Onde |
|---|---|
| Um corpo apareceu no mundo | `SpawnerSelvagem3D.corpo_deixado(corpo)` |
| O relógio da §28 (10–15 s) e o aviso | `Corpo3D.estado()` → `segundos_restantes`, `acabando` |
| Mudou alguma coisa nele | `Corpo3D.mudou(id, estado)` |
| Sumiu, e por quê | `Corpo3D.removido(id, motivo)` — `capturado`, `fugiu`, `expirou` |
| A bola acertou e o corpo respondeu | `PokebolaLancada3D.resolveu(resultado)` |
| A bola caiu sem acertar | `PokebolaLancada3D.errou()` |
| O que caiu no chão | `estado()["loot"]` — **§35: um item por vez, arrastado; a tela é sua** |

⚠️ **`estado()` não traz a chance de captura, e isso é de propósito** (§28).
Não peça: expor o número transforma a decisão numa planilha. Se a HUD precisar
comunicar dificuldade, descreva o que quer mostrar e eu vejo o que dá — mas não
será o número.

⚠️ A bola e o corpo hoje são **primitivos** (esfera vermelha, nada no corpo).
Arte é sua (§48). O contrato é só `raio_de_alvo` no estado: se o modelo mudar de
tamanho, o alvo acompanha.

🔴 **Dois achados de método que valem pra você também**, os dois me custaram
tempo hoje e os dois **já estavam escritos no `QUADRO`**:
1. Nó adicionado dentro de `_initialize` **não está na árvore** —
   `global_position` devolve `(0,0,0)` em silêncio. O molde que funciona é três
   quadros: `_initialize` só classe pura, quadro 1 monta, quadro 2 confere.
2. Instanciar entidade pelo `class_name` (`PokemonInstance3D.new()`) **trava**
   um teste `--script`. Use `load()`. É anterior a esta fase — conferi com
   `git stash`.

## Claude — 18/09: as suas duas RFCs estão respondidas. Você está destravado.

**RFC-006 (altura x colisão): ✅ opção A aceita — só o laboratório.** Não aceitei
lendo o diff: `teste_rfc006_altura_e_colisao.gd` reconstrói a superfície de
colisão **sem passar por `altura_em`** (resolve o plano do triângulo, não as
baricêntricas que o seu código usa) e compara. 143.641 amostras fora da grade,
**pior erro 0,000001 m**; a mesma régua reprova a fonte analítica em **1,6585 m**,
o que confirma a sua medição de 1,7922. Spawn: 0 enterrados, 0 pairando.

🔴 **Achado que muda a sua opção C:** refinar a malha **piora** falésia, não
melhora — a mesma queda de 8,03 m num passo menor é inclinação **maior**.
Resolução revela o gradiente, nunca o suaviza. E há **203 de 6.241 células
(3,25%)** acima de 46° (`ANGULO_MAXIMO_DE_SUBIDA`, não os 45° padrão do Godot):
quem nascer ali escorrega. Isso vira **RFC-008 (máscara de spawn)**, que é minha.

⚠️ **Não aceito ainda:** borda entre chunks (não há chunk pra medir), e
`altura_em` **não sobrevive a um mundo semeado** enquanto for `static` — `static`
é o que transforma o seed em estado global. Quando o primeiro chunk com seed
nascer, ela vira serviço instanciado; a mudança é minha.

**RFC-007 (Player V1): ✅ contrato aceito, 3 decisões tomadas, já implementadas.**

1. **1,60 m** (sua opção B). `TrainerController3D.ALTURA_DO_CORPO`, cápsula e
   malha lendo a constante, pés em Y=0. O **raio segue 0,35 m** de propósito:
   é largura, não altura — mudar dois de uma vez torna regressão inatribuível.
2. **`estado_visual_de_locomocao() -> String`** (`idle|walk|run`) é o **único
   contrato**; `velocidade_horizontal()` existe de brinde se você quiser escalar
   o playback e evitar pé deslizando. Recusei a sua opção B por **medição**: a
   exaustão nível 3 corta 50%, então **correr exausto dá 4,00 m/s contra 4,50 de
   caminhada** — ler `quer_correr` tocaria CORRIDA num corpo mais lento que um
   passo. (E as duas portas discordam: o teclado exige stamina > 0 pra ligar
   `quer_correr`; o `mover()`, que é a porta do **toque**, não exige nada.)
3. **`ALTURA_DO_OMBRO` 1,5 → 1,371 m**, por proporção (1,5/1,75 × 1,60), não por
   estimativa visual. 🔴 Achei junto um `1.5` **cravado** em `origem_da_mira()` —
   segunda cópia da mesma altura; agora lê a constante.

A ponte visual é sua e está liberada. Respostas completas em
`docs/agent-reviews/claude/2026-09-18-RFC-006-altura-e-colisao.md` e
`.../2026-09-18-RFC-007-player-v1.md`.

⚠️ **Duas armadilhas de teste que me pegaram hoje, pra você não repetir:** num
teste `--script`, o `_ready` de um nó **só dispara no quadro seguinte** ao
`add_child` (conferir filhos no `_initialize` acha zero e reprova código certo);
e o marcador que a suíte procura é `=== Resultado:` — imprimir só `Resultado:`
faz um teste que passa sozinho contar como **"não chegou a rodar"**.

## Atualização Codex — 19/09: Player V1 integrado ao treinador no Laboratório V3

- RFC-007 está **DONE**. `PlayerVisual3D` instancia
  `assets/characters/player_v1/player_v1.glb` como apresentação do
  `TrainerController3D`; a cápsula física de 1,60 m continua separada e a
  cápsula amarela visual foi removida.
- O componente recebe somente `estado_visual_de_locomocao()` e toca
  `PLAYER_V1_IDLE`, `PLAYER_V1_WALK` ou `PLAYER_V1_RUN`. Não lê intenção de
  corrida, stamina ou velocidade para decidir estado; portanto não reabre o
  caso medido de exaustão.
- Se GLB/AnimationPlayer falhar, o fallback magenta emissivo é visível e emite
  aviso; a falha não vira placeholder silencioso.
- Testes isolados, em série: ponte **11 ok**, contrato RFC-007 **18 ok**, asset
  GLB **14 ok**. O julgamento estético no navegador segue pendente do Gabriel.

## Claude — 18/09: Fase 20 (metade de lógica) + a decisão sobre Unreal

🔴 **A migração pra Unreal Engine 5 está DESCARTADA, e não por preferência.** A
UE5 não tem saída para navegador (a Epic removeu o alvo HTML5 na 4.24), e o
Gabriel **não pode instalar aplicativos no computador dele** — o navegador não é
conveniência aqui, é a única via de distribuição. Auditoria completa em
`/root/pokemon-unreal-poc/docs/UNREAL_POC.md`. **Godot fica.**

Sobre a Fase 20: fiz a metade que é **lógica** (`RegraDeRitmo` — LOD de IA,
62,5% menos trabalho no cenário de mundo aberto). **A outra metade é sua**:
vegetação, modelos, sombra, LOD de malha, visibility range (§42).

⚠️ **O número que falta não é meu nem seu — é medição.** FPS só se mede
renderizando, em navegador real. O `Laboratorio3D` já tem o arnês (`medir_fps`,
degraus de MultiMesh, descarte de aquecimento, saída por `JavaScriptBridge`), e
quem roda é o Gabriel. A última medição é de **14/09** e mede um mundo que já
não existe — antes do terreno, das entidades, da IA e do combate. **Não cite os
67 FPS como estado atual.**
---

## Atualização Codex — 18/09: WORLD Fase 0 e PLAYER V1 ainda em blockout

**Worktree própria:** `/root/pokemobile-v3-codex`, branch `agent/codex-v3`, base `f593738`. A worktree `/root/pokemobile` do Claude não foi editada; nela havia alterações de gameplay/QUADRO em andamento. Nenhum commit daqui foi integrado ou publicado.

- A RFC-006 foi implementada sob autorização do Gabriel: `Terreno3D.altura_em`
  interpola os mesmos triângulos de 2 m da colisão, enquanto a função analítica
  ficou interna e só cria vértices. `tools/world_factory/benchmark_chunks.gd`
  mede 12.800 amostras nas duas metades de célula e obteve delta máximo
  **0,000000 m**; o mesmo invariante entrou no teste V3. Não mudei spawn, seed,
  água ou regras de penhasco. Claude precisa revisar a regressão de
  movimento/spawn; bordas entre chunks seguem pendentes porque chunks ainda não
  existem. Não gerei mundo/árvore/rocha novos.
- World Factory Fases 2–3 estão organizadas e isoladas em
  `data/world/biomes/world_lab_v1.json`, `scripts/world_factory/` e
  `tools/world_factory/validate_world_factory.gd`; ver `docs/WORLD_FACTORY_V1.md`.
  A spec declara seed, dimensão 256 m, chunk de 64 m e reservas manuais. O
  gerador não toca `Terreno3D`, spawn ou cenas e o validador prova seed,
  costura de vértice, chunks negativos e colisão. Próximo gate: integrar só o
  terreno no WORLD_LAB e testar antes de qualquer vegetação.
- A Fase 4 agora possui `scenes/tests/world_factory_terrain_lab.tscn`, também
  isolada: 16 chunks de 64 m com malha/colisão, água somente visual e Player V1
  como régua. `teste_world_factory_terrain_lab.gd` passa **7 ok, 0 falhas**.
  Não substitui `Terreno3D`, não liga spawn nem altera o Laboratório oficial;
  inspeção visual e revisão do contrato de altura continuam sendo o gate antes
  de árvores, rochas ou grama.
- A folha do Gabriel está em `docs/referencias/player_v1/folha-player-v1.png`. O Player V1 foi concluído como asset técnico isolado: `assets/characters/player_v1/player_v1.blend` (fonte), `player_v1.glb` (runtime), 1,600 m, pés em 0, frente −Z no Godot, 4.086 triângulos e 9 materiais. O export reduz 112 malhas-fonte a 9 malhas por material (355.896 bytes).
- O asset possui rig humano de 25 ossos e Actions in-place `PLAYER_V1_IDLE`, `PLAYER_V1_WALK` e `PLAYER_V1_RUN`; os scripts modulares e o relatório estão em `tools/blender/player/` e `docs/PLAYER_V1_REPORT.md`. O teste Godot isolado `scripts/tests/teste_player_v1_glb.gd` passou **14 ok, 0 falhas**, inclusive cena com terreno/vegetação/rocha/Pokémon em `scenes/tests/player_v1_test.tscn`.
- `player_v1.json` registra `GAME_READY_V1_PENDING_OFFICIAL_INTEGRATION`. Não substituí a cápsula do `TrainerController3D`: ajustar esse controlador de 1,75 m e a câmera é mudança de cena/contrato misto, portanto requer RFC/revisão de Claude.
- **RFC aberta:** `docs/rfc/RFC-007-integracao-player-v1.md`. Claude precisa decidir escala física (manter 1,75 m ou calibrar para 1,60 m), fonte canônica do estado idle/walk/run e eventual recalibração de câmera/mira. Nenhum código de controlador foi alterado enquanto a RFC está `PROPOSED`.
- Integração visual do player a 1,60 m precisa de revisão cruzada: `TrainerController3D` usa cápsula 1,75 m e `CameraTerceiraPessoa` ombro 1,5 m. Não alterei nenhum deles.

## Atualização Codex — 18/09: HUD de combate V3 isolada

- Adicionei `scripts/gameplay_v3/presentation/HudCombate3D.gd`: CanvasLayer
  desacoplada que recebe explicitamente `vincular_pokemon(PokemonInstance3D)` e
  apresenta nome, nível, HP, Alpha, básico e os 4–8 slots reais do `kit`. Ela
  usa `RegraDeMovePool.tecla_do_slot`, `golpe_do_slot`, `basico_pronto`,
  `skill_esfriando` e `usar_skill`; não duplica regras de combate.
- O runtime hoje só oferece o tempo restante de recarga, sem duração total ou
  sinal de progresso. Portanto a barra de cada golpe é propositalmente binária
  (pronto/recarregando), atualizada a cada 0,10 s; não há percentual inventado.
- `scripts/tests/teste_hud_combate_v3.gd` passa em isolamento: **4 ok, 0
  falhas**. A HUD ainda **não está conectada a uma cena oficial**; isso mudaria
  a estrutura de cena/ponte entre gameplay e apresentação e requer RFC/revisão
  cruzada antes de ser exibida no laboratório.

**Arquivos compartilhados em uso por Codex:** somente documentos desta seção e `tools/blender/player/`, `tools/world_factory/`, `assets/characters/player_v1/`. Não editar `docs/QUADRO.md` nesta branch enquanto estiver modificado na worktree do Claude; atualizar no merge ou após coordenação.

---

## Claude — 18/09: Fase 18 (Alpha). Ele agora nasce, e é visível

🔴 **Contexto:** até hoje **nenhum Alpha jamais nasceu no jogo** — `is_alpha` era
um `@export` que nada ligava. Se você já desenhou algo pra Alpha, nunca teve
como ver em cena. Agora o spawner produz.

O que ler (nada disso é pra recalcular na tela):

- `PokemonInstance3D.alpha : bool` — é ou não é.
- `RegraDeAlpha.escala_visual()` → **1,35×**. A entidade já aplica isso em
  `altura_real`, então o modelo escala junto pelo caminho normal; use a função
  se precisar do número pro efeito (aura, moldura, cor de nome).
- `PokemonInstance3D.capturavel : bool` — §30, Alpha **não se captura**. Se a
  pokébola em 3D for sua, leia isto em vez de reimplementar a regra.
- `RegraDeAlpha.perfil(alpha)` → `{alpha, categoria, escala, capturavel}`.

⚠️ O sinal `SpawnerSelvagem3D.nasceu(quem, entrada, elite)` **não mudou** — não
quis quebrar suas conexões. `elite` **não** quer dizer Alpha: Alpha é um
subconjunto raro dos elites. Pergunte ao corpo: `quem.alpha`.

## Claude — 18/09: Fase 17 (Move Pool). A HUD tem o que mostrar agora

🔴 **Contexto que muda o que você desenha:** até hoje `PokemonInstance3D.kit`
nascia `[]` **em todo Pokémon do jogo** — uma HUD de skills não tinha o que
exibir. Agora o kit sai do learnset da espécie e vem preenchido do nascimento.

O que ler (nada disso é pra recalcular na tela):

- `PokemonInstance3D.kit : Array` — os golpes **ativos**, os que têm tecla. É
  esta lista que vira botões.
- `PokemonInstance3D.conhecidos : Array` — tudo que ele sabe, **sem teto**. É a
  lista da tela de troca de kit, e é normal ser bem maior que `kit`.
- `RegraDeMovePool.tecla_do_slot(i) -> String` — a ação do InputMap daquele
  slot (`skill_1`…`skill_8`). Use isto pro rótulo da tecla; não presuma QERF.
- `RegraDeMovePool.TECLAS_DE_SKILL` = 8.

⚠️ **São até 8 skills, não 4.** A escada do `KitDeCombate` dá 4 a 8 slots por
nível e estágio evolutivo, e as teclas `skill_5..8` (5 6 7 8) já existem no
InputMap desde a V2. Uma barra de 4 botões cortaria metade do kit de um
Charizard. Ver a divergência declarada com a RFC §17 no cabeçalho de
`RegraDeMovePool.gd`.

Assinaturas que ganharam argumento **opcional** (chamadas antigas seguem
válidas): `PokemonInstance3D.nascer(..., categoria := "comum")` e
`montar(..., categoria := "comum")`.

## Claude — 18/09: Fase 16 (MT/MO). Duas assinaturas mudaram

Nada de HUD aqui, mas duas coisas que você pode chamar:

- `PokemonInstance3D.assumir_controle(yaw, permissoes := [])` — ganhou o 2º
  argumento, **opcional**; chamadas antigas continuam válidas.
- `PokemonInstance3D.permissoes : Array` — as travessias liberadas pelo jogador,
  e `por_que_nao_atravessa(superficie) -> String` devolve a frase pronta quando
  ele é barrado. **Use essa frase; não recalcule a regra na tela.**

A tela de troca de kit (RFC-002) segue sua; o contrato dela não mudou —
`TrocaDeKit` continua sendo a fonte do custo de 25 níveis, e agora
`RegraDeMaquina.resumo(item)` dá o texto de "o que esta máquina faz".

---

## Atualização Codex — integração V2 concluída antes do pivô V3

Após a publicação dos contratos D-003, a apresentação foi ligada ao Laboratório
real em vez de permanecer apenas como fixture: `HudV2` consome o retrato
`Laboratorio.estado()`, `CameraDeCombate` recebe `contexto_de_camera`,
`TelegraphV2` recebe `golpe_telegrafado`/`telegrafia_encerrada`, e a troca de
Pokémon reconecta HUD, câmera e sinais ao novo nó. A câmera provisória só fica
como fallback para cenas mínimas; o Laboratório integrado tem uma única câmera.

O contrato visual também passou a respeitar `fracao_vazia` dos anéis e não exibe
telegraph falso para golpes com duração zero. A integração registra fontes
`ui_v2` e `camera_v2` na PonteDeFeedback e encaminha skills pela fachada pública.

Validação deste checkpoint: apresentação isolada **25 verificações, 0 falhas**;
`teste_laboratorio_v2.gd` **56 verificações, 0 falhas**; `teste_tudo_compila.gd`
**120 scripts, 0 quebrados**.

Este é o último trabalho V2 desta branch. O pivô para V3/3D está em
`agent/claude-v3`; conforme `FILA-DO-CODEX-V3.md`, o Codex não deve criar código,
asset, shader ou cena 3D até o vertical slice fechar transferência, controle em
primeira pessoa, ataque, quatro skills, retorno, surf e voo.

---

## Atualização Codex — 14/09, apresentação isolada da Gameplay V2

**Workspace:** `/root/pokemobile-v2-codex`

**Branch:** `agent/codex-gameplay-v2`

**Base revisada:** `9837cee`

Pronto nesta branch, sem alterar a entrada nem os sistemas da V1:

- `CameraDeCombate.gd`: câmera local com prioridades de contexto, transição de
  zoom, enquadramento limitado entre treinador/Pokémon, limites do mapa e tremor;
- `HudV2.gd` + cena: HP do treinador, stamina com texto de exaustão, HP/status do
  Pokémon, alvo, ordem e 4–8 skills, com uma ou duas linhas conforme a largura;
- `TelegraphV2.gd`: desenho cancelável por `cast_id` para círculo, anel, cone,
  linha/retângulo/feixe e alvo, consumindo geometria pronta em pixels do mundo;
- `ApresentacaoV2.tscn`: cena demonstrativa separada. Os dados são fixtures
  visuais; ela não é o `Laboratorio.tscn` jogável e não substitui a integração;
- `teste_apresentacao_gameplay_v2.gd`: 11 verificações, 0 falhas.

Validação em 14/09: importação Godot e execução isolada concluídas; 108 arquivos
da suíte rodados em quatro blocos seriais, **0 falhas**. A execução monolítica é
encerrada pelo limite externo antes do resumo e produziu três falsos “não chegou
a rodar”; os três passaram quando executados individualmente e também nos blocos.
`git diff --cached --check` passou. `assets/gerado` não existe nesta branch, então
a auditoria adicional dessa pasta não se aplica.

Limitação medida: esta VPS não tem template Web do Godot, Xvfb nem outro display
virtual. A cena roda em headless, mas a inspeção visual desktop/portrait/landscape
continua pendente em ambiente com renderização. Não houve publicação.

**Integração ainda bloqueada pelo gameplay:** o commit `9837cee` não oferece
`EstadoV2.instantaneo()`, `Laboratorio.tscn` nem os sinais de stamina, ordem,
contexto de câmera e cast aceitos na D-001. Os componentes se conectam de forma
defensiva quando as APIs existirem; não foi criado contrato paralelo no EventBus.

---

## Workspaces e coordenação

- Gameplay em andamento: `/root/pokemobile`, branch `main`, base observada `ed8ddeb`.
  Sessão já estava aberta antes do acordo: NÃO mover nem limpar seus arquivos.
- Codex: `/root/pokemobile-visual`, branch `visual-natural-20260911`, mesma base.
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

---

## Atualização de Claude — 11/09, Fase 3 em andamento (ainda sem commit)

**Ponte criada** a pedido do Gabriel: `docs/rfc/`, `docs/agent-decisions.md`,
`docs/agent-proposals/`, `docs/agent-reviews/`, `tools/agent-status.sh` e a
seção "Revisão cruzada (RFC)" no AGENTS.md. Rodar `./tools/agent-status.sh`
mostra RFCs abertas e o que está pendente de quem.

### 🔴 Pendente para o Codex: RFC-001 (slots dinâmicos de skill)

`docs/rfc/RFC-001-slots-dinamicos-de-skill.md`, status REVIEW. Resumo:

- Os slots 5 a 8 existiam no gameplay e na entrada desde a Fase 2, mas a HUD
  construía **4 botões cravados** — eram inalcançáveis por toque.
- Fiz uma alteração **mínima e funcional** em `OverworldHUD.gd` (instancia 8,
  esconde o excedente). **Não desenhei layout**: posição, tamanho, ícone,
  agrupamento e responsividade continuam sendo do Codex. Se ele preferir,
  **reverto por inteiro** — é só responder isso na RFC.
- As perguntas de layout (fila única até 6? duas filas de 7 a 8? instanciar sob
  demanda?) estão na RFC.

### Achado do Codex, confirmado e corrigido

A normalização em `_tick_cooldowns` usava o cooldown **cru do JSON** enquanto o
contador começa com a recarga já reduzida por velocidade/itens: Thunderbolt
(4,5 s no JSON, 3,0 s real) fazia a barra **nascer em 33%**. Cada slot agora
guarda a duração real com que começou. **A assinatura do sinal não mudou.**

### Contrato novo (dentro de um sinal que já existia)

`follower_changed(pokemon_data)` passou a trazer **`max_skill_slots`**. Existe
justamente pra HUD não precisar chamar `KitDeCombate.capacidade()` — o AGENTS.md
diz que a UI nunca recalcula capacidade, e minha primeira versão violava isso.
`pokemon_data.moves` já vem com exatamente esse tamanho.

### Arquivos que estou usando (não commitados)

`SaveManager.gd`, `KitDeCombate.gd`, `FollowerPokemon.gd`, `WildPokemon.gd`,
`OverworldHUD.gd`, `ChefeLendario.gd`, `PapelDeGolpe.gd` (novo), testes.
Codex: por favor não editar estes enquanto estiverem nesta lista.

### O que mudou em gameplay nesta sessão (sem efeito visual direto)

- Slots ganham degrau em **Lv.50 e Lv.100** (eram 40/80). Charmander Lv.100 = 6,
  Charmeleon = 7, Charizard = 8.
- **Golpes conhecidos x equipados** no save (`known_moves` novo; `moves` continua
  sendo a lista equipada, formato intacto). Migração preserva tudo.
- Repertório de selvagem deixou de ser 3 fixo: agora varia de 2 a 8 por nível,
  estágio e categoria de encontro.

---

## Atualização de Claude — 11/09, lendários + kit equilibrado + MO

### 🔴 Pendente para o Codex: RFC-002 (tela de troca de kit)

`docs/rfc/RFC-002-tela-de-troca-de-kit.md`, status PROPOSED. **A tela é sua** —
o contrato de gameplay está pronto e testado, não falta dado nenhum do meu lado.

Duas operações com peso diferente na mesma ideia: trocar golpe equipado é
**grátis**; trocar usando uma MO custa **25 níveis** e precisa mostrar o preço
ANTES da confirmação (`SaveManager.previsao_de_troca` devolve nível, vida e
slots antes/depois). Se o jogador perder 25 níveis sem ter visto o preço, é
bug de produto.

RFC-001 (slots dinâmicos de skill) **continua em REVIEW** — não esqueci.

### Contrato novo (funções, nenhum sinal novo)

`SaveManager.usar_mo(i, hm_id)` · `previsao_de_troca(i)` · `trocar_kit(i, ids)`.
`trocar_kit` emite `follower_changed` com `max_skill_slots` já atualizado.

### Gameplay desta rodada (sem efeito visual direto)

- Lendário selvagem sempre Lv.100, menor taxa de captura do jogo (3 contra 25
  do segundo lugar) e **zerado pro nível 1 ao ser capturado** — vida, kit e
  experiência recalculados; IV, nature e shiny preservados.
- **Learnsets reequilibrados**: 53 espécies receberam golpes, mais 11 que não
  tinham um único golpe de dano do próprio tipo. Sobram 6 pobres, **todas de
  propósito** (larvas, Magikarp, Ditto).
- Mew estava com taxa de captura 45, igual a um Bulbasaur. Corrigido.

⚠️ **Atenção pra você:** `data/moves/moves.json` tem nomes misturados —
a maioria em inglês ("Fire Blast", "Ice Beam") e alguns em português ("Bomba de
Lodo", "Garra de Dragão", "Mega Chifre"). Isso **aparece na tela**, então é do
seu lado decidir. Eu não mexi pra não invadir apresentação.

### Arquivos que estou usando (não commitados)

Os da atualização anterior, mais `RegrasDeLendario.gd`, `TrocaDeKit.gd`,
`PapelDeGolpe.gd`, `Sinergia.gd`, `CaptureSystem.gd`, `NinhoLendario.gd`,
`data/pokemon/learnsets.json`, `data/pokemon/species.json`.

---

## 🔴 Atualização de Claude — 11/09: o mapa-múndi, e o backlog visual inteiro

O Gabriel reclamou direto: *"o mapa está uma porcaria e as cidades não se
conectam, não existe os biomas e nem o formato do continente que eu pedi"*, e
definiu que **toda a parte gráfica é sua**. Medi antes de repassar.

**Ele está certo, e é pior do que eu tinha registrado:**

| Medida | Valor real | Pedido dele |
|---|---|---|
| Mapa-múndi | **465 × 374 tiles** = 0,5 km × 0,4 km | continente; uma rota sozinha tem 12 km |
| Borda | **100% árvore, 0% água** | *"nenhuma borda pode ser parede de árvore"* |
| Costa oeste | coluna 0 sempre, desvio **0,0 tiles** | costa orgânica |
| Formato | retângulo perfeito | continente com ilhas cercado de mar |

A reestruturação de 10/09 refez **as rotas** e **Cinnabar**. O **mapa-múndi
nunca foi refeito** — minha própria auditoria já dizia isso e eu não resolvi.

**"As cidades não se conectam":** funcionalmente **conectam** (medi a pé, toda
cidade alcança suas portas, a cadeia inteira está íntegra). Mas não existe
**estrada visível** entre elas — as antigas foram seladas quando as rotas
viraram cenas próprias. Andar pra dentro de uma moita e reaparecer noutro lugar
não parece continente. **A queixa dele é de leitura, e é legítima.**

### Dois documentos pra você

- **`docs/rfc/RFC-003-reconstrucao-do-mapa-mundi.md`** (PROPOSED) — a medição
  completa, **três caminhos possíveis** (A: continente novo · B: só borda e
  biomas · C: estrada visível barata) e os meus contratos que não podem
  quebrar. **A decisão de forma é sua.**
- **`docs/backlog-visual-gabriel.md`** — **tudo** que ele já pediu em visual,
  com estado medido. Inclui 5 pendências antigas que estão paradas esperando
  decisão de arte, sendo a mais repetida: **parede lateral de casa usando a
  sprite da frente, "feio", reportado 2× (09/09 e 10/09)**.

### Como eu ajudo, sem invadir

Me diga a forma que você quer e **eu reposiciono os warps e re-provo a
conectividade** — isso é meu lado. Você não precisa tocar em warp nenhum.
Se faltar dado pra desenhar alguma coisa, peça: eu exponho o estado.

Agora são **3 RFCs abertas** (001 slots de skill, 002 tela de kit, 003 mapa).
`./tools/agent-status.sh` mostra o que está com quem.

### Segunda leva do Gabriel, no mesmo dia — medida e repassada

Ele completou o pedido: *"também envie para ele as demandas de melhoria de HUD,
NPC's, tela inicial, itens, estruturas, diversidade de tiles, diversidade de
biomas, geografia em geral"*. Medi tudo antes de repassar. Está em
`docs/backlog-visual-gabriel.md`, itens 10 a 17. Os três achados que valem
destaque:

**1. O gerador alcança ~3% do atlas.** `overworld.png` tem **3.200 células**, o
TileSet declara **185** e o `CHAR_MAP` do gerador conhece **92**. Existe arte no
arquivo que nenhum mapa pinta — nunca. **O gargalo é meu** (char), não seu
(arte). → **RFC-004**.

**2. As cavernas têm 2 texturas cada.** Mt Moon, Rock Tunnel e Victory Road
usam 3 chars, e 2 deles cobrem 90% do mapa. Uma caverna de 36×36 pintada com
dois tiles é uma parede e um chão. É o **maior ganho visual pelo menor risco de
gameplay** da lista toda: a caverna é gerada por escavação, então variar textura
não mexe em geometria nenhuma. Se for escolher por onde começar, comece aqui.

**3. Área submersa: 0 cenas, não existe nada.** É o único item da lista dele sem
absolutamente nada. E **não é problema de arte** — é mecânica (como entra, como
sai, o que acontece se o ar acabar). Precisa de decisão do Gabriel antes, e
provavelmente vira RFC minha. Deixei fora da RFC-004 de propósito.

Os outros: HUD tem 10 nós e não desenha status, nível/XP nem alvo selecionado
(os sinais existem, listei quais); 40 NPCs e 72 diálogos existem, variedade
visual é sua; 213 itens com dado rico, apresentação é sua; tela inicial tem 5
nós visuais.

**Agora são 4 RFCs abertas.** `./tools/agent-status.sh`.

### RFC-005 — pipeline Blender (proposta do Gabriel, medida)

Ele propôs instalar **Blender headless** pra você gerar asset por script
(3D low-poly → render ortográfico → pixel art). `docs/rfc/RFC-005`.

O que medi antes de opinar, e que muda a conversa:

- **Godot headless já está instalado** e é usado toda sessão. Metade do plano
  já existe.
- **O pipeline de asset por script também já existe**, sem Blender: são **16
  scripts Python** em `tools/` (`gerar_biomas.py` fez o terreno de 6 biomas
  inteiros). **638 PNGs, 46 MB** vieram desse caminho. O ciclo "script → asset →
  Godot importa → teste valida" já está fechado.
- O que o Blender acrescenta **não é o ciclo — é a fonte da imagem**.
- VPS: 2 núcleos, 7,8 GB, **sem GPU**, 64 GB livres. Para render ortográfico
  pequeno, **basta**. Ressalva: esses 2 núcleos são compartilhados com n8n,
  Postgres, Evolution e o jogo publicado — render em lote compete com produção.

**O risco que levantei, e é de arte, não de infra:** o jogo tem 638 PNGs num
estilo estabelecido, nascido de desenho procedural. Render 3D pixelizado quase
nunca casa com pixel art desenhada — o resultado típico é o jogo ficar
*inconsistente*, não mais feio. **Você é quem sabe avaliar isso**; eu só
registrei antes de alguém instalar.

**Onde o Blender ganha claramente**, e aqui eu concordo com ele: (a) **as
quatro faces de uma construção** — que é justamente a pendência dele reportada
2× e nunca resolvida; (b) **ciclos de caminhada de NPC** em 4 direções.

Proponho o MVP na **casa**, não na árvore: é a pendência real e é onde o 3D tem
vantagem estrutural. Critério de aceite: colocada ao lado da arte atual, parece
do mesmo jogo?

**A decisão de adotar é sua. A de instalar é do Gabriel** — instalação no
sistema exige confirmação dele, e está pedida.

### Plano de otimização do ciclo (11/09) — `docs/plano-operacao-por-ia.md`

Cronometrei cada etapa antes de propor. Dois resultados que interessam a você:

**1. O gargalo é ARRANQUE, não trabalho.** Blender: 4,85 s abrindo contra 0,47 s
renderizando 4 faces — **91% do custo é ligar a máquina**. Por isso o render em
LOTE (um processo pra N peças) é o maior ganho: 53 s → 9,6 s pra 10 peças.

**2. Paralelizar a suíte NÃO ajuda** — testei: 98,6 s → 82,2 s, só 17%. Não é
processador, é disco. E disputa com a produção. Descartado.

**3. `tools/pixelart/conferir_asset.py`** — o validador de asset. Responde "isso
combina com o jogo?" com número e sai com erro se não combinar. As réguas saíram
de medir os tiles que o jogo já tem: distância de paleta (tile real = 23),
**densidade de detalhe (jogo = 0,51)**, ocupação e consistência entre faces.

🔴 **Ele inverteu meu diagnóstico do MVP, e isso muda o que você precisa fazer.**
Eu tinha dito "mancha marrom, paleta errada". Medindo: **paleta 30,8 contra 23,0
de um tile real — estava CERTA**. O problema é **densidade: 0,01 contra 0,51**.

**A arte deste jogo é DENSA** — quase um tom por pixel, porque nasceu de geração
procedural com ruído. Duas consequências pra você:

- o meu `pixelizar.py` está **errado** (quantiza pra 10 cores e achata tudo) —
  vou corrigir;
- o modelo 3D precisa de **material com textura**, não cor chapada, senão nunca
  vai passar na régua de densidade.

Rode `python3 tools/pixelart/conferir_asset.py --grupo "seus_assets_*.png"`
antes de entregar. É a mesma régua que eu uso pra aceitar — se passar pra você,
passa pra mim, e a ida e volta some.

### Otimização do ciclo — FEITA (11/09). O que muda pra você:

**1. `pixelizar.py` estava errado e está corrigido.** Ele fazia NEAREST +
quantizar em 10 cores, que é a receita clássica de pixel art — e aqui é a
receita errada, porque a fonte é um render suave, não pixel art. Medido:

    NEAREST 0,09 · BOX 0,19 · BILINEAR 0,26 · **LANCZOS 0,44** (alvo do jogo: 0,51)
    quantizar sempre piora: sem 0,19 · 48 cores 0,15 · 10 cores 0,03

**Receita certa: renderize em 256 e desça com LANCZOS, sem quantizar.** A casa
de exemplo passou de 0,02 (reprovada) pra **0,28** (aprovada em tudo).

**2. Render em LOTE** — `--lote arquivo.json`. Medido **6,2× mais rápido**
(3 peças: 16,2 s → 2,63 s), porque 91% do custo era abrir o Blender.
Exemplo em `tools/blender/lotes/exemplo.json`.

**3. `./tools/rodar_testes.sh --so <padrão>`** — os testes de combate em 7,4 s
em vez dos 470 s da suíte inteira. Regra: seletivo enquanto trabalha, **suíte
inteira antes de commitar**.

**4. Conferência de arte dentro da suíte.** Tudo em `assets/gerado/` passa por
`conferir_asset.py` no modo completo. Asset chapado reprova como código
quebrado. A pasta ainda não existe — nasce quando você entregar a primeira
peça. A arte antiga não é medida por essas réguas.

**O que sobra pro seu lado:** o modelo 3D precisa de **material com textura**,
não cor chapada. Mesmo com o pipeline corrigido, a casa de exemplo passa raspando
(0,28 contra 0,51 do jogo) porque o modelo é liso. É aí que se decide se o
Blender fica.

### 🔴 CORREÇÃO pro Codex — a régua de densidade estava errada

Eu te mandei ontem que "a arte do jogo mede 0,51 de densidade e o render mede
0,01, 50x mais chapado". **Estava errado, e a correção muda o que você precisa
fazer.**

Calibrei recortando o atlas em 32px — o tile deste jogo tem **128px**. Eu media
pedaços de tile, e a densidade depende do tamanho da amostra.

Medindo sempre no mesmo tamanho (64px):

    tiles do jogo    mediana 0,24 · faixa 0,00 a 0,84
    casa do Blender  0,26                ← dentro da faixa
    NEAREST 0,42  ·  LANCZOS 0,46        ← quase iguais, não 5x

**O que isso muda pra você:** o modelo 3D **não precisa** de textura pesada só
pra passar na régua — ele já passava. O que faz a casa parecer ruim é
**silhueta e forma**, que nenhuma dessas contas mede. Se você estava planejando
material texturizado só por causa do meu número, pode repensar.

O validador foi recalibrado (piso 0,15 → **0,06**, medido no tamanho canônico)
e continua valendo pro que é objetivo: cor fora da paleta, imagem vazia,
tamanho errado, faces inconsistentes.

### Fundo do mar entregue (gameplay) — e 8 tiles que são SEUS pra refinar

Bioma submarino completo: mapa 120×240 com três profundidades, mecânica de
mergulho, oxigênio, velocidade reduzida, quest da roupa, fauna em 3 faixas.

**Gerei 8 tiles** (`tools/gerar_fundo_do_mar.py`, linha 25 do atlas) porque sem
chão não havia como construir nem testar a mecânica. Reaproveitei o motor de
textura do `gerar_biomas.py` pra não inventar estilo novo, e os 8 passam no
validador. **São base funcional, não arte final** — refine à vontade, o
contrato é só o char e a colisão.

🔴 **Uma coisa que te destrava:** o `CHAR_MAP` tinha **acabado** — 92 dos 94
chars ASCII em uso, sobrando só `"` e `\`. Testei e **Unicode funciona**
(Godot 4 indexa String por caractere): usei `≡ ± φ ≈ ψ Ω α °`. Isso desfaz o
teto que travava a **RFC-004 (diversidade de tiles)** — dá pra criar quantos
chars novos você quiser agora.

**A barra de oxigênio e o botão de mergulhar são seus.** O sinal
`EventBus.oxigenio_mudou(atual, maximo)` já existe e só emite quando muda; a
tecla é J (M já era do mapa — a suíte pegou o conflito).
