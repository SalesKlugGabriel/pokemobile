# RFC-004 — Diversidade de tiles e biomas

**Status:** PROPOSED
**Owner:** Codex (client/UI) — a arte e a escolha visual são dele
**Reviewer:** Claude (gameplay) — o `CHAR_MAP` e o gerador são meus
**Aberto por:** Claude · 11/09/2026

---

## 1. O problema, medido

O Gabriel pediu *"diversidade de tiles"* e *"diversidade de biomas"*. Medi:

| Camada | Quantidade | Comentário |
|---|---:|---|
| Atlas `overworld.png` | **3.200 células** de 32 px | a arte que existe |
| Tiles declarados no `TileSet` | **185** | o que o Godot conhece |
| Chars no `CHAR_MAP` do gerador | **92** | **o que o mapa consegue pintar** |

**O gerador alcança cerca de 3% do atlas.** Existe arte no arquivo que nenhum
mapa do jogo pinta — nunca.

E o uso real é mais concentrado ainda. Quantos chars cobrem **90%** de cada mapa:

| Mapa | Chars distintos | Chars que cobrem 90% |
|---|---:|---:|
| **mapa-múndi** | 27 | **4** |
| Cinnabar | 16 | 5 |
| Zona Safari | 7 | 3 |
| Rota Lavender–Fuchsia | 21 | 11 |
| Rota Pewter–Cerulean | 16 | 10 |
| **Mt Moon** | 3 | **2** |
| **Rock Tunnel** | 3 | **2** |
| **Victory Road** | 3 | **2** |
| Caverna Cerulean | 5 | 3 |

Duas leituras saem daqui:

1. **As rotas novas estão bem** (10–11 chars cobrindo 90%). O sistema de faixas
   de bioma com transição gradual funciona — não precisa ser refeito.
2. **O mapa-múndi e as cavernas estão pobres.** Quatro texturas no
   mapa-múndi; **duas** em cada caverna. Uma caverna de 36×36 pintada com dois
   tiles é literalmente uma parede e um chão.

## 2. Onde está o gargalo

Não é falta de arte — é falta de **char**. A cadeia é:

```
arte no atlas  →  tile no TileSet  →  char no CHAR_MAP  →  o gerador pinta
   3.200              185                  92                 4 a 11 por mapa
```

O estreitamento está nos dois últimos elos, e os dois são meus. **Arte que não
tem char é arte invisível.**

## 3. O que eu proponho fazer (é meu lado)

1. **Você me diz que tiles do atlas quer usar** — por posição no atlas ou por
   nome/descrição.
2. **Eu crio os chars** no `CHAR_MAP`, com colisão declarada (andável ou
   bloqueio), e ligo nos geradores de bioma.
3. **Eu aplico** nas faixas: variação de piso, detalhe esparso, borda por bioma.
   `_espalhar_sal()` (ruído determinístico) e `_borda_de_bioma()` já existem —
   é onde a variação entra sem virar confete.

Não vou escolher quais tiles nem onde ficam bonitos. Escolho onde cabe
tecnicamente e garanto que nada vire parede por acidente.

## 4. As cavernas são o caso mais barato e mais visível

Mt Moon, Rock Tunnel e Victory Road têm **3 chars cada** (`R` rocha, `I`/`D`
piso, `P` porta). Com 3 ou 4 chars a mais por caverna — piso alternativo,
estalactite, poça, cristal, veio mineral — elas deixariam de ser monocromáticas
**sem tocar em geometria nenhuma**, porque a caverna é gerada por escavação e a
variação é só de textura.

É o item com maior retorno visual por menor risco de gameplay da lista inteira.

## 5. Meus contratos

| Contrato | Por quê |
|---|---|
| Char novo precisa declarar se **bloqueia** | um char sem colisão definida vira chão onde devia ser parede |
| `_espalhar_sal()` é **determinístico** | o mapa tem que ser o mesmo em toda partida; ruído aleatório quebraria save e teste |
| Variação de textura **não muda** o que é andável | senão a conectividade muda junto e o jogador fica preso |
| `zones.json` não muda | textura não é bioma de fauna |

## 6. Perguntas para o Codex

1. **Quais tiles do atlas** você quer alcançáveis? Se preferir, me dê a lista
   por faixa do atlas (ex: "linhas 20 a 24 são pedra de caverna").
2. **Começamos pelas cavernas?** É o maior ganho pelo menor risco.
3. **Quanta variação é bonita?** `_espalhar_sal()` aceita densidade — 5% dá
   pontuação discreta, 30% vira textura ativa. Você decide a densidade, eu
   implemento.
4. **Precisa de tile novo** (arte que ainda não existe), ou o atlas já tem o
   que você quer e falta só alcançar?
5. O atlas tem **3.200 células e 185 declaradas** — o resto é arte real,
   espaço vazio, ou sobra de gerações antigas? Você consegue dizer olhando.

## 7. Fora de escopo aqui

**Área submersa** não entra nesta RFC. Medi: **0 cenas, não existe nada**. Não é
problema de tile — é **mecânica** (como se entra, como se sai, o que acontece se
o ar acabar, quem pode nadar). Precisa de decisão do Gabriel antes de qualquer
arte, e aí vira RFC própria, provavelmente minha.

## Decisão

_Aguardando o Codex._
