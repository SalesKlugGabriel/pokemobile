# GAMEPLAY V3 — 3D · direção atual e autoritativa

> **Leia este arquivo primeiro ao retomar a V3.** Ele é o painel de controle da
> migração e o único lugar onde o estado de cada fase é atualizado.
>
> Em qualquer conflito entre V2 e V3, **V3 vence** — mas sistema da V2 que
> continua compatível é **preservado**, não reescrito.

**Aberto em:** 14/09/2026 · **Base:** commit `bef3146`
**Documentos irmãos:** [RFC](rfc/RFC-GAMEPLAY-V3-3D.md) ·
[migração](MIGRATION_V2_TO_V3.md) · [mundo](WORLD_3D_ARCHITECTURE.md) ·
[combate 1ª pessoa](COMBAT_FIRST_PERSON.md) · [surf e voo](TRAVERSAL_SURF_FLY.md)

---

## A fantasia que precisa ser provada

> **Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
> controle do meu Pokémon.**

Tudo que não contribui direto pra provar isso fica em segundo plano.

**Não é MOBA.** Combate 1v1, no próprio terreno, sem arena. Valorant, Paladins e
Smite entram só como referência de **controle, câmera, mira e resposta**. ARK
entra como referência de **mundo, relevo, escala e verticalidade**. A identidade
continua Pokémon.

---

## 📍 ONDE ESTAMOS

| | |
|---|---|
| **Fase atual** | **3 — treinador 3D** (0, 1 e 2 fechadas) |
| **Branch** | `agent/claude-v3` (a criar) · `main` segue com a V2 |
| **Código V3 escrito** | **nenhum**, de propósito |
| **Bloqueio** | RFC esperando o Gabriel |

### Decisões em aberto (precisam do Gabriel)

| # | Decisão | Quando trava |
|---|---|---|
| 1 | **Billboard ou modelo 3D pros Pokémon?** 605 sprites existem, 0 modelos | Fase 5 |
| 2 | ~~Manter `gl_compatibility`?~~ | ✅ **RESOLVIDO** — medido, aguenta. Ver abaixo |
| 3 | `Terrain3D` de terceiros ou malha própria? | Fase 4 |

### ✅ A medição da Fase 2 (14/09, desktop, navegador real)

`gl_compatibility` · 1592×720 · 20.000 instâncias em MultiMesh + 40 corpos com
física + sombra direcional ligada.

| Vegetação | FPS |
|---:|---:|
| 0 | 83,5 |
| 500 | 86,0 |
| 2.000 | 83,5 |
| 8.000 | 76,0 |
| **20.000** | **67,0** |

**Piso de 67 FPS no pior caso, acima da meta de 60.** A curva cai ~20% ao
adicionar 20 mil plantas — o MultiMesh está fazendo o trabalho dele.

⚠️ **Ruído de ~3 FPS**: 500 plantas mediu *mais* que 0. Diferença abaixo disso
não é real, e não vale tirar conclusão dela.

⚠️ **Isto é DESKTOP.** O celular é o aparelho fraco e é o que decide de verdade.
Medir nele antes da Fase 19 (polimento), quando a vegetação real existir.

🔵 **Achado de brinde:** na captura dá pra ver a HUD da V2 e o botão de feedback
desenhando **por cima da cena 3D**. Os autoloads sobrevivem ao pivô sem nenhuma
adaptação — prova visual do que a tabela de migração afirmava.

---

## As 20 fases

Marcar aqui a cada sessão. **Uma fase só vira ✅ quando tem teste e foi vista
rodando** — não quando o código existe.

