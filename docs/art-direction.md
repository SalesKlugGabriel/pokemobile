# Direção visual vigente

Índice curto, não uma segunda paleta. Fonte canônica:
[ART_BIBLE](../assets/ART_BIBLE.md) e [direção mestre](direcao-de-arte-mestre.md).
Referências do Gabriel: `docs/referencias/tileset-visual-referencia*.png` e
imagens de estruturas na mesma pasta.

Objetivo atualizado (Gabriel, 11/09): mundo tão natural e convincente quanto possível
dentro da pixel art. Legibilidade Pokémon GBA, usabilidade Tibia/OT Pokémon e HUD
moderna responsiva. Isso não significa texturas fotográficas ou migrar para 3D.

- Luz de cima/esquerda, sombra para baixo/direita; volume em tons discretos.
- Preservar grade de 128 px por tile e contratos de frames; não alterar escala
  física para acomodar arte. Sprites completos, centralizados, pivô consistente.
- Pixel clusters, silhuetas orgânicas e paleta existente. Sem blur, gradiente suave,
  vetor liso, ruído pixel a pixel, números/letras acidentais ou upscale como redesenho.
- Árvores grandes 2×3 tiles devem combinar com as pequenas; substituir somente a
  arte, preservando as seis células e suas colisões.
- Casas precisam de laterais/cantos reais, telhado e contato com o chão; não repetir
  uma fachada de janela nos quatro lados.
- Bordas grama/terra/areia/água naturais, água rasa visualmente distinta, vegetação
  e geologia coerentes com o bioma. Efeitos não encobrem alvo/telegraph.
- Iterar em lotes completos: antes → integração → navegador → depois → correção.
  Registrar o que foi medido e o que segue pendente.

Gabriel autorizou decisões e execução em 11/09 após definir a divisão dos agentes.
Pedidos antigos de aprovação por fase não exigem reconfirmar decisões já delegadas.
