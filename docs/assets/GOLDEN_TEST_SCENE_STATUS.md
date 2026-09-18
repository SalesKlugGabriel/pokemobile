# Golden Test Scene — status

## Escopo

Área de referência limitada a **100 × 100 m**. A expansão do mapa está congelada até os gates visuais serem aprovados.

## Composição atual

- costa com água rasa/profunda e transição de areia;
- elevação/falésia ao norte;
- floresta agrupada no quadrante oeste;
- clareira central com treinador e Charizard;
- caminhos conformados à altura do terreno;
- rochas instanciadas por `MultiMesh`;
- grama instanciada por `MultiMesh`;
- iluminação direcional, céu procedural e névoa atmosférica.

## Gates

| Gate | Estado | Observação |
|---|---|---|
| Terreno | WIP | malha refinada e costa funcional; erosão artística ainda pendente |
| Vegetação | WIP | clusters e seed determinística; variantes orgânicas de árvores ainda pendentes |
| Materiais | WIP | shaders de terreno/água/árvore ativos; paleta final ainda pendente |
| Iluminação | WIP | céu, sol, sombra e fog ativos; composição de luz ainda pendente |
| Trainer | WIP | rig e Actions validados, modelagem ainda blockout |
| Pokémon | PASS inicial | Charizard Golden Pass validado no Godot |
| Animação | PASS inicial | locomação e estados de combate integrados para Charizard |
| Godot | PASS técnico | exportação Web sem erros de script |

## Critério para desbloquear expansão

Nenhuma expansão para 500 × 500 m ou novos biomas até Terreno, Vegetação, Materiais, Iluminação e Trainer saírem de `WIP`.