| # | Fase | Estado | Nota |
|---|---|---|---|
| 0 | Auditoria | ✅ | 14/09 · `MIGRATION_V2_TO_V3.md` |
| 1 | Documentação / RFC | 🔵 em revisão | RFC aberto |
| 2 | Cena 3D experimental isolada | ✅ | 14/09 · **medido em navegador real: piso de 67 FPS** |
| 3 | Treinador em 3ª pessoa | 🔵 em andamento | `TrainerController3D` |
| 4 | Terreno 3D | ⬜ | decisão 3 |
| 5 | Pokémon 3D | ⬜ | **decisão 1** |
| 6 | Companion Pokémon | ⬜ | |
| 7 | Transferência Treinador → Pokémon | ⬜ | o coração da fantasia |
| 8 | Pokémon em 1ª pessoa | ⬜ | |
| 9 | Ataque básico | ⬜ | |
| 10 | 4 skills | ⬜ | melee, projétil, área, drenagem |
| 11 | Wild Pokémon | ⬜ | reusa `ComportamentoSelvagem` |
| 12 | Combate 1v1 | ⬜ | |
| 13 | Combate → Mundo | ⬜ | fecha o laço da fantasia |
| 14 | Surf | ⬜ | |
| 15 | Fly | ⬜ | |
| 16 | TM/HM | ⬜ | `TrocaDeKit` já existe |
| 17 | Move Pool | ⬜ | `KitDeCombate` já existe |
| 18 | Alpha | ⬜ | regras já existem |
| 19 | Polimento | ⬜ | **Codex entra aqui** |
| 20 | Performance | ⬜ | |

**Não pular fase.** A ordem existe porque cada uma depende da anterior estar de
pé — e porque pular é como se constrói seis sistemas pela metade.

---

## Critério de sucesso da primeira etapa

Funcionando de ponta a ponta, sem travar:

entrar no mundo → andar → correr → olhar ao redor → atravessar terreno →
encontrar um Pokémon → iniciar batalha → **assumir o Pokémon** → lutar em 1ª
pessoa → encerrar → **voltar a ser o treinador**.

Mais, do lado da engenharia:

- **FPS medido em navegador real.** Nunca alegado a partir de teste headless.
- A suíte das 18 classes puras continua verde **sem uma linha alterada**.
- Um save da V2 carrega na V3 **sem migração**.

---

## O que NÃO fazer agora

MMO, servidores, matchmaking, ranking, economia, market, housing, PvP
competitivo, persistência massiva. Também: converter dezenas de Pokémon, criar
mil golpes, construir Kanto, ou produzir gráfico final.

Primeiro single-player local. Depois PvE. Depois 1v1 online. **Muito depois**,
MMO.

---

## Divisão de trabalho

**Nesta fundação, só o Claude conduz** (§45 do pedido): auditoria, arquitetura,
documentação, migração, controller, câmera, combate, integração e testes. A
razão é ter uma autoridade arquitetural única enquanto a fundação se forma.

**O Codex entra na Fase 19**, e só depois de existir o slice funcional com
treinador 3D + terreno + Pokémon 3D + transferência + 1ª pessoa + ataque básico
+ 4 skills + volta ao treinador + surf e voo básicos. Aí ele assume terreno,
vegetação, árvores, grama, água, praia, VFX, animação, HUD e polimento.

⚠️ **Ele tem trabalho não integrado** na branch `agent/codex-gameplay-v2` (HUD,
câmera e telegrafia da V2, commit `28a764e`). **Precisa ser avisado do pivô**
antes de investir mais — parte disso vira legado.

---

## Como retomar em outra sessão

1. Ler este arquivo (o painel acima diz a fase).
2. Ler a [RFC](rfc/RFC-GAMEPLAY-V3-3D.md) se a dúvida for de arquitetura, ou a
   [tabela de migração](MIGRATION_V2_TO_V3.md) se for "o que faço com o sistema X".
3. `git branch` — a V3 vive em `agent/claude-v3`; `main` tem a V2.
4. `tools/rodar_testes.sh` antes de começar, pra saber de onde partiu.
5. ⚠️ **Nunca rodar a suíte com outro `godot4` ativo** (`ps aux | grep godot4`).
   Duas suítes em 2 núcleos produzem reprovação falsa — já aconteceu.
6. Ao terminar: atualizar a tabela de fases **aqui**, `progresso.md`, e commitar.

**Nada da V2 é apagado nesta migração.** `MapLayouts`, as 120 cenas 2D e os
tilesets ficam no repositório mesmo depreciados, até a V3 substituir de verdade.
