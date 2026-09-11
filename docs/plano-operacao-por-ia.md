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
| 1 | Corrigir `pixelizar.py` (quantização achatou a arte) | desbloqueia o pipeline | Claude |
| 2 | Blender em lote | **5,5×** na geração | Claude |
| 3 | Godot seletivo na iteração | 7,8 min → segundos | Claude |
| 4 | `conferir_asset.py` na suíte | asset ruim reprova sozinho | Claude |
| 5 | Protocolo TASK-NNN | menos ida e volta | ambos |
| 6 | Modelo 3D com textura de verdade | decide se o Blender fica | **Codex** |

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
