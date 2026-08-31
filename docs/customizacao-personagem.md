# Customização de personagem (Paper Doll) — guardado para o futuro

> Pesquisa trazida pelo Gabriel em 31/08/2026. **Nada disto foi construído ainda** — é a
> especificação a seguir quando ele pedir pra começar a customização visual do Treinador.
> Guardado aqui (não só na memória do Claude) porque é referência técnica de verdade, do tipo
> que uma sessão futura vai precisar reler linha a linha antes de codar.

## A ideia central: Paper Doll / camadas, não sprite completo

Em vez de desenhar um personagem inteiro por combinação (corpo+cabelo+roupa...), cada parte
vira uma camada separada com os MESMOS frames/posições, desenhadas em ordem por cima uma da
outra. Só se troca a camada que mudou.

Exemplo de contagem: 10 cabelos × 10 cores × 8 camisetas × 8 calças × 6 sapatos × 10 chapéus ×
5 acessórios = 1.920.000 combinações se fosse sprite completo — impossível de manter. Em
camadas, são só os ~57 assets individuais (10+10+8+8+6+10+5), e o jogo monta a combinação.

## Camadas, em ordem (de baixo pra cima)

```
00_shadow
01_body
02_legs
03_feet
04_pants
05_shirt
06_jacket
07_hair_back
08_face
09_hair_front
10_hat
11_eyes
12_glasses
13_accessory
14_back_item
15_weapon
16_effect
```

Cada camada é um spritesheet com as 4 direções × idle/walk (e mais adiante run/attack/hurt),
todas alinhadas ao mesmo frame de referência.

## Tamanho

- Tile do mundo: 32×32px (hoje o jogo usa 16×16 — decisão de aumentar fica pra quando isso for
  construído, não é decisão automática).
- Personagem: 32×40 ou 32×48px (maior que o tile, cabeça pode ultrapassar).
- **Footprint de colisão continua pequeno** (16×16 ou 24×16) mesmo com o sprite maior — só o
  desenho estica pra cima, a caixa de colisão/movimento não muda.

## O que fica customizável

- **Corpo**: pele (poucas variações desenhadas + palette swap pra cor, não desenhar 6 corpos).
- **Cabelo**: estilo (curto/médio/longo/moicano/cacheado/afro/rabo de cavalo/topete/
  bagunçado/especial) × cor (preto/castanho/loiro/ruivo/branco/azul/verde/rosa).
- **Roupa**: TOP (camiseta/regata/jaqueta/moletom/colete/uniforme/especial) e BOTTOM (calça/
  shorts/jeans/uniforme/especial).
- **Chapéu**: boné/touca/chapéu/capacete/bandana/boina/cartola/capuz.
- **Acessório**: óculos/máscara/brinco/colar/relógio/mochila/bolsa.
- **Cosméticos ligados a Pokémon** (visual, não é equipamento de combate): mochila do
  Charmander, boné do Pikachu, cinto de Poké Bolas, jaqueta da Equipe Rocket, uniforme de
  Líder de Ginásio...
- **Outfits**: conjuntos completos (Treinador Kanto, Treinador Johto, Pesquisador, Criador
  Pokémon, Ranger, Membro de equipe, Líder de Ginásio, Elite Trainer) — ao equipar, o outfit
  substitui várias camadas de uma vez, mas o nome/identidade/animações continuam as mesmas.
- **Equipamento visual** (mais pra frente): head/back/body/legs/feet/main hand/off hand — tudo
  aparece de verdade no personagem no mundo.

## Animações — já pensar nisso desde o início pra não refazer depois

```
idle_down/up/left/right
walk_down/up/left/right
run_down/up/left/right
attack_down/up/left/right
hurt_down/up/left/right
faint
emote
interact
```

## Pipeline recomendado

```
Aseprite/Pixelorama → sprites por camada
        ↓
Spritesheets padronizados (mesma grade em toda camada)
        ↓
Character Composer próprio (código do jogo)
        ↓
JSON de aparência (é isso que fica salvo, não a imagem)
        ↓
Sprite final composto no mundo
```

Exemplo do JSON de aparência (o que o save guarda — nunca a imagem montada):

```json
{
  "body": "male_01",
  "skin": "skin_03",
  "hair": { "style": "hair_07", "color": "brown" },
  "eyes": "eyes_02",
  "top": { "item": "shirt_04", "color": "blue" },
  "bottom": { "item": "pants_02", "color": "dark" },
  "shoes": "shoes_03",
  "hat": "cap_05",
  "accessory": "glasses_02",
  "back": "backpack_01"
}
```

## Se algum dia migrar pra Phaser (hoje o jogo é Godot)

O material original pesquisado partia de Phaser (`Container` pra agrupar sprites,
`DynamicTexture`/`RenderTexture` pra compor as camadas numa textura só, gerada depois que o
jogador termina de escolher a aparência — evita manter 10+ sprites desenhando ao vivo por
jogador). Em Godot, o equivalente seria compor as camadas num `SubViewport` +
`ViewportTexture`, ou simplesmente empilhar `AnimatedSprite2D` (uma por camada) dentro de um
`Node2D`, sincronizando a animação tocada em todas ao mesmo tempo — mais simples de
implementar, mais caro de rodar com muitos jogadores na tela ao mesmo tempo (só vira problema
de verdade se/quando o multiplayer existir).

## Editor de personagem in-game (ideia pra tela, não motor)

Uma tela de criação com preview ao vivo + setas `◀ Cabelo 07 ▶` por categoria + paleta de cor
+ botão "Aleatório" + "Confirmar". Fica pra fase de layout, depois que as camadas e o
Composer já existirem.

## Decisão de especificação (se/quando for construído)

32×32 ou 32×40/48 → pixel art própria → 4 direções → Paper Doll → 10-15 camadas → palette
swap → spritesheet padronizado → composição numa textura única → sprite final no mapa.
