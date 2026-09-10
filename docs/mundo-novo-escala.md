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

## Fases (cada uma testável/publicável isolada — mesmo padrão "Tier N" de sempre)

0. **Esqueleto** — só as âncoras acima em `zones.json`, sem pintar nada. ✅ Este doc.
1. **Pallet↔Viridian↔Pewter** (1km+3km=4.000 tiles) — primeira espinha jogável, é
   onde o jogo começa. Constrói o helper `_blend_biome_cell()` (mistura gradual de
   bioma, peça nova) + migra as 3 cidades (offset em bloco: NPCs, quests, spawns,
   patrulhas) + pinta as 2 rotas com progressão de bioma real (campo→floresta→
   colinas/montanha rochosa, com caverna se a rota cortar a montanha por dentro).
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

## Migração de conteúdo existente (por que é viável sem reconstruir do zero)

Cada cidade em `MapLayouts.gd` já pinta por COORDENADA LOCAL (offset a partir de um
ponto-âncora), não coordenada absoluta cravada — mover uma cidade pro grid novo é
mudar onde o bloco entra no despacho do gerador mestre, não reescrever a pintura.
Interiores (ginásios, Centros Pokémon, dungeons) ficam idênticos — só a entrada no
mundo aberto muda de lugar. NPCs/quests/zonas de spawn/patrulhas daquela cidade
recebem o MESMO offset em lote (script de migração, não reposicionamento manual).
