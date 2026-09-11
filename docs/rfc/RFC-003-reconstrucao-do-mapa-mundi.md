# RFC-003 — Reconstrução do mapa-múndi: forma do continente, costa e biomas

**Status:** PROPOSED
**Owner:** Codex (client/UI) — a forma e o visual são dele
**Reviewer:** Claude (gameplay) — colisão, warps, conectividade e spawn são meus
**Aberto por:** Claude · 11/09/2026
**Prioridade:** a mais alta da lista visual. O Gabriel reclamou direto:
*"o mapa está uma porcaria e as cidades não se conectam, não existe os biomas e
nem o formato do continente que eu pedi"*

---

## 1. O que eu medi antes de escrever isto

Não é impressão. São números do `MapLayouts.get_layout("world_map")` de hoje:

| Medida | Valor medido | O que o Gabriel pediu |
|---|---|---|
| Tamanho do continente | **465 × 374 tiles** | na régua dele (1 tile = 1 m) isso é **0,5 km × 0,4 km** |
| Borda do mapa | **100% árvore, 0% água** | *"nenhuma borda pode ser parede de árvore"* |
| Costa oeste | primeira terra sempre na **coluna 0**, desvio médio **0,0 tiles** | *"costa orgânica, nunca forma quadrada"* |
| Formato | retângulo perfeito | continente com ilhas, cercado de mar |

**Tradução:** o mapa-múndi é um **retângulo de meio quilômetro cercado por uma
parede de árvores**. Uma única rota (Lavender–Fuchsia) tem 12 km — ou seja, o
"continente" é **24 vezes menor que uma estrada dele**.

A reestruturação geográfica de 10/09 refez **as rotas** (cenas próprias, 38 km
somados) e **Cinnabar** (1200×1200, costa de 3 harmônicas). **O mapa-múndi, onde
ficam as cidades, nunca foi refeito.** Isso está registrado na minha própria
auditoria (`docs/mundo-novo-escala.md`, seção 3): *"Costa orgânica ✅ nas
ilhas/costa — o litoral do world_map segue o de sempre"*. Eu declarei a
pendência e não a resolvi.

## 2. "As cidades não se conectam" — o que é verdade e o que não é

Medi a conectividade a pé, de cada cidade até cada porta do mapa-múndi:

| Cidade | Portas alcançáveis a pé |
|---|---|
| Pallet | RotaViridianPallet |
| Viridian | RotaViridianPallet, RotaPewterViridian, Liga Indigo |
| Pewter | RotaPewterViridian, RotaPewterCerulean |
| Cerulean | RotaPewterCerulean, RotaCeruleanSaffron, Caverna Cerulean |
| Saffron | as 4 rotas + Silph Co |
| Vermilion | RotaSaffronVermilion, Digletts, S.S. Anne |
| Celadon | RotaSaffronCeladon, Rocket Hideout, Game Corner |
| Lavender | RotaSaffronLavender, RotaLavenderFuchsia, Torre |
| Fuchsia | RotaLavenderFuchsia, Safari |

**Funcionalmente elas se conectam** — a cadeia Pallet → Viridian → Pewter →
Cerulean → Saffron → tudo está inteira e testada.

**Mas o Gabriel não está errado.** O que ele vê é: uma cidade, mata em volta,
uma porta na mata, e do outro lado uma rota que é outra cena. **Não existe
estrada visível ligando cidade a cidade no mapa-múndi** — as estradas antigas
foram SELADAS (viraram mata) quando as rotas novas nasceram em cenas separadas.
Para o jogador, um continente onde você anda para dentro de uma moita e
reaparece em outro lugar **não parece um continente**.

Essa é a parte que é de apresentação, e é o coração desta RFC.

## 3. O que proponho discutir (a decisão é sua)

Não vou escolher a solução — é desenho de mundo. Vejo três caminhos, e cada um
tem consequência diferente do meu lado:

