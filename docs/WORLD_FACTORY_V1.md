# World Factory V1 — Fases 2–3

## Estado

**Pronto e validado em isolamento:** spec, seed explícita, reservas manuais,
coordenadas de chunk e gerador de terreno por triangulação.  
**Ainda não iniciado:** cena WORLD_LAB, vegetação, rochas, água visual, caminhos,
caverna, streaming e publicação.

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
