# PokéMobile — Art Bible

> Fase A do documento `docs/direcao-de-arte-mestre.md` (Gabriel, 2026-09-03). Escrita a partir da
> **auditoria técnica e visual já feita no jogo real** (não é teoria solta) + das cores extraídas
> de verdade das duas referências que o Gabriel mandou (`docs/referencias/tileset-visual-
> referencia.png` e `-2.png`).
>
> 🔴 **Rascunho aguardando aprovação do Gabriel — nenhum asset foi desenhado ainda.**
> Depois de aprovado, este arquivo vira a referência obrigatória de toda fase seguinte
> (B em diante), e qualquer mudança de paleta/luz/resolução daqui pra frente passa por aqui
> primeiro, não é decidida solta dentro de uma fase.

---

## 1. Resolução interna padrão

**Manter 128×128px por tile — não mudar.**

Não é uma escolha nova: é a grade real que o próprio jogo já usa hoje, migrada nesta mesma sessão
de desenvolvimento (era 32px antes) e já adotada por **100% dos assets vivos** conferidos na
auditoria — o tileset inteiro (`overworld.png`), o Treinador, os NPCs e as 302 sprites de Pokémon
(151 espécies × normal/shiny) já respeitam essa grade ou uma fração exata dela (frame de
personagem = 128×256, ou seja 1×2 tiles; ícone de UI = 32×32, ou seja 1/4 de tile). Trocar agora
destruiria a migração e obrigaria a reexportar tudo sem ganho nenhum de qualidade visual — o
problema encontrado na auditoria nunca foi "resolução errada", foi estilo/acabamento.

**Sub-grades permitidas** (todas múltiplos exatos de 128, pra nunca gerar sub-pixel):
- Ícone de UI/item: 32×32 (4 cabem num tile)
- Sprite de personagem/NPC: 128×256 (1×2 tiles — corpo humano, já em uso)
- Sprite de Pokémon: 128×128 por frame (já em uso)
- Tile de chão/decoração: 128×128 (já em uso)

## 2. Paleta global por categoria

Cores-base **extraídas de verdade** das referências do Gabriel (não inventadas) — os tons
intermediários (sombra/highlight) de cada linha ainda precisam ser pintados à mão quando cada
asset for desenhado, mas a base é real:

| Categoria | Base | Sombra | Sombra profunda | Highlight | Acento |
|---|---|---|---|---|---|
| **GROUND** (chão batido/areia) | `#B2874E` | `#8A6538` | `#5E4526` | `#D4A868` | — |
| **GRASS** (grama baixa/alta) | `#5D8C23` | `#497C21` | `#2E5313` | `#7FB544` | `#A0D060` (highlight de ponta) |
| **VEGETATION** (árvore/arbusto) | `#508B26` (folhagem) | `#18310E` (núcleo escuro) | `#0C1D08` | `#7FB544` | `#6B4A2A` (tronco) |
| **WATER** | `#1E6F9A` (raso) | `#0D3D6D` (fundo) | `#082647` | `#8FD4E8` (highlight/espuma) | `#C8E3E9` (gelo) |
| **STRUCTURES** (parede/madeira) | `#A06732` (madeira) / `#544B41` (pedra) | `#70431F` / `#3A332B` | `#4B2C14` / `#211D18` | `#C98F52` / `#7A6E60` | `#B24424` (telhado, acento quente) |
| **CHARACTER** (Treinador — preservar boné vermelho + macacão azul) | `#C23B3B` (boné) / `#3B5FA0` (macacão) | `#8E2A2A` / `#2A447A` | `#5C1B1B` / `#182C4E` | `#E86B6B` / `#6E93D0` | `#F2C9A0` (pele) |
| **POKEMON** | *(por espécie — sem cor global; cada Pokémon segue a paleta que a PokeAPI já define, que é a fonte de verdade da categoria inteira)* | | | | |
| **UI** | `#22201C` (painel escuro, já confirmado na referência da Mochila) | `#151412` | `#0A0908` | `#3A362F` (borda clara do painel) | `#D4A868` (texto/destaque, tom dourado herdado do GROUND) |
| **SHADOW** (sombra de contato no chão) | `#000000` a 35–45% de opacidade, nunca blur — sempre forma rasterizada | | | | |
| **EFFECTS** (hit/heal/pickup) | A definir na Fase F, herdando SEMPRE a cor semântica (dano=vermelho da paleta CHARACTER, cura=verde da paleta GRASS) — nunca uma cor nova fora da tabela | | | | |

## 3. Direção de luz única

