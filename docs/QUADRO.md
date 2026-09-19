# QUADRO — PokéMobile

> **Comece por aqui.** Este é o **estado**: o que está feito, o que falta, e de
> quem é cada coisa. `GAMEPLAY_V3.md` é o painel detalhado da migração e as RFCs
> são o desenho; **em caso de divergência, o quadro ganha.**
>
> Regra em `/root/memoria/padrao-agentes.md`, seção 4. Quem fecha uma sprint
> atualiza este arquivo **na mesma sessão**, antes de commitar.

**Estado em:** 18/09/2026
**Branch do Claude:** `agent/claude-v3`
**Suíte:** `bash tools/rodar_testes.sh` — **130 arquivos, 0 com falha**

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
| 12 | **Combate 1v1** | ✅ 18/09 · `RegraDeCombate` + `Combate1v1` · 34 conferências |
| 13 | **Combate → Mundo** | ✅ 18/09 · `RegraDeRetorno` + `RetornoAoMundo` · 50 conferências · **o laço da fantasia está fechado** |
| 14–15 | **Surf · Fly** | ✅ 18/09 · `RegraDeTravessia` · 44 conferências |
| 16 | **TM/HM** | ✅ 18/09 · `RegraDeMaquina` · **capacidade × permissão** · 48 conferências |
| 17 | **Move Pool** | ✅ 18/09 · `RegraDeMovePool` · **conhecidos / equipados / ativos** · 59 conferências · 🔴 achou o kit vazio |
| 18 | **Alpha** | ✅ 18/09 · `RegraDeAlpha` · 58 conferências · 🔴 **nunca tinha nascido um** · raridade fixada pelo Gabriel |
| 19 | **Polimento** | ⬜ · **o Codex entra aqui** · acionado em 19/09 |
| 20 | **Performance** | 🟡 18/09 · `RegraDeRitmo` · **LOD de lógica**, 62,5% menos IA · 33 conferências · **falta medir FPS em navegador — é do Gabriel** |

**As 18 primeiras fases estão fechadas** — a migração de regras acabou. A 20 tem
a metade que é minha feita (custo de lógica); a outra metade é desenho, e depende
da 19 (Codex) existir pra ter o que medir.

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
| 1 | Fase 20 — a metade de DESENHO (vegetação, modelos, sombra) | **sim** — depende da Fase 19 do Codex existir pra ter o que medir |
| 1b | Ligar `permissoes_do_jogador()` na mochila de verdade quando a V3 tiver save | sim — depende do save da V3 |
| 1c | Ligar `capturavel` na pokébola da V3 (hoje ninguém captura em 3D) | sim — a captura em 3D ainda não existe |
| 1d | Fazer a contagem de elites derrotados **sobreviver a salvar/carregar** (hoje vive só no spawner) | sim — depende do save da V3 |
| 1e | ✅ **RFC-008 — máscara de spawn. FEITA (19/09).** `RegraDeHabitabilidade` + laço de tentativas no spawner · 29 conferências. 🔴 A medição corrigiu meu número: eu previ 3,25% de recusa (falésia) e o real é **38,7%**, porque quem domina é a **água** — `TENTATIVAS` 6 → **10** | — |
| 1f | **`altura_em` deixa de ser `static`** quando o 1º chunk semeado nascer. `static` é o que transforma o seed em estado global; vira serviço instanciado e `SpawnerSelvagem3D`/`PokemonInstance3D`/`RegraDeAcompanhar` passam a receber a referência | sim — não existe chunk no runtime ainda |
| 3 | Ajuste de *sensação* dos controles | **sim** — depende do item 🟡 1 |

---

## 🟣 Pendente — Codex (HUD, câmera, sprites, modelos, animação, efeitos)

