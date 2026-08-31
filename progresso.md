# Progresso — PokéMobile

> Formato de cada entrada: Lote, o que foi feito, o que foi testado, próximo passo,
> se precisa de decisão do Gabriel. Mais recente primeiro.
>
> A partir de 31/08, cada evolução de progresso ganha uma tag de versão no Git
> (`git tag`, ex: v0.2.1) e é enviada ao GitHub — assim dá pra voltar ou comparar
> qualquer momento anterior. Ver lista de versões: `git tag`.

---

## Acessibilidade, Ajuda, Controles reatribuíveis + visual novo da Loja/Mochila (2026-08-31, continuação)

**Pedido do Gabriel:** conferir se toda função que o jogador pode usar está acessível pela tela,
criar um guia de ajuda dentro do jogo, e uma tela de Controles pra reatribuir tecla. Depois, mandou
uma imagem de referência (estilo Poketibia) pedindo que Loja e Mochila ficassem parecidas.

**Auditoria de acessibilidade — achados:**
- 5 ações de teclado nunca ligadas a nada (`skill_1-4`, `pokeball`/Espaço, `fullscreen`/F11,
  `menu_map`) — não são "funções escondidas", são atalhos mortos, sobra de uma versão anterior.
  Não entraram na tela de Controles (reatribuir uma tecla que não faz nada só confundiria).
  `scripts/combat/CaptureSystem.gd` também é código órfão — nenhuma cena/script usa ele (a
  captura de verdade mora em `BattleManager._attempt_capture`); não apagado agora, só registrado.
- Todo o resto do jogo (Mochila/Loja/Pokédex/Time/Salvar) já era alcançável — todos passam pelo
  menu de Pausa, que por sua vez é alcançável tanto pelo teclado (Esc/P) quanto por um botão de
  toque de verdade (`BtnStart` em `TouchControls.tscn`, já existia) — jogador de celular sem
  teclado não fica travado.
- Nenhum atalho (Correr, Interagir) tinha onde o jogador aprendesse que existe — resolvido pela
  Ajuda nova.

**Construído:**
- **Tela de Ajuda** (Pausa → Ajuda): texto explicando andar/interagir/menu de pausa/atalhos
  diretos/batalha/capturar/evoluir/MT-MO/dinheiro — **mostra a tecla ATUAL de cada ação** (se o
  jogador reatribuir na tela de Controles, o texto da Ajuda já aparece certo, não fica
  desatualizado, porque lê direto do `KeybindManager`).
- **Tela de Controles** (Pausa → Controles), `KeybindManager` novo (autoload): lista as 10 ações
  que realmente fazem algo no jogo, clica "Alterar", aperta a tecla nova, salva sozinho em
  `user://keybinds.cfg` (**testado ao vivo: sobrevive a recarregar a página**). Se a tecla nova já
  era de outra ação, a outra perde a tecla (evita as duas dispararem juntas sem o jogador saber) —
  avisado na tela. Botão "Restaurar padrões" volta tudo pro original do project.godot.
- **Visual novo de Loja e Mochila**, inspirado na referência que o Gabriel mandou: painel escuro
  arredondado, barra lateral de categorias com ícone (gerados em código, mesmo estilo simples já
  usado nos sprites do jogo — `assets/generate_item_icons.py`), linha de item com ícone. A Loja
  ganhou filtro por categoria também (antes era uma lista só, agora filtra por Poções/Bolas/
  Pedras/TM-HM/Batalha/Vitaminas). Achado no caminho: a Mochila aberta pela Pausa era um popup
  pequeno (400×300) — aumentada pra quase tela cheia, igual a Loja.
- **Fora do escopo desta rodada** (visual): minimapa, barra de atalhos "F1-F6" com item
  arrastável, chat/log de mensagens, dock de Perfil/Quests, inventário em grade com slots
  travados — tudo isso é Lote 10 (polimento) de verdade, precisa de mais sistemas por trás
  (mapa renderizado, sistema de slot-atalho, sistema de mensagens) que ainda não existem.

