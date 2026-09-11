# Checklist de playtest — Fase 3 do combate

> **Por que este documento existe.** Tudo que validei até aqui foi **headless**:
> sem renderização, sem toque, sem animação, sem GPU. Isso prova fórmula, regra e
> custo de CPU — e **não prova nada** sobre FPS real, legibilidade, alvo de toque,
> ou se a barra de 8 botões cabe num celular em pé.
>
> O pedido foi explícito: *"não alegar 60 FPS com base apenas em teste headless"*.
> Não vou alegar. Este arquivo é o que falta medir **no jogo rodando**.
>
> Divisão: o que é **estado/regra** é meu (Claude) para corrigir; o que é
> **layout/leitura/toque** vai para o Codex, via `docs/rfc/` — ver RFC-001.

---

## Como rodar

O jogo está publicado em **https://poke.workprog.pro**. Para ver FPS real:

- **Desktop (Chrome/Edge):** F12 → ⋮ → *More tools* → *Rendering* → marcar
  **Frame Rendering Stats**. Mostra FPS e frame time no canto.
- **Celular:** não há contador embutido. O sinal utilizável é qualitativo —
  travadas perceptíveis, atraso entre o toque e o golpe sair, animação picotando.
  Anotar **onde** aconteceu (mapa, quantos bichos na tela).

Marcar cada item: ✅ passou · ⚠️ passou com ressalva · ❌ falhou.
Para ❌ e ⚠️, anotar **o que apareceu na tela**, não o diagnóstico.

---

## 1. Slots — 4 a 8 (o coração desta fase)

Precisa de um Pokémon de cada capacidade. O caminho rápido é testar com o time
que já existe e observar a barra mudar ao subir de nível/evoluir.

| Capacidade | Como conseguir | O que observar |
|---|---|---|
| 4 slots | qualquer inicial abaixo do Lv.50 | 4 botões, nada sobrando |
| 5 slots | inicial no Lv.50+, **ou** primeira evolução abaixo do Lv.50 | o 5º botão aparece |
| 6 slots | forma final abaixo do Lv.50, **ou** inicial no Lv.100 | |
| 7 slots | primeira evolução no Lv.50+ | **a barra ainda cabe?** |
| 8 slots | forma final no Lv.100 | **o alvo de toque ainda é usável?** |

- [ ] A barra **muda sozinha** ao subir de nível (sem sair e voltar do mapa)
- [ ] A barra **muda sozinha** ao evoluir
- [ ] Slot vazio (desequipado) e slot inexistente parecem **coisas diferentes**
- [ ] Com 8 slots, dá pra acertar o botão certo **no celular, em pé**
- [ ] Com 8 slots, a barra **não cobre** o Pokémon nem a barra de vida

## 2. Entrada (teclado e toque)

- [ ] Teclas **1 a 8** disparam os slots 1 a 8
- [ ] Os **botões da tela** disparam o mesmo golpe que a tecla
- [ ] Remapear `skill_5` a `skill_8` nos controles funciona e **persiste**
- [ ] Nenhuma das teclas novas conflita com atalho existente
- [ ] No celular, a **ponte de toque** do export continua funcionando

## 3. Recarga

🔴 **Corrigido nesta sessão, precisa de confirmação visual.** A barra era
normalizada pelo cooldown cru do JSON enquanto o contador usava a recarga real
(reduzida por velocidade/itens): Thunderbolt **nascia em 33%**.

- [ ] A barra de recarga começa **vazia** (0%), não pela metade
- [ ] Ela enche **suave** até 100% e o botão reabilita no fim
- [ ] Um Pokémon **rápido** recarrega visivelmente mais rápido
- [ ] Com item de recarga equipado, idem

## 4. Telegraph, área e empurrão

- [ ] O círculo do telegraph aparece **antes** do dano
- [ ] Sair do círculo a tempo **realmente evita** o dano
- [ ] **Surf** varre uma **linha** na direção da mira, não um círculo
- [ ] **Tornado** abre um **cone** à frente
- [ ] **Earthquake** e **Blizzard** são círculos
- [ ] O empurrão do Tornado joga o alvo pra trás
- [ ] O empurrão **para na parede** — não atravessa pedra, árvore nem água

## 5. Status e precisão

- [ ] Blizzard (70 de precisão) **erra às vezes**, e aparece "Errou!"
- [ ] Um golpe **imune** mostra "não afeta!" e **não** aplica status
- [ ] Queimadura/veneno tiram vida ao longo do tempo, sem travar o jogo
- [ ] O rótulo de status (BRN/PSN/PAR…) aparece sobre o bicho certo

## 6. IA selvagem

- [ ] Um bicho **passivo** não ataca sem motivo
- [ ] Um **agressivo** parte pra cima ao chegar perto
- [ ] Levar um golpe faz o bicho **priorizar quem bateu**
- [ ] O bicho **desiste e volta pra casa** se você correr o bastante
- [ ] Voltando pra casa, ele **recupera vida**
- [ ] Um bicho de longe usa golpe de longe; de perto, o forte de perto

## 7. Bando

- [ ] Um Beedrill ataca e os vizinhos da **mesma espécie** respondem
- [ ] Eles chegam **em onda**, não todos no mesmo instante
- [ ] No máximo **5** respondem, mesmo com mais na tela
- [ ] O mapa inteiro **não** acorda (a corrente para em 1 salto)
- [ ] Dá pra **fugir** de um bando de 5 — difícil, não impossível

## 8. Alpha e chefe

- [ ] Um Alpha **dura menos** e **machuca mais** que na versão anterior
- [ ] O chefe usa **golpes de Pokémon** além das funções de encontro
- [ ] Depois de uma função pesada, aparece **"Exposto!"**
- [ ] Bater durante a janela **tira visivelmente mais vida**
- [ ] A luta de chefe fecha em **~2,5 a 3 minutos** bem jogada
- [ ] O enrage **não** dispara em toda luta — só quando você demora

## 9. Stress (o item que o headless não responde)

Cenário: ir para uma área de spawn denso, deixar acumular **o máximo de
selvagens na tela**, com o time ativo perto, e usar golpes de área em sequência.

| Medida | Desktop | Celular |
|---|---|---|
| FPS em exploração normal | | |
| FPS com ~20 selvagens na tela | | |
| FPS com o máximo de selvagens | | |
| FPS durante 2 golpes de área seguidos | | |
| Atraso entre tocar o botão e o golpe sair | | |

- [ ] Sem travada perceptível ao entrar num mapa novo
- [ ] Sem travada ao vários bichos entrarem em combate juntos
- [ ] As barras de vida acompanham o dano sem atraso
- [ ] Nada de acúmulo: depois de 10 minutos, o jogo continua igual

**Referência headless (não é FPS):** a lógica de combate de um segundo cheio —
60 selvagens decidindo 5×/s, 30 golpes simples, 6 de área, 65 tiques de status —
custou **5.428 µs de CPU**, 0,54% de um núcleo. Se o jogo cair de FPS, o gargalo
**quase certamente não é o combate**: é desenho, sprite, TileMap ou shader.
Isso é informação pro Codex, não uma defesa minha.

---

## O que fazer com o resultado

| Tipo de problema | Para quem | Onde registrar |
|---|---|---|
| Número errado, regra errada, IA burra, save | Claude | direto, com o que apareceu na tela |
| Layout, leitura, alvo de toque, animação, FPS de desenho | Codex | `docs/rfc/` ou o handoff |
| Não está claro de quem é | qualquer um | `docs/agent-handoff.md`, que o outro lê |

Um item ❌ com descrição do que apareceu na tela vale mais que dez ✅.