| # | O quê | Quando |
|---|---|---|
| 0 | 🔴 **PLAYER 3D V1 — a ponte visual.** O GLB está pronto e validado; **destravado**: a RFC-007 foi aceita e as 3 decisões estão tomadas | **prioridade** · `docs/agent-reviews/claude/2026-09-18-RFC-007-player-v1.md` |
| 0b | 🔴 **WORLD FACTORY V1** — **contrato de altura aceito** (RFC-006, opção A, medido por mim a 0,000001 m). ⚠️ O aceite é só do laboratório: **borda entre chunks continua sem contrato**, porque chunk ainda não existe pra medir | `docs/agent-reviews/claude/2026-09-18-RFC-006-altura-e-colisao.md` |
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

### ✅ A altura do player — RESOLVIDA E APLICADA em 18/09: **1,60 m**

| Fonte | Diz |
|---|---|
| A folha de concept art do Gabriel (18/09) | **1,60 m** |
| `TrainerController3D` (cápsula e malha) | 1,75 m |
| O `player.glb` de 14–15/09, medido | 1,750 m |

**A folha é internamente coerente, e dá pra provar:** ela lista Pikachu em
**0,40 m** e Charizard em **1,70 m** — e os dois batem **exatamente** com
`heights.json` do jogo. Ela não inventou escala de Pokémon pra caber no
personagem; usou a real.

O outlier é o **código**: 1,75 m é altura de **adulto** (a própria folha põe o
NPC adulto em 1,75), quase certamente um placeholder que nunca foi calibrado
contra referência nenhuma.

➡️ **Feito.** `TrainerController3D.ALTURA_DO_CORPO = 1.60` (cápsula e malha lendo
a constante, pés em Y=0), e `CameraTerceiraPessoa.ALTURA_DO_OMBRO` recalibrada
**por proporção** — 1,5/1,75 = 0,857, × 1,60 = **1,371 m**. O raio segue 0,35 m
de propósito: é largura, não altura.

🔴 Achado ao aplicar: `origem_da_mira()` tinha um `1.5` **cravado**, segunda
cópia da altura do ombro vinda do corpo de 1,75 m. Agora lê a constante.

⚠️ **Se a câmera ficar alta ou baixa pro Gabriel no navegador, o número a mexer
é `ALTURA_DO_OMBRO`** — não a cápsula, que agora tem razão medida pra ser 1,60.

### 📄 A folha de referência não está no disco — a transcrição está

A imagem chega ao Claude na conversa e **não é gravada na VPS**; o Gabriel
também não consegue subi-la. A referência disponível é
**`docs/referencias/player_v1/FOLHA-DE-REFERENCIA.md`**, escrita painel por
painel, separando o que está desenhado do que é interpretação.

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

## 🧭 Anotado para o futuro, sem prazo (decisões do Gabriel, 18/09)

Coisas que ele levantou e escolheu **não** atacar agora — *"vamos continuar com
o plano atual para não atrasar o projeto"*. Ficam aqui pra não virarem folclore:

| O quê | O que ele disse |
|---|---|
| **Luta massiva: 1v5, 1v10** | É consequência do mundo aberto com aggro de vários mobs. A Fase 12 já **não impede** — o que falta é o resto (câmera, alvo, leitura de tela) ser pensado pra isso |
| **4 skills pode ser pouco** | *"considerando esse 'battle royale solo' acho que 4 skills apenas pode ser pouco para uma luta massiva"*. `KitDeCombate` já prevê **até 8 slots** (4 base + 2 aos níveis 50 e 100), então o dado não precisa mudar — é decisão de balanceamento |
| **1v1 vira PvP** | A mecânica de duelo existe e está testada; PvP está fora do escopo declarado da V3 |

## 🤝 As duas RFCs do Codex, respondidas em 18/09

O Codex abriu duas e ficou parado esperando decisão minha. **As duas estão
respondidas; ele está destravado nas duas.**

| RFC | Veredito | O que isso libera |
|---|---|---|
| **006** — altura x colisão | ✅ **opção A aceita** (só o laboratório) | World Factory volta a andar no terreno |
| **007** — Player V1 | ✅ **aceita**, 3 decisões tomadas | a ponte visual do treinador |

**RFC-006 — o que eu medi, em vez de ler o diff.** `teste_rfc006_altura_e_colisao.gd`
reconstrói a superfície de colisão **sem passar por `altura_em`** (plano do
triângulo, não as baricêntricas do código sob teste) e compara:

```
143.641 amostras fora da grade      pior erro 0,000001 m
a mesma régua na fonte analítica    erraria  1,6585 m   ← ela enxerga o defeito
720 pontos do anel de spawn         0 enterrados, 0 pairando
11.449 pontos de profundidade       0 trocariam de classe
```

A segunda linha é a que dá valor às outras: sem ela, "erro zero" poderia ser um
teste que não mede nada.

🔴 **Achado meu, que nenhum dos dois tinha:** refinar a malha **não** conserta
falésia — **piora**. A mesma queda de 8,03 m num passo menor é inclinação maior;
resolução revela o gradiente, nunca o suaviza. Então a opção C da RFC não é
"insuficiente sozinha", ela anda na direção contrária. O que falta não é
resolução, é a **RFC-008**.

**RFC-007 — a decisão que foi medida, não escolhida.** Recusei a opção B (o
visual ler `quer_correr`) porque a exaustão nível 3 corta 50% da velocidade:

| | |
|---|---|
| correr **exausto** | **4,00 m/s** |
| caminhar pleno | **4,50 m/s** |

Correndo exausto o treinador anda mais devagar que um passo, com a tecla de
correr apertada — a opção B teria tocado CORRIDA ali. O contrato novo é
`estado_visual_de_locomocao()`, derivado do que o corpo **faz**.

---

## 🟡 Pendente — Gabriel

| # | O quê | Por quê |
|---|---|---|
| 1 | **Qual aspecto dos controles incomoda** | "melhorar os controles" são **seis** ajustes diferentes: velocidade, sensibilidade do mouse, aceleração, atrito, virada do personagem, distância da câmera. Mexer nos seis de uma vez faz ninguém saber qual melhorou |
| 2 | Jogar a V3 depois do conserto de direção (17/09) e dizer se o W agora anda pra onde se olha | o teste prova direção e independência da câmera; **não prova sensação** |
| 3 | ✅ **Respondido (18/09):** elite **2%**, Alpha **0,5%**, **+0,1%** por elite derrotado nas últimas **3 h**. Implementado e travado por teste | — |
| 4 | ✅ **Respondido (18/09):** o **teto de 5%** e a leitura de **2% como teto** (`× perigo da zona`, Pallet em 0%) ficam como propostos — *"mantenha como você propôs"* | — |
| 5 | ✅ **Respondido (19/09):** *"pode seguir com a rfc 8"* — implementada e travada por teste no mesmo dia | — |
| 6 | **Conferir a câmera no navegador** depois que o Codex ligar o Player V1 | o treinador encolheu de 1,75 m pra 1,60 m e o ombro da câmera desceu junto, por proporção. Se ficar alto ou baixo, o número a mexer é `ALTURA_DO_OMBRO` — e só você consegue julgar isso, porque é sensação |

---

## 🔴 Duas suítes ao mesmo tempo davam falha FALSA — corrigido em 19/09

`rodar_testes.sh` escrevia em `/tmp/saida_teste.txt`, um caminho **global**. Com
Claude e Codex em worktrees diferentes na mesma VPS, os dois escreviam e liam o
mesmo arquivo, e o resultado de um teste sumia no meio do outro.

O sintoma engana porque não parece contenção: sai **"não chegou a rodar (nenhuma
linha de resultado)"** — exatamente a mensagem de um teste que morreu ao
compilar. Custou **5 reprovações falsas** numa suíte; as 5 passaram sozinhas
depois, 4 vezes seguidas cada.

O caminho passou a carregar o nome da worktree. ⚠️ Continua valendo **não rodar
as duas ao mesmo tempo** — são 2 núcleos, e a lentidão ainda pode estourar o
`timeout 300` de cada teste. A diferença é que agora o resultado fica lento, não
**falso**.

---

## 🖥️ O painel do Gabriel

`docs/painel/index.html` — uma página só, pra ler as sprints, os contratos e a
fila de pendências sem abrir documento nenhum. Feita pro celular.