**Testado ao vivo:** Ajuda abre com as teclas certas; Controles reatribui Correr de Shift pra "J",
confirmado funcionando e confirmado que sobrevive a recarregar a página inteira; Restaurar
padrões testado; Loja com o visual novo — comprei Super Potion (₽300) e troquei de categoria
(Poções → Pokébolas), tudo funcionando; Mochila com o visual novo abrindo certo.

**Precisa de decisão do Gabriel?** Não por enquanto.

---

## Pedras evoluem, TM/HM ensinam golpe (2026-08-31, continuação — estilo "Poketibia" sem multiplayer)

**Contexto:** Gabriel pediu que a mecânica de itens/loja/pedras fosse no estilo dos jogos de
Poketibia (PokeXGames/OTPokemon/PokemonBR — todos rodando o motor do Tibia). Pesquisado: nesses
jogos a troca entre jogadores é uma janela em tempo real (dois jogadores no mesmo mapa), o que
exigiria dar ao PokéMobile uma arquitetura que ele não tem hoje (servidor, contas, sincronização
— projeto de semanas). **Perguntado ao Gabriel antes de construir** (regra de confirmar decisão
de arquitetura) — ele escolheu **só o estilo de loja/pedras/TM, sem multiplayer por enquanto**.

**O que foi construído:**
- **Pedras evoluem Pokémon de verdade.** `evolutions.json` já tinha as 13 evoluções por pedra
  mapeadas certinho (bate exato com o Gen 1: Pikachu por Pedra Trovão, Poliwhirl por Pedra Água,
  etc) — só nunca tinha sido ligado a nada (`SaveManager._check_evolution` só olhava nível).
  `SaveManager.try_evolve_with_stone()` novo, reaproveitando a mesma lógica de troca de espécie
  que já existia pra evolução por nível.
- **TM/HM ensinam golpe de verdade.** 15 itens novos em `items.json` (12 MTs + 3 MOs, com preço
  e a referência de qual golpe ensinam). `SaveManager.learn_move()` novo. Se o Pokémon já sabe 4
  golpes, abre uma segunda tela pra escolher qual esquecer (like os jogos de verdade).
  **Simplificação assumida**: qualquer Pokémon aprende qualquer MT/MO (o Gen 1 real restringe por
  espécie — essa tabela de compatibilidade não existe nos dados baixados da PokéAPI ainda; fica
  pra outra rodada se o Gabriel quiser mais fidelidade). MOs também podem ser esquecidas (no jogo
  real não podem) — simplificação de propósito pra não duplicar o sistema de aprender golpe.
- **Painel "em qual Pokémon?" novo**, construído em código (não em `.tscn`) — reaproveitado tanto
  pra pedra quanto pra MT/MO. Construído em código de propósito, com um único filho direto no
  PanelContainer, pra não repetir o mesmo bug de "PanelContainer com filho demais empilha tudo"
  que travou o menu de golpes mais cedo hoje.
- **Achado no caminho, corrigido**: a Mochila (`BagScene.gd`) tinha só 5 abas, e 3 delas nem
  batiam com os dados de verdade — "Frutas" (`berry`) não existe em nenhum item, "Chave"
  procurava `key_item` mas o dado usa `key`, e não existia aba nenhuma pra `stone` (pedra
  comprada ficava invisível na Mochila, sem jeito de usar). Reescrito pra bater com as 8
  categorias reais (`medicine/ball/stone/tm_hm/battle/vitamin/key/field`) — Pedras, Vitaminas,
  Batalha e Campo agora aparecem (antes eram invisíveis). **Achado 2**: o sinal `item_selected`
  da Mochila nunca era conectado quando aberta pela Pausa — clicar "Usar" fora de batalha não
  fazia nada nenhum, silenciosamente.

