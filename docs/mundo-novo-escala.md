# Mundo novo em escala real — blueprint (10/09/2026)

> Fonte de verdade única pras coordenadas-âncora da reestruturação geográfica pedida
> pelo Gabriel (planta à mão + prompt de escala, 10/09). Ler junto com
> `direcao-de-arte-mestre.md` (estilo visual) e `pokemobile_matriz_ecologica.md` (na
> memória — fauna por bioma, aplicar SÓ depois que a geografia estiver pronta).
>
> Decisão confirmada com o Gabriel: **escala LITERAL, 1 km ≈ 1.000 tiles** (não
> comprimida). `1 tile ≈ 1 metro`.

## Regras de forma (confirmadas ao aprovar o plano)

- Continente com várias ilhas, cercado de mar aberto por todo o entorno.
- **Nenhuma borda de mapa vira "parede de árvore" nem forma quadrada** — toda costa
  (continente e cada ilha) é orgânica de verdade. Primitivas já prontas em
  `MapLayouts.gd`: `ondular_costa`, `costurar_costa`, `amaciar_bordas` — usar em
  TODA borda nova.
- Ilhas também orgânicas (nunca círculo/quadrado perfeito).
- **Bioma de montanha de verdade** (rocha com elevação, distinto de "colinas") +
  **caverna não-linear** (padrão Rock Tunnel/Tier 10) sempre que uma rota atravessa
  montanha por dentro. ✅ Mt Moon já passou pelo retrofit da regra de caverna
  não-linear (Fase 2, 10/09) — pendência antiga, finalmente executada.

## Distância pedida × distância de hoje

| Trecho | km | tiles pedidos | tiles hoje (medido em zones.json) |
|---|---|---|---|
| Viridian–Pallet | 1 | 1.000 | ~79 |
| Viridian–Pewter | 3 | 3.000 | — |
| Pewter–Cerulean | 7 | 7.000 | ~200 |
| Cerulean–Saffron | 4 | 4.000 | — |
| Saffron–Celadon | 4 | 4.000 | — |
| Saffron–Vermilion | 2 | 2.000 | — |
| Cerulean–Lavender | 5 | 5.000 | — |
| Lavender–Fuchsia | 12 | 12.000 | ~66 |
| Cinnabar | 25 km² de área | ~5.000×5.000 se quadrada | ilha pequena hoje |

## Coordenadas-âncora do grid novo (centro de cada cidade)

Convenção herdada do mapa atual: **y cresce pra SUL, x cresce pra LESTE** (Pewter já
era a cidade mais ao norte, y≈0, no mapa de hoje — mantido). Estas são posições de
ÂNCORA (centro da cidade); a distância real percorrida vem do CAMINHO da rota entre
elas (sinuoso), não da distância em linha reta — algumas âncoras ficam mais perto em
linha reta do que o km pedido de propósito, a rota é que faz a volta certa.

| Cidade | Âncora (x, y) | Fase |
|---|---|---|
| Pewter | (0, 0) | 1 |
| Viridian | (0, 3.000) | 1 |
| Pallet | (0, 4.000) | 1 |
| Cerulean | (7.000, 0) | 2 |
| Saffron | (7.000, 4.000) | 3 |
| Celadon | (3.000, 4.000) | 3 |
| Vermilion | (9.000, 5.500) | 3 |
| Lavender | (12.000, 0) | 4 |
| Fuchsia | (12.000, 12.000) | 5 |
| Safari Zone | (13.500, 13.500) — presa em Fuchsia | 6 |
| Cinnabar | (-6.000, -1.000) — ilha isolada a oeste, mar aberto | 6 |

## 🔴 3 ilhas que JÁ EXISTEM e não podem se perder na reestruturação (lembrete
## do Gabriel, 10/09, depois da Fase 3)

Não entravam na tabela acima porque já foram construídas em sessões anteriores
(antes deste blueprint existir) — mas continuam de pé, e cada fase nova que mexer
perto delas precisa CONFERIR que elas continuam alcançáveis, com a mesma
disciplina de "checar antes de selar" das Fases 1-3.

