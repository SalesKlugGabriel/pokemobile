# Fila do Codex — Gameplay V3 (3D)

> **Esta é a lista de espera, não a ordem de começar.** Pelo §46 do pedido do
> Gabriel, o Codex **não entra ainda**. Leia primeiro
> `2026-09-14-PIVO-PARA-3D.md`.
>
> Atualizado em 14/09/2026 · branch `agent/claude-v3`

---

## Quando você entra (§47)

Só depois de existir o vertical slice funcional:

```
treinador 3D ✅ · terreno ✅ · Pokémon 3D ✅ · transferência ⬜ ·
Pokémon em 1ª pessoa ⬜ · ataque básico ⬜ · 4 skills ⬜ ·
volta ao treinador ⬜ · surf básico ⬜ · voo básico ⬜
```

**5 de 10 prontos.** O que falta é combate — Fases 6 a 15.

Enquanto isso: **não produza asset, não crie shader, não mexa em cena.** Não é
desconfiança. É ter uma arquitetura só enquanto a fundação se forma, que é o
que o Gabriel pediu com todas as letras.

---

## 🔴 A tarefa que mais importa, e ela já pode ser PENSADA

**Modelos 3D de Pokémon.** O Gabriel decidiu em 14/09: **modelo, não billboard**.

Isso significa que **os 605 sprites saem do mundo** e a produção de modelos vira
o **caminho crítico do projeto** — não o código. É a sua área, é o item mais
caro da V3 inteira, e é o único que não tem atalho.

**Leia `docs/POKEMON_MODEL_PIPELINE.md`.** O contrato está lá: `.glb`, escala em
metros, origem nos pés, frente em −Z, no máximo 2 materiais, e os 4 estados de
animação (`idle`, `walk`, `attack`, `hurt`).

O que já está resolvido do meu lado e você não precisa refazer:

- **As 151 alturas reais** já existem em `heights.json` (0,2 m do Diglett a
  8,8 m do Onix). Seu modelo tem que bater com a altura de lá.
- **Colisor, hurtbox, alcance e câmera NÃO vêm do modelo.** São perfil. Modelo
  bonito com colisor errado é pior que primitivo com colisor certo, porque o
  primeiro parece funcionar.
- **Modelo ausente já cai num primitivo colorido por tipo e AVISA** na linha do
  tempo do feedback. Você pode entregar um de cada vez, sem quebrar nada.

**Os três primeiros (§16), na ordem:** Charizard (#6, terrestre), Gyarados
(#130, aquático), Pidgeot (#18, voador). Um por arquétipo — é o que prova o
contrato inteiro.

Sugestão: **faça UM e me mande.** Se o contrato estiver errado, é melhor
descobrir no primeiro que no décimo.

---

## A fila, na ordem que o §47 define

| # | Tarefa | Depende de | Nota |
|---|---|---|---|
| 1 | **Terreno visual** | Fase 4 ✅ | A malha existe e funciona. Ela é **cinza e feia de propósito** — só cor por altura. Material, textura e transição de bioma são seus |
| 2 | **Vegetação** | Fase 4 ✅ | ⚠️ **MultiMesh obrigatório.** Medido: 20 mil instâncias custaram 16 FPS (83,5 → 67). Node por planta mata o navegador |
| 3 | **Árvores** | ídem | §24: nunca em grade. Cluster, escala e rotação variáveis |
| 4 | **Grama alta** | ídem | §25: GPU-friendly. Continua sendo o lugar de encontro escondido |
| 5 | **Água** | Fase 4 ✅ | Hoje é um plano translúcido **sem colisão**, de propósito: quem decide se dá pra entrar é a travessia, não uma parede |
| 6 | **Praia** | Fase 4 ✅ | A transição já é contínua na geometria — **não ponha degrau de volta**. Ver o achado abaixo |
| 7 | **Modelos de Pokémon** | — | 🔴 o caminho crítico. Pode começar a pensar já |
| 8 | **VFX de combate** | Fase 10 | O contrato `golpe_resolvido` já existe e já leva tipo, direção e efetividade classificada |
| 9 | **Animações** | Fase 7 | Os 4 estados do contrato |
| 10 | **HUD 3D** | Fase 12 | Seu `HudV2` sobrevive quase inteiro — `Control` não tem dimensão |
| 11 | **Polimento** | Fase 19 | |

---

## Números medidos que você deve usar, e não re-descobrir

**FPS no desktop do Gabriel**, `gl_compatibility`, 1592×720, com 40 corpos de
física e sombra direcional ligada:

| Vegetação | FPS |
|---:|---:|
| 0 | 83,5 |
| 2.000 | 83,5 |
| 8.000 | 76,0 |
| **20.000** | **67,0** |

**Orçamento:** 20 mil instâncias custam ~16 FPS e ainda sobra margem sobre 60.
⚠️ **Isto é desktop.** O celular ainda não foi medido, e é o aparelho fraco.

⚠️ **Ruído de ~3 FPS** — 500 plantas mediu *mais* que zero. Diferença abaixo
disso não é real, e não vale otimizar contra ela.

---

## Três armadilhas que já custaram caro nesta migração

Registro porque economiza o seu tempo, e as três são erros meus.

1. **O código que evitava a "parede artificial entre mar e terra" estava
   construindo uma.** O achatamento da praia era condicional, e achatamento
   condicional cria degrau na borda da condição — 1,60 m de salto em 0,78 m.
   Se você mexer no terreno, **mexa de forma contínua**.

2. **Não havia falésia nenhuma no mapa.** O morro subia 28°, que se sobe
   andando. A regra de ângulo máximo do controlador nunca era exercida. Relevo
   sem parede é decoração.

3. **Medir FPS onde não há GPU dá número convincente e falso.** A VPS deu 8 FPS
   reto em todos os degraus — e o "reto" denunciava: se a cena fosse o gargalo,
   cairia. **Toda medição de performance acontece no aparelho do Gabriel.**

---

## O contrato entre nós continua o mesmo (§48)

**Claude:** gameplay, arquitetura, lógica, fórmulas, testes.
**Codex:** visual, assets, apresentação.

Você não altera fórmula, stats, status, progressão nem arquitetura de gameplay
sem autorização. Eu não troco seus assets sem necessidade.

**O que mudou na V3:** durante a fundação, a autoridade arquitetural é uma só
(§45). Isso acaba quando o slice fechar.

---

## Quando for a hora

Eu aviso aqui e no `GAMEPLAY_V3.md`. Até lá, se quiser adiantar alguma coisa
**sem tocar no repositório**, o melhor uso do seu tempo é o modelo de teste do
item 7 — é o que descobre se o contrato está certo.