**Testado ao vivo:** comprei Pedra do Fogo na Loja (₽2100), abri a Mochila pela Pausa, aba
"Pedras" aparece com a pedra, "Usar" abre o painel "Usar em qual Pokémon?", escolhi o Bulbasaur
(que não evolui com essa pedra) — confirmado "sem efeito" e a pedra continua x1 (não foi gasta à
toa). Fluxo de MT/MO **não testado ao vivo** (mesmo código, mesmo padrão do fluxo de pedra já
confirmado — não tinha dinheiro sobrando pra comprar uma MT na mesma sessão de teste).

**Próximo passo:** testar MT/MO ao vivo quando houver saldo; depois seguir com o resto do pedido
original (item de batalha tipo X-Attack ainda não faz efeito nenhum — achado, não corrigido
ainda) ou o que o Gabriel pedir a seguir.

**Precisa de decisão do Gabriel?** Não por enquanto.

---

## Auditoria de golpes/itens + troca de Pokémon + dinheiro/Loja (2026-08-31, continuação)

**Pedido do Gabriel:** conferir se todos os golpes seguem a lógica certa de dano/buff/debuff/
efetividade, entender por que o loot "não dropava" (hipótese dele: itens não existiam ainda), e
construir um sistema de loot vendável → dinheiro → Loja (poções, pokébolas, TM/HM). Também pediu
pra abrir a seleção de time quando o Pokémon ativo desmaia em vez de encerrar a batalha na hora.

**Achados da auditoria (todos reais, nada disso era "não implementado ainda" — o código já
existia mas nunca funcionava):**
1. **Praticamente nenhum golpe de status/buff/debuff fazia efeito.** `moves.json` usa nomes tipo
   `"atk_minus1"`/`"paralysis"`/`"confuse_10"`, mas o código só reconhecia `"atk_down_1"`/
   `"paralyze"` (nomes diferentes, criados sem olhar o dado de verdade) — o `match` nunca batia
   com nada, então o golpe só mostrava "usou X!" e não fazia mais nada.
2. **`accuracy: 0` no dado significa "sempre acerta"** (usado por golpes que nunca erram, tipo
   Investida Rápida, e por golpes de status que não miram o oponente, tipo Ágil) — o código lia
   `0 < 100` como "precisa checar acerto", e a checagem com accuracy 0 sempre dava 0% de chance.
   Ou seja, **todo golpe "que nunca erra" sempre errava**, e vários golpes de buff (Ágil, Tela de
   Luz, Anfitrião de Foco...) nunca funcionavam.
3. **Usar qualquer item em batalha (Poção incluída) não fazia nada.** `_apply_item` lia
   `item.get("effect")`, mas `items.json` não tem esse campo — usa `heal_hp`/`cures`/`revive_hp`/
   `restore_pp` diretamente. Então usar Poção em batalha só gastava o item sem curar HP nenhum.
4. **Nenhum efeito secundário de golpe de dano existia** (ex: Lança-Chamas nunca queimava,
   Chispa nunca paralisava) — o código só tentava aplicar efeito em golpes de status puro.
5. Recuo, dreno de HP, golpes de dano fixo (Investida-K.O., Contra-Golpe, Fúria), multi-hit
   (2 a 5 vezes), confusão (não existia nem como conceito no jogo) e "apanhar antes de agir"
   (flinch) também não existiam.
6. **O motivo do dinheiro não aparecer:** `OverworldHUD.gd` já chamava `SaveManager.get_money()`
   desde antes dessa função existir de verdade — a causa exata do erro "a number is required"
   que aparecia sozinho o jogo inteiro, sem nunca ter sido rastreado até agora.

**Sobre a hipótese do Gabriel (itens não existirem):** não era isso — os 16 itens do loot já
existiam certinhos em `items.json` (com preço, e tudo). O loot só "não dropava" por sorte — a
chance de item cair por vitória é só ~15-20%, e nas poucas batalhas testadas antes não caiu
nenhuma vez (matemática: 3 vitórias seguidas sem loot tem ~58% de chance de acontecer só por
acaso). Confirmado que a fórmula está ligada certo.

