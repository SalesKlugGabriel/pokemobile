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
| Animações | `idle`, `walk`, `attack`, `hurt` | Os quatro estados mínimos que o combate produz |

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