| Ilha | Onde fica hoje | Como se chega | Status |
|---|---|---|---|
| **Ilha Gélida** (covil do Articuno) | Mar ao NORTE de Cerulean, depois da Rota 24→Rota 25→Casa do Bill (linhas negativas, mesmo `world_map`) | A PÉ (a ilha em si) + warp só pro covil de 10 andares (`WarpIlhaGelida`) | Intacta — nenhuma fase até agora tocou coordenada negativa |
| **Seafoam Islands** | Mar ao SUL de Vermilion, depois do Arquipélago Tropical (mesma faixa de colunas de Vermilion, continuando ao sul da costa) | Só por Surf/Fly — **nenhum dos dois existe ainda no jogo**, de propósito (sem warp/prédio) | Intacta — nenhuma fase até agora tocou o sul de Vermilion |
| **Ilha do Deserto** | Mar ao SUL de Vermilion, depois da Power Plant (mais ao sul que Seafoam) | Só por Surf/Fly, mesma regra acima | Intacta |

**Atenção pras próximas fases**: a Fase 4 (Saffron→Lavender) e a Fase 5
(Lavender→Fuchsia) não encostam nem no norte de Cerulean nem no sul de
Vermilion — zero risco pra essas 3 ilhas nelas. O único ponto de atenção real
é se uma fase futura decidir reconstruir Vermilion em si (ela ainda não tem
fase própria neste blueprint) — nesse caso, a saída SUL dela (pra Seafoam/
Ilha do Deserto) e a entrada norte de Cerulean (pra Rota 24/Ilha Gélida) têm
que ser preservadas ou migradas, nunca só apagadas.

## 🔴 Mudança de arquitetura (10/09, achado NA HORA de construir a Fase 1) —
## rota nova é CENA PRÓPRIA, cidade não migra

O plano original (abaixo, riscado) dizia "migra as 3 cidades pro grid novo,
offset em bloco". Ao abrir `MapLayouts._gen_world_map()` de verdade, achei que
ele é um gerador DENSO: um laço `for r in H: for c in W:` que pinta TODO
retângulo do mapa, célula por célula. Isso funciona bem pro `world_map` de
hoje (~465×374 ≈ 174 mil células) mas **não escala** pra distância pedida — só
a "espinha" principal já soma ~38.000 tiles de comprimento; numa largura
típica de rota isso passaria de 1 milhão de células só nas rotas, e o mundo
inteiro (com Cinnabar/Safari/ilhas) chegaria a centenas de milhões — inviável
como UM `_gen_*()` só.

**Solução, e é melhor que a original**: cada rota nova (ou grupo de rotas)
vira uma CENA PRÓPRIA, ligada por `WarpZone` — exatamente o padrão que os
andares de dungeon já usam (IndigoLeague_F1..F5 etc., cenas encadeadas). Pallet/
Viridian/Pewter **não precisam migrar nem mudar UM tile** — ficam exatamente
onde estão hoje (zero risco pro conteúdo já testado). Um `WarpZone` novo,
plantado dentro da área já andável de cada cidade (não no meio de terreno
novo), leva pra dentro da rota nova; a rota nova tem seu próprio `WarpZone` de
volta em cada ponta. Isso também bate CERTO com o pedido original do Gabriel
(seção 2): "cada conexão entre cidades deve ser dividida em vários segmentos
de mapa" — ele já estava pedindo múltiplas cenas, não uma reta contínua.

**Achado no caminho, corrigido**: existia uma regra de arquitetura antiga (
31/08) — "warp só serve pra caverna/subterrâneo/submarino/continente", travada
em 7 arquivos de teste (`teste_fase3_tier2..7`, `teste_fase3_mapa`) como uma
lista de exceção fechada. Rota nova quebrava esses testes de propósito (é
exatamente o tipo de coisa que eles existem pra pegar). Resolvido abrindo mais
uma exceção na lista — "Rota" — já que o pedido do Gabriel EXIGE múltiplas
cenas por rota; a regra antiga protegia "cidade não vira warp", que continua
valendo, só ganhou uma segunda categoria legítima.

**Bug real achado de brinde**: `AjudaMapa.altura_cobre_as_zonas()` (helper de
teste) somava o `tile_rect` de TODA zona do `zones.json` sem filtrar por
`map_id` — uma zona de CENA PRÓPRIA (mt_moon, rock_tunnel, e agora a rota
nova) tem coordenada local, sem relação com o grid do `world_map`. Zonas
pequenas (mt_moon, h=30) nunca estouravam o `world_map` real (374 linhas) e
escondiam o bug; a primeira zona de cena própria MAIOR que isso (rota nova,
h=1.000) expôs. Corrigido filtrando por `map_id == "world_map"` (mesma regra
que `ZoneManager.find_zone_id()` já usa).

