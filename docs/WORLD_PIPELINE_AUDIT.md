# WORLD PIPELINE AUDIT — Fase 0

**18/09/2026 · branch `agent/codex-v3` · base `f593738`**
Escopo: auditar a fábrica 3D proposta, **sem gerar ou substituir assets e sem alterar gameplay**. Esta é a entrega de aprovação anterior ao WORLD_LAB.

## Veredito

A arquitetura “Blender fabrica peças, Godot instancia por seed e máscaras” cabe no projeto, mas **não está pronta para implementação** enquanto o ownership das coordenadas legadas não for fechado com o gameplay. O contrato de altura do laboratório foi corrigido pela RFC-006; o laboratório atual tem 160 × 160 m e malha de 2 m, enquanto a fábrica pede 256 × 256 m com chunks. A mudança não é apenas visual.

O achado mais importante foi resolvido de forma mensurável: antes da RFC-006,
`Terreno3D.altura_em(x,z)` devolvia a curva contínua e podia divergir da
colisão triangulada de 2 m em até **1,7922 m**. Agora a fonte contínua só cria
vértices e a API pública interpola os mesmos triângulos A-B-C/A-C-D do colisor.
O benchmark mede as duas metades das 6.400 células: **12.800 amostras**, máximo
**0,000000 m**, nenhuma acima de 10 cm. Spawn, seguidor e chão continuam na
mesma API, sem raycast. Medição reproduzível:
`tools/world_factory/benchmark_chunks.gd`.

## 1. Contrato de altura, colisão e navegação

- `Terreno3D.altura_em(x,z)`, `ponto_em`, `superficie_em`, `caminhavel` e `inclinacao_em` são a API usada pelo laboratório, seguidor e spawn. A assinatura `altura_em(x,z)` deve sobreviver; substituir a malha por um GLB sem consulta de altura quebraria nascimento e acompanhamento. Fonte: `scripts/gameplay_v3/mundo/Terreno3D.gd`.
- `Terreno3D` constrói `ArrayMesh` e `StaticBody3D`/`create_trimesh_shape()` da
  mesma grade. A RFC-006 separou a fonte analítica de geração da API pública:
  pontos intermediários agora interpolam exatamente os mesmos triângulos da
  colisão. Para a fábrica, cada chunk deve manter a mesma regra e provar borda
  compartilhada; a solução atual não valida chunks porque eles ainda não existem.
- Não há `NavigationRegion3D`, `NavigationAgent3D` nem navmesh na V3 atual. Locomoção usa `CharacterBody3D` e regras próprias. A fábrica não deve anunciar “navegação resolvida” só porque tem terreno e colisão. Falésias, água e obstáculos precisam de máscaras de spawn e teste de alcance; o spawner atual consulta altura, mas não verifica `caminhavel` nem inclinação do ponto.
- Água atual é um `PlaneMesh` transparente **sem colisão**. A transição terra–praia–mar depende da altura e deve continuar sem degrau. Colisão de árvore deve ser tronco; grama e copa não devem criar milhares de corpos.

## 2. Legado 2D e coordenadas protegidas

`MapLayouts.gd` tem **4.531 linhas** nesta base (o encaminhamento citava 2.923) e contém boas **regras de composição**: `_mancha_de_mato` cria grupos, `amaciar_bordas` preserva estrada/prédio/água, `ondular_costa` preserva largura mínima de praia e `costurar_costa` trata a margem depois da pintura. Vale portar **as invariantes e máscaras**, não copiar `TileMap`, chars ou atlas para 3D. O gerador 3D precisa operar em metros, com camadas de macroforma, costa, caminho e reservas manuais.

Medi o dado nesta base:

| Fonte | Medição | Consequência |
|---|---:|---|
| `data/world/zones.json` | 150 zonas, todas com `tile_rect`; extensão observada x −100..7000, y −80..12000 tiles | 1 tile = 1 m é a escala, mas o laboratório de 256 m não representa Kanto inteiro |
| `data/quests/quests.json` | 62 quests; **44** com `location_tile` | o encaminhamento dizia “61, cada uma com posição”; está desatualizado nesta base |
| Quests com posição | 44/44 caem em algum `tile_rect`, mas **37/44** caem em mais de uma zona | `tile_rect` não define um dono único de bioma ou de chunk |
| `scenes/world/maps/*.tscn` | 28 cenas contêm referência textual a NPC | placements manuais devem ser extraídos/validados antes de migrar |

`location_tile` é coordenada da geografia legada, não uma autorização para deslocá-la. O vínculo 2D `(tile.x,tile.y)` → 3D `(x,z)` e sua origem/sinal precisam de um teste com landmarks conhecidos antes da migração. Zonas se sobrepõem: resolver por ordem do JSON seria arbitrário. É necessário um índice espacial com prioridade explícita de landmark/cidade/rota/bioma, e revisão dos dados ambíguos com Claude.

## 3. Ownership e regeneração seletiva

Proposta de ordem para cada chunk, sem gravar por cima do original:

1. **Camada imutável/manual:** landmarks, quest anchors, NPCs, cidades, portas/warps, caminho obrigatório e áreas reservadas; IDs estáveis. Uma reserva manual pode excluir scatter ou impor faixa caminhável.
2. **Camada geográfica determinística:** macroforma e altura contínuas em coordenadas globais; mesmas amostras na borda de chunks vizinhos. `world_seed` é separado de `RNGManager` e do `randf()` global.
3. **Camada de bioma por dados:** máscaras de altitude, costa, inclinação, zona e transição; não inferir tudo do primeiro `tile_rect` que contém o ponto.
4. **Camada procedural substituível:** árvores, rochas, grama e decoração com IDs derivados de `(world_seed, camada, chunk_x, chunk_z, variante)`. Regenerar `4,7` troca **somente** esta camada daquele chunk; manual e camadas vizinhas ficam intactas.

Guardar seed, versão do gerador, hash da configuração, IDs das reservas e hash do resultado por chunk. Testes obrigatórios: repetir seed → mesmo hash; alterar densidade florestal → só vegetação dos chunks afetados; regenerar um chunk → anchors/warps/NPCs/quests preservados; borda compartilhada → mesma altura e normal. Coordenadas negativas usam divisão inteira por **floor**, não truncamento em direção a zero.

## 4. Chunk: benchmark, não palpite

`tools/world_factory/benchmark_chunks.gd` usa a **função real** de altura de `Terreno3D`, área total 256 × 256 m, passo 2 m, 32.768 triângulos, `SurfaceTool.generate_normals()` e `create_trimesh_shape()`. Executei três repetições por tamanho em um projeto Godot 4.2.2 mínimo/headless, sem autoloads, na VPS. Resultados são medianas **CPU de construção**, não FPS/GPU nem streaming:

| Chunk | Quantidade | Gerar malhas | Criar colisão |
|---:|---:|---:|---:|
| 32 m | 64 | 83,7 ms | 32,3 ms |
| 64 m | 16 | 74,9 ms | 34,2 ms |
| 128 m | 4 | 77,6 ms | 36,7 ms |
| 256 m | 1 | 93,3 ms | 41,9 ms |

As diferenças entre 32/64/128 m são pequenas nesta amostra. **64 m é candidato de ensaio**, não decisão final: 16 chunks permitem regeneração local com menos nós que 32 m. O tamanho só fecha após medir culling, frame time, memória e travessia na GPU do desktop e no celular do Gabriel. A medição anterior de 67 FPS com 20 mil MultiMesh é desktop; não certifica celular.

## 5. Peças, instancing e orçamento de build

- Blender: malhas-fonte de três árvores, três rochas, três gramíneas/folhagens, materiais simples, origem/escala, GLBs e validadores. Os geradores existentes em `tools/blender/generators/` são ponto de partida **técnico**, não selo de qualidade final.
- Godot: terreno por chunk, masks, MultiMesh de grama/folhagem/props sem física, instâncias de árvores e rochas com colisão simplificada quando próximas; scatter reproduzível. Nunca um GLB com milhares de cópias.
- Candidatos já presentes (`tree_a/b/c`, `rock_small/round/angular`, `grass_short/mid/tall`) somam **387.752 bytes de GLB**. Reutilizá-los inicialmente acrescenta **0 bytes de novo arquivo-fonte**; a qualidade visual ainda precisa ser julgada no jogo.
- O `.pck` web de **55,5 MB** é a medição anterior registrada no pedido, não foi reconstruído nesta auditoria. Para V1, orçamento proposto: medir o delta real após export e impedir crescimento sem relatório; não prometer um número de MB antes de escolher malhas, texturas e compressão. Terreno gerado em runtime não deve ser exportado como um GLB de mundo inteiro.

## 6. Riscos em ordem

1. **Alto — ownership/identidade espacial.** Zonas sobrepostas e anchors legados tornam perigoso regenerar ou deslocar o mundo. Definir prioridade explícita e invariantes com Claude.
2. **Alto — custo mobile desconhecido.** Headless mede CPU, não GPU; benchmark desktop anterior não autoriza 20 mil instâncias no celular.
3. **Médio — borda e normais de chunk.** Altura global pode casar e ainda haver linha de iluminação, pois normais geradas por chunk não incluem o vizinho. Testar altura **e normal** na borda.
4. **Médio — bioma e navegação desacoplados.** `SpawnerSelvagem3D` não recusa água/penhasco; visual novo pode tornar bug antigo mais frequente. Requer contrato cruzado.
5. **Médio — qualidade artística.** Os GLBs atuais são candidatos, não golden assets aprovados por esta auditoria; primeiro ver três variantes no enquadramento real.

## Próximo gate

As Fases 2–3 foram iniciadas em implementação isolada: `world_lab_v1.json`,
`WorldSpec`, `WorldTerrainFactory` e o validador reproduzível estão descritos em
`docs/WORLD_FACTORY_V1.md`. A próxima entrega é a Fase 4: WORLD_LAB com o
terreno, sem vegetação, para testar treinador, praia, relevo e colisão antes de
rochas/árvores/grama. A auditoria não autoriza mudar banco ou build publicado.
