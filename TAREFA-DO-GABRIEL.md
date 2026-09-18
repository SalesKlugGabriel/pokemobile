# 🔴 TAREFA NOVA DO GABRIEL — PLAYER 3D V1 (18/09/2026)

Leia: `docs/agent-proposals/gabriel/2026-09-18-player-3d-v1.md`
na branch **`agent/claude-v3`** (ou faça o merge dela — ela já contém a sua arte
da Golden Scene, mesclada em 18/09 sem conflito).

## Em uma frase

O Gabriel quer o **primeiro modelo 3D definitivo do PLAYER**, feito no Blender,
visualmente próximo a uma folha de concept art que ele montou — não "um modelo
que funcione".

## Três coisas antes de começar

1. 📄 **A folha de referência não existe como arquivo, e não vai existir.** A
   imagem chega ao Claude na conversa e **não é gravada no disco da VPS**; o
   Gabriel tentou subir e também não conseguiu.
   ➡️ **Use `docs/referencias/player_v1/FOLHA-DE-REFERENCIA.md`** — a folha
   transcrita painel por painel (turnaround, os cinco recortes de detalhe, os
   três quadros de contexto em jogo, a régua de escala, a paleta, o equipamento),
   separando o que está **desenhado** do que é interpretação. **Leia inteira
   antes da FASE 1.**

   Os três quadros de contexto são a parte que mais importa: eles ensinam a
   **distância e o ângulo da câmera**, o **tamanho do personagem na tela**, e que
   a leitura à distância depende de **silhueta + boné vermelho + mochila** — não
   de detalhe facial.
2. Já existe `assets/models/trainer/player.glb` (seu, 14–15/09), e **nada no
   jogo o carrega** — conferido por `git grep` em todas as branches. O treinador
   em cena hoje é uma **cápsula amarela** montada em código. O player_v1 não
   substitui nada: é o primeiro a entrar de verdade.
3. 🔴 **Frente no −Z, origem nos pés, 1 unidade = 1 metro.** Desde 18/09 o corpo
   do treinador **encara a mira do mouse**. Um modelo apontando pra +Z aparece
   andando de costas o tempo todo — que é exatamente a queixa que acabamos de
   resolver, e seria cruel reintroduzi-la pelo asset.

## O processo que ele pediu, e que importa

Ele foi explícito: **não entregar tudo de uma vez.** Modelo sem rig → turnaround
→ **parar e comparar com a referência** → só então rig, skinning, três animações
(idle/walk/run, só essas), export, cena de teste no Godot com terreno,
vegetação e Pokémon de verdade, e screenshots de escala.

E a regra que ele grifou: **low-poly não é baixa qualidade.**

## Ao terminar

Atualize `docs/QUADRO.md` na mesma sessão — regra dele de 17/09. Você já está
listado lá como dono do item 0 (prioridade).

---

# 🔴 SEGUNDA TAREFA — WORLD / TERRAIN / BIOME FACTORY V1

Leia: `docs/agent-proposals/gabriel/2026-09-18-world-factory-v1.md`
(branch `agent/claude-v3`).

O pedido original do Gabriel tinha 54 seções. O Claude **filtrou e anotou** a
pedido dele, trocando os "investigue" pelos números já medidos nesta VPS e
apontando as contradições em vez de repassá-las.

## O que mudou em relação ao texto original

**Cortado do V1:** cavernas inteiras (é uma segunda fábrica — a entrada vira
placeholder), a CLI completa, LOD implementado, e a hierarquia de Kanto (é o
passo DEPOIS da fábrica existir).

**Acrescentado, porque o texto não sabia:**

- `Terreno3D.altura_em(x,z)` é a **única fonte de verdade da geografia**, e
  **quatro sistemas já dependem dela** — inclusive todo nascimento de selvagem
  da Fase 11. A fábrica pode trocar a implementação; a função tem de continuar
  respondendo, ou bicho passa a nascer dentro da montanha **sem dar erro**.
- Os números medidos: `gl_compatibility`, **piso de 67 FPS com 20.000 instâncias
  em MultiMesh** (desktop, navegador real, 14/09), `.pck` já em **55,5 MB**.
- **A seed do mundo não pode usar o `RNGManager`** — ele existe pra uma partida
  ser reproduzível, e gerar terreno consumindo sorteios dele empurraria de lado
  captura, status e loot. É o mesmo bug que você achou em 14/09.
- O trabalho manual que o gerador **não pode apagar**: 61 quests com
  `location_tile`, ~30 NPCs posicionados, `zones.json`, e as 2.923 linhas do
  `MapLayouts.gd`.

## 🔴 A altura do player: resolvido — **1,60 m**

Eu tinha levantado como contradição. A transcrição da folha resolveu.

A folha lista **Pikachu em 0,40 m** e **Charizard em 1,70 m**. Conferi contra o
`heights.json` do jogo: **os dois batem exatamente**. Ela não inventou escala de
Pokémon pra caber no personagem — usou a real, que é o que a §15 exige.

Isso inverte quem é o outlier: **não é a folha, é o código.** O treinador é uma
cápsula de **1,75 m**, altura de **adulto** (a própria folha põe o NPC adulto em
1,75), quase certamente placeholder que nunca foi calibrado.

➡️ **Trabalhe com 1,60 m.** Quando o modelo entrar, `TrainerController3D` muda
junto — cápsula e malha. Vale confirmar com o Gabriel, mas a evidência tem lado.

## A primeira entrega NÃO é um asset

É `docs/WORLD_PIPELINE_AUDIT.md`, com 9 perguntas específicas listadas no
documento. **Pare ali e espere o Gabriel aprovar** antes de gerar geometria.
