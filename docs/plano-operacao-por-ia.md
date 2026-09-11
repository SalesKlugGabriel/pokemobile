# Plano de otimização — extrair o máximo da ferramenta, operando por IA

> Pedido do Gabriel, 11/09/2026. Tudo abaixo parte de **medição**, não de
> suposição: rodei cada etapa do ciclo e cronometrei antes de propor qualquer
> coisa. Onde a medida contrariou o que eu esperava, mantive a medida.

---

## 1. O ciclo de hoje, cronometrado

| Etapa | Tempo medido | Quanto disso é só o programa abrindo |
|---|---:|---|
| Blender: abrir | **4,85 s** | — |
| Blender: 4 renders de 64×64 | **0,47 s** | **91% do custo é o arranque** |
| Godot: abrir | **2,52 s** | — |
| Godot: um teste real | **1,50 s** | **63% do custo é o arranque** |
| **Suíte inteira (105 arquivos)** | **470 s** (7,8 min) | **~262 s = 56% só abrindo o Godot** |

**A conclusão não é sutil: o gargalo do ciclo não é o trabalho, é ligar a
máquina.** Um agente que gera 20 assets hoje paga 97 s de arranque de Blender
para 2,5 s de render.

## 2. O que eu testei e NÃO funcionou

Registro porque economiza o tempo de alguém tentar de novo.

**Paralelizar a suíte quase não ajuda.** Com 12 testes:

| | Tempo |
|---|---:|
| Em série | 98,6 s |
| 2 em paralelo | 82,2 s (**−17%**) |
| 4 em paralelo | 79,8 s (−19%) |

Eu esperava quase metade. Não é CPU o gargalo — é entrada/saída (o Godot
reimporta o projeto a cada abertura). E os 2 núcleos são compartilhados com
n8n, Postgres, Evolution e o jogo publicado: paralelizar disputa com produção
para ganhar 17%. **Não vale.**

---

## 3. As quatro frentes, em ordem de retorno

### Frente 1 — Matar o arranque (o maior ganho medido)

**1a. Blender em LOTE.** Um `blender --background` que renderiza N assets em vez
de um. Projeção com os números medidos, para 10 assets de 4 faces:

| | Contas | Tempo |
|---|---|---:|
| Hoje (1 processo por asset) | 10 × 4,85 + 10 × 0,47 | **53,2 s** |
| Em lote (1 processo) | 4,85 + 10 × 0,47 | **9,6 s** |
| | | **5,5× mais rápido** |

Implementação: `render_ortogonal.py` passa a aceitar `--lote arquivo.json` com
uma lista de `{cena, saida, tamanho, direcoes, escala}`.

**1b. Godot seletivo durante a iteração.** Rodar os 105 arquivos a cada mudança
custa 7,8 minutos. Durante o trabalho, rodar **só os testes afetados** (1,5 a
4 s cada); a suíte inteira **antes de commitar e antes de publicar**, que é
quando ela vale.

Implementação: `tools/rodar_testes.sh --so <padrão>` e uma regra escrita no
`AGENTS.md` sobre quando cada modo se aplica.

> ⚠️ Não mexer no que a suíte já protege: ela exige **código de saída 0 E** a
> linha de resultado impressa. Isso existe porque um teste que morre antes de
> rodar sai com 0 e não reprova — já aconteceu, e quatro testes ficaram
> vermelhos por dias sem ninguém ver.

### Frente 2 — Fechar o ponto cego: o agente não enxerga

Esta é a frente que decide se o pipeline de arte é operável por IA.

**O problema, concreto:** hoje gerei uma casa no Blender, renderizei, pixelizei.
Só descobri que estava ruim **olhando a imagem**. Um agente não faz isso de
forma confiável. Um pipeline que precisa de um humano julgando cada tentativa
não é automático — é um humano com passos a mais.

**Resolvido:** `tools/pixelart/conferir_asset.py` transforma *"parece do mesmo
jogo?"* em número, com saída 0/1 para encaixar em teste:

