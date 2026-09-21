# Rattata #19 — relatório de asset

**ASSET:** `assets/models/pokemon/19.glb`
**TYPE:** Pokémon terrestre quadrúpede, selvagem comum
**SOURCE:** `assets/models/pokemon/source/rattata_19.blend`
**BUILD:** `tools/blender/pokemon/rattata/build.py`

| Item | Resultado |
| --- | --- |
| Polígonos | 1.442 triângulos |
| Materiais | 2 PBR (`FUR`, `DETAIL`) |
| Texturas | nenhuma — cores PBR compactas para WebGL |
| Escala | 0,300 m, conforme `heights.json` |
| Origem | pés em Y=0, centrado no plano horizontal |
| Orientação | frente canônica −Z no Godot |
| Rig | sim — 14 ossos: raiz, cadeia corporal, mandíbula, orelhas, quatro patas e cauda em dois segmentos |
| LOD | LOD0; LOD1 ainda não necessário para criatura pequena |
| Export | GLB com armature, materiais e Actions |

## Animações

`PKM_RATTATA_IDLE`, `WALK`, `RUN`, `ATTACK_01`, `HIT` e `FAINT`.

As locomções são in-place: a posição, colisão e velocidade continuam sob Godot.
Previews Workbench das seis poses ficam em
`assets/models/pokemon/previews/rattata_19/`; elas foram usadas para corrigir a
hierarquia da cauda/orelhas e a ligação do rig antes da exportação final.

## Godot test

**PASS** — `scripts/tests/teste_modelo_rattata_19.gd`: 17 verificações, incluindo
altura, pés, rig, Actions, orçamento de materiais e triângulos. A regressão V3
de skills deixa de emitir o fallback de modelo ausente para a espécie #19.

## Known issues

O runtime valida e importa as Actions, mas ainda não possui uma ponte canônica
que escolha `idle/walk/run/attack/hit/faint` a partir do estado real de
`PokemonInstance3D`. Não foi criada uma leitura visual de campos internos;
o contrato necessário está proposto na RFC-010.
