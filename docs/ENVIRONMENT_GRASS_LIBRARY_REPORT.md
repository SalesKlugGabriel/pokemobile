# Biblioteca ambiental — grama

Data: 22/09/2026

## Entrega

| Asset | Tipo | Triângulos | Altura nominal |
| --- | --- | ---: | ---: |
| GRASS_SHORT | tufo baixo | 24 | 0,30 m |
| GRASS_MID | tufo médio | 30 | 0,56 m |
| GRASS_TALL | tufo alto | 36 | 0,88 m |

Cada tufo é composto por cards de lâminas em duas seções, com curvatura,
largura e inclinação determinísticas. A entrega elimina a antiga composição de
seis espinhos triangulares; continua leve para `MultiMesh` e para o shader de
vento V3 já existente.

**Materiais:** PBR simples por altura, com roughness alta.
**Texturas:** nenhuma; o shader V3 da cena mantém a variação de vento.
**Rig / animações:** não se aplicam a vegetação estática instanciada.
**Export:** GLB; fonte em `assets/models/environment/grass/source/grass_library.blend`
e scripts em `tools/blender/environment/`.

## Validação

- Preview: `assets/models/environment/grass/previews/grass_library.png`.
- Godot: `teste_biblioteca_grama_3d.gd` — **12 ok, 0 falhas** (importação,
  escala, apoio em Y=0 e densidade crescente).
- Factory: `teste_world_factory_terrain_lab.gd` — **20 ok, 0 falhas**.

## Limitações conhecidas

- Arbustos são uma camada distinta e ainda não foram inseridos na spec/scatter;
  não foram simulados como grama grande.
- A inspeção de FPS e composição em navegador real permanece pendente.
