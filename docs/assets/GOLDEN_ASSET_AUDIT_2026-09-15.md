# Golden Asset Audit — 2026-09-15

Escopo validado na Golden Test Scene Web (100 m × 100 m). A cena foi tratada
como régua técnica, sem expansão de mundo.

| Categoria | Revisão aplicada | Validação | Estado |
| --- | --- | --- | --- |
| Árvores | 5 silhuetas orgânicas, galhos e clusters de copa; distribuição determinística e exclusão da água | GLB + MultiMesh no Godot Web | PASS (Golden v1) |
| Pedras | 5 variantes deformadas, bevel e materiais PBR com variação | GLB + MultiMesh no Godot Web | PASS (Golden v1) |
| Corais/algas | 3 famílias de coral ramificado + algas instanciadas, limitadas à água rasa | GLB + MultiMesh no Godot Web | PASS (Golden v1) |
| Grama | clusters short/mid/tall, escala por bioma, máscara de água e vento por shader | Godot Web/GL Compatibility | PASS (Golden v1) |
| Charizard | silhueta refinada, 14 bones, pesos por componente anatômico, cauda contínua e 7 Actions | importação GLB, AABB e reprodução Web | PASS técnico / ART PASS seguinte necessário |
| Pidgeot | rig específico e 6 Actions, incluindo WALK e FLY | importação GLB e lista de Actions | PASS técnico / ART PASS seguinte necessário |
| Gyarados | rig serpentino e 5 Actions, incluindo SWIM | importação GLB e lista de Actions | PASS técnico / ART PASS seguinte necessário |
| Treinador | materiais e leitura visual refinados, rig anatômico e 8 Actions | importação GLB, AABB e reprodução Web | PASS técnico / ART PASS seguinte necessário |
| Água | modo de profundidade corrigido para Godot 4 Web, ondas e transparência estilizada | navegador WebGL | PASS |

## Quality gates executados

- Escala/orientação: trainer 1,75 m; Charizard 1,70 m; Pidgeot 1,50 m;
  Gyarados 6,50 m.
- Origem: contato no chão em `Y=0` para os terrestres.
- Animação: locomotion in-place; posição e colisão permanecem no Godot.
- Performance: vegetação, rochas e corais usam MultiMesh e seeds determinísticas.
- Browser: exportação Web carregada e capturada sem erros de script, shader ou
  InputMap.

## Pendências conhecidas

Os personagens já deixaram de ser placeholders rígidos, mas ainda são modelos
procedurais low-poly. O próximo gate visual exige malha orgânica contínua,
topologia de deformação, dedos/garras/face mais definidos, weight painting suave
e revisão individual de cada ciclo. A encosta ao fundo também permanece como
blockout de terreno e não deve virar referência para expansão do mapa.