## Fases (cada uma testável/publicável isolada — mesmo padrão "Tier N" de sempre)

0. **Esqueleto** — só as âncoras acima em `zones.json`, sem pintar nada. ✅
1. ✅ **Pallet↔Viridian↔Pewter** (1km+3km=4.000 tiles) — primeira espinha
   jogável, é onde o jogo começa. **COMPLETA (10/09/2026).**
   - ✅ **Viridian↔Pallet (1.000 tiles) — FEITO, testado (19 conferências),
     publicado.** `RotaViridianPallet.tscn` (cena nova) + `MapLayouts.
     _gen_rota_viridian_pallet()`/`_rota_viridian_pallet_cell()` + o helper
     `_misturar_bioma_cell()` (mistura gradual de bioma, testado à parte, 7
     conferências). Caminho principal ondulando (nunca reta), largura
     variável, faixa de mato alto (zona de encontro selvagem), lago pequeno
     de variedade, borda pra floresta em transição gradual (nunca corte
     seco), tudo com `amaciar_bordas`/`plantar_arvores_grandes` do jogo já
     aplicando por cima (essas passadas rodam pra QUALQUER cena, não só
     world_map). SEM montanha/caverna aqui de propósito (curta, "deve
     parecer uma viagem curta" — a exigência de montanha+caverna é da
     Pewter↔Viridian). `WarpZone` plantado dentro de Viridian (tile local
     old_r≈34, corredor cols 44-56) e dentro de Pallet (old_r≈84) — TESTADO
     visualmente (build local, screenshot), NÃO ainda percorrido a pé de
     ponta a ponta contra produção pelo Gabriel.
   - ✅ **Pewter↔Viridian (3.000 tiles) — FEITO, testado (37+9 conferências
     + suíte inteira 90/0), publicado (10/09/2026).** `RotaPewterViridian.
     tscn` + `CavernaMontanhaPV.tscn` (cena própria pra travessia). Bandas
     norte→sul: Montanha (rocha `^`, falésia `/`, cume `<`, pedregulho `>`,
     trilha `:` — biomas novos, nunca usados de verdade até agora) → blend
     → Floresta densa (substitui a antiga Viridian Forest, que virou
     conteúdo morto junto com o resto de Rota 1/2, ver abaixo) → blend →
     Campo perto de Viridian.
     **A caverna é travessia OBRIGATÓRIA de verdade**: a crista fica
     bloqueada por fora entre r=300 e r=620 (testado: nenhum tile andável
     sobra na largura inteira), só passa entrando em `CavernaMontanhaPV.
     tscn` — e essa caverna, diferente de Mt Moon/Rock Tunnel/Victory Road
     (que têm as duas bocas PRÓXIMAS), liga de verdade dois lados opostos
     (porta sul boca-Pewter ↔ porta norte boca-floresta), não-linear
     (caminhada com viés + ramos secundários, mesma técnica de sempre).
   - 🔴 **Achado crítico no meio do caminho, corrigido**: as duas rotas
     "antigas" (Rota 1 Viridian↔Pallet, Rota 2 Pewter↔Viridian), que ainda
     viviam DENTRO do `world_map` de sempre, continuavam 100% andáveis —
     um atalho reto que ignorava as rotas novas inteiras. Testei
     conectividade real e confirmei: dava pra ir de Pewter a Pallet sem
     tocar nenhuma rota nova. As duas foram SELADAS (`_route1_cell`/
     `_route2_cell` agora só devolvem floresta densa impassável, exceto o
     lago de pesca da Rota 1 — que ficou como dado histórico; o lago
     CANÔNICO agora é o da RotaViridianPallet.tscn, que já tinha um
     equivalente). 4 NPCs que moravam nessas bandas foram realocados:
     Campista/Treinador1/Pescador migraram pra dentro de
     RotaViridianPallet.tscn (mesmas coordenadas relativas, patrulha e
     presente old_rod preservados); Colecionador de Insetos (só ele
     PRECISA continuar dentro de `Entities/Colecionador` no WorldMap.tscn —
     testado por nome) foi reposicionado pro corredor de Pewter. 6 testes
     antigos ajustados pra essa realidade nova (o pior: `teste_fase3_mapa.
     gd` tinha uma asserção que EXIGIA o corredor contínuo sem quebra —
     desenho de 03/09, exatamente o oposto do que a escala real pede — 
     virou "confirma que está selado"; `teste_conectividade.gd` ganhou um
     helper `_alcancavel_via_rota()` que confere a cadeia cidade→warp→rota
     (provada à parte)→warp→cidade, em vez de exigir BFS direto no
     world_map pra Viridian/Pewter).
