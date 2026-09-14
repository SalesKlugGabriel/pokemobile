# Para o Codex — a leitura do combate (14/09/2026)

Pedido do Gabriel, nas palavras dele:

> *"Precisamos colocar animações para esses 108 golpes que não são visíveis para
> que em combate seja possível saber o que aconteceu e não apenas receber um
> dano sem saber de onde veio, tem golpe que pode dar até 4x de dano e isso
> simplesmente baixar a barra de HP sem nenhum feedback visual vai frustrar
> muito a gameplay"*

Antes de dividir o trabalho, **duas correções de diagnóstico** — as duas minhas.

---

## 1. O problema NÃO é cast time. É que a informação nunca chegava em você.

Eu tinha avisado "108 golpes sem janela de leitura". Verdade no número,
enganoso no sentido. Medido:

| Poder | Golpes | Sem janela |
|---|---:|---:|
| 1–39 | 21 | 21 |
| 40–69 | 37 | 12 |
| **70–99** | 38 | **0** |
| **100–129** | 14 | **0** |
| **130+** | 7 | **0** |

**O golpe mais forte entre os 108 instantâneos tem poder 40.** Todo golpe que
machuca já telegrafa. O dado está bem desenhado — soco rápido sai na hora,
golpe pesado avisa. Eu pintei um problema com a forma errada, desculpa.

**O problema real é outro, e é meu:** o sinal que você escuta era

```gdscript
damage_dealt(target, amount, is_critical, attacker)
```

Ele **não diz qual golpe, de que tipo, nem se foi super-efetivo**. A única coisa
que o `FeedbackDeImpacto` conseguia deduzir era a fração da vida — por isso um
**4× e um golpe neutro grande produziam exatamente a mesma coisa na tela**.

Não era falta de capricho seu. A informação nunca saía do gameplay.

## 2. Prioridade: decidida, e some

O Gabriel fechou: *"nenhum golpe tem prioridade, tendo o cooldown disponível,
pode ser utilizado"*. Os 6 golpes que tinham `priority != 0` foram zerados, e um
teste trava isso. Prioridade é conceito de combate por turno — em tempo real não
existe "mesmo turno", e a recarga é a única fila que existe.

---

## O que EU fiz (pronto, testado, no `main`)

### `EventBus.golpe_resolvido(relatorio)` — o relatório completo de um acerto

`damage_dealt` **continua existindo, com a mesma assinatura** (D-001, você
pediu). Este vem ao lado.

```gdscript
{
  # Quem e o quê
  "golpe": "thunderbolt", "nome_do_golpe": "Thunderbolt",
  "tipo": "Electric", "categoria": "special",
  "area_type": "circle", "contato": false,
  "atacante_id": 123, "alvo_id": 456,

  # Onde — pra você saber de ONDE veio, literalmente
  "origem": Vector2, "destino": Vector2, "direcao": Vector2,

  # Quanto, e o que isso significa
  "dano": 120,
  "fracao_da_vida": 0.6,          # já dividido; você não recalcula
  "vida_depois": 30, "vida_maxima": 200,
  "mult_tipo": 4.0,
  "efetividade": "muito_forte",   # imune / muito_fraco / fraco / neutro / forte / muito_forte
  "frase": "É devastador!",
  "stab": true,
  "derrotou": false,
  "teve_aviso": false,            # false = instantâneo, a leitura é TODA no impacto
}
```

### `EventBus.status_aplicado(relatorio)`

Ficar paralisado sem saber por quê é a mesma frustração do dano sem origem, em
outra forma. Traz `status`, `golpe`, `tipo`, `origem`, `destino` e os dois ids.

### Por que a classificação vem pronta

`efetividade` é **string**, não `float`. Você não compara `mult == 0.25` nem se
preocupa com arredondamento — quem calculou é quem classifica. E as faixas são
generosas de propósito: um Held pode empurrar 2× pra 2,2× (§46), e isso continua
sendo `"forte"`.

`frase` já vem em português e vazia no neutro — golpe neutro não precisa de
aviso, e encher a tela de texto em todo acerto mata o destaque do que importa.

---

## O que é SEU

**Tudo que se vê.** Eu digo *o que aconteceu*; você decide *como se vê*.

### 1. O impacto, com peso proporcional ao que foi (prioridade alta)

Os 108 instantâneos não têm janela ANTES — então **toda a leitura precisa
acontecer no impacto**. É aqui que o pedido do Gabriel se resolve.

Sugestões, não decisões (o campo `efetividade` é o gancho):

| efetividade | ideia |
|---|---|
| `muito_forte` (4×) | tratamento máximo — número grande, cor forte, tremor, congelamento de quadro, a frase "É devastador!" |
| `forte` (2×) | claramente acima do normal |
| `neutro` | o impacto discreto de hoje |
| `fraco` / `muito_fraco` | número apagado, som abafado, sem tremor |
| `imune` | **nada de número** — "Não afeta!" e só. Um zero flutuando parece bug |

`derrotou: true` merece um momento próprio: é o fim de uma luta de ~18 s.

### 2. A cor do golpe pelo TIPO

`tipo` vem no relatório. Fogo, Água e Elétrico com a mesma partícula cinza é
outra forma de "não sei o que me acertou".

### 3. `origem` e `direcao` — de ONDE veio

Uma seta, um rastro, um risco de impacto orientado. Numa briga com 3 selvagens
e um Alpha, saber de qual deles veio o golpe é metade da leitura.

### 4. Status visível

`status_aplicado` traz a origem. Um ícone que nasce em quem lançou e viaja até
quem recebeu explica a paralisia sem nenhuma palavra.

### 5. O que NÃO fazer

- **Não recalcular efetividade.** Ela vem classificada. Se comparar `mult_tipo`
  por conta, vamos ter duas contas e elas vão divergir num ajuste de Held.
- **Não animar cada tick de veneno com o tratamento de um acerto.** Dano
  contínuo vira ruído se receber o mesmo peso — hoje ele nem passa por este
  sinal.
- **Não atrasar o dano pra a animação caber.** O dano já aconteceu quando o
  sinal chega. Se precisar de mais tempo de leitura num golpe específico, peça
  `cast_time` — isso é regra de combate, é meu, e eu ajusto o dado.

---

## Onde isto vale hoje, e onde não

⚠️ **Só na Gameplay V2** (`CombatenteV2` e o ataque básico do `PokemonAtivoV2`).

A V1 continua emitindo só `damage_dealt`. Foi decisão consciente: a V1 está
sendo substituída, e emitir o relatório nos 3 pontos de dano dela seria trabalho
num motor que vai sair. **Se você preferir que eu faça, eu faço** — diga.

---

## Suas tarefas, na ordem que eu faria

1. **O export web de teste do Laboratório.** Você reivindicou, e é o que
   destrava o Gabriel pra jogar. Os testes de gameplay estão verdes: 111
   arquivos, 0 falhas.
2. **O impacto com peso por efetividade** — resolve o pedido desta rodada.
3. HUD e câmera, que você já tem commitadas na branch.

⚠️ Lembrete do `AGENTS.md`: **não rode `tools/rodar_testes.sh` com outro
`godot4` rodando** (`ps aux | grep godot4`). Duas suítes em 2 núcleos estouram o
corte de 300 s e produzem reprovação falsa. Já aconteceu uma vez.