**O que foi construído:**
- Reescrita a leitura de golpes: um parser genérico traduz qualquer `"<stat>_plus/minus<1|2>"` e
  qualquer condição de status (com ou sem chance % no nome) direto do jeito que `moves.json` já
  escreve, em vez de uma lista fixa de nomes inventados. Cobre buff/debuff, veneno/queimadura/
  paralisia/sono/congelamento (com chance certa), confusão (virou um estado próprio, separado,
  porque dá pra estar confuso E envenenado ao mesmo tempo), flinch, recuo, dreno de HP, golpes de
  dano fixo (K.O., Contra-Golpe, Fúria, dano-por-nível), multi-hit, Semeadura Fantasma (drena HP
  todo turno), Foco Energético (mais crítico), Descanso, Neblina (reseta status), e Pagamento em
  Dinheiro (Golpe da Sorte agora realmente dá ₽ — ligado direto no sistema de dinheiro novo).
  **Fora do escopo desta rodada** (documentado no código, não crasha, só não faz o efeito
  especial ainda): Investida/Voo/Cavar de 2 turnos, Disparo/Espelho, Metrônomo, Mimic, Refletir/
  Tela de Luz, Substituto, Bide, armadilhas (Grude/Aperto de Fogo) — todos golpes raros/muito
  complexos de fazer certo, ficam pra outra rodada.
- `_apply_item` reescrito pra ler o formato real de `items.json` — Poção/Hiper Poção/etc curam
  de verdade agora, Antídoto/Anti-Queimadura/etc curam o status certo, Revive funciona.
- **Troca de Pokémon em batalha**: item "POKÉMON" do menu de ação (existia, nunca fazia nada —
  nem conectado) agora abre a lista do time. Se o Pokémon ativo desmaia e ainda sobra time vivo,
  a troca abre sozinha e obrigatória (antes disso, desmaiar = perder a batalha na hora, mesmo com
  o time inteiro saudável esperando). Treinadores com mais de um Pokémon no time também mandam o
  próximo quando o atual desmaia (não só o jogador).
- **Dinheiro + Loja**: `SaveManager.get_money/add_money/spend_money` (faltavam de verdade).
  Loja nova (`Pause → Loja`, aba Comprar/Vender): comprar qualquer item vendável por dinheiro,
  vender item do inventário por metade do preço (loot virou dinheiro de verdade, como o Gabriel
  pediu). Itens de chave/campo (bicicleta, mapa...) não entram na loja.
- **Achado extra no caminho**: a Pokédex tinha o mesmo bug de layout que corrigi ontem no menu de
  golpes (um cabeçalho esticado até o meio da tela por engano de âncora) — corrigido nos dois
  lugares (Pokédex e a Loja nova, que copiou o padrão antes de eu perceber).

**Testado:** Recompilado e publicado, testado ao vivo no navegador — dinheiro aparece certo no
HUD (sem mais o erro misterioso), Loja compra e vende de verdade (dinheiro sobe/desce, item
some/aparece no inventário nas quantidades certas). Troca de Pokémon **não testada ao vivo ainda**
(o time só tem 1 Pokémon nas partidas de teste — precisa capturar um segundo pra testar de
verdade a troca forçada) — só conferido pela leitura do código.

**Próximo passo:** testar a troca de Pokémon ao vivo com time de 2+; depois seguir pro pedido
seguinte do Gabriel — mecânica de itens/loja/stones/trade no estilo dos jogos de Poketibia
(PokeXGames/OTPokemon/PokemonBR). Pesquisa inicial feita, ver `memoria/projetos/pokemobile
_lote7_9_dano_e_loja.md` (memória) — é uma decisão de arquitetura grande (multiplayer de
verdade), levada ao Gabriel antes de começar a construir.

**Precisa de decisão do Gabriel?** Sim — ver conversa sobre o pedido de mecânica estilo
Poketibia/multiplayer.

---

## Lote 7 e 9 — XP/nível e loot testados ao vivo, 2 bugs graves achados e corrigidos (2026-08-31, continuação)

