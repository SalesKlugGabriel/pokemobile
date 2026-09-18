# QUADRO — PokéMobile

> **Comece por aqui.** Este é o **estado**: o que está feito, o que falta, e de
> quem é cada coisa. `GAMEPLAY_V3.md` é o painel detalhado da migração e as RFCs
> são o desenho; **em caso de divergência, o quadro ganha.**
>
> Regra em `/root/memoria/padrao-agentes.md`, seção 4. Quem fecha uma sprint
> atualiza este arquivo **na mesma sessão**, antes de commitar.

**Estado em:** 17/09/2026
**Branch do Claude:** `agent/claude-v3`
**Suíte:** `bash tools/rodar_testes.sh` — **117 arquivos, 0 com falha**

---

## A direção, em uma frase

> *"Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
> controle do meu Pokémon."*

3D, terceira pessoa no mundo, **primeira pessoa no combate**, 1v1 no próprio
terreno, sem arena. O treinador continua no mundo enquanto você luta.

**Nada da V2 é apagado** nesta migração. As 120 cenas 2D, os tilesets e o
`MapLayouts` ficam no repositório mesmo depreciados, até a V3 substituir de
verdade.

---

## As 20 fases

| # | Fase | Estado |
|---|---|---|
| 0–8 | Auditoria, RFCs, cena 3D, treinador, terreno, Pokémon 3D, companheiro, transferência, 1ª pessoa | ✅ 14/09 |
| 9 | **Ataque básico** | ✅ 17/09 · 50 conferências |
| 10 | **4 skills** (single/circle/cone/line, aviso, drenagem) | ✅ 17/09 · 61 conferências |
| 11 | **Wild Pokémon** | ✅ 17/09 · `RegraDeSpawn` + `IASelvagem3D` + `SpawnerSelvagem3D` · 63 conferências |
| 12 | Combate 1v1 | 🔵 **próxima** |
| 13 | Combate → Mundo | ⬜ |
| 14–15 | Surf · Fly | ⬜ |
| 16–18 | TM/HM · Move Pool · Alpha | ⬜ · as regras já existem na V2 |
| 19 | **Polimento** | ⬜ · **o Codex entra aqui** |
| 20 | Performance | ⬜ |

**Não pular fase.** A ordem existe porque cada uma depende da anterior estar de
pé — e porque pular é como se constrói seis sistemas pela metade.

---

## ✅ O bloqueio da Fase 11 caiu — contrato de nascimento

O sintoma era dois Pokémon parados a 1,2 m se deslocando sozinhos (1,264 m em um
quadro, velocidade zero, determinístico). **A causa não era colisor.**

Instrumentando `move_and_slide`, a colisão saiu com normal `(0,1,0)`: o Charizard
**pousava** no Rattata. Um `CharacterBody3D` passa um quadro de física com o
colisor onde nasceu, antes de o servidor acompanhar um `global_position`
atribuído depois do `add_child` — e quando o colisor salta pro lugar certo, o
Godot **carrega** quem está em pé nele.

```
posição ANTES  do add_child   0,000 m
posição DEPOIS do add_child   1,265 m
```

E o corpo de ordem errada nasce na **origem do mundo**, não perto do destino:
catapulta quem estiver na origem, a qualquer distância.

**Conserto:** `PokemonInstance3D.nascer(pai, especie, nivel, posicao, arquetipo)`
— uma porta só, posição antes da árvore — mais um detector que avisa (não
corrige) quando alguém erra a ordem. Travado por `teste_nascimento_v3.gd`, que
confere os dois sentidos.

⚠️ **Todo spawn da Fase 11 em diante usa `nascer()`.** `new()` + `add_child()` +
posicionar é o caminho que catapulta o jogador.

## 🔵 Pendente — Claude (gameplay, regras, IA, save, dados, testes lógicos)