⚠️ Ela é **gerada**, não escrita: `python3 tools/gerar_painel.py` lê este
`QUADRO.md` e `docs/rfc/*.md` e monta a página. O motivo é o mesmo que criou
este quadro — um painel escrito à mão seria o oitavo documento de coordenação a
envelhecer sozinho. **Se o painel mentir, a fonte é que está errada.**

**Rode o gerador ao fechar qualquer sprint**, junto com a atualização deste
arquivo. Vale para os dois agentes.

### No ar em **https://poke.workprog.pro/painel**

Servido pelo mesmo nginx do jogo. Duas armadilhas resolvidas no caminho, as
duas do tipo que quebra em silêncio:

- 🔴 **`Cross-Origin-Embedder-Policy: require-corp`**, que o WebAssembly do jogo
  exige, **bloquearia a fonte do Google** no painel — a página abriria com a
  fonte do sistema e ninguém saberia por quê. Os cabeçalhos do jogo desceram
  pra dentro de `location /`; o painel não herda nada.
- 🔴 **`absolute_redirect off`**: sem isso, abrir `/painel` (sem a barra, que é
  como a pessoa digita) redirecionava pra `http://host:8080/painel/` — a porta
  interna, morta do lado de fora.
- O Dockerfile copia de `docs/painel/`, **não** de `builds/web/`: esta última é
  saída de build e some a cada `exportar_web.sh`.

⏳ **`pokemobile.workprog.pro` ainda não existe no DNS.** A regra do Traefik
está escrita e **comentada** em `/root/pokemobile.yaml` — ligada com o domínio
sem resolver, o Let's Encrypt falharia em laço e a cota de emissão desta VPS
(8 subdomínios) entraria em risco. Basta o Gabriel criar o registro A.

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
| 🔴 **O 1v1 é a mecânica de DUELO (PvP), não a regra do mundo** (Gabriel, 18/09) | *"é possível acontecer um 1v5 ou 1v10 dependendo da área do mapa"*. Vários mobs podem agredir ao mesmo tempo. Minha primeira versão fazia o terceiro largar o alvo — não era conservadorismo, era **bug**: lutar com um bicho fazia todos os outros esquecerem o jogador |
| **Os dois caindo no mesmo quadro é DERROTA** | Vitória com o próprio Pokémon desmaiado não existe. Perder empatado é perder |
| **Só a DERROTA devolve o controle** (18/09) | Vencer e a briga se desfazer não devolvem nada — no mundo aberto o jogador continua sendo o Pokémon até decidir o contrário. Forçar a volta a cada vitória viraria uma sequência de telas de transição |
| **Com hostil por perto, não dá pra voltar ao treinador** | Senão o corpo do treinador vira **saída de emergência**: cinco mobs em cima, aperta T, o perigo evapora. Isso esvaziaria o pilar do "mundo perigoso" — e o Gabriel acabou de reforçar que 1v5 e 1v10 acontecem |
| **Surfar é ASSUMIR um Pokémon que nada** (18/09) | Não existe "o treinador em cima de um bicho": existe o jogador *sendo* o bicho, com o `MovementProfile` dele. Mesma transferência da Fase 7. Voar é idêntico, com outro arquétipo |
| **Terrestre anda em água RASA, e é barrado na profunda** | Barrar a rasa criaria parede invisível justo na borda da praia, onde o jogador mais anda. E é a profunda que dá sentido ao Surf |
| **Teto de voo é RELATIVO ao terreno** | Absoluto faria esbarrar num limite invisível ao subir a montanha, e voar mais alto no vale do que no pico |
| **Classe pura nunca cita autoload — e nó também não deveria** | `PonteDeFeedback` citado direto no `ControlModeManager` derrubou a carga da classe inteira num teste `--script`: `new()` passou a responder "função inexistente". Mesma lição do `RNGManager` na Fase 11, em outro autoload |
| **Toda briga tem prazo** (20 s sem ninguém apanhar = desfaz) | Dois lutadores presos em lados opostos de uma pedra ficariam "em combate" pra sempre, e o jogador nunca recuperaria o treinador |
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
