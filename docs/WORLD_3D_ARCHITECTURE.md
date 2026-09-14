# Arquitetura do mundo 3D

> Parte da [Gameplay V3](GAMEPLAY_V3.md). Estado: **proposta**, nada implementado.

## O que muda de fundo

O mundo da V2 é pintado com **caracteres**: `MapLayouts.gd` tem 4.531 linhas de
grade de char, e cada char vira um tile do atlas. Isso não converte pra 3D — é
substituição, e é o maior custo assumido do pivô.

**O que sobrevive é o dado, não a geometria.** `zones.json` guarda fauna, faixa
de nível e perigo por zona. Nada disso é 2D: só o `tile_rect` é, e ele vira
volume.

## Camadas

```
Terreno       altura, encosta, falésia, praia, água, caverna
Navegação     NavigationRegion3D — substitui o Contorno da V2
Zonas         volumes que declaram fauna, nível, perigo e regras de voo
Vegetação     MultiMesh, distribuição semi-procedural
Água          raso / profundo / mergulho
Spawn         em superfície, não em tile
```

## Terreno

Malha com altura, não tiles. **Não construir Kanto** — o slice é um laboratório
pequeno (§10 do pedido): campo, floresta, grama alta, colina, pedras, praia,
água rasa e profunda, caverna, área de voo, área de surf.

Decisão em aberto (Fase 4): `Terrain3D` de terceiros ou malha própria. A
diferença prática é ferramenta de edição contra controle total; medir antes.

## Vegetação (§24)

**Nunca em grade.** Distribuição semi-procedural com cluster, escala e rotação
variáveis, densidade por bioma.

Obrigatório desde o primeiro dia, não como otimização depois: **MultiMesh**, LOD,
visibility range e occlusion. O motivo é duro — o renderer deste projeto é
`gl_compatibility`, escolhido pro export web, e ele não tem os recursos pesados
de iluminação e culling do Forward+. Uma floresta feita de Nodes individuais
mata o navegador antes de ficar bonita.

## Grama (§25)

Variação de altura, densidade e movimento, integrada ao terreno. Solução
GPU-friendly: **milhares de Nodes individuais estão proibidos**, pelo mesmo
motivo acima.

A grama alta continua sendo o lugar de encontro escondido — a função de gameplay
que ela já tinha em 2D não muda.

## Praia (§26)

Transição contínua: terra → areia → água rasa → água profunda.

**Sem parede artificial entre mar e terra.** Era uma queixa explícita do Gabriel
no mundo 2D (a muralha de árvores na costa), e em 3D o relevo resolve sozinho —
desde que a malha seja desenhada com a transição, e não com um degrau.

## Zonas

`zones.json` sobrevive. O `tile_rect` vira volume 3D, e a zona ganha campos
novos: regra de voo (`FLY_ALLOWED` / `FLY_RESTRICTED` / `NO_FLY`, §29) e
profundidade de água.

`PerigoDaZona` (14/09) fica **intocado**: ele lê o nível médio da fauna da zona,
não a geometria. A regra que o Gabriel pediu — lugar perigoso tem **menos**
encontros, mais raros e mais fortes — vale igual em 3D.

## Spawn

`SpawnManager` é REBUILD: nascer em superfície navegável, não em tile. O que
sobrevive: os pesos por período do dia e clima (`PesoDeSpawn`), o perigo por
zona e a fauna do `zones.json`.

## Performance (§42)

Pensada desde o começo, não depois: MultiMesh, LOD, visibility range, occlusion,
pooling de efeitos, regiões de navegação, partição espacial, camadas de física,
culling e streaming futuro.

🔴 **A medição que decide tudo acontece na Fase 2**: FPS em navegador real com
uma cena 3D vazia. Se o `gl_compatibility` não aguentar o básico, a decisão vira
"trocar de renderer e perder o export web" — e é melhor descobrir com uma cena
vazia do que com uma floresta pronta.
