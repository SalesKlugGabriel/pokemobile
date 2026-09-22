# Pidgeot Golden Asset — 22/09/2026

**Canônico:** `assets/models/pokemon/18.glb`
**Fonte:** `assets/models/pokemon/source/pidgeot_golden/Pidgeot_Golden_Working.blend`
**GLB de trabalho:** `assets/models/pokemon/source/pidgeot_golden/Pidgeot_Golden_Working.glb`
**Backup anterior:** `assets/old/pidgeot_20260922/18.glb`

## Produção

O Pidgeot anterior vinha de `gerar_trio_aquatico_voador.py`: esferas UV,
cone para o bico, asas de um polígono largo e penas de cauda em cones. A
nova malha usa corpo e cabeça por perfis, bico em volume afilado, crista
em camadas, asa com braço/cotovelo e penas de duas camadas, além de cauda
em leque e pés com dedos separados. Os scripts modulares estão em
`tools/blender/pokemon/pidgeot/`. Renders de frente, lado, costas,
três quartos e poses estão em `assets/models/pokemon/previews/pidgeot_golden/`.

| Medida | Asset anterior | Golden |
| --- | ---: | ---: |
| GLB | 160.324 bytes | 143.144 bytes |
| Malhas | 1 | 1 |
| Triângulos Blender | não medido | 1.422 |
| Vértices Blender | não medido | 837 |
| Materiais | 2 | 5 |
| Ossos | 7 | 12 |
| Actions | 6 | 7 |

Os cinco materiais Principled são marrom, creme, escuro, dourado e vermelho,
sem textura externa. O número excede a recomendação histórica de dois materiais;
é um custo deliberado para separar bico/crista/olho/peito sem textura de atlas.
Esta é uma limitação para revisão de performance em lote de espécies.

**Escala e orientação:** altura 1,50 m, pés a cerca de 0 m (erro de 1,3 mm),
frente −Z no Godot. O marcador exportado aponta no eixo anatômico do bico.

**Rig:** root, corpo, cabeça, braço e antebraço de cada asa, duas pernas,
dois pés e cauda; todos os vértices possuem pesos. Sete Actions in-place:
`IDLE`, `WALK`, `RUN`, `FLY`, `ATTACK_01`, `HIT`, `FAINT`. RUN tem passada
distinta; FLY dobra e abre ambas as seções da asa. O gameplay mantém posição,
colisão e velocidade.

## Validação

- Blender 4.2.9: `validate.py` validou malha, escala, pesos, materiais, rig,
  Actions e ausência de root motion. Prévia dos oito ângulos/poses inspecionada.
- Godot 4.2.2: `teste_pidgeot_golden_working.gd` passou 16/16, incluindo
  amplitude de corrida e batimento da asa. `teste_pidgeot_golden_runtime.gd`
  passou 7/7 pelo carregamento real de `PokemonInstance3D` e
  `PokemonVisual3D`.
- Suíte completa após a promoção: **151 arquivos, 0 falhas**.
- Web publicado com carimbo `1790096755`; `/v3d/` respondeu HTTP 200 e
  carregou JS, WASM e PCK sem erro de página no navegador automatizado.
  A captura da cena completa excedeu o tempo limite do navegador em software
  da VPS; a conferência visual jogável no dispositivo do Gabriel segue aberta.

## Limites

A inspeção visual foi feita em Workbench e o teste de runtime é headless.
O navegador em software desta VPS não mede FPS de jogo com confiança; a
leitura em dispositivo real continua necessária. Dobras finas das penas,
LOD distante e atlas de materiais podem ser refinados após a aprovação
visual no laboratório.
