# World Factory V1 — fundação visual do WORLD_LAB

## Estado

**Pronto e validado em isolamento:** spec, seed explícita, reservas manuais,
coordenadas de chunk, relevo multiescala por triangulação, praia, shoreline,
água visual, cinco formações rochosas GLB e laboratório em 16 chunks.
**Pronto e validado em isolamento:** vegetação inicial instanciada (árvores,
grama e corais), com alcance de visibilidade.
**Ainda não iniciado:** caminhos, caverna jogável, streaming, integração no
Laboratório oficial e publicação.

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
- vegetação com seed própria derivada da seed do mundo, densidade, espaçamento,
  escala, variantes e distâncias de visibilidade todos explícitos;
- reservas manuais: spawn, clareira, caminho e futura caverna.

Reservas ainda não alteram gameplay nem colocam props; são ownership explícito
para que o scatter das fases seguintes não possa ocupar esses espaços.

## Fase 5 — vegetação de referência instanciada

`WorldVegetationScatter` é uma camada pequena da **mesma** World Factory: recebe
`WorldSpec` e `WorldTerrainFactory`, não cria geografia e não consulta RNG
global. Cada categoria deriva uma sequência de `world_seed + seed_offset + salt`;
alterar ordem de montagem da cena não altera o mundo. A saída contém apenas
transformações, enquanto `WorldFactoryTerrainLab` decide apresentá-las em
`MultiMeshInstance3D`.

O WORLD_LAB atual monta 32 árvores entre as cinco variantes existentes, 228
clusters de grama (baixa/média/alta) e 28 corais entre três variantes, todos com
variação de rotação e escala. Árvores e grama aceitam exclusivamente superfície
`grass`, respeitam inclinação e excluem spawn, clareira, caminho e reserva de
caverna. Corais aceitam exclusivamente `shallow_waterbed`; portanto árvores e
grama não podem nascer dentro da água, e corais não ocupam solo seco ou oceano
profundo. Não há colisores de vegetação nesta fase: o Player V1 permanece a
régua de escala, e colisões/obstáculos de gameplay pertencem à integração futura.

São 16 MultiMeshes (cinco árvores LOD0, cinco LOD1, três gramíneas e três
corais), em vez de centenas de nós de props. As distâncias de visibilidade e
margem de fade também vêm da spec: grama 48 m, árvores 104 m, corais 42 m e
margem 12 m.

`tools/blender/generators/gerar_lod_arvores.py` deriva os cinco GLBs LOD1 sem
alterar os LOD0: `tree_[a-e]_lod1.glb`. A redução por Decimate é 0,38 e foi
validada no Blender: A 898 → 341, B 762 → 289, C 1.034 → 392, D 898 → 341,
E 1.034 → 392 triângulos. LOD0 fica ativo até 46 m e ainda projeta sombra; LOD1
começa em 38 m (sobreposição/fade de 8 m), segue até 104 m e não projeta sombra.
Não é um modelo de impostor final, mas é uma troca de malha real, configurada na
spec e pronta para medição em navegador.

Em 22/09, os cinco LOD0 foram reconstruídos por
`tools/blender/environment/tree_library.py` e `build_trees.py`. A fonte única
`assets/models/environment/trees/source/tree_library.blend` contém troncos por
anéis, raízes, galhos e massas foliares facetadas em camadas; não usa cilindro
nem esfera como geometria final. O preview de inspeção fica em
`assets/models/environment/trees/previews/tree_c.png`; GLBs anteriores foram
preservados em `assets/old/environment_trees_20260922/`.

## Fase 6 — composição ambiental declarativa

A vegetação não é mais espalhada de maneira uniforme pelo retângulo do mundo.
Cada grupo da spec declara zonas circulares com `id`, centro, raio e peso: borda
da clareira, mata ao norte e bosque a leste para árvores; prados para grama;
manchas de grama alta; e dois recifes no raso. A World Factory sorteia uma zona
ponderada antes de escolher uma posição, preservando seed, regras de superfície,
espaçamento e reservas. `zone_id` acompanha cada transformação para inspeção e
teste, sem criar um segundo mapa de biomas.

Essa camada define intenção de composição no WORLD_LAB — áreas abertas continuam
abertas, vegetação densa fica agrupada e os recifes possuem leitura própria — mas
não declara geografia canônica além do que já existe em `world_lab_v1.json`.
Rios, cidades, cavernas e biomas finais continuam dados de mundo futuros.

## Fase 7 — polimento de material e transição

O shader de terreno agora combina variação macro, média e granular para o leito
marinho, areia úmida/seca, grama, pequenas manchas de solo e rocha. A ordem das
camadas mantém rocha como acabamento final sobre encosta/altura, evitando que
variação de grama a cubra. O shader de água recebeu resposta de Fresnel, emissão
discreta, transparência variável e ondas em duas escalas; a profundidade visual
continua sendo dada pelo leito classificado sob o plano de água.

Árvores voltaram a usar os materiais PBR que já existem nos seus GLBs. Antes, um
shader único substituía tronco e copa e usava altura global, o que mudava a cor
de uma árvore conforme a elevação do terreno. Grama conserva o shader V3 de
vento e variação. Essa fase não acrescenta textura externa, não altera a paleta
canônica e não tenta esconder geometria com iluminação.

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

Resultado atual: **20 ok, 0 falhas** — factory criada pela spec, 16 chunks
visuais, 16 colisores, água shader sem física, malha de água subdividida, cinco
rochas assentadas, 16 MultiMeshes de vegetação com visibility range e Player V1
sobre o terreno. O teste também confirma as cinco variantes LOD1, sua faixa de
ativação e que seus arquivos são menores que LOD0. O validador de spec/factory
retorna **22 ok, 0 falhas**, inclusive
contagem declarada, determinismo do scatter, exclusão das reservas, vegetação
terrestre fora da água, corais somente no raso e todas as instâncias dentro de
sua zona de composição declarada. O teste de cena também verifica árvores com
materiais PBR próprios e grama com shader V3. O export Web temporário concluiu
sem erro de script ou shader; o renderer SwiftShader headless da VPS não manteve
a cena V3 viva depois do carregamento, portanto FPS e avaliação visual final
seguem para navegador real, sem publicação.

Medição CPU em 21/09 (VPS, 2 núcleos, headless): 16 chunks de 64 m / 32.768
triângulos geraram em **151,517 ms** (mediana); trimeshes em **34,624 ms**.
FPS é uma medição de navegador real e permanece fora deste laboratório.

Isto não é ainda a integração de gameplay: `Terreno3D`, spawn, Surf e a
superfície física da água continuam fora do escopo. O próximo gate visual é
medir composição/LOD e materiais em navegador real; não expandir o mapa antes
dele.