| # | O quê | Bloqueado? |
|---|---|---|
| 1 | Fase 12 — Combate 1v1 | não — **é a próxima** |
| 2 | Fases 13 a 18, na ordem | sim, em cadeia |
| 3 | Ajuste de *sensação* dos controles | **sim** — depende do item 🟡 1 |

---

## 🟣 Pendente — Codex (HUD, câmera, sprites, modelos, animação, efeitos)

| # | O quê | Quando |
|---|---|---|
| 0 | 🔴 **PLAYER 3D V1** — o modelo definitivo do treinador, pedido do Gabriel com folha de concept art | **prioridade** · `docs/agent-proposals/gabriel/2026-09-18-player-3d-v1.md` |
| 0b | 🔴 **WORLD FACTORY V1** — fábrica determinística de mundo (terreno, biomas, rochas, árvores, caminhos). **Começa por auditoria, não por asset** | `docs/agent-proposals/gabriel/2026-09-18-world-factory-v1.md` |
| 1 | **Qualidade gráfica do mundo 3D** — terreno, vegetação, árvores, grama, água | agora, em paralelo |
| 2 | Modelos de Pokémon em volume | agora · contrato em `POKEMON_MODEL_PIPELINE.md` |
| 3 | HUD de combate: cooldown do básico e das 4 skills, telegrafe do aviso | quando quiser — a API já entrega tudo (ver abaixo) |
| 4 | Polimento geral | Fase 19 |

### ⚠️ O que o Claude entregou e o Codex pode consumir já

| O quê | Onde |
|---|---|
| **Cooldown do básico** | `PokemonInstance3D.basico_pronto()` e `basico_esfriando()` — em segundos, prontos |
| **Cooldown de uma skill** | `skill_esfriando(indice)` |
| **Por que o botão não respondeu** | `usar_skill()` devolve `{"recusado": motivo}` com o motivo **em português** |
| **O telegrafe do aviso** | sinal `EventBus.skill_anunciada` — traz forma, alcance, raio, largura, direção travada e quando resolve, **tudo em metros e já calculado** |
| **Apagar o telegrafe** | sinal `EventBus.skill_cancelada` — sai quando quem anunciava cai no meio |
| **O relatório de um acerto em 3D** | `EventBus.golpe_resolvido` — tipo, efetividade **como palavra**, frase, fração da vida, direção em `Vector3` |

**A tela não recalcula nada disso.** Se faltar um número, o Codex **descreve o
dado** e o Claude implementa com fonte e confiança declaradas — a conta acontece
no backend, nunca na tela.

### 🔴 A pergunta que trava as DUAS tarefas novas: qual é a altura do player?

| Fonte | Diz |
|---|---|
| A folha de concept art do Gabriel (18/09) | **1,60 m** |
| `TrainerController3D` (cápsula e malha) | **1,75 m** |
| O `player.glb` de 14–15/09, medido | **1,750 m** |

A altura do player é o **denominador de tudo**: árvore de 8 m, pedra de 50 cm,
largura de caminho, altura de caverna, enquadramento de câmera. Escolher errado
obriga a refazer a fábrica de mundo inteira.

**Pergunte ao Gabriel antes da FASE 1 das duas tarefas.** E, decidido, **o código
muda junto** — ninguém tinha notado a divergência até 18/09.

### ⚠️ Sobre o PLAYER 3D V1, antes de começar

- **A folha de referência não está no repositório** — foi enviada na conversa e não
  chegou ao disco da VPS. **Peça ao Gabriel** antes da FASE 1.
- Já existe `assets/models/trainer/player.glb` (seu, 14–15/09), e **nada no jogo o
  carrega** — conferido por `git grep` em todas as branches. O treinador em cena é
  uma **cápsula amarela** montada em código. O player_v1 não substitui nada: ele é
  o primeiro a entrar de verdade.
