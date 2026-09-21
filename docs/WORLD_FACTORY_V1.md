# World Factory V1 — fundação visual do WORLD_LAB

## Estado

**Pronto e validado em isolamento:** spec, seed explícita, reservas manuais,
coordenadas de chunk, relevo multiescala por triangulação, praia, shoreline,
água visual, cinco formações rochosas GLB e laboratório em 16 chunks.
**Ainda não iniciado:** vegetação, caminhos, caverna jogável, streaming,
integração no Laboratório oficial e publicação.

## Fonte de configuração

`data/world/biomes/world_lab_v1.json` é a única entrada da fábrica para o
protótipo. Ela declara, sem defaults silenciosos:

- versão e `world_seed`;
- retângulo de 256 × 256 m, passo de 2 m e chunk de 64 m;
- nível do mar e limite de inclinação documentado;
- parâmetros explícitos de `beach_width_m`, `shoreline_width_m` e
  `shallow_depth_m`, além dos limiares de rocha;
- cinco formações rochosas de referência, cada uma apontando para uma variante
  reutilizável em `assets/models/environment/rocks/`;
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
- `tipo_de_superficie_em` classifica leito profundo, leito raso, shoreline,
  areia, grama e rocha a partir de altura/inclinação e dos parâmetros da spec.
  A classificação é uma consulta da mesma factory, não um segundo gerador.
- Esta classe é paralela a `Terreno3D`; ela não substitui o laboratório nem
  autoriza alterar `SpawnerSelvagem3D` nesta fase.

## Reprodução e gate

```bash
godot4 --headless --path /root/pokemobile-v3-codex \
  --script res://tools/world_factory/validate_world_factory.gd
```

O validador prova: JSON válido, mesma seed reproduz relevo e classificação,
seed diferente altera o terreno, os parâmetros costeiros vêm da spec, borda de
chunks coincide, `floor` é usado em chunks negativos, a malha tem colisão
triangulada e as seis faixas de superfície existem no WORLD_LAB.

Antes de seguir para árvores, rochas ou grama, a Fase 4 deve montar o
WORLD_LAB sem vegetação e validar jogador, colisão, praia e penhasco dentro do
Godot. A fábrica não está autorizada a gerar mundo grande nesta etapa.

## Fase 4 — laboratório de terreno isolado

`scenes/tests/world_factory_terrain_lab.tscn` monta a spec `world_lab_v1` sem
alterar `Terreno3D`, spawn ou o Laboratório oficial. O script
`WorldFactoryTerrainLab.gd` cria 16 chunks de 64 m, cada um com malha e
`StaticBody3D`/trimesh próprios. O shader de terreno separa grama, rocha,
areia, shoreline e leito marinho; o plano de água subdividido usa o shader
`water.gdshader`, é visual e não recebe colisão. As cinco rochas são instâncias
de GLB existentes; o Player V1 continua apenas como régua de 1,60 m, assentado
por `factory.altura_em`.

Validação reproduzível:

```bash
godot4 --headless --path /root/pokemobile-v3-codex \
  --script res://scripts/tests/teste_world_factory_terrain_lab.gd
```

Resultado atual: **11 ok, 0 falhas** — factory criada pela spec, 16 chunks
visuais, 16 colisores, água shader sem física, malha de água subdividida, cinco
rochas assentadas e Player V1 sobre o terreno. A captura Web local foi feita em
1280 × 720 com WebGL: relevo, costa e as transições são visíveis; não houve
publicação.

Medição CPU em 21/09 (VPS, 2 núcleos, headless): 16 chunks de 64 m / 32.768
triângulos geraram em **151,517 ms** (mediana); trimeshes em **34,624 ms**.
FPS é uma medição de navegador real e permanece fora deste laboratório.

Isto não é ainda a integração de gameplay: `Terreno3D`, spawn, Surf e a
superfície física da água continuam fora do escopo. O próximo gate visual é
vegetação instanciada/LOD; não expandir o mapa antes dele.
