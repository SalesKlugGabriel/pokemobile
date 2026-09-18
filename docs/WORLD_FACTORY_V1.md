# World Factory V1 — Fases 2–3

## Estado

**Pronto e validado em isolamento:** spec, seed explícita, reservas manuais,
coordenadas de chunk, gerador de terreno por triangulação e laboratório de
terreno em 16 chunks.
**Ainda não iniciado:** vegetação, rochas, caminhos, caverna, streaming,
integração no Laboratório oficial e publicação.

## Fonte de configuração

`data/world/biomes/world_lab_v1.json` é a única entrada da fábrica para o
protótipo. Ela declara, sem defaults silenciosos:

- versão e `world_seed`;
- retângulo de 256 × 256 m, passo de 2 m e chunk de 64 m;
- nível do mar e limite de inclinação documentado;
- reservas manuais: spawn, clareira, caminho e futura caverna.

Reservas ainda não alteram gameplay nem colocam props; são ownership explícito
para que o scatter das fases seguintes não possa ocupar esses espaços.

## Contratos

- `WorldTerrainFactory` recebe a spec no construtor. Não lê `RNGManager`, não
  chama `randf()` e não depende da árvore de cena.
- Toda altura de vértice usa coordenada global + seed. Dois chunks adjacentes
  obtêm o mesmo vértice na borda, inclusive para coordenadas negativas.
- `altura_em` interpola a mesma diagonal A-B-C/A-C-D entregue ao mesh. Assim
  spawn e colisão podem compartilhar a regra quando o WORLD_LAB for integrado.
- Esta classe é paralela a `Terreno3D`; ela não substitui o laboratório nem
  autoriza alterar `SpawnerSelvagem3D` nesta fase.

## Reprodução e gate

```bash
godot4 --headless --path /root/pokemobile-v3-codex \
  --script res://tools/world_factory/validate_world_factory.gd
```

O validador prova: JSON válido, mesma seed reproduz o relevo, seed diferente o
altera, borda de chunks coincide, `floor` é usado em chunks negativos e a malha
tem colisão triangulada.

Antes de seguir para árvores, rochas ou grama, a Fase 4 deve montar o
WORLD_LAB sem vegetação e validar jogador, colisão, praia e penhasco dentro do
Godot. A fábrica não está autorizada a gerar mundo grande nesta etapa.

## Fase 4 — laboratório de terreno isolado

`scenes/tests/world_factory_terrain_lab.tscn` monta a spec `world_lab_v1` sem
alterar `Terreno3D`, spawn ou o Laboratório oficial. O script
`WorldFactoryTerrainLab.gd` cria 16 chunks de 64 m, cada um com malha e
`StaticBody3D`/trimesh próprios; a água é visual e não recebe colisão. O Player
V1 entra apenas como régua de escala, assentado por `factory.altura_em`.

Validação reproduzível:

```bash
godot4 --headless --path /root/pokemobile-v3-codex \
  --script res://scripts/tests/teste_world_factory_terrain_lab.gd
```

Resultado: **7 ok, 0 falhas** — factory criada pela spec, 16 chunks visuais,
16 colisores, água sem física e Player V1 sobre o terreno. Isto não é ainda a
integração de gameplay: o próximo gate é inspeção visual do relevo e revisão
do contrato de altura/movimento antes de adicionar qualquer vegetação.