- 🔴 **Frente no −Z.** Desde 18/09 o corpo do treinador **encara a mira do mouse**.
  Um modelo apontando pra +Z aparece andando de costas o tempo todo — que é
  exatamente a queixa que acabou de ser resolvida.
- Origem **nos pés**, 1 unidade = 1 metro. O primeiro Charizard veio deitado por
  Z-up não convertido; o `ValidadorDeModelo` pegou, e a régua continua valendo.

### Modelos: o contrato mudou por causa da entrega dele, e ele estava certo

- O **nome** da animação é livre; o que importa é o **papel** (parado, locomoção,
  ataque, dano). A convenção de prefixo por espécie do Codex é melhor e foi
  adotada.
- **Nem todo Pokémon anda.** O Gyarados nada, e não deveria ter `walk`. O papel é
  **locomoção** — uma animação de deslocamento, com o nome que fizer sentido.
- Modelos entregues e aprovados: **#6 Charizard, #18 Pidgeot, #130 Gyarados**.
  Qualquer outra espécie cai no primitivo **e avisa** (nunca cápsula silenciosa).

---

## 🟡 Pendente — Gabriel

| # | O quê | Por quê |
|---|---|---|
| 1 | **Qual aspecto dos controles incomoda** | "melhorar os controles" são **seis** ajustes diferentes: velocidade, sensibilidade do mouse, aceleração, atrito, virada do personagem, distância da câmera. Mexer nos seis de uma vez faz ninguém saber qual melhorou |
| 2 | Jogar a V3 depois do conserto de direção (17/09) e dizer se o W agora anda pra onde se olha | o teste prova direção e independência da câmera; **não prova sensação** |

---

## 📌 Decisões que valem, e o porquê de cada uma

| Decisão | Por quê |
|---|---|
| **Pokémon são modelos 3D**, não sprites | Gabriel, 14/09. 605 sprites seguem valendo em Pokédex, HUD e menus — `Control` não tem dimensão |
| **Regra fora do nó.** As classes de regra são `RefCounted` puras | É o que fez o pivô pra 3D ser possível: 18 das 42 classes de combate não sabiam se o jogo era 2D ou 3D |
| **Um dono de input por vez**, e quem não está ativo tem o processamento **desligado** | Ignorar o evento não basta — é assim que nascem dois controladores reagindo ao mesmo botão (§12) |
| **Sem RNG de precisão no combate** | Se a geometria acertou, é acerto. É o que faz o combate parecer habilidade em vez de sorte (§22) |
| **O ataque básico é Normal**, não do tipo do atacante | Daria STAB de graça e tornaria as 4 skills decorativas |
| **Cooldown por golpe, não por slot** | Por slot, trocar a ordem das skills zeraria os cooldowns — exploit de graça |
| **A direção do aviso é travada no início** | Relida na resolução, o aviso não custaria nada e ninguém desviaria de nada |
| **Modelo ausente cai no primitivo E AVISA** | Asset faltando que aparece como cápsula silenciosa é zero silencioso |
| **O corpo do treinador encara a MIRA do mouse**, não a direção do movimento (18/09) | Pedido do Gabriel: *"o mouse precisa ser a mira para todas as ações"*. Com o corpo virando pro movimento e a câmera atrás, **nunca se vê a frente do personagem** — ele parecia andar de costas |
| **Selvagem nasce num ANEL** (12 a 28 m), nunca perto | Fora do raio de aggro de um agressivo (5 m): o bicho tem de aparecer e se aproximar, não materializar na cara. E protege do contrato de nascimento |
| **Lugar perigoso: menos encontro, e mais raro** | Pedido do Gabriel. Esticar só o intervalo não bastaria — a população acumularia até igualar a zona segura. Por isso o teto de população cai junto |
| **Classe pura nunca cita autoload** | Autoload não é identificador em teste `--script`. Vai por `Sorteio`, que resolve em tempo de chamada e preserva a sequência do jogo |

---

## 🧨 O inimigo comum: o zero silencioso