2. ✅ **Pewter→Cerulean (7.000 tiles) — FEITO, testado (34 conferências +
   suíte inteira 91/0), publicado (10/09/2026).** `RotaPewterCerulean.tscn`
   — primeira rota LESTE-OESTE (Pewter e Cerulean têm a mesma âncora Y). 4
   bandas do blueprint original: Rocky Highlands (com Mt Moon no meio, ver
   abaixo) → blend → Forest Valley → blend → River Basin (rio de verdade
   serpenteando ao lado do caminho — decisão de risco: não corta o
   caminho, então não precisa de ponte obrigatória) → blend → Open Fields
   perto de Cerulean.
   **Mt Moon retrofitada pra caverna não-linear** (pendência confirmada
   pelo Gabriel ao aprovar o plano): o desenho antigo era um corredor reto
   cols 9-10 com rocha só decorativa — virou caminhada com viés + ramos
   secundários (mesma técnica das outras cavernas), porta sul mantida fixa
   (compatibilidade), porta norte dinâmica (onde a caminhada realmente
   chegou). A crista da montanha na rota nova fica bloqueada por fora
   entre as duas bocas — Mt Moon virou travessia OBRIGATÓRIA de verdade,
   não mais um desvio opcional dentro do world_map.
   **Lição da Fase 1 aplicada de propósito desta vez**: antes de selar a
   Rota 3/4 antiga, conferido que zero NPC morava lá (só Cerulean, que
   ficou intocada) — nenhuma migração de NPC foi necessária aqui,
   diferente da Fase 1. 4 testes antigos ajustados (`teste_fase3_tier2.gd`
   tinha a mesma classe de asserção "corredor contínuo sem quebra" da
   Fase 1; `teste_estradas_alargadas.gd` perdeu a seção Rota 3/4, que
   testava uma largura fixa que não existe mais; `teste_spawn_por_terreno.
   gd` precisou de uma 2ª troca de zona-substituta, já que a primeira
   escolha da Fase 1 — Rota 3 — foi selada nesta fase).
   🔴 **Correção (10/09, Fase 5): a conclusão de performance desta fase
   estava ERRADA — o problema era real, só a forma de medir escondeu.**
   Na hora, medi via `_initialize()` de um script `SceneTree` headless e
   conclui "~800ms, resolvido". Na Fase 5, medindo do jeito CERTO (dentro
   de `_process()`, o mesmo caminho que o jogo de verdade usa pra rodar
   `_ready()`), a MESMA rota (Pewter-Cerulean, 700 mil tiles) media
   **12,7s**, não 800ms — `_initialize()` mede rápido demais porque o
   processo sai (`quit()`) antes de comandos do TileMap ainda em fila
   terminarem de processar; nunca era um número real. Causa raiz achada e
   corrigida na Fase 5 (ver aquela seção) — valia pra TODAS as rotas desde
   a Fase 1, não só pra esta.