**Luz vindo de cima-esquerda, sombra projetada pra baixo-direita** — confirmado batendo com as
duas referências do Gabriel (o telhado da casa e a árvore na imagem-cena têm a face
esquerda/superior mais clara e a direita/inferior mais escura; a sombra de contato no chão cai
pra baixo-direita da base de cada objeto). **Regra sem exceção**: todo asset novo (personagem,
árvore, estrutura, efeito) usa esse mesmo ângulo — é o que a Fase 4 do pedido original chamava de
"identidade visual consistente", e é o tipo de coisa que fica impossível de corrigir depois se
cada lote escolher o próprio ângulo.

## 4. Estilo — regras sem exceção

**Fazer:**
- Contorno escuro (não preto puro — usar a "sombra profunda" da própria paleta do objeto, ver
  tabela acima) só onde separa silhuetas que se sobrepõem; nunca contornar cada pixel individual.
- Dithering controlado (padrão xadrez/diagonal de 2 tons) só em transições grandes (água, céu se
  algum dia existir) — nunca em áreas pequenas tipo olho/detalhe de rosto.
- Cluster de pixels pra textura (grama, pedra, folhagem) — nunca ruído aleatório pixel a pixel.
- Ambient occlusion estilizado: uma faixa 1-2px mais escura só onde um objeto encosta no chão ou
  outro objeto (base do tronco, embaixo do parapeito) — não em toda a silhueta.

**Proibido** (lista literal do Gabriel, sem interpretação):
- Blur, gradiente suave, anti-aliasing de verdade (o "suavizado" de um editor de imagem comum).
- Aparência de desenho vetorial (**achado da auditoria: é exatamente o problema atual do
  `player.png`** — blocos de cor lisos sem textura nenhuma, ver seção 6).
- Aparência de IA genérica / pixel art "lisa demais".
- Textura fotográfica.
- Repetição óbvia de tile (ver Fase C — variações de chão).
- Outline preto em excesso.
- Upscale automático (resize + sharpen) no lugar de redesenho de verdade.

## 5. Estrutura de pastas

**Preservar a estrutura existente** (`assets/sprites/{player,npc,pokemon}/`,
`assets/tilesets/`, `assets/ui/icons/`) — já é organizada por categoria, coerente com o que o
código (`SpriteBuilder.gd`) espera, e trocar os caminhos agora quebraria toda referência
`res://assets/...` do projeto sem ganho nenhum. Único acréscimo, exigido pelo próprio pedido do
Gabriel:

```
assets/
  old/              ← NOVO. Backup do asset substituído, mesmo nome + sufixo _v0
                       (ex.: player.png substituído → assets/old/player_v0.png), criado
                       ANTES de qualquer sobrescrita, toda fase.
  sprites/
    player/         (já existe)
    npc/            (já existe)
    pokemon/        (já existe)
  tilesets/         (já existe)
  ui/icons/         (já existe)
  ART_BIBLE.md      ← este arquivo
```

---

## Diagnóstico herdado da auditoria (por que a paleta acima começa onde começa)

Resumo de 3 achados da auditoria técnica anterior, que esta Art Bible já leva em conta:

1. **O tileset (`overworld.png`) já está OK** — tem sombreamento e variação de tom de verdade. A
   paleta GROUND/GRASS/WATER/STRUCTURES acima foi extraída DELE, não inventada — a meta da Fase C
   é expandir esse padrão (mais variações, sem repetição), não substituí-lo.
2. **Os Pokémon (`mon_XXX.png`) já são arte real** (sprites oficiais via PokeAPI) — por isso a
   categoria POKEMON na tabela não tem paleta própria: forçar uma paleta genérica em cima da arte
   oficial destruiria a única coisa no jogo com pedigree de produção de verdade.
3. **O Treinador/NPCs são o elo fraco** — blocos de cor lisos, sem sombra/highlight, quase sem
   diferença entre frames de caminhada. É por isso que a Fase B do prompt do Gabriel já começa
   pelo personagem: é o pior ponto e o mais visível o tempo inteiro.

Achado técnico à parte, que não é sobre arte mas afeta a percepção de qualidade: o modo de
escala da janela (`window/stretch/mode="canvas_items"`, sem escala inteira) já está causando
borrão sub-pixel independente da arte — recomendo corrigir isso ANTES da Fase B, senão a arte
nova sofre o mesmo efeito. Fica registrado aqui porque impacta diretamente a Fase B ("comparar
com o jogo real"): sem esse ajuste, a comparação visual fica injusta com a arte nova.
