# PLAYER 3D V1 — relatório de entrega

**ASSET:** Player V1 / treinador explorador adolescente
**TYPE:** personagem humanoide estilizado, game-ready
**SOURCE:** `assets/characters/player_v1/player_v1.blend`
**RUNTIME EXPORT:** `assets/characters/player_v1/player_v1.glb`

| Item | Resultado |
| --- | --- |
| Escala/origem | 1 unidade = 1 m; 1,600 m; pés em Y=0 no Godot |
| Frente | −Y no Blender → −Z no Godot |
| Polígonos fonte | 4.086 triângulos |
| Materiais | 9 PBR simples; sem texturas externas |
| Rig | Sim — 25 ossos, incluindo tronco, membros, boné e mochila |
| Skinning | Sim — pesos explícitos por região, testados em pose de locomoção |
| Animações | `PLAYER_V1_IDLE`, `PLAYER_V1_WALK`, `PLAYER_V1_RUN` (in-place) |
| GLB | 355.884 bytes; 9 malhas de runtime mescladas por material |
| Cena de teste | `scenes/tests/player_v1_test.tscn` |
| Orientação | Frente canônica −Z no Godot; medida no pacote importado |
| Godot test | PASS — `teste_player_v1_glb.gd` e `teste_player_v1_frente.gd` |

## Validações executadas

- Malha: altura, origem, orientação, nomenclatura e orçamento de triângulos.
  A exportação espelha a fonte em Y antes do GLB, pois a conversão glTF leva
  Blender +Y para Godot −Z; não existe correção de yaw no controlador.
- Rig: 25 ossos obrigatórios, modifier Armature e influência útil em 112 malhas-fonte.
- Animação: Actions persistidas, membros alternados em walk/run e root sem deslocamento.
- Exportação: GLB binário com skeleton e os três clips importados no Godot.
- Integração isolada: terrain atual, vegetação, rocha e Charizard/Pidgeot/Gyarados na cena de referência.

## Known issues / próximos gates

- O modelo **não foi conectado** ao `TrainerController3D`; substituir a cápsula oficial muda uma cena/contrato misto e exige RFC com Claude.
- A validação automática usa Godot headless. Uma revisão estética humana em renderização real continua recomendada antes da troca do placeholder.
- A fonte continua modular por manutenção; o GLB runtime é otimizado para nove malhas, sem alterar a fonte editável.