**O que foi feito:** O código de XP/nível (Lote 7) e loot (Lote 9) já estava escrito (achado
pronto no início desta sessão, não commitado ainda). Antes de aceitar como "funcionando", testei
ao vivo no navegador (Chromium automatizado) uma batalha selvagem real — e achei que **nenhum
golpe estava causando dano**: escolher "Tackle" várias vezes contra um Rattata não tirava HP
nenhum dele. Causa raiz: `MoveMenu` (o menu de golpes) tinha 3 filhos diretos (`Grid`, `MoveInfo`,
`BtnBack`) dentro de um `PanelContainer` — e um `PanelContainer` estica TODOS os filhos diretos
pro mesmo espaço inteiro, empilhados. Isso fazia o botão invisível "VOLTAR" cobrir a tela toda por
cima dos botões de golpe, roubando todo clique (por isso clicar em "Tackle" sempre só fechava o
menu, sem nunca lutar). Corrigido agrupando os 3 num `VBoxContainer` só (é o padrão certo do
Godot pra isso). Achado um segundo bug, mais grave, no caminho: **o menu de Pausa travava pra
sempre assim que abria** — nem "Continuar", nem clicar em nada, nem apertar a mesma tecla (Esc/P)
fechava. Causa: abrir a pausa liga `get_tree().paused = true`, mas o próprio menu de pausa nunca
foi marcado como "roda mesmo pausado" (`process_mode`) — então ele se auto-travava. Corrigido com
uma linha (`process_mode = Node.PROCESS_MODE_ALWAYS`). Os dois bugs eram antigos (não foram
causados pelo código do Lote 7/9), só nunca tinham sido pegos porque ninguém tinha testado um
combate real nem aberto a pausa numa sessão automatizada até agora.

**Testado:** Depois da correção, republiquei e testei de novo ao vivo — Tackle agora tira HP de
verdade dos dois lados (confirmado "Rattata usou Tackle!" + barra baixando), venci 2 batalhas
seguidas ("Você venceu!" na tela), Mochila abre e fecha normal pela Pausa. **Não confirmado ao
vivo** (por chance/RNG, não por bug): nível subindo (o Bulbasaur ainda não tinha XP suficiente
pra passar do Nível 5 nas batalhas testadas) e item de loot aparecendo na Mochila (a chance de
loot por vitória é só ~15-20%, não caiu em nenhuma das 3 vitórias testadas) — conferido pelo
código que as duas fórmulas existem e estão ligadas certas (não é código morto).

**Próximo passo:** Lote 8 (HUD de nível/stats) — ainda não começado.

**Precisa de decisão do Gabriel?** Não — combinamos que só chamo você se eu travar de verdade.

---

## Lote 5/6 — Batalha selvagem e captura, ponta a ponta (2026-08-31, continuação)

**O que foi feito:** Continuando a verificação ao vivo, a batalha abria mas
mostrava "???"/"Nv.?"/"HP:?/?" pros dois lados, sem sprite nenhum. Causa:
10 caminhos de nó em `BattleScene.gd` (nome/nível/HP/status de cada lado)
estavam todos com um nível de pasta faltando — corrigidos, e sprites
adicionados (mesma causa dos achados anteriores). Rodei uma varredura
automática comparando TODO `@onready` do projeto contra a árvore real da
cena — achou mais um caso igual na Mochila (`BagScene.gd`), corrigido. Por
fim, achado um terceiro bug: o nome da categoria "Pokébola" no código
(`"pokeball"`) não batia com o nome real nos dados (`"category":"ball"`) —
mesmo com 5 Pokébolas no inventário, a aba aparecia vazia. Corrigido nos 2
lugares que usavam o nome errado, e mais um campo (`catch_rate_mult`) que
fazia toda bola ter o mesmo efeito de captura.

**Testado:** Publicado e confirmado num navegador de verdade, do começo ao
fim: escolher starter → andar → Pokémon selvagem (espécie certa) persegue e
inicia batalha → batalha mostra nome/nível/HP/sprite dos dois lados →
Mochila abre sem erro → Pokébola aparece (x5) → lançar de fato tenta a
captura (essa tentativa falhou, Pidgey contra-atacou — comportamento
correto, a captura não é garantida).

