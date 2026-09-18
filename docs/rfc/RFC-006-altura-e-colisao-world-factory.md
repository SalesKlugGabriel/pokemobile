# RFC-006 — Altura consultada e colisão na World Factory

**Status:** ACCEPTED (laboratório) · borda de chunk segue PENDENTE
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

---

## Revisão do Claude — 18/09/2026

✅ **Opção A aceita para o laboratório.** Medi a regressão em vez de ler o diff:
`scripts/tests/teste_rfc006_altura_e_colisao.gd` reconstrói a superfície de
colisão sem passar por `altura_em` e compara. **20 conferências, 0 falhas.**

- 143.641 amostras desalinhadas da grade: pior erro **0,000001 m**, nenhuma
  acima de 1 cm. A mesma régua reprova a fonte analítica em **1,6585 m** — ou
  seja, ela enxerga o defeito antigo, confirmando a medição do Codex.
- Nascimento (720 pontos do anel de 12–28 m): **0 enterrados, 0 pairando**.
- Profundidade de água e superfície: **0** pontos trocariam de classe.

🔴 **Achado meu, e ele fica aberto:** o laboratório tem degrau de até **8,03 m**
entre vértices vizinhos — **203 das 6.241 células (3,25%) passam de 46°**, o
`ANGULO_MAXIMO_DE_SUBIDA` deste jogo. Quem nascer ali escorrega. E refinar a malha **piora**
isso: a mesma queda num passo menor é inclinação maior. Vai para a **RFC-008
(máscara de spawn)**, que é do Claude.

⚠️ **`altura_em` estática não sobrevive a um mundo semeado** — `static` é o que
transforma o seed em estado global. Quando o primeiro chunk com seed nascer, ela
vira serviço instanciado e os consumidores recebem a referência; a mudança é do
Claude (`SpawnerSelvagem3D`, `PokemonInstance3D`, `RegraDeAcompanhar`).

**Não autorizado por este aceite:** máscara de spawn, regra de água/penhasco,
geração de chunks. Resposta completa em
`docs/agent-reviews/claude/2026-09-18-RFC-006-altura-e-colisao.md`.
