# Proposta de integração visual — ambiente natural

Owner: Codex. Reviewer de integração: Claude. Estado: implementado isoladamente,
em validação visual; sem publicação e sem alteração de contrato de gameplay.

Único ponto compartilhado: `BaseMap._ready()`, depois de `_paint_tiles()`, adiciona
o nó `AcabamentoNatural` como filho do TileMap e injeta a referência ao mapa.
O componente só lê as células já pintadas; não altera TileSet, colisões, spawn,
RNG, entidades, save ou coordenadas. Material pré-existente é preservado.

Um shader no TileMap anima apenas os pixels azuis dos slots de água/costa; o
componente desenha bordas de solo e sombra de mata só no retângulo visível.
Há limite de 1.600 células: em zoom extremo a decoração fina é omitida por inteiro.

Mudança de arte: somente pixels nas linhas 11–13 do atlas (as quatro árvores
grandes). Dimensões, IDs e colisões permanecem iguais; original em assets/old/.

Para revisão: confirmar que nenhum sistema de gameplay assume uma lista fechada
de filhos do TileMap ou precisa usar seu material. Nenhum sinal/API novo é pedido.
Testes de imutabilidade do mapa e preservação de material estão em
`scripts/tests/teste_acabamento_natural.gd`.