Coisa que existe, não dá erro, e **não faz nada**. É o padrão de bug que mais
apareceu neste projeto:

| Onde | O que era |
|---|---|
| Tabela de tipos | 15 dos 18 tipos — Bite nunca era super-efetivo |
| Drenagem | nunca curou, em **nenhuma** versão: o código lia um campo `drenagem` que nenhum dos 192 golpes tem |
| Habilidades | 132 de 151 espécies com habilidade vazia, lida em 5 lugares |
| Mergulho | lia uma propriedade que nunca existiu |
| Status | `effect` lido como nome de status, quando é um DSL (`burn_10`) |
| Gráfico do Simulador | faltava **um argumento** na chamada — nenhum marcador de evento, nenhum erro |
| Dano da skill (17/09) | `detalhe.get("dano", 0)` quando o contrato é `final` — relatório completo, dano zero |
| Ordem de nascimento (17/09) | posicionar depois do `add_child` catapultava quem estava na origem, sem erro nenhum |
| Autoload em classe pura (17/09) | `Compile Error: Identifier not found: RNGManager` impresso na suíte **com o teste passando** — erro que não reprova |

**As duas regras que saem disso:**

1. *O campo existir não é o mesmo que o valor servir.* Ao afirmar que algo está
   preenchido, medir **quantos têm valor útil**, não quantos têm a chave.
2. *`Dictionary.get(chave, padrão)` é fábrica de zero silencioso.* Onde há
   contrato, ler sem padrão e estourar.

E: **falta de coisa tem de ser visível.** Asset ausente, dado faltando, regra não
implementada — tudo avisa, nunca cai num default calado.

---

## 🧪 Disciplina de teste (custou caro cada linha)

- **Um agente por vez na suíte.** 2 núcleos compartilhados com a produção. Duas
  suítes ao mesmo tempo produzem **reprovação falsa**. Conferir
  `ps aux | grep godot4` antes de disparar.
- **Não edite o que está sendo medido.** Suíte disparada, mãos longe do
  repositório.
- **Reprovação sob carga não é regressão** até ser reproduzida sozinha.
- **Silêncio não é aprovação.** Um teste que morre antes de rodar também sai com
  código 0. `tools/rodar_testes.sh` exige código 0 **e** a linha
  `=== Resultado: N ok, M falhas ===`.
- **Teste que reprova por sorteio ensina a ignorar vermelho.** Conferência
  estatística precisa de amostra que dê ~4σ, não ~2,9σ.
- **Número cravado que mede o cadastro do Gabriel envelhece sozinho.** Medir o
  baseline no próprio teste.
- **Em teste `--script`, autoload não é identificador.** Usar variável de membro
  preenchida por `root.get_node()` — e só a partir do primeiro `_process`.
- **Em headless o laço roda o mais rápido que consegue.** Esperar tempo real
  esperando **tempo de parede**, nunca contando quadros.
- **Cena montada em `_initialize` não entra na árvore de verdade.** Montar no
  primeiro `_process`.

---

## 📚 Histórico e desenho (não é estado)

| Arquivo | O que é |
|---|---|
| `GAMEPLAY_V3.md` | o painel detalhado da migração, fase por fase, com as medições |
| `MIGRATION_V2_TO_V3.md` | a auditoria: 24 KEEP, 14 ADAPT, 8 REBUILD, 9 DEPRECATE |
| `rfc/RFC-GAMEPLAY-V3-3D.md` | a RFC do pivô |
| `WORLD_3D_ARCHITECTURE.md` · `COMBAT_FIRST_PERSON.md` · `TRAVERSAL_SURF_FLY.md` | o desenho de cada frente |
| `POKEMON_MODEL_PIPELINE.md` | o contrato de um modelo — **ler antes de produzir** |
| `direcao-de-arte-mestre.md` | direção de arte global — **ler antes de mexer em gráfico** |