**Próximo passo:** Confirmar XP/nível subindo depois de vencer uma batalha
(Lote 7) e o loot depois de vencer (Lote 9) — o código de ambos existe, lido
mas não confirmado ao vivo ainda.

**Precisa de decisão do Gabriel?** Não por enquanto — o ciclo principal
(andar → encontrar → batalhar → capturar) já está confirmado funcionando.

---

## Lote 5 — Spawn de Pokémon selvagem (2026-08-31)

**O que foi feito:** Gabriel escolheu "testar e ligar o que já existe" em vez de
seguir os Lotes na ordem literal. Fui pra Rota 1 conferir o spawn de Pokémon
selvagem e achei 3 problemas em cadeia, todos corrigidos: (1) `WildPokemon.gd`
nunca carregava sprite nenhum — mesmo nascendo, era invisível; (2) o arquivo
de zonas (`zones.json`) tinha coordenadas pensadas pra um Kanto inteiro que
nunca foi construído, sem bater com o mapa real (só Pallet Town + Rota 1 +
Viridian City) — corrigidas as 3 zonas reais; (3) o raio de sorteio de
posição do Pokémon era maior que o mapa inteiro (200 tiles num mapa de 100) —
reduzido pra 20.

**Testado:** Publicado e confirmado num navegador de verdade — Pokémon
selvagem aparece do lado do jogador poucos segundos depois de entrar na Rota
1. **Não testado ainda:** a batalha abrindo de fato quando o Pokémon alcança
o jogador (o "fio" que liga um ao outro existe e está conectado no código,
só não confirmei o momento exato ao vivo).

**Próximo passo:** Confirmar a batalha abrindo (fecha o Lote 5) e seguir pro
Lote 6 (captura) — o código de captura em batalha já existe e parece
corretamente ligado ao inventário e ao save (lido, não testado ao vivo
ainda).

**Precisa de decisão do Gabriel?** Não por enquanto.

---

## Lote 0 — Diagnóstico ao vivo + correções emergenciais (2026-08-31)

**O que foi feito:** Antes de começar os "lotes" pedidos, o Gabriel jogou e reportou 3
problemas (câmera longe, Pokémon companheiro não aparece, não dá pra abrir
Pokédex/Mochila/Pokémon). Investigando cada um a fundo, achei as causas reais:
câmera em zoom 2x (aumentada pra 3x); o Pokémon companheiro tinha código escrito
mas nunca tinha uma cena (`.tscn`) nem era instanciado em lugar nenhum — criei a
cena e liguei ao jogador; as telas de Pokémon/Mochila/Pokédex já existiam prontas,
só que nada no jogo abria elas — adicionei botões no menu de pausa. No meio do
caminho também achei e corrigi: a tela de Pokémon lia a chave de HP errada
(sempre mostrava 0), a tecla D conflitava "andar" com "abrir Pokédex", e 2 erros
de sintaxe que impediam dois scripts de carregar. Também descobri e corrigi algo
importante de infraestrutura: só existia 1 commit no Git deste projeto (de
22/04) — todo o desenvolvimento desde então nunca tinha sido salvo, só publicado
direto na VPS. Consolidei tudo em um commit novo.

**Testado:** Publicado em poke.workprog.pro e verificado num navegador de
verdade (automatizado): zoom mais próximo confirmado visualmente; Pokémon
companheiro aparece do lado do jogador e segue o rastro dele ao andar; menu de
pausa abre com os 3 botões novos; nenhum erro novo no console do navegador.

**Próximo passo:** Alinhar os "Lotes 1-10" que o Gabriel mandou com o que já
existe no jogo (ver conversa — muita coisa da lista já está construída, só
precisa ligar/testar, não recriar do zero).

**Precisa de decisão do Gabriel?** Sim — qual lote ele quer que eu ataque
primeiro, já usando a lista ajustada.