### Caminho A — continente maior, com a costa e os biomas de verdade
Refazer `_gen_world_map` num continente organicamente contornado, com
**estradas visíveis** entre as cidades (mesmo que curtas — a distância real
continua nas cenas de rota) e faixas de bioma no caminho.
*Custo meu:* reposicionar warps, conferir colisão e re-testar conectividade.
*Ganho:* resolve as três queixas de uma vez.

### Caminho B — manter o tamanho, arrumar só a borda e os biomas
Costa orgânica no lugar da parede de árvore, mar em volta, faixas de bioma
pintadas. As cidades continuam ligadas por porta.
*Custo meu:* baixo. *Ganho:* resolve "parede de árvore" e "sem biomas", **não
resolve** "as cidades não se conectam".

### Caminho C — estrada visível ligando as cidades, sem mudar o resto
Pintar trilhas curtas cidade→porta, com a porta no fim de uma estrada em vez de
no meio da mata.
*Custo meu:* mínimo. *Ganho:* resolve a leitura de "continente ligado" barato.

Minha leitura, e é só leitura: **C resolve a queixa mais dolorosa por muito
menos esforço que A**, e pode vir primeiro. Mas quem decide forma de mundo é
você.

## 4. Meus contratos — o que NÃO pode quebrar

Isto não é lista de desejos; é o que tem teste e quebra o jogo se mudar sem me
avisar. Se qualquer item atrapalhar o visual, **abra revisão em vez de
contornar**.

| Contrato | Por quê | Teste que trava |
|---|---|---|
| Todo tile de porta continua **andável e alcançável a pé** desde a cidade | é a conectividade do jogo inteiro | `teste_conectividade.gd` |
| `WarpZone.position` e `spawn_tile` de cada porta | mudar sem mover o par do outro lado faz o jogador nascer dentro de pedra | testes por rota |
| `tile_rect` das zonas em `zones.json` | define fauna, música e nome da região | `teste_matriz_ecologica.gd` |
| Chars de colisão (`T N O K / < > R ~ 0 ) w W E` bloqueiam) | virar o char muda o que é parede | `teste_tudo_compila.gd` |
| Os 6 atalhos antigos continuam **selados** | senão o jogador corta caminho e pula rotas inteiras | `docs/mundo-novo-escala.md` §2 |
| As 3 ilhas (Gélida, Seafoam, Deserto) e seus acessos | pedido explícito do Gabriel, 10/09 | `teste_alcance_surf.gd` |
| Água continua sendo água pro Surf | `WorldManager.is_water_tile` | `teste_alcance_surf.gd` |

**Como eu ajudo:** me diga a forma que você quer e eu **reposiciono os warps e
re-provo a conectividade** — isso é meu. Você não precisa mexer em warp nenhum.

## 5. O que eu já entrego pronto pra isso

- `MapLayouts._borda_de_bioma(c, r, estilo)` — bordas por bioma (rocha, brejo,
  costa, seco) em vez de árvore uniforme. **Já existe e está em uso nas rotas**;
  o mapa-múndi ainda não usa.
- `ondular_costa`, `costurar_costa`, `amaciar_bordas` — primitivas de costa
  orgânica, prontas, usadas em Cinnabar.
- `_misturar_bioma_cell()` + `_progresso_transicao()` — transição gradual entre
  biomas, sem corte seco.
- `AjudaMapa.caminho_a_pe()` — a prova de conectividade, que eu rodo a cada
  mudança.

## 6. Perguntas para o Codex

1. **Qual caminho** — A, B ou C? Ou outro?
2. Se for A: **que tamanho** o continente deve ter? Lembrando que o tamanho tem
   custo de carregamento medido (a rota de 12 km leva ~4 s pra abrir).
3. **Estrada visível entre cidades**: você quer que eu gere as trilhas no
   `MapLayouts` (é geração de tile, meu lado) seguindo um traçado que você
   define, ou prefere fazer você mesmo?
4. **A planta-base desenhada à mão** do Gabriel está em
   `docs/mundo-novo-escala.md`. Ela é a referência de forma?
5. Precisa de **char/tile novo** no atlas pra algum bioma que falta?

## Decisão

_Aguardando o Codex._
