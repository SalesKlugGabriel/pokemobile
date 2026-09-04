# PokéMobile — Direção de Arte Global (Prompt Mestre de Reconstrução Visual)
### Cole este arquivo no Claude Code sempre que for trabalhar em QUALQUER elemento gráfico do jogo

> Recebido do Gabriel em 2026-09-03. Referências visuais anexas (`docs/referencias/tileset-visual-referencia.png`
> e `tileset-visual-referencia-2.png`) já existiam no repositório desde 01/09/2026 — são os mesmos arquivos,
> reenviados agora para reforçar a direção. Ver `memoria`/changelog de 01/09 para o contexto original.

---

## Por que este prompt existe

O pedido original era reconstruir só a cena principal. Mas você quer isso em **todo o jogo**: mapa, estruturas, os 151 Pokémon de Kanto, tela de batalha, HUD, inventário, efeitos. Se cada uma dessas partes for reconstruída separadamente sem uma referência única, o personagem vai parecer de um jogo, a árvore de outro, e o Pokémon de um terceiro.

A solução: definir a identidade visual **uma única vez** (Fase A), e só depois aplicá-la, categoria por categoria, na ordem que faz sentido para o jogo que já está evoluindo (mesma lógica de lotes que já usamos no resto do projeto).

**Regra permanente, vale para toda fase abaixo:** nunca reconstruir tudo de uma vez. Uma fase por vez, com checkpoint de revisão antes da próxima.

---

## Regra mais importante (vale para tudo, sempre)

NÃO faça upscale automático de nada (aumentar resolução + sharpen + blur). Cada elemento deve ser **redesenhado do zero em pixel art**, elemento por elemento, mantendo a função e a composição que já existem no jogo — não é "outro jogo", é "o mesmo jogo com gráficos profissionais".

---

## FASE A — Art Bible (fazer isso PRIMEIRO e uma única vez)

Antes de tocar em qualquer asset, criar e documentar em `/assets/ART_BIBLE.md`:

1. **Resolução interna padrão** (densidade de pixel) — a mesma para o menor ícone de UI e para o maior tile de mapa.
2. **Paleta global por categoria:** GROUND, GRASS, VEGETATION, STRUCTURES, CHARACTER, POKEMON, UI, SHADOW, HIGHLIGHT, EFFECTS — cada uma com cor base, sombra, sombra profunda, highlight e cor de acento. Mesma lógica de cor em todas as categorias.
3. **Direção de luz única** (ex: top-left → bottom-right), aplicada a 100% dos elementos do jogo, sem exceção.
4. **Estilo definido:** "top-down modern pixel art". Proibido: blur, gradiente suave, anti-aliasing, contorno preto exagerado, textura fotográfica, repetição óbvia de tile, sprites genéricos.
5. **Estrutura de pastas:** preservar a existente ou criar `/assets/pixel_art/`, `/sprites/`, `/tiles/`, `/ui/`, `/effects/`, `/old/` (backup).

Este documento é a referência obrigatória de **todas** as fases seguintes.

🔴 **DECISÃO GABRIEL:** aprovar a Art Bible (paleta, estilo, resolução) antes de qualquer asset ser desenhado. É a decisão mais barata de corrigir agora — e a mais cara de corrigir depois de 100 assets prontos.

---

## FASE B — MVP da cena principal
*(equivalente ao pedido original — usar a screenshot em anexo como referência)*

Reconstruir apenas: terreno, grama, 1 árvore, personagem, criatura atual, sombra do personagem, HUD superior, barra inferior com os botões existentes — seguindo a Art Bible da Fase A.

Ciclo obrigatório (repetir 3 vezes): criar → integrar → rodar o jogo → print → comparar com o original → corrigir.

Preservar: boné vermelho e corpo azul do personagem, função e posição da criatura atual (não trocar por outra), toda a lógica de jogo (movimento, combate, XP, colisão) intacta — só a camada visual muda.

🔴 **DECISÃO GABRIEL:** comparar com o jogo real e aprovar antes de expandir para o resto do mundo.

---

## FASE C — Expansão do mapa (tiles e estruturas)

- Tileset completo de terreno e grama: bordas, cantos, variações, transições naturais, sem costura visível (seamless).
- Pelo menos 4 árvores diferentes (silhuetas distintas), cada uma com sombra própria no chão.
- Estruturas (casas, cercas — mesmas do Lote 4 do plano de gameplay) na mesma linguagem visual da Art Bible.

Mesmo ciclo de qualidade da Fase B (criar → integrar → rodar → comparar → corrigir).

---

## FASE D — Pokémon (sprites de batalha)

São 151 espécies (Kanto, já decidido). **Não reconstruir todos de uma vez.**

- **Lote D1:** só os Pokémon que já aparecem nas áreas construídas hoje (Pallet Town / Rota 1 / Viridian City) + o Pokémon inicial do jogador.
- **Lotes seguintes:** liberar novos Pokémon na mesma velocidade em que o mapa for se expandindo (Fase 3 do plano mestre) — nunca redesenhar Pokémon de áreas que ainda não existem no jogo.
- Cada um precisa: silhueta própria, sombra no chão, pequena animação idle, e conferência de consistência com a Art Bible.

---

## FASE E — Telas de batalha e interface

- Tela de batalha: fundo, posicionamento dos combatentes, barra de HP, indicador de tipo.
- HUD e tela de status (expandindo o HUD já feito na Fase B para outras telas).
- Inventário: grade de itens e ícones.
- Botões de ação (Tackle/Grow e os que vierem depois), com estados: normal, hover, pressed, disabled, cooldown.

---

## FASE F — Efeitos e polimento final

- Efeitos de golpes (impacto, partículas simples), transições de tela.
- Auditoria final de consistência (ver checklist abaixo) em **todos** os elementos já criados nas fases anteriores.

---

## Checklist de consistência (rodar ao final de CADA fase, não só no final do projeto)

- [ ] Todos os assets da fase têm a mesma densidade de pixel
- [ ] Nenhum está borrado ou com anti-aliasing
- [ ] Sombras e highlights seguem a mesma direção de luz da Art Bible
- [ ] Paleta bate com a definida na Fase A
- [ ] Novos elementos combinam visualmente com os das fases anteriores
- [ ] Tiles não têm costura visível nem repetição óbvia
- [ ] Todos os sprites têm o pivô (ponto de ancoragem) correto

---

## Ferramentas

Prioridade: **Aseprite / pixel-mcp** (arte real, editável, pixel a pixel) — nunca gerar como imagem rasterizada genérica no lugar de pixel art de verdade. Preservar os arquivos-fonte `.aseprite`.

Para elementos genéricos e não centrais (ex: pedras, decorações de fundo), pacotes prontos como **Kenney.nl** ou **OpenGameArt** podem preencher lacunas mais rápido — mas só depois de adaptados à paleta da Art Bible, senão destoam do resto.

---

## Backup (obrigatório antes de cada fase)

Verificar Git, criar commit/checkpoint, conferir arquivos modificados. Nunca sobrescrever assets sem guardar o antigo em `/assets/old/`.

---

## Entrega esperada ao final de cada fase

1. O que foi reconstruído nesta fase (lista simples)
2. Screenshots antes/depois
3. Arquivos novos e modificados
4. Resultado do checklist de consistência
5. Problemas encontrados
6. Próxima fase recomendada
