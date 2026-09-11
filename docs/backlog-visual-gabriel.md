# Backlog visual — tudo que o Gabriel já pediu

> **Para o Codex.** Consolidado por Claude em 11/09/2026, a pedido dele:
> *"toda a parte de grafico fica por conta do codex, então envie pra ele todas
> as melhorias que eu já solicitei"*.
>
> Cada item traz **o que ele pediu**, **o estado medido hoje** e **o que é meu
> contrato** (o que não pode quebrar). Nada aqui é opinião minha sobre como
> deve ficar — forma e estética são suas.
>
> Marquei ❌ quando **medi** que não existe, ⚠️ quando existe pela metade e ✅
> quando está feito. Onde eu não consegui medir, escrevi que não consegui.

---

## 🔴 P0 — A queixa de hoje

### 1. Formato do continente ❌
**Pedido:** continente com ilhas, cercado de mar, **costa orgânica em toda borda**,
nunca forma quadrada. *(repetido em 10/09 ao aprovar o plano de escala)*

**Medido hoje:** o mapa-múndi é **465 × 374 tiles** (0,5 km × 0,4 km na régua
dele), **retângulo perfeito**, com a costa oeste sempre na coluna 0 e **desvio
médio de 0,0 tiles**. Não há contorno orgânico nenhum.

→ **RFC-003** tem os números e três caminhos possíveis.

### 2. "Nenhuma borda pode ser parede de árvore" ❌
**Medido hoje:** a borda do mapa-múndi é **100% árvore, 0% água**. É literalmente
a parede que ele proibiu.

Existe `MapLayouts._borda_de_bioma(c, r, estilo)` pronta (rocha/brejo/costa/seco)
e **em uso nas rotas** — o mapa-múndi não usa.

### 3. "As cidades não se conectam" ⚠️
**Medido:** funcionalmente **conectam** — testei a pé, toda cidade alcança suas
portas, e a cadeia Pallet → Viridian → Pewter → Cerulean → Saffron → tudo está
inteira.

**Mas ele tem razão no que vê:** não existe **estrada visível** entre cidades no
mapa-múndi. As estradas antigas foram seladas (viraram mata) quando as rotas
viraram cenas separadas. Andar para dentro de uma moita e reaparecer noutro
lugar não parece um continente.

→ Detalhe e opções na **RFC-003**.

### 4. Biomas no mapa-múndi ❌
**Pedido:** biomas distintos e reconhecíveis; costa em faixas (interior →
vegetação costeira → areia → praia → raso → oceano); montanha com elevação.

**Medido:** o mapa-múndi usa 27 chars, mas 53% é água, 21,6% é árvore e 13,4% é
grama — ou seja, três texturas cobrem 88% do mapa. As **rotas** têm 32 faixas de
bioma (isso está feito); o mapa-múndi, não.

---

## P1 — Pendências antigas dele, nunca decididas

Estas estão registradas em `progresso.md` como *"pendente de decisão do Gabriel
(arte/design, não mexi sem confirmar)"* — algumas há mais de uma semana.

| # | O que ele disse | Estado |
|---|---|---|
| 5 | **Paredes laterais de casa** usam a mesma sprite da frente — *"feio"*, **reportado 2× (09/09 e 10/09)** | ❌ nunca corrigido |
| 6 | **Tocos de árvore cortados**: cor e centralização erradas | ❌ |
| 7 | **Árvores grandes** deveriam seguir o estilo das pequenas, *"que ele achou mais bonitas"* | ⚠️ você está redesenhando |
| 8 | **Tela da Pokédex** *"pobre e sem graça"* — **ele mandou referência visual** | ❌ |
| 9 | Uma **estrutura que bloqueia o caminho mas dá pra contornar** — parece erro de nível | ❌ não decidi sozinho se remove ou fecha |

O item 5 é o que ele mais repetiu. Se for pra escolher um, é esse.

---

## P2 — Coisas que ele pediu e **estão feitas** (não refazer)

Registro pra você não gastar tempo: ✅ **Cinnabar** como ilha de exploração
(1200×1200, costa de 3 harmônicas) · ✅ **cavernas não-lineares** (Rock Tunnel,
Mt Moon retrofitada, Victory Road, Digletts) · ✅ **biomas de montanha** nas
rotas Pewter–Viridian e Pewter–Cerulean · ✅ **transição gradual de bioma** nas
rotas (`_misturar_bioma_cell`) · ✅ **as 3 ilhas** (Gélida, Seafoam, Deserto) e
seus acessos · ✅ **escala por altura real** da Pokédex (Tauros maior que
Spearow **é o sistema funcionando**, não bug — já virou confusão duas vezes) ·
✅ **Giovanni "em cima do prédio"** é o Ginásio de Viridian fechado, de
propósito, até a MAIN-08.

---

## O que é meu, e como eu ajudo

Se a mudança visual mexer em **tile, colisão, warp ou zona**, ela cruza pro meu
lado. Não é burocracia — é que essas quatro coisas têm teste e quebram o jogo
em silêncio:

- **Warps:** me diga a forma que você quer e **eu reposiciono e re-provo a
  conectividade**. Você não precisa tocar em warp nenhum.
- **Colisão:** os chars `T N O K / < > R ~ 0 ) w W E` bloqueiam. Trocar o char
  muda o que é parede.
- **Zonas** (`zones.json`): `tile_rect` define fauna, música e nome da região.
  Se a cidade mudar de lugar, o retângulo muda comigo.
- **Os 6 atalhos antigos selados:** se reabrirem, o jogador pula rotas inteiras.

**Precisa de um dado que não existe pra desenhar alguma coisa? Peça.** Eu
exponho o estado. O contrário — a apresentação recalculando regra de gameplay —
é o que o AGENTS.md proíbe, e com razão.

---

## Uma coisa que deixei pra você decidir

`data/moves/moves.json` tem **nomes misturados**: a maioria em inglês ("Fire
Blast", "Ice Beam", "Thunderbolt") e alguns em português ("Bomba de Lodo",
"Garra de Dragão", "Mega Chifre"). Isso **aparece na tela**, então é decisão de
apresentação. Não mexi.
