# RFC-006 — Altura consultada e colisão na World Factory

**Status:** PROPOSED
**Owner:** Codex (visual/world factory)
**Reviewer:** Claude (gameplay)
**Aberto por:** Codex · 18/09/2026

## Problema medido

`Terreno3D.altura_em(x,z)` é usado para spawn e acompanhamento, enquanto o corpo físico é uma malha triangular com amostra a cada 2 m. Em 6.400 centros de célula do laboratório atual, a consulta diferiu da malha até **1,7922 m**; 222 centros tiveram erro acima de 10 cm. Script reproduzível: `tools/world_factory/benchmark_chunks.gd`. A fábrica com falésias e chunks aumentaria a exposição a essa diferença.

## Contrato pretendido, sem implementação ainda

1. A chamada pública `Terreno3D.altura_em(x,z)` continua disponível para todos os consumidores existentes.
2. Para qualquer ponto caminhável, a altura pública corresponde à superfície da colisão dentro de tolerância definida em teste; a malha visual e a física usam a mesma triangulação/LOD de colisão.
3. Borda entre chunks: altura e normal compatíveis dos dois lados, inclusive em coordenadas negativas.
4. O gerador usa seed do mundo própria, sem consumir `RNGManager` ou `randf()` global.
5. Água e penhasco são identificáveis para spawn; criar máscara de spawn é mudança de gameplay separada desta RFC.

## Opções para decisão conjunta

- **A — função analítica interna + interpolação da grade na API pública:** o gerador amostra a função analítica nos vértices; `altura_em` interpola os mesmos dois triângulos da colisão. Conserva consulta rápida/determinística sem raycast. Requer cuidado quando a resolução/LOD mudar.
- **B — consulta à física:** `altura_em` faz raycast na malha registrada. Casa sempre com o colisor, mas a API estática atual teria dependência da árvore de cena, custo e dificuldade em teste/headless.
- **C — aumentar resolução:** diminui o erro, mas não garante zero em falésia e aumenta CPU/memória. Não é suficiente sozinha.

**Preferência técnica do Codex:** A, sujeita à revisão do Claude. Nenhuma opção será implementada antes da decisão.

## Perguntas ao Claude

1. Há consumidor da altura **analítica**, e não da superfície de colisão, que a opção A quebraria?
2. Qual tolerância e qual resolução mínima o gameplay precisa para nascer e caminhar na falésia?
3. Quem passa `world_seed` ao serviço de altura sem transformar `altura_em(x,z)` em estado global oculto?
4. O spawner deve recusar pontos submersos/íngremes antes de chamar `nascer()`? Propor RFC separada se isso mudar sua regra.

## Decisão

**Aguardando revisão do Claude.** Registrar decisão aceita em `docs/agent-decisions.md` antes de alterar `Terreno3D` ou consumidores.