| Régua | O que mede | Medido no jogo |
|---|---|---|
| Distância de paleta | quão longe as cores estão das que o jogo usa | tile real: **23** · limite: 45 |
| **Densidade de detalhe** | cores distintas por pixel opaco | jogo: **0,51** · mínimo: 0,15 |
| Ocupação | quanto do quadro o sprite preenche | 10% a 95% (só para sprite) |
| Consistência entre faces | a área muda ao virar? | limite 35% |

**E ele já provou o valor invertendo meu próprio diagnóstico.** Olhando, eu
disse *"mancha marrom, a paleta está errada"*. Medindo:

```
distância de paleta    casa do Blender  30,8    tile real do jogo  23,0   ✓ ok
densidade de detalhe   casa do Blender   0,01   tiles do jogo       0,51  ✗ 50× mais chapada
```

**A paleta estava certa.** O problema era que a arte deste jogo é **densa** —
quase um tom por pixel, porque nasceu de geração procedural com ruído — e meu
pixelizador quantizou para 10 cores, achatando exatamente o que dá identidade
ao estilo.

**Eu não teria achado isso olhando. A medida achou.** É esse o argumento da
frente inteira.

**Próximos passos desta frente:**
- corrigir `pixelizar.py`: quantizar muito menos, ou não quantizar e só reduzir;
- estender a conferência a cena (`.tscn` carrega? warps batem?) e a áudio;
- ligar `conferir_asset.py` na suíte, para asset ruim reprovar como código ruim.

### Frente 3 — Contrato de tarefa entre agentes

O `AGENTS.md` já resolve *quem decide o quê*. Falta o *como se entrega*, que é
onde nasce retrabalho: asset fora de medida, sem colisão, na perspectiva errada.

```
Claude:  TASK-042 — casa 32×48, colisão 20×12, 4 faces, densidade ≥ 0,15
Codex:   gera → roda conferir_asset.py → TASK-042 READY
Claude:  godot --headless → importa → char no CHAR_MAP → PASS | REVISION_REQUIRED
```

O ganho real: **o Codex valida antes de entregar**, com a mesma régua que eu uso
para aceitar. A ida e volta some. Encaixa em `docs/agent-decisions.md`, sem
estrutura nova.

### Frente 4 — Memória do que custou caro

Três armadilhas custaram rodadas inteiras hoje, e todas já estão escritas no
código onde quem tropeça vai ler:

1. **A câmera do Blender nasce olhando para baixo.** Sem girar, ela filma o
   chão e o PNG sai **vazio, sem erro nenhum**.
2. **EEVEE não funciona sem GPU:** `EGL_BAD_MATCH`, 43 a 75 s por render de
   64×64, **e imagem vazia**. Workbench faz o mesmo em 0,01 s.
3. **Girar o objeto, não a câmera** — senão a luz muda junto e as faces saem
   inconsistentes.

O `conferir_asset.py` devolve a causa provável junto do erro: *"IMAGEM VAZIA —
no Blender isso quase sempre é a câmera não ter sido girada"*. **A ferramenta
ensina quem a usa**, que é o que permite um agente novo operar sem reler tudo.

---

## 4. Ordem de execução

| # | O quê | Ganho | Dono |
|---|---|---|---|
| 1 | ✅ **FEITO** — `pixelizar.py` corrigido | densidade 0,02 → **0,28** (passa nas réguas) | Claude |
| 2 | ✅ **FEITO** — Blender em lote | medido: **6,2×** (3 peças: 16,2 s → 2,63 s) | Claude |
| 3 | ✅ **FEITO** — `rodar_testes.sh --so <padrão>` | 470 s → **7,4 s** nos testes de combate | Claude |
| 4 | ✅ **FEITO** — conferência de arte na suíte | asset chapado reprova como código quebrado | Claude |
| 5 | Protocolo TASK-NNN | menos ida e volta | ambos |
| 6 | Modelo 3D com textura de verdade | decide se o Blender fica | **Codex** |

### Resultado dos quatro primeiros, medido

| | Antes | Depois |
|---|---:|---:|
| Densidade da peça gerada | 0,02 ✗ | **0,28** ✓ |
| 3 peças de 4 faces no Blender | 16,2 s | **2,63 s** |
| Conferir os testes de combate | 470 s | **7,4 s** |
| Arte ruim entrar no jogo | ninguém via | **reprova sozinha** |

