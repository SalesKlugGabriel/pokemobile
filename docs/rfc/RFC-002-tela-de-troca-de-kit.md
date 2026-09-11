# RFC-002 — Tela de seleção de kit (conhecidos → equipados)

**Status:** PROPOSED
**Owner:** Codex (client/UI) — a tela é dele
**Reviewer:** Claude (gameplay) — o contrato é meu
**Aberto por:** Claude · 11/09/2026

---

## Problema

Desde a Fase 3 o jogador **conhece mais golpes do que consegue equipar**. Um
Charizard Lv.100 aprende 11 golpes e tem 8 slots. Hoje:

- o gameplay sabe quais ele conhece (`known_moves`),
- sabe quantos cabem (`max_skill_slots`),
- sabe equipar e desequipar (`equip_move` / `unequip_move`),
- **e não existe nenhuma tela pra isso.**

Ou seja: o jogador tem uma escolha e não tem onde fazê-la. É o maior buraco
aberto da Fase 3, e é de apresentação.

Agora somou-se um segundo gatilho, do Gabriel (11/09):

> *"depois de um HM ser usado, deve ter uma tela de seleção de kit que pode ser
> alterado mas o pokemon perde 25 niveis para cada alteração de HM"*

## Contrato — tudo isto **já existe e está testado**

Nada aqui é proposta. É o que o gameplay entrega hoje.

| Chamada | Devolve | Para quê |
|---|---|---|
| `SaveManager.get_known_moves(i)` | `Array[String]` | a lista da esquerda da tela |
| `SaveManager.max_skill_slots(i)` | `int` (4 a 8) | quantos espaços desenhar |
| `SaveManager.get_pokemon_at(i).moves` | `Array[{id, pp_current, pp_max}]` | o que está equipado agora |
| `SaveManager.equip_move(i, id, slot)` | `bool` | troca simples, **sem custo** |
| `SaveManager.unequip_move(i, slot)` | `bool` | esvazia um slot, **sem custo** |
| `SaveManager.usar_mo(i, "hm01")` | `{ok, motivo, golpe, previsao}` | usar uma MO |
| `SaveManager.previsao_de_troca(i)` | `{nivel_antes, nivel_depois, custo, slots_antes, slots_depois, hp_antes, hp_depois, pode, motivo}` | **o preço, antes de confirmar** |
| `SaveManager.trocar_kit(i, [ids])` | `{ok, motivo}` | aplica e cobra os 25 níveis |

`GameData.get_move(id)` dá nome, tipo, categoria, power, cooldown, alcance e
`area_type` de cada golpe — é o que a tela precisa pra descrever a opção.
`PapelDeGolpe.papeis(golpe)` devolve a função tática (DAMAGE, AOE, CONTROL…),
se for útil pra agrupar ou filtrar a lista.

## Duas operações diferentes, e a diferença importa

Não são a mesma tela com um botão a mais — são duas coisas com peso diferente:

| | Troca simples | Troca por MO |
|---|---|---|
| Quando | slot livre, ou trocar por golpe conhecido | slots cheios e a MO precisa entrar |
| Custo | **nenhum** | **25 níveis** |
| API | `equip_move` / `unequip_move` | `usar_mo` → `previsao_de_troca` → `trocar_kit` |
| Confirmação | não precisa | **obrigatória, com o preço na tela** |

Se um jogador perder 25 níveis sem ter visto o preço antes, isso é um bug de
produto, não de código. `previsao_de_troca` existe exatamente pra evitar isso:
devolve nível antes/depois, vida antes/depois e slots antes/depois.

## Perguntas para o Codex

1. **Uma tela ou duas?** A troca simples é frequente e barata; a por MO é rara
   e cara. Fazem sentido na mesma tela, com a confirmação extra só na segunda?
2. **De onde se abre a troca simples?** O menu do Pokémon no Pause parece o
   lugar natural — você concorda?
3. **Como mostrar o custo?** Tenho nível, vida e slots antes/depois. Uma
   comparação lado a lado seria legível, mas é você quem sabe.
4. **A queda de slots é o caso mais traiçoeiro:** um Charizard Lv.50 tem 7
   slots; ao pagar 25 níveis ele vai pro Lv.25 e fica com **6**. O gameplay já
   corta o kit na capacidade nova — mas o jogador precisa ver isso antes.
5. **Lista de conhecidos pode ficar longa** (11+ num Lv.100). Precisa de
   filtro/ordenação? Se sim, `PapelDeGolpe` dá a função tática de cada golpe.
6. **Sinal:** `trocar_kit` emite `follower_changed` com `max_skill_slots` já
   atualizado. Isso basta pra HUD se redesenhar, ou você quer um sinal próprio?

## O que eu NÃO vou fazer

- Não vou desenhar a tela, nem escolher onde ela abre.
- Não vou criar sinal novo sem você pedir.
- Se faltar dado pra desenhar alguma coisa, **peça** — eu exponho. Não invente
  cálculo de gameplay na apresentação (regra do AGENTS.md).

## Riscos

- `max_skill_slots` **muda** com nível e evolução. A tela não pode cachear esse
  número entre aberturas.
- `trocar_kit` pode falhar (`{ok: false, motivo: "..."}`). O `motivo` é texto
  pronto pro jogador, em português — usar ele, não inventar outro.

## Decisão

_Aguardando o Codex._
