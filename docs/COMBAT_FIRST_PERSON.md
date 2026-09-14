# Combate em primeira pessoa

> Parte da [Gameplay V3](GAMEPLAY_V3.md). Estado: **proposta**, nada implementado.

## A inversão

Na V2 o jogador **manda** o Pokémon atacar (`MesaDeComandos`: atacar, ir,
seguir, manter, recuar). Na V3 ele **é** o Pokémon, em primeira pessoa.

É a mudança mais profunda do pivô, e ela aposenta a mesa de comandos como peça
central. O que não muda: **combate 1v1, no próprio terreno, sem arena**. O
treinador continua no mundo enquanto você luta.

## O ciclo

```
WORLD (3ª pessoa, treinador)
   │  encontro
   ▼
transferência ── câmera move pro Pokémon, input troca de dono
   │
   ▼
COMBAT (1ª pessoa, Pokémon)   ← o coração da fantasia
   │  vitória, derrota ou fuga
   ▼
volta ao treinador
```

A transferência (Fase 7) e a volta (Fase 13) são o que precisa ser provado
primeiro. Um combate bom que não devolve o controle direito quebra a fantasia
inteira.

## Input (§18)

`LMB` ataque básico · `Q` `E` `R` `F` as 4 skills · `WASD` movimento ·
mouse para câmera e mira. **Tudo no `InputMap`**, nunca cravado.

`ControlModeManager` é o único árbitro: um modo ativo por vez. Quem não está
ativo tem o processamento de input **desligado** — não basta ignorar o evento,
porque "ignorar" é onde nascem dois controladores reagindo ao mesmo botão.

## Mira e acerto (§22)

**Sem RNG de precisão.** Se a geometria acertou, é acerto; se não, é erro.

Isto **já é a regra da V2** — `FormaDeArea` resolve por geometria e `DanoV2` é
determinístico (sem crítico, sem variância). Nenhuma fórmula muda no pivô. O que
muda é o instrumento: `RayCast3D`, `ShapeCast3D`, `Area3D` ou projétil, conforme
a natureza da skill.

**Hitbox de ataque e hurtbox do Pokémon continuam separadas** — já eram.

## Câmera por espécie (§19)

`CameraProfile`: altura, FOV, pitch, yaw, offset, sensibilidade, clipping.

Um Onix e um Rattata não podem usar a mesma altura de câmera. Mas a prioridade é
**jogabilidade acima de anatomia perfeita**: se a cabeça anatomicamente correta
produz uma câmera ruim, a câmera ganha.

## As 4 primeiras skills (§21)

Uma melee, uma projétil, uma de área e uma de suporte/drenagem. Quatro bastam
pra provar a arquitetura, e `moves.json` já tem as quatro categorias com
`area_type`, `range`, `cooldown` e `cast_time` — **o dado não precisa mudar**.

## O que vem pronto da V2

Dano determinístico, STAB 1,25/1,15, tabela de tipos completa (18 tipos desde
14/09), livro de efeitos com saldo líquido e imunidade de 1 s, regeneração fora
de combate, drenagem pelo dano real, XP por dano causado, corpo com uma
tentativa de captura, Alpha, lendário, kit por nível e evolução.

E os contratos de leitura: `golpe_resolvido` e `status_aplicado` levam tipo,
origem, direção, fração da vida e a **efetividade já classificada em palavra** —
feitos pra a tela nunca refazer a conta. Valem igual em 3D, com `Vector3`.

## O que precisa ser construído

`PokemonCombatController` (1ª pessoa), `PokemonInstance3D` (corpo, colisor,
hurtbox), hitbox 3D, projétil 3D, e a transferência de controle.

## Critério

Dá pra lutar, ganhar, perder e **voltar a ser o treinador** — sem travar, sem
perder o controle e sem a câmera se perder no meio.

---

# A transferência de controle (Fase 7) — desenho

> Escrito em 14/09, antes de implementar. É **o coração da fantasia**, e a peça
> que os jogos costumam errar não é a ida: é a volta.

## O que precisa acontecer, em ordem

```
WORLD                          COMBAT
  treinador tem input            Pokémon tem input
  câmera 3ª pessoa nele          câmera 1ª pessoa nos olhos dele
  companheiro o segue            companheiro deixa de seguir
  ────────────────────────────►
                    transferência
  ◄────────────────────────────
                       volta
```

## Os quatro problemas que este desenho resolve

### 1. Nunca dois donos do input, nem por um quadro

Já resolvido pelo `ControlModeManager` (§12) e já provado por teste: ele
**desliga** quem não está ativo em vez de pedir que se comporte, e desliga todo
mundo **antes** de ligar o novo. Um quadro com dois donos basta pra um passo
duplo aparecer na tela.

### 2. A câmera não pode ser destruída e recriada (§13)

As duas câmeras **existem o tempo todo**. A troca é de `current`, com uma
interpolação entre as duas poses — destruir e recriar perde o estado e produz
o corte seco que a §13 proíbe.

### 3. Para onde a câmera olha quando você volta

O problema fino. Três opções, e a escolha muda como a volta *sente*:

| Opção | Efeito |
|---|---|
| Voltar pro yaw que o treinador tinha | Você volta olhando pro lado errado se a luta girou |
| Herdar o yaw do Pokémon | Continuidade de direção — você volta olhando pra onde estava lutando |
| Apontar pro Pokémon | Bom pra ver quem lutou, ruim pra continuar andando |

**Escolha: herdar o yaw do Pokémon.** A luta gira o jogador; devolvê-lo virado
pra trás é desorientação gratuita. Continuidade de direção é o que faz a volta
parecer um mesmo movimento, e não duas cenas coladas.

### 4. O Pokémon cai no meio da luta

A §4 é clara: sem Pokémon em pé, **o treinador fica vulnerável**. Então a queda
do Pokémon **devolve o controle automaticamente** — não é escolha do jogador, é
consequência. É o que dá peso a estar sem ninguém fora da ball.

## O que é preservado na troca

| | |
|---|---|
| Treinador | posição, física **ligada**, vida, stamina — ele permanece no mundo (§17) |
| Treinador | intenção **zerada** — senão ele anda pra sempre na última direção |
| Pokémon | vida, efeitos, recargas — a luta continua de onde estava |
| Companheiro | deixa de seguir enquanto é controlado; volta a seguir depois |
| Câmera | yaw herdado nos dois sentidos |

## O contrato que a apresentação recebe

```gdscript
transferencia_iniciada(de: String, para: String, alvo_id: int)
transferencia_concluida(modo: String)
```

O Codex decide a duração, a curva e o efeito da transição. Eu digo **quando** e
**entre quem** — mesma fronteira da D-003, que funcionou.

## O critério

A §51, itens 8 a 11: assumir o Pokémon, lutar em 1ª pessoa, encerrar, **voltar a
ser o treinador**. Sem travar, sem perder o controle, e sem a câmera se perder
no meio.
