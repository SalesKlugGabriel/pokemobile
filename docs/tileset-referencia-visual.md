# Referência visual de tileset — guardado pro futuro (01/09/2026)

O Gabriel mandou uma imagem de referência (`docs/referencias/tileset-visual-referencia.png`)
mostrando o "visual alvo" que ele quer pro mapa — **não é pra implementar agora**. Pedido dele:
"Ok siga em frente, futuramente vamos corrigir todos os detalhes do mapa, segue referência de
como quero que fique parecido". Ou seja: continuar a construção do mapa com o CHAR_MAP atual
(16 tipos de tile), e usar esta referência quando a fase "sprites mais legais" (item 4 da ordem
geral — depois de Mapa → Pokémon/estruturas → Mecânicas) ou uma retrofitagem de detalhes visuais
virar foco de verdade.

## O que a referência mostra (5 fileiras, ~40 tiles)

**Terreno base:** Chão Batido, Grama Baixa, Grama Alta, Arbusto, Árvore, Árvore Pinho, Árvore
Outono, Toco/Tronco.

**Estrutura:** Parede, Janela, Porta, Entrada Casa, Canto Casa, Telhado, Cerca, Caixa.

**Água/gelo/rocha:** Água, **Água com Praia** (transição orgânica areia→água, já é praticamente
o que `shore_de_vermilion()` tenta fazer só com posição de tile, sem sprite dedicado), Água com
Lírios, Gelo, Gelo Trincado, Rocha, Parede de Rocha, **Entrada Caverna** (arco de pedra — hoje a
entrada do Mt Moon é só um tile "P" no meio de rocha "R", sem moldura visual).

**Terrenos especiais:** Solo Envenenado (roxo — Zona Rocket/pântano?), Lama, Lama Funda, Poça
d'Água, **Rocha Vulcânica** (rachaduras de lava — óbvio candidato pra Cinnabar/Pokémon Mansion),
Areia, Trilhos (minério — Rock Tunnel/Power Plant?), Piso de Pedra.

**Interior/decoração:** Piso de Pedra Clara, Pedra com Musgo, Piso de Madeira, Tapete, Flores,
Cogumelos, Folhas Caídas, Junco.

## Comparação com o CHAR_MAP atual (`MapLayouts.gd`)

Hoje só existem 16 tiles (grama, caminho, flor, areia, grama clara, caminho escuro, piso, tapete,
parede, água, árvore, rocha, cerca, porta, telhado, sebe) — um atlas simples 8×2. A referência do
Gabriel tem categorias que HOJE são representadas pelo MESMO tile genérico (ex: "R" serve tanto
pra rocha de montanha quanto pra rochedo de maré quanto pra pedregulho de caverna — na
referência, cada um é visualmente distinto). Pra chegar no visual da referência, o atlas
`overworld.tres` precisa crescer bastante (provavelmente uma re-geração/expansão do tileset, não
só desenho manual) — fica pra quando "sprites mais legais" virar o foco real.

## Achado que já vale aplicar cedo (sem esperar o atlas crescer)

A separação clara de terreno-por-bioma na referência (Rocha Vulcânica ≠ Rocha comum ≠ Parede de
Rocha; Areia ≠ Lama ≠ Solo Envenenado) reforça a regra permanente já registrada em memória
(01/09): cada bioma precisa de identidade própria. Mesmo sem os sprites novos, o **layout**
(estrutura geológica, rota não-linear em caverna, curva orgânica em litoral) já pode seguir esse
espírito — é o que orienta a construção do Rock Tunnel e de qualquer caverna/litoral futuro.

## Segunda referência (02/09) — `docs/referencias/tileset-visual-referencia-2.png`

Screenshot de um jogo pronto (estilo Stardew Valley) mostrando o nível de detalhe que o Gabriel
quer: sprites com sombra/textura de verdade (não bloco de cor sólida), lago com lírios/pedras na
borda, casa com telhado inclinado/janelas/vaso de flor, cerca de madeira com sebe, HUD de mochila
com abas (Remédios/Pokébolas/Frutas/Chave/TM-HM). Mesmo status da primeira referência: **guardado
pro futuro, não implementar agora** — mandado durante a reorganização geográfica de 02/09, sem
pedido de ação imediata.

## Terceira leva de referências (02/09, sessão do zoom/árvore) — Estrutura (casa/Centro Pokémon/Mercado)

Mandadas no meio do trabalho de diversidade de tiles ("aproveitando que estamos falando de objetos
novos, olha essa referência pra casas, centro Pokémon e market"). 3 arquivos em
`docs/referencias/`:

- `estrutura-referencia-casa.jpg` — planta de casa vista de cima SEM telhado (mostra o interior:
  piso de tábua clara, escada, portas, janelas de sacada), cercada por canteiro de flores
  (vermelha/amarela/roxa), 2 fileiras de sebe recortada nas laterais, caminho de terra batida com
  borda de pedra.
- `estrutura-referencia-pokemon-center.jpg` e `estrutura-referencia-market.jpg` — screenshots de
  um jogo já pronto (MMO 2D com chat/HUD visível). **Bate com o estilo que eu já tinha achado numa
  pesquisa anterior (mesma sessão): Pokémon Revolution Online (PRO)** — fã-MMO conhecido, sprites
  de overworld HD amplamente compartilhados/reutilizados em outros fã-projetos (o mesmo espírito
  de reaproveitamento já usado pras sprites de Pokémon vindas do PokeAPI). Mostra chão de PC em
  ladrilho cinza/azulado com padrão, balcão de atendimento, PC de cura, prateleiras/vending de
  Mercado.

**Mesmo status das 2 referências anteriores: guardado pra quando "Estrutura" (Parede, Janela,
Porta, Entrada Casa, Canto Casa, Telhado, Cerca, Caixa) virar o foco de verdade** — o Gabriel
confirmou ("siga pra próxima parte antes de trabalharmos em detalhes") que a leva de hoje é
Terreno base primeiro; casas/Centro Pokémon/Mercado ficam pra próxima rodada de diversidade de
tiles.