3. ✅ **Nó central — FEITO, testado (48 conferências + suíte inteira 92/0),
   publicado (10/09/2026).** Cerulean→Saffron (4.000) + Saffron→Vermilion
   (2.000) + Saffron→Celadon (4.000). `RotaCeruleanSaffron.tscn` +
   `RotaSaffronVermilion.tscn` (norte-sul) + `RotaSaffronCeladon.tscn`
   (leste-oeste, como a Pewter-Cerulean) — campo aberto com mato alto e
   transição orgânica pra floresta, mais simples que a Pewter-Cerulean (o
   blueprint do Gabriel não detalhou biomas específicos aqui). Saffron
   ganhou 3 saídas novas (norte/sul/oeste); a 4ª saída dela (leste, ver
   abaixo) NÃO mudou nesta fase. Rota 5/6/7 antigas seladas — zero NPC
   encontrado nelas (igual à Fase 2, nenhuma migração necessária). 6 testes
   antigos ajustados, mesma classe de correção das Fases 1/2 ("corredor
   contínuo" virou "confirma que está selado").
   🔴 **Correção de topologia, achada ao investigar antes de construir**:
   o item 4 abaixo dizia "Cerulean→Lavender" (baseado nas âncoras Y=0 de
   ambas) — mas a implementação JÁ EXISTENTE liga Lavender a **Saffron**
   (não a Cerulean), reaproveitando Rock Tunnel: Saffron→Rota 8→Rota 9→
   Rock Tunnel→Rota 10→Lavender, tudo na mesma faixa de linhas de Saffron
   (não na de Cerulean). Forçar a topologia do blueprint teria exigido
   desmontar Rock Tunnel/Route8-9-10/Lavender/Fuchsia já construídos e
   testados — risco desnecessário. O item 4 foi renomeado pra
   "Saffron→Lavender" pra bater com o mapa real; nada foi tocado nela
   nesta fase (fica pra quando essa fase específica chegar).
4. ✅ **Saffron→Lavender — FEITO, testado (25 conferências + suíte inteira
   92/0), publicado (10/09/2026).** (5.000 tiles — nome corrigido, ver
   achado de topologia acima; era "Cerulean→Lavender" na primeira versão
   deste doc). `RotaSaffronLavender.tscn` (leste-oeste). **Rock Tunnel NÃO
   precisou de retrofit** — conferido antes de construir: já era
   não-linear desde que foi construída (Tier 10, mesma técnica
   `_rocktunnel_carve` do Mt Moon pós-retrofit), com porta única
   (entrada/saída pelo mesmo lugar). Entra na rota nova como **desvio
   opcional** (não bloqueia o caminho de superfície, mesmo desenho de
   sempre) — só o warp de entrada migrou pra dentro da cena nova; a
   caverna em si (interior, conectividade, determinismo) não mudou nada.
   Rota 8/9/10 antiga selada, zero NPC encontrado (igual Fases 2/3).
   `teste_estradas_alargadas.gd` apagado (as 3 rotas que ele cobria — 3/4,
   7, 8 — já viraram cenas próprias nas Fases 2/3/4; cobertura equivalente
   está nos testes dedicados de cada rota nova).
5. ✅ **Lavender→Fuchsia — FEITO, testado (24 conferências + suíte inteira
   93/0), publicado (10/09/2026).** (12.000 tiles, a maior jornada do
   mapa). `RotaLavenderFuchsia.tscn` (norte-sul) com os 7 segmentos de
   bioma do prompt original do Gabriel: Campo Seco → Mata Fechada → Vale
   do Rio (com ponte de verdade, "#", cruzando o caminho) → Pântano →
   Floresta Tropical → Planície Costeira → Arredores (encosta em Fuchsia).
   **Primeira vez que "9" (mata fechada) e "z"/"!"/"("/")" (pântano) — no
   CHAR_MAP desde 05/09, nunca pintados em lugar nenhum — aparecem de
   verdade no jogo.** Única rota da reestruturação cuja âncora bate DIRETO
   com a topologia real (Lavender/Fuchsia mesma coluna), sem correção como
   a Fase 3 precisou. Rota antiga selada, zero NPC encontrado.

   🔴 **Achado crítico de performance, ao vivo, não só de teste — corrige
   uma conclusão ERRADA da Fase 2 (ver aquela seção).** Testei a rota
   pelo jeito CERTO (medindo dentro de `_process()`, não `_initialize()`)
   e achei **~17 segundos de congelamento real** entrando na maior rota —
   e, ao remedir as fases anteriores da MESMA forma, o mesmo problema já
   estava lá desde a Fase 1 (Pewter-Cerulean sozinha: 12,7s, não os 800ms
   que eu tinha reportado). Causa raiz, achada por profiling passo a
   passo: `MapLayouts.paint()` sempre rodava 6 passadas de acabamento
   (`preencher_vazios`, `amaciar_bordas` ×3, `ondular_costa`,
   `limpar_entalhes_da_costa`, `plantar_arvores_grandes`, `costurar_costa`)
   desenhadas pro `world_map` retangular de sempre (~174 mil células) —
   cada uma varre `tilemap.get_used_cells()` inteiro, e `amaciar_bordas`
   olha 8 vizinhos de cada célula, 3 vezes. Numa rota de 1,2 milhão de
   células isso sozinho custava ~10,6s. Nenhuma rota da reestruturação
   PRECISA dessas passadas — a borda orgânica, o rio/lago e a variedade de
   árvore já nascem prontos na própria função de célula de cada rota.
   **Corrigido**: as 6 passadas agora só rodam pra `map_id == "world_map"`
   (o único map_id testado/comprovadamente dependente delas —
   `teste_costa_e_surf.gd`/`teste_telhado_segundo_andar.gd` confirmam).
   Segundo achado menor no mesmo profiling: `_apply_camera_limits()`
   chamava `get_pixel_bounds()` → `get_layout()` de novo, regenerando a
   MESMA grade que `_paint_tiles()` acabara de gerar — só pra ler largura/
   altura. Corrigido com uma memoização de 1 posição
   (`_ultimo_layout_map_id`/`_ultimo_layout_dims`), segura porque só é
   lida no mesmo `_ready()` logo em seguida (dimensão nunca muda com save,
   só o conteúdo de cada célula muda — world_map incluído).
   **Resultado, medido de novo depois da correção** (mesmo método,
   `_process()`): Lavender-Fuchsia (a maior, 1,2 mi) 17s→5s; Pewter-
   Cerulean (a 2ª maior, 700 mil) 12,7s→3,4s; as demais rotas, todas
   abaixo de 2,2s. Ainda não é instantâneo, mas é uma carga de tela
   aceitável, não um congelamento — e o republish desta fase já levou a
   correção pras 4 fases anteriores também (elas estavam no ar com o
   problema desde que cada uma foi publicada).
6. **Cinnabar** (ilha vulcânica ~5.000×5.000) + **Safari Zone** (5 zonas
   encadeadas).

Depois de tudo isso: aplicar `pokemobile_matriz_ecologica.md` (fauna por bioma) —
etapa seguinte, não faz parte deste blueprint.

## Padrão pra próxima cena de rota (copiar de RotaViridianPallet.tscn)

1. `MapLayouts.gd`: nova const de largura/altura + `_gen_rota_X()` +
   `_rota_X_cell(c,r,W,H)` + registrar em `get_layout()` com o `map_id` novo.
   Reusar `_misturar_bioma_cell()`/`_progresso_transicao()` pra toda transição
   de bioma; reusar `_espalhar_sal()` pra qualquer ruído determinístico novo.
2. `.tscn` novo em `scenes/world/maps/`: copiar a estrutura de
   `RotaViridianPallet.tscn` (Script BaseMap com `map_id`, TileMap, Entities/
   Player+Camera2D com `limit_*` = tamanho da cena×128, ZoneManager,
   SpawnManager, 2 WarpZones — um em cada ponta —, DialogBox/OverworldHUD/
   PauseMenu/PartyScene).
3. `zones.json`: zona nova com `map_id` IGUAL ao `map_id` da cena (senão
   `ZoneManager.find_zone_id()` não acha) + `tile_rect` LOCAL (x:0,y:0 até a
   largura/altura da cena) + `wild_pokemon` (por ora reaproveitar o que já
   existia pra aquele trecho, até a matriz ecológica entrar de verdade).
4. `WorldMap.tscn` (ou a cena da cidade vizinha): 2 `WarpZone` novos — um em
   cada cidade que a rota conecta —, plantados numa posição JÁ ANDÁVEL da
   cidade (não em terreno novo), com `spawn_tile` mirando um ponto seguro
   (alguns tiles longe do próprio warp, pra não re-disparar na volta).
5. Teste novo no molde de `teste_rota_viridian_pallet.gd`: dimensões, grade
   real gerada, caminho andável ponta a ponta (amostragem pelo centro),
   bordas não retas, `paint()` roda sem erro, warps existem nos dois lados
   com o `target_map` certo, zona existe com `map_id` certo.
6. Rodar a suíte INTEIRA antes de publicar — a Fase 1/Viridian-Pallet quebrou
   7 testes antigos que checavam "nenhum warp de cidade/rota sobra" (ver
   achado acima); qualquer rota nova pode reabrir esse tipo de checagem.

## Migração de conteúdo existente — SÓ SE PRECISAR mover uma cidade de lugar

Não foi necessário pra Fase 1 (cidades ficaram onde estavam). Se uma fase
futura precisar mesmo mover uma cidade (não só estender a rota até ela): cada
cidade em `MapLayouts.gd` já pinta por COORDENADA LOCAL (offset a partir de
um ponto-âncora) — mover é mudar onde o bloco entra no despacho do
`_world_cell()`, não reescrever a pintura. NPCs/quests/spawns/patrulhas
daquela cidade precisariam do MESMO offset em lote.
