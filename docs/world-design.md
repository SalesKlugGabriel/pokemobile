# Mundo e biomas — mapa das fontes

Fonte de geografia: [mundo-novo-escala.md](mundo-novo-escala.md), código atual em
`MapLayouts.gd`, cenas `scenes/world/maps/` e zonas em `data/world/zones.json`.
Fauna: matriz ecológica do Gabriel em
`/root/.claude/projects/-root/memory/pokemobile_matriz_ecologica.md` (referência
externa desta VPS); regras implementadas nos dados e verificadas por
`scripts/tests/teste_matriz_ecologica.gd` e `teste_spawn_horario_clima.gd`.

## Objetivos preservados

- Escala literal pedida: 1 tile ≈ 1 metro, 1 km ≈ 1.000 tiles.
- Continente/ilhas cercados por mar, costas orgânicas; evitar bordas quadradas e
  paredes artificiais de árvores. Não mudar coordenadas durante polimento visual.
- Rotas longas em cenas próprias ligadas por warps; cidades existentes preservadas.
  Não substituir pelo antigo plano de um único TileMap denso gigante.
- Montanhas com elevação aparente, cavernas não lineares e identidade geológica.
- Costa em faixas: interior → vegetação costeira → areia/rocha → praia → raso → oceano.
- Bioma determina fauna; sobreposição entre áreas vizinhas, raridade e horário/clima
  pertencem aos dados e ao gameplay, nunca ao efeito visual.
- Preservar Ilha Gélida, Seafoam e Ilha do Deserto e seus acessos/progressão.

## Linguagem visual por ambiente

| Ambiente | O que o jogador deve reconhecer |
|---|---|
| Campos e rotas rurais | Grama baixa, trilhas gastas, flores pontuais, mata nas bordas |
| Mata fechada/tropical | Copas sobrepostas visualmente, raízes, serrapilheira, sombra de contato |
| Colinas/montanhas | Menos vegetação, estratos, rocha angular, paredes/elevação distinguíveis do piso |
| Lagos/costa/oceano | Barranco ou areia conforme terreno, margem rasa, azul profundo e reflexos discretos |
| Pântano | Solo úmido escuro, junco, água parada; não parecer praia azul |
| Deserto/ruínas | Areia ocre, dunas e pedra desgastada; não retângulos lisos genéricos |
| Vulcão | Rocha escura fraturada, lava legível como perigo; respeitar área de dano real |
| Gelo | Piso glacial e blocos sólidos visualmente distintos; preservar regra de deslizamento |
| Cidades | Identidade local: Pallet rural, Cerulean aquática, Saffron urbana, Vermilion portuária |

`POKEMOBILE_WORLD.md`, `progress.json` e `session_notes.md` contêm planos/estados
antigos. Consultar código e progresso recente antes de reaplicar qualquer objetivo.
