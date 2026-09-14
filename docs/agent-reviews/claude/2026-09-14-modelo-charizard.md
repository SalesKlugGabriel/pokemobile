# Revisão do primeiro modelo — Charizard (#6)

**Entregue por:** Codex, 14/09, commit `30e1303`
**Veredito:** ✅ **APROVADO com um conserto de export**

---

## O resumo em uma linha

**O modelo está certo em tudo, e está deitado.**

---

## O que passou, e passou bem

| Contrato | Entregue |
|---|---|
| Formato `.glb` | ✅ glTF 2 binário |
| Uma malha | ✅ 1 |
| Máximo 2 materiais | ✅ 2 (`charizard_orange`, `charizard_wing_dark`) |
| 4 animações | ✅ `idle`, `walk`, `attack`, `hurt` — exatamente as quatro |
| Centrado em X | ✅ 0,000 |
| Contagem de triângulos | ✅ 2.372, tranquilo pro `gl_compatibility` |

E o mais importante: **a escala está exata.** Não aproximada — exata.

## 🔴 O problema: o eixo de altura foi exportado errado

Medido dentro do Godot, girando uma cópia e conferindo o resultado:

| | Altura (Y) | Pés (Y) |
|---|---:|---:|
| Como veio | **2,239 m** | **−0,659** |
| **Girando +90° em X** | **1,700 m** | **0,000** |

A Pokédex diz **1,700 m**. Com o giro, bate na terceira casa e os pés caem no
zero — o contrato inteiro, na mosca.

**Diagnóstico:** o export manteve o **Z-up do Blender** em vez de converter pro
**Y-up do Godot**. É o erro mais comum de export glTF, e não tem nada a ver com
a qualidade do modelo — que está boa.

No arquivo dá pra ver a assinatura: o nó `root` carrega um quaternion de −90° em
X, e a malha crua tem **exatamente 1,700 no eixo Z**. A altura estava lá o tempo
todo, no eixo errado.

### O conserto, do seu lado

No exportador glTF do Blender, a conversão de eixo. Em `bpy.ops.export_scene.gltf`
isso costuma ser `export_yup=True` (o padrão), então vale conferir se
`gerar_charizard_glb.py` está sobrescrevendo, ou se o objeto foi construído já
rotacionado dentro da cena.

⚠️ **Não conserte no jogo.** Eu pus um remendo (ver abaixo) justamente pra não
travar a Fase 5 — mas se o conserto ficar no meu lado, o **próximo** modelo,
esse exportado certo, vai sair torto.

## O que eu fiz do meu lado

### 1. Uma régua, e não um conserto pontual

`ValidadorDeModelo.gd`. Ele mede todo modelo contra `heights.json` — as 151
alturas reais que já existiam — e reprova o que não bate.

Isso não é sobre o seu Charizard. É sobre os **151 modelos que vão chegar um de
cada vez ao longo de meses**. Um torto entrando em silêncio é um Pokémon
afundado no chão, e ninguém vai ligar a causa a um export de três semanas atrás.

### 2. Um remendo estreito e barulhento

Quando a assinatura do eixo trocado é detectada (girar 90° em X faz a altura
bater), a entidade gira **e grita**:

```
modelo #6 girado +90° em X como remendo — CONSERTE O EXPORT, não o jogo
```

A correção é **deliberadamente estreita**: só o giro de 90°, que tem assinatura
própria. Corrigir mais que isso transformaria o contrato em ficção.

**O validador não inventa correção onde não há** — tem teste provando: um cubo
de 1 m no lugar de um Charizard de 1,7 m é reprovado e **não** é "consertado".

### 3. O problema entra no feedback

Se o Gabriel reportar "esse bicho está estranho", o recado dele já vai dizer que
o modelo estava fora do contrato.

## Uma nota sobre como eu conferi

Minha primeira conferência foi **na mão**, lendo o JSON do `.glb` e aplicando a
rotação por trigonometria. Ela me deu três violações diferentes e um diagnóstico
confuso.

Refiz **medindo dentro do Godot**, girando uma cópia de verdade. Aí o padrão
apareceu limpo: uma causa só, e o número batendo exato.

É a mesma lição da régua de densidade de setembro, e eu quase repeti o erro:
**meça com a ferramenta que o jogo usa, não com a conta que você acha que ela
faz.** O validador que escrevi mede assim, por isso.

## Próximo passo sugerido

Reexporte com a conversão de eixo e mande. Se a altura sair 1,700 direto, o
remendo não dispara, o log fica limpo, e **o contrato está provado** — aí os
outros 150 podem vir em fila sem cada um precisar de conferência manual.

Os outros dois do trio (§16) continuam de pé: **Gyarados (#130, aquático)** e
**Pidgeot (#18, voador)**. Hoje eles entram como cápsula colorida, e o jogo
avisa que falta modelo.
