# Pipeline de modelo de Pokémon

> Decisão do Gabriel, 14/09: os Pokémon são **modelos 3D**, não sprites.
> Parte da [Gameplay V3](GAMEPLAY_V3.md).

## O que este documento existe para evitar

Que o primeiro modelo pronto exija reescrever a entidade, o combate ou a IA.

O contrato abaixo é o que um modelo precisa entregar para **entrar trocando um
caminho de arquivo**. Quem produzir — Blender, Codex, asset comprado — segue
isto e o modelo cai no lugar.

## O custo, declarado sem rodeio

**605 sprites deixam de servir no mundo.** Eles continuam valendo em Pokédex,
HUD e menus, que são `Control` e não têm dimensão. Mas o que anda no mapa e luta
passa a ser modelo.

**A produção de modelos vira o caminho crítico do projeto**, não o código. 151
espécies com malha, rig e animação é um volume que nenhuma sessão resolve. Por
isso a arquitetura abaixo é desenhada para o jogo **funcionar sem eles**.

## A regra que torna isso tratável

```
O slice precisa de 3 Pokémon, não de 151.
Placeholder é permitido (§16).
Modelo ausente NUNCA pode quebrar o jogo — ele cai num primitivo e AVISA.
```

O "avisa" não é detalhe. Modelo faltando que aparece como cápsula silenciosa é o
mesmo zero silencioso que já mordeu este projeto três vezes: o golpe que sumia
do kit, a drenagem que não curava, a tabela de tipos com 15 dos 18. Falta de
asset tem de ser visível.

## Contrato de um modelo

| Item | Exigência | Motivo |
|---|---|---|
| Formato | `.glb` (glTF binário) | É o que o Godot importa sem plugin |
| Escala | **1 unidade = 1 metro**, altura real da Pokédex | `PokemonScale.gd` já existe e já sabe a altura por espécie |
| Origem | **nos pés**, centrado em X/Z | Origem no centro faz o bicho afundar no chão |
| Frente | eixo **−Z** | Convenção do Godot; girar no código multiplica erro |
| Malha | uma só, ou poucas | `gl_compatibility` não gosta de muitos materiais |
| Materiais | máximo 2 | idem |
| Rig | opcional no começo | Sem rig, entra parado. É pior, mas entra |
| Animações | 4 **papéis**: parado, locomoção, ataque, dano | Ver abaixo — o NOME é livre |

### O que o modelo **não** define

Colisor, hurtbox, alcance, velocidade e câmera **não vêm do modelo**. Eles são
dado (`MovementProfile`, `CombatProfile`, `CameraProfile`), porque um modelo
bonito com colisor errado é pior que um placeholder com colisor certo.

## Como a entidade carrega

```
PokemonInstance3D
  ├── visual      ← carregado por CAMINHO, vindo do dado da espécie
  ├── colisor     ← do MovementProfile, nunca do modelo
  ├── hurtbox     ← do CombatProfile
  └── (sem modelo) → primitivo colorido + aviso no log e na linha do tempo
```

Nenhum `if species_id == 6` em lugar nenhum. A §14 do pedido é explícita:
*"Não colocar comportamento inteiro dentro de scripts específicos de espécie."*

## Os três primeiros (§16)

Um terrestre, um aquático, um voador — para provar os três `MovementProfile`.
A escolha das espécies pode esperar; a arquitetura não.

## Produção

O **Blender 4.2.9 headless** já está instalado nesta VPS desde 11/09, com
pipeline de render em lote e um validador de asset (`tools/pixelart/`). Foi
construído para sprite, mas o caminho de gerar por script e conferir por régua
objetiva serve igual.

⚠️ **Lição cara daquela sessão, que vale carregar:** eu calibrei a régua de
densidade contra o tamanho errado e ela contou uma história dramática e falsa.
Ao criar régua para modelo — contagem de polígonos, escala, origem — **conferir
a régua contra um caso conhecido antes de confiar nela.**

## Ordem sugerida

1. Fase 5 anda com **primitivos** e o aviso de modelo ausente.
2. Um modelo real de teste valida o contrato inteiro.
3. Só então produção em volume — e aí é trabalho do Codex (§47), não meu.


---

## ✅ Contrato revisado (16/09) — os três primeiros modelos

Charizard (#6), Gyarados (#130) e Pidgeot (#18) entregues pelo Codex e
**aprovados**: altura exata da Pokédex (1,700 / 6,500 / 1,500 m), pés em 0,000,
animações completas.

Duas coisas que a entrega mostrou que **o contrato estava errado**, não o modelo:

### 1. O nome da animação é livre; o que importa é o papel

Eu tinha exigido `idle`, `walk`, `attack`, `hurt`. Ele entregou **sete** por
espécie, com prefixo: `PKM_CHARIZARD_IDLE`, `_WALK`, `_RUN`, `_ATTACK_01`,
`_HIT`, `_FAINT`, `_FLY`.

**A convenção dele é melhor** — o prefixo evita colisão quando várias animações
vivem na mesma biblioteca. A régua passou a casar por **sufixo**, sem diferenciar
maiúscula, com sinônimos:

| Papel | Nomes aceitos, em ordem de preferência |
|---|---|
| parado | `idle` |
| **locomoção** | `walk` · `run` · `swim` · `fly` · `move` |
| ataque | `attack` · `atk` |
| dano | `hurt` · `hit` · `damage` |

### 2. Nem todo Pokémon anda

O Gyarados não tinha `walk`, **e não deveria ter**: ele nada. O contrato
assumia que todo Pokémon caminha, o que é falso pra dois dos três arquétipos que
a §15 pede.

O papel é **locomoção**. Um modelo precisa de **uma** animação de deslocamento,
com o nome que fizer sentido pro bicho.

⚠️ **A ordem de preferência importa**, e a primeira versão errou: varrendo a
lista de animações por fora, o Charizard resolvia locomoção como `_FLY` — um
Charizard terrestre voando pra andar. Varrendo os **sinônimos** por fora,
`walk` ganha de `run`, que ganha de `swim`, que ganha de `fly`.
