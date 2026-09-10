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
  montanha por dentro. Mt Moon entra pro retrofit da regra de caverna não-linear
  quando a Fase 2 (Pewter→Cerulean) chegar nela — pendência antiga, nunca
  executada.

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
1. **Pallet↔Viridian↔Pewter** (1km+3km=4.000 tiles) — primeira espinha
   jogável, é onde o jogo começa.
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
   - ⬜ **Pewter↔Viridian (3.000 tiles)** — próximo passo. Aqui entra a
     exigência de montanha+caverna não-linear (padrão Rock Tunnel) que ficou
     pendente. Biomas: Rochoso/Montanha (perto de Pewter, com caverna) →
     Floresta (existe Viridian Forest já no jogo — cuidado pra não duplicar/
     conflitar) → Campo (perto de Viridian).
2. **Pewter→Cerulean** (7.000 tiles) — Rocky Highlands→Forest Valley→River
   Basin→Open Fields. Retrofit de Mt Moon pra caverna não-linear aqui.
3. **Nó central**: Cerulean→Saffron (4.000) + Saffron→Celadon (4.000) +
   Saffron→Vermilion (2.000).
4. **Cerulean→Lavender** (5.000 tiles).
5. **Lavender→Fuchsia** (12.000 tiles, 7 segmentos de bioma — a maior jornada do
   mapa, ver texto original do Gabriel pra sequência exata: Dry Grasslands→Dense
   Forest→River Valley→Wetlands→Tropical Forest→Coastal Plains→outskirts).
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
