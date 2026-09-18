# RFC-006 — Altura consultada e colisão na World Factory

**Status:** IMPLEMENTED · revisão de regressão do gameplay pendente
**Owner:** Codex (visual/world factory)
**Reviewer:** Claude (gameplay)
**Aberto por:** Codex · 18/09/2026

## Problema medido

`Terreno3D.altura_em(x,z)` é usado para spawn e acompanhamento, enquanto o corpo físico é uma malha triangular com amostra a cada 2 m. Em 6.400 centros de célula do laboratório atual, a consulta diferiu da malha até **1,7922 m**; 222 centros tiveram erro acima de 10 cm. Script reproduzível: `tools/world_factory/benchmark_chunks.gd`. A fábrica com falésias e chunks aumentaria a exposição a essa diferença.

## Contrato implementado no laboratório

1. A chamada pública `Terreno3D.altura_em(x,z)` continua disponível para todos os consumidores existentes.
2. Dentro dos 160 × 160 m físicos do laboratório, a altura pública corresponde
   à superfície dos triângulos de colisão com tolerância de `0,0001 m`; a malha
   visual e a física usam a mesma triangulação.
3. Borda entre chunks: permanece requisito da World Factory. Ainda não há chunks
   no runtime, portanto esta RFC não declara normal de chunk validada.
4. O gerador usa seed do mundo própria, sem consumir `RNGManager` ou `randf()` global.
5. Água e penhasco são identificáveis para spawn; criar máscara de spawn é mudança de gameplay separada desta RFC.

## Opções para decisão conjunta

- **A — função analítica interna + interpolação da grade na API pública:** o gerador amostra a função analítica nos vértices; `altura_em` interpola os mesmos dois triângulos da colisão. Conserva consulta rápida/determinística sem raycast. Requer cuidado quando a resolução/LOD mudar.
- **B — consulta à física:** `altura_em` faz raycast na malha registrada. Casa sempre com o colisor, mas a API estática atual teria dependência da árvore de cena, custo e dificuldade em teste/headless.
- **C — aumentar resolução:** diminui o erro, mas não garante zero em falésia e aumenta CPU/memória. Não é suficiente sozinha.

**Opção aplicada:** A. A fonte analítica passou a ser interna
(`_altura_analitica_em`) e serve apenas para amostrar vértices. A API pública
`altura_em` localiza a célula de 2 m e interpola A-B-C ou A-C-D com as mesmas
baricêntricas usadas pelo `ArrayMesh` e pelo `TrimeshShape3D`. Não há raycast,
estado de cena ou consumo de RNG. Fora do retângulo físico, onde não há colisor,
a API conserva a altura analítica para consultas geográficas pré-cena.

## Perguntas ao Claude

1. Há consumidor da altura **analítica**, e não da superfície de colisão, que a opção A quebraria?
2. Qual tolerância e qual resolução mínima o gameplay precisa para nascer e caminhar na falésia?
3. Quem passa `world_seed` ao serviço de altura sem transformar `altura_em(x,z)` em estado global oculto?
4. O spawner deve recusar pontos submersos/íngremes antes de chamar `nascer()`? Propor RFC separada se isso mudar sua regra.

## Decisão

**Execução autorizada pelo Gabriel em 18/09/2026.** A opção A foi implementada
em `Terreno3D` sem alterar consumidores, seed, regra de spawn, água ou
inclinação. O benchmark reproduzível agora confere ambas as metades de todas as
6.400 células: `HEIGHT_CONSISTENCY amostras=12800 max_m=0.000000`, sem amostra
acima de 10 cm. O teste de cena V3 recebeu a mesma propriedade.

O Claude ainda deve revisar a regressão de movimento/spawn antes de considerar
o contrato de chunks aceito. Esta RFC não autoriza construir máscaras de spawn,
alterar a regra de água/penhasco nem iniciar geração de chunks.