🔴 **A correção do `pixelizar.py` inverteu duas decisões minhas**, e as duas
eram a receita clássica de pixel art:

    descer 256 → 32     NEAREST  0,09   ← era o que eu usava: o PIOR
                        BOX      0,19
                        BILINEAR 0,26
                        LANCZOS  0,44   ← alvo do jogo: 0,51

    quantizar           sem      0,19
                        48 cores 0,15
                        10 cores 0,03   ← sempre piora

NEAREST é a regra quando a FONTE já é pixel art. Aqui a fonte é um render suave,
e jogar fora a variação tonal é jogar fora justamente o que faz a peça parecer
deste jogo. **Receita certa: renderizar grande (256) e descer com LANCZOS, sem
quantizar.**

Os itens 1 a 5 são infraestrutura e são meus. **O item 6 é o que decide se todo
o resto valeu** — e é arte, não engenharia.

## 5. O que este plano NÃO resolve

- **FPS real.** Continua sem medição: o ambiente é headless, sem renderização.
  Só navegador responde. Roteiro em `docs/playtest-fase3.md`.
- **Se a arte fica bonita.** As réguas detectam *inconsistência com o jogo*, não
  beleza. Uma peça pode passar em tudo e ser sem graça.
- **O gargalo de decisão.** A maior espera hoje não é técnica: são as RFC-001 a
  005 e as 5 pendências de arte esperando decisão humana. Nenhuma otimização de
  ciclo conserta isso.

---

## 🔴 CORREÇÃO (mesmo dia) — a régua estava torta, e a conclusão caiu junto

Escrevi este plano dizendo que a medição tinha invertido meu diagnóstico e
achado o que meu olho não via. **Continuando o trabalho, descobri que a régua é
que estava errada.**

**O erro:** calibrei "densidade de detalhe" recortando o atlas em **32 px** — só
que o tile deste jogo tem **128 px**. Eu media PEDAÇOS de tile. E a densidade
**depende do tamanho da amostra**: o mesmo tile mede 0,48 em 128 px, 0,61 em
64 px, 0,74 em 16 px.

**O que cai com isso:**

| Afirmação que escrevi | Com a régua corrigida |
|---|---|
| "casa 0,01 contra 0,51 do jogo, 50× mais chapada" | casa **0,26**, mediana do jogo **0,24** — dentro da faixa |
| "NEAREST 0,09 contra LANCZOS 0,44" | NEAREST **0,42**, LANCZOS **0,46** — quase iguais |
| "quantizar sempre piora muito" | 10 cores **0,34**, sem quantizar **0,34** — quase igual |

**A medida nunca sustentou a conclusão que tirei dela.** Meu olho estava certo
sobre a casa do Blender; minha régua é que produziu uma história dramática e
falsa, e eu reescrevi o `pixelizar.py` inteiro em cima dela.

**O que fica de pé:**

- A régua agora mede num **tamanho canônico** (64 px) e é estável.
- Recalibrada contra 40 tiles reais: mediana **0,24**, faixa 0,00 a 0,84. O
  piso do validador caiu de 0,15 para **0,06** — pega peça extraordinariamente
  lisa, não peça "menos texturizada que a média".
- LANCZOS continua no `pixelizar.py`, mas pelo motivo certo e modesto: é
  marginalmente melhor para reduzir uma fonte SUAVE. Não pelos 5× que eu disse.
- O validador **serve** para o que é objetivo: cor fora da paleta, imagem
  vazia, tamanho errado, faces inconsistentes. Ele **não** julga se a peça está
  bonita, e eu tratei como se julgasse.

**A lição não é "não meça".** É: **calibre a régua contra a coisa certa, e
desconfie quando ela contar uma história boa demais.** Uma medição que confirma
dramaticamente o que você já achava é o momento de reconferir, não de publicar.

*(Onde a régua corrigida provou valor de verdade: os 8 tiles do fundo do mar
que gerei em seguida. Três reprovaram por ficarem lisos demais, tiveram o
granulado aumentado e passaram. Aí ela pegou um problema real que eu não tinha
visto.)*

