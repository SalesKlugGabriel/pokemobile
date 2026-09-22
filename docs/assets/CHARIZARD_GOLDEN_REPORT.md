# Charizard Golden Asset — reconstrução de 22/09/2026

**Asset canônico:** `assets/models/pokemon/6.glb`
**Fonte:** `assets/models/pokemon/source/charizard_golden/Charizard_Golden_Working.blend`
**GLB de trabalho:** `assets/models/pokemon/source/charizard_golden/Charizard_Golden_Working.glb`
**Backup do anterior:** `assets/old/charizard_20260922/6.glb`

## Resultado medido

| Medida | Anterior | Atual |
| --- | ---: | ---: |
| Triângulos após importação | 3.458 | 2.328 |
| Vértices após importação | 7.286 | 2.047 |
| Tamanho GLB | 475 KB | 247 KB |
| Ossos | 14 | 23 |
| Materiais | 7 | 7 |
| Actions | 7 | 7 |

O novo corpo foi modelado por anéis de perfil e tubos anatômicos com pesos
graduais nas articulações. Cabeça e focinho foram refeitos; olhos, narinas,
mandíbula, chifres, mãos, pés e dedos têm formas próprias. A cauda é contínua e
curvada. Cada asa tem borda de ataque, membrana recortada e nervuras. A chama
possui centro e três línguas. Não há UV sphere, cone ou cilindro como geometria
final da espécie.

**Escala:** 1,70 m; pés em Y=0; frente −Z no Godot, confirmada por marcador
anatômico exportado. Comparação visual com treinador de 1,60 m em
`scenes/tests/charizard_golden_visual.tscn`.

**Materiais:** sete Principled BSDF, sem textura externa; corpo laranja, sombra
laranja, barriga creme, membrana azul, olhos, garras e chama. A regra antiga de
“máximo 2 materiais” em `POKEMON_MODEL_PIPELINE.md` já divergia do GLB anterior
de 7 slots; esta entrega preserva o número usado no runtime.

**Rig:** 23 ossos, incluindo braços, antebraços, mãos, coxas, canelas, pés,
asas, base e ponta de cauda. Pesos de pele presentes em todos os vértices.

**Animações:** `PKM_CHARIZARD_IDLE`, `WALK`, `RUN`, `ATTACK_01`, `HIT`, `FAINT`,
`FLY`. Locomoção in-place. WALK e RUN têm poses distintas de quadril, joelho,
braço, tronco e cauda. O teste Godot mediu amplitude de perna de 0,78 rad em
WALK e 1,07 rad em RUN na pose de comparação. A posição física continua sob o
controle do gameplay.

## Validação

- Blender 4.2.9: `tools/blender/pokemon/charizard/validate.py` verifica malha,
  altura, pés, pesos, materiais, rig, Actions e ausência de root motion.
- Godot 4.2.2: `teste_charizard_golden_working.gd` validou **15/15** no GLB de
  trabalho; `teste_charizard_golden_runtime.gd` validou **9/9** no canônico.
- Ensaio antes da troca: sete testes em cópia do projeto, cobrindo spawn,
  locomoção, apresentação, ataque, skills, combate 1v1 e retorno ao mundo,
  todos sem falhas.
- Suíte completa após a troca: 145 arquivos, 1 falha intermitente em
  `teste_reengenharia_combate.gd` (resistência dupla). O teste isolado passou
  em 3 de 4 repetições; o resultado calculado oscilou no limite da tolerância
  (`x0,20` a `x0,21`). Nenhum código de combate foi alterado nesta entrega.
- WebGL: cena de escala capturada em
  `assets/models/pokemon/previews/charizard_golden/godot_gameplay.png`, sem
  erro de script ou shader. Renders ortogonais de oito ângulos no mesmo diretório.

## Limitações

- A cena de escala não substitui um playtest manual completo no laboratório
  publicado. O navegador desta VPS tem apenas renderização por software e o
  WORLD_LAB completo não estabilizou nele; performance em dispositivo real
  continua por medir.
- Wing fold detalhado, blend shapes faciais e LOD distante são etapas futuras.
