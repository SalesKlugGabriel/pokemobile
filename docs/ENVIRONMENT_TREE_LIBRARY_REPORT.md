# Biblioteca ambiental — árvores

Data: 22/09/2026

## Entrega

| Asset | Tipo | Triângulos LOD0 | Triângulos LOD1 |
| --- | --- | ---: | ---: |
| TREE_A | árvore costeira estilizada | 898 | 341 |
| TREE_B | árvore baixa e aberta | 762 | 289 |
| TREE_C | árvore alta de copa densa | 1.034 | 392 |
| TREE_D | árvore inclinada de copa larga | 898 | 341 |
| TREE_E | árvore alta de copa larga | 1.034 | 392 |

**Modelagem:** tronco, raízes e galhos são malhas tubulares por anéis; a copa é
composta por lobos facetados assimétricos em camadas. Nenhum asset usa
cilindro + esfera como geometria final.

**Materiais:** dois PBR simples e reutilizáveis por asset (casca e folhagem).
**Texturas:** nenhuma; paleta e roughness são materiais de tempo real.
**Rig / animações:** não se aplicam a props estáticos.
**LOD:** LOD1 com 38% dos triângulos do LOD0, em média; a Factory preserva os
cinco caminhos existentes, seus MultiMeshes, ranges de visibilidade e seed.
**Export:** GLB, fonte Blender reproduzível em
`assets/models/environment/trees/source/tree_library.blend` e scripts em
`tools/blender/environment/`.

## Validação

- Preview de inspeção: `assets/models/environment/trees/previews/tree_c.png`.
- Godot: `scripts/tests/teste_biblioteca_arvores_3d.gd` confirma importação,
  altura, apoio em Y=0 e redução geométrica real no LOD1 de cada variante.
- Factory: `scripts/tests/teste_world_factory_terrain_lab.gd` passou com
  **20 ok, 0 falhas** após a substituição dos GLBs.

## Limitações conhecidas

- Não há colisão de props nesta fase; isso é decisão da integração de gameplay.
- O navegador real ainda precisa medir FPS e a leitura da composição à distância.
- Vento em folhagem e LOD adicional são melhorias futuras; esta entrega não
  altera a arquitetura da World Factory nem cria scatter paralelo.
