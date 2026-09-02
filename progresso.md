# Progresso — PokéMobile

> Formato de cada entrada: Lote, o que foi feito, o que foi testado, próximo passo,
> se precisa de decisão do Gabriel. Mais recente primeiro.
>
> A partir de 31/08, cada evolução de progresso ganha uma tag de versão no Git
> (`git tag`, ex: v0.2.1) e é enviada ao GitHub — assim dá pra voltar ou comparar
> qualquer momento anterior. Ver lista de versões: `git tag`.

---

## As 151 sprites reais (4 direções + shiny) — arte de verdade, sem depender de IA (2026-09-02, sessão seguinte 2)

**Pedido do Gabriel, depois de eu ficar travado de novo pela cota diária da ferramenta de imagem:
"Você não consegue pegar as imagens disponíveis e simplesmente usar e animar (...) em vez de gerar
com IA?"** Resposta: sim — e ele confirmou o uso ("o projeto é só meu, sempre sonhei em ter um
game onde eu poderia fazer do meu jeito, então siga com as imagens prontas"). Isso destrava de vez
o bloqueio de cota que vinha limitando a sessão anterior.

**Fonte:** repositório público e gratuito `PokeAPI/sprites` no GitHub, que hospeda as sprites
originais da Geração 1 (Red/Blue) de cada Pokémon — sem chave de API, sem cota, sem depender de
geração por IA. É arte da Nintendo/Game Freak; usar num projeto pessoal, sem venda nem
distribuição, é prática comum em fã-jogos e o próprio Gabriel confirmou que é assim que quer.

**Script novo `scripts/tools/build_pokemon_sprites.py`** baixa `front_default` (de frente) e
`back_default` (de costas) de cada uma das 151 espécies, remove o fundo branco sólido (chroma-key,
sem alpha na fonte), centraliza numa moldura 32×32 (as sprites baixadas variam de 32 a 40px), e
monta a mesma folha 96×128 (3 colunas × 4 linhas) já usada pro Treinador/NPC — down=frente,
up=costas, left=frente (sem sprite de perfil real disponível, é a melhor aproximação), right=frente
espelhada. Roda pra todos os 151 de uma vez: **151 processadas, 0 falharam.**

**Shiny: aproximação nossa, não existe "shiny" oficial pra Red/Blue** (o conceito só existe a
partir da Geração 2) — gerado por rotação de matiz (HSV +100°) em cima do sprite normal,
preservando o alpha. Criados os 151 `mon_XXX_shiny.png` que faltavam desde a sessão anterior (o
sistema de sorteio 1/4096 já existia, só não tinha arte própria pra mostrar ainda).

**Achado logo depois de rodar o script, corrigido antes de testar**: `SpriteBuilder.
build_pokemon_frames()` ainda tinha a detecção de formato da sessão anterior, pensada pra uma
hipótese de "48×64/tile 16" que nunca chegou a ser usada — a arte real saiu maior (96×128/tile 32,
igual ao Treinador). Sem a correção, cada sprite seria fatiada com o tamanho errado e toda imagem
sairia corrompida. Corrigido pra checar `>=96×128` e fatiar com tile 32.

**Escala ajustada nos 3 lugares que desenham Pokémon** (`WildPokemon.gd`, `FollowerPokemon.gd`,
`PokemonEntity.gd`): a arte nova já nasce 2× maior que o placeholder antigo, então a escala no
código caiu pela metade (4.0→2.0 nos dois primeiros, 2.0→1.0 no terceiro) pra manter o mesmo
tamanho em tela — sem isso, todo Pokémon apareceria com o dobro do tamanho certo.

**1 teste antigo ficou desatualizado e foi corrigido** (`teste_fase5_shiny_e_sprite4dir.gd`):
esperava que a espécie 1 (Bulbasaur) ainda caísse no fallback "sem variante shiny gerada" — agora
ela tem a própria. Também trocado o teste de "formato antigo" pra usar o `placeholder.png` (que
continua 32×16 de verdade) em vez da espécie 1 (que agora já é o formato novo).

**Testado:** suíte inteira (48 arquivos, incluindo os 2 ajustes acima) — **0 falhas**. Depois,
export Web + nginx + Playwright (Chromium headless) jogando de verdade: Novo Jogo → Bulbasaur
inicial → andar até a Rota 1 → Bulbasaur (Follower) e 2 Pokémon selvagens diferentes na tela, todos
com a arte real (não mais placeholder), em escala proporcional ao Treinador e ao cenário, sem erro
de console relacionado a sprite. (O vulto humanoide de cabelo castanho visto num dos prints era um
NPC comum da Rota 1, não relacionado a este trabalho.)

**Não incluído, de propósito**: sprite de perfil verdadeiro (esquerda/direita hoje reaproveitam a
sprite de frente, só espelhada — não existe arte oficial de perfil pra Red/Blue), quadro de
caminhada (a arte de batalha é parada — Pokémon fica sem animação de "andar" por ora, mesmo
trade-off que outras partes do jogo já aceitaram). Fica pra o Gabriel decidir se quer desenhar/
gerar essas partes depois.

**Pendente, sem urgência** (não pedido nesta leva, mas mencionado antes): follower com movimento
mais orgânico tipo "corda" em vez do lag reto atual (o Gabriel pediu pra deixar pra depois);
customização/skins completas do Treinador (precisa de conversa própria de escopo antes de
começar).

---

## Preparação pras sprites (4 direções + shiny) e sombra de visibilidade (2026-09-02, sessão seguinte)

**Pedido do Gabriel: seguir com as sprites dos 151 Pokémon (4 direções + shiny, mesmo conceito do
player/tileset) e melhorar visibilidade/personalização do Treinador.** Tentei gerar a primeira
sprite (Bulbasaur) — **cota diária da ferramenta de imagem ainda travada** (mesmo dia de hoje,
confirmado por erro 429 de novo). Sem poder gerar arte agora, adiantei tudo que dava pra fazer
sem depender de imagem nova:

**`SpriteBuilder.build_pokemon_frames()` já aceita o formato novo de verdade.** Detecta sozinho
se o arquivo é o formato antigo (32×16, sem direção real, as 151 espécies até hoje) ou o novo
(48×64, 4 direções reais — mesmo layout já usado pro Treinador/NPC) só pelo tamanho da imagem.
Nenhuma espécie quebra enquanto espera a arte — no dia em que a cota liberar, gerar a sprite e
salvar no lugar certo já é suficiente, não precisa mexer em código de novo.

**Sistema de shiny implementado de ponta a ponta — achado importante: nunca tinha sido sorteado em
lugar nenhum do jogo.** O campo `is_shiny` já existia no save desde muito antes (usado pelo
combate por turno), mas nada nunca definia ele como `true` — a conquista "Shiny Hunter" do master
doc (1/4096) nunca podia acontecer de verdade. Agora: `WildPokemon` sorteia 1/4096 ao nascer no
mapa, `CaptureSystem` persiste esse resultado no Pokémon capturado, `FollowerPokemon` exibe o
shiny de quem já foi salvo. Sem a arte shiny ainda gerada, tudo cai pro sprite normal (mesma
convenção de fallback já usada no resto do projeto) — mecânica pronta, só falta a arte.

**Sombra de visibilidade no Treinador** — ele não tinha nenhum contraste com o chão, se perdia
visualmente em terrenos parecidos. Sombra oval construída em código (degradê radial, sem precisar
de arte nova) — resolve o pedido sem depender da cota travada.

**Testado**: 10 conferências novas headless (fallback de path em 3 níveis, formato antigo
continua funcionando, taxa de shiny confirmada estatisticamente em 20 mil tentativas, persistência
na captura) + suíte inteira (46 arquivos, 0 falhas) + navegador real confirmando a sombra visível
nos pés do personagem. Publicado.

**Pendente, precisa da cota liberar (amanhã)**: gerar de fato a primeira leva de sprites 4
direções + shiny, espécie por espécie, "aos poucos" como já combinado.

**Pendente, precisa de conversa com o Gabriel antes de começar**: personalização/skins do
Treinador — já existe uma especificação completa e grande (`docs/customizacao-personagem.md`,
sistema "Paper Doll" de camadas, ~57 peças) guardada desde 31/08 pra quando ele pedisse pra
começar. É um projeto grande por si só (UI de criação de personagem, formato de dado por peça,
compor camadas em tempo real) — vale alinhar o escopo antes de começar a construir, pra não
gastar a cota de imagem construindo a coisa errada.

---

## Times de ginásio completos e temáticos (2026-09-02, sessão seguinte)

**Pedido do Gabriel, depois do motor de combate pronto: cada líder de ginásio ganhar o time
completo (6 Pokémon, com 2 exceções) do tipo do próprio ginásio.** Antes, todo líder tinha só 2
Pokémon cravados (placeholder desde antes desta sessão). Times novos, level ascendente, mantendo
o "ás" (Pokémon mais forte) igual ao que já existia quando possível:

- **Brock** (Pedra, 6): Geodude, Kabuto, Omanyte, Rhyhorn, Graveler, Onix
- **Misty** (Água, 5): Psyduck, Poliwag, Poliwhirl, Staryu, Starmie
- **Lt. Surge** (Elétrico, 6): Pikachu, Magnemite, Voltorb, Magneton, Electabuzz, Raichu
- **Erika** (Planta, 6): Exeggcute, Parasect, Vileplume, Victreebel, Tangela, Exeggutor
- **Koga** (Planta+Veneno, 6): Oddish, Gloom, Bellsprout, Weepinbell, Ivysaur, Venusaur —
  **substituído por completo** (era Koffing/Weezing, veneno puro — pedido explícito do Gabriel
  de mudar pro tema Planta+Veneno, diferente do Koga canônico dos jogos originais)
- **Sabrina** (Psíquico, 6): Abra, Drowzee, Kadabra, Mr. Mime, Hypno, Alakazam
- **Giovanni** (Terra, 6): Rhyhorn, Nidoqueen, Nidoking, Dugtrio, Sandslash, Rhydon
- **Blaine** (Fogo, 5): Growlithe, Ponyta, Rapidash, Magmar, Arcanine

**Líder novo criado em Lavender, a pedido do Gabriel** ("Lavender tem um líder de Pokémon
fantasma", não existe no jogo original): **Morty** (nome emprestado do líder Fantasma de Johto,
já que Kanto/Gen 1 nunca teve um) — posicionado perto do Sr. Fuji, diálogo próprio
(`morty_gym`). **Achado que limita o time dele a 5, não 6**: a Geração 1 só tem 3 Pokémon do tipo
Fantasma no total (Gastly/Haunter/Gengar) — completado com Cubone/Marowak (o par mais associado a
Lavender/Torre Pokémon na lore, mesmo sendo tipo Terra). **Escopo definido, mais simples que um
ginásio completo**: só o combate (NPC treinador com time temático) foi ligado — não criei quest
`GYM-09`, insígnia nem prédio de ginásio próprio (o sistema de quests hoje é fechado em 8 ginásios
canônicos); se o Gabriel quiser o pacote completo depois, é um pedido à parte.

**Achado ao testar**: 8 testes antigos travavam o time EXATO de 2 Pokémon de antes (regressão
esperada de um dado que mudou de propósito, não bug) — atualizados pra conferir o time novo
completo, mesmo padrão já visto várias vezes nesta sessão (dado muda por pedido do Gabriel, teste
que travava o valor antigo precisa acompanhar).

**Testado**: 111 conferências novas headless (tipo de cada Pokémon bate com o tema do ginásio,
quantidade certa, nenhuma espécie repetida no mesmo time) + os 8 testes antigos corrigidos + suíte
inteira (45 arquivos, 0 falhas) + navegador real sem erros (edição direta em `WorldMap.tscn`, mais
arriscada que os outros arquivos — testado com cuidado extra). **Não testado ao vivo em batalha
real** — os ginásios ficam longe do spawn (mesma limitação de alcance já registrada na Fase 7).
Publicado.

---

## Motor de combate em tempo real — Fase 10, PLANO INTEIRO COMPLETO (2026-09-02, sessão seguinte)

**Última fase do plano: densidade de Pokémon selvagem por profundidade na floresta — "vira uma
luta de sobrevivência", pedido original do Gabriel.** Espécie por área continua exatamente igual
(a tabela de `zones.json` não foi tocada) — só a VELOCIDADE de spawn aumenta quanto mais fundo o
jogador entra. "Fundo" = distância até a borda mais próxima do `tile_rect` que a zona já tinha em
`zones.json` (achado: não precisou de nenhum campo novo no JSON, o dado já existia). Só zonas com
"forest" no id (hoje só a Floresta de Viridian) — decisão nossa, a pesquisa de Tibia/PokeXGames não
confirmou nenhuma fonte real pra "mais fundo = mais inimigos", é design seguindo a descrição do
Gabriel. `MAX_WILD_INSTANCES` continua sendo o teto de segurança absoluto (nunca mais Pokémon no
mapa inteiro do que isso, protege performance).

**Testado**: 6 conferências novas headless (intervalo normal fora de floresta, intervalo no teto
mínimo no centro, decrescente conforme mais fundo, nunca abaixo do teto, espécie por zona
intocada) + suíte inteira (44 arquivos, 0 falhas) + navegador real sem erros. Publicado.

---

## 🏁 Plano do motor de combate em tempo real — TODAS AS 10+ FASES COMPLETAS

Do pedido original do Gabriel ("estude o modo de batalha de tibia... desenhe as skills conforme
outros poketibias... vamos focar em fazer um poketibia melhorado") até aqui, numa sessão só:

- **Fase 0** — HP/dano/desmaio do Treinador
- **Fase 0.5** — seleção de alvo por clique/toque + barra de vida/nível
- **Fase 1** — habilidades (Blaze/Overgrow/Torrent/Guts) ligadas fora do turno
- **Fase 2** — habilidades passivas NOVAS (Mega Drain do Vileplume, Counter Helix do Scyther)
- **Fase 3** — `moves.json` com cooldown/alcance/área de verdade
- **Fase 4** — dano em área funcionando (sem fogo amigo)
- **Fase 5** — XP/level-up/loot/Pokédex/quest unificados fora do turno
- **Fase 6** — sistema de captura em tempo real revivido e corrigido
- **Fase 7** — tela de batalha por turno desligada de vez (selvagem + treinador/ginásio)
- **Fase 8** — checklist (bug de posição pós-batalha resolvido por estrutura)
- **Fase 9** — skill flutuando + botão de skill tocável no HUD + atalho configurável
- **Fase 10** — densidade de spawn por profundidade na floresta

**Zona Safari continua no sistema por turno de propósito** (isca/pedra/bolas limitadas não eram o
pedido, arriscar quebrar sem necessidade não valia a pena — fica pra quando o Gabriel pedir).

Ao todo: ~190 conferências automáticas novas, suíte inteira sempre revalidada a cada fase (chegou
a 44 arquivos), cada fase confirmada em navegador real antes de publicar. Plano completo em
`/root/.claude/plans/adaptive-tickling-reddy.md`.

**Pendências registradas pelo próprio Gabriel, deixadas pra depois por ele mesmo**:
- Jeito do Pokémon seguidor andar mais "orgânico" (tipo coleira solta, não sempre exatamente atrás
  na direção cardeal oposta) — "isso é coisa simples, deixe pra depois".
- Reorganização geral do mapa em continentes/ilhas + tema visual por cidade (ver entrada de
  02/09 mais acima, "Cronograma reorganizado") — planejada, não iniciada.

---

## Motor de combate em tempo real — Fase 9 (2026-09-02, sessão seguinte)

**A peça visual do print original do Gabriel, mais 2 pedidos que ele fez na sequência ao ver o
progresso: (1) skill visível/tocável no HUD, não só atalho de teclado escondido; (2) atalho
configurável.** Skill de golpe agora aparece flutuando sobre o alvo (nome + dano, cor por tipo de
efeito — laranja pra área, amarelo pra golpe único, verde pra Mega Drain curando, roxo pro
"Reflexo!" do Counter Helix) — `FloatingText.gd` novo, mesmo padrão de nó-temporário-com-Tween que
`CaptureSystem.throw_pokeball()` já usava. HUD ganhou 4 botões de verdade (não só indicador) com o
nome do golpe de cada slot — **tocáveis** (funciona em touch, não só teclado) e com barra de
cooldown fina embaixo.

**Achado que resolveu o 2º pedido de graça**: `KeybindManager.gd` já tinha sistema de rebind
COMPLETO (reatribuir tecla, salvar em disco, detectar conflito) — só que `skill_1-4`/`pokebola`
ficavam de fora da lista de reatribuíveis por um motivo que o próprio código documentava:
"nunca foram ligadas a nenhuma função no jogo". Agora que são (Fases 0.5-6), bastou tirar essas 5
ações dessa exclusão — a tela de Controles já é 100% genérica, escreve as linhas sozinha.

**Achado de posicionamento (só neste PC, corrigido antes de publicar)**: os botões nasceram fora
da tela na primeira tentativa — `set_anchors_preset()` chamado ANTES dos filhos existirem calcula
a posição com o container ainda 0×0. Corrigido chamando depois de montar os 4 botões.

**Testado**: 22 conferências novas de UI (Fase 9) + 14 de rebind + suíte inteira (43 arquivos, 0
falhas) + **confirmado ao vivo no navegador**: botões "Tackle"/"Growl" (moveset real do Bulbasaur
Lv.5) aparecendo certos, tocáveis, na posição certa. Publicado.

**Próximo passo**: só falta a Fase 10 (densidade de Pokémon selvagem por profundidade na
floresta — "luta de sobrevivência", o pedido original do Gabriel) pra fechar o plano inteiro.

---

## Motor de combate em tempo real — Fase 7 (2026-09-02, sessão seguinte)

**A fase mais arriscada de todo o plano: tela de batalha por turno desligada de vez, pra selvagem
comum E pra treinador/ginásio.** Confirmado ao vivo no navegador: Pokémon selvagem aparece com
barra de vida + nível flutuando DIRETO NO MAPA, do lado do jogador — nenhuma tela abre.

**Como foi feito, sem reescrever o `BattleManager`:** `WildPokemon._set_state()` parou de emitir
`wild_encounter_started` (o gatilho que troca de tela) pra qualquer encontro comum — só continua
emitindo pra Zona Safari (`zone_id == "safari_zone"`), que **fica de propósito no sistema por
turno por enquanto** (isca/pedra/bolas limitadas são uma mecânica só dela, ainda não portada — não
era o pedido do Gabriel, e arriscar quebrar algo que já funciona sem necessidade não valia a pena).
Um sinal novo, `wild_pokemon_engaged`, mantém o efeito cosmético (câmera balançando, som) pra
QUALQUER encontro, Safari ou não, sem acoplar ao sistema por turno.

**Batalha de treinador/ginásio agora é uma SEQUÊNCIA de Pokémon reais no mapa** (mesma classe
`WildPokemon`, com `is_trainer_owned=true`, nasce direto agressivo) — vence um, o próximo "sai da
bola" automaticamente, igual jogo clássico, sem abrir tela nenhuma. `NpcEntity.gd` ganhou esse
sequenciamento; `BattleResolver.gd` ganhou uma versão de fim-de-combate pra Pokémon de treinador
(mesma fórmula de XP, sem loot/Pokédex — não é selvagem —, com o nome do treinador certo no sinal
de quest).

**2 achados de regressão pegos ANTES de publicar** (não pelo teste automático, por leitura
cuidadosa do código): (1) a pesca (`_try_fish()`) ainda emitia o sinal antigo direto pra forçar
batalha assim que fisgava — corrigido pra só marcar o peixe como "hostil" (ATTACK), o resto já é o
mesmo combate em tempo real; (2) `SaveManager.mark_seen()` (marca "visto" na Pokédex) só
acontecia quando o encontro esquentava no sistema antigo — sem essa emissão, pararia de marcar
qualquer coisa. Corrigido marcando "visto" assim que o Pokémon nasce no mapa (mais correto até,
cobre selvagem e Pokémon de treinador igual).

**Achado de infraestrutura (3ª vez na sessão)**: `class_name CaptureSystem` cravado colidiu com o
autoload — resolvido na Fase 6, mencionado aqui porque o padrão se repetiu: sempre que um autoload
novo é registrado, checar se o script não tem `class_name` do mesmo nome.

**Fora do escopo desta fase, achado mas não tocado**: existe uma classe `PokemonEntity.gd`/
`PokemonSpawner.gd` mais antiga, com o MESMO tipo de disparo direto pro sistema por turno —
confirmado que é código morto de verdade (só usado em 3 cenas de cidade avulsas — Route1/
PalletTown/ViridianCity — que nada no jogo aponta mais, substituídas pelo `WorldMap.tscn`
unificado). Deixado como está, documentado aqui pra não ser esquecido se um dia for religado.

**Testado**: 17 conferências novas headless (sequência de treinador, sinal correto, Zona Safari
preservada, Pokédex, cosmético desacoplado) + suíte inteira (41 arquivos, 0 falhas) + **confirmado
ao vivo em navegador real**: Pokémon selvagem com barra de vida/nível direto no mapa, zero tela de
batalha. Não testado ao vivo (só headless): a sequência de treinador/ginásio de ponta a ponta —
os treinadores reais do jogo ficam em dungeons (Rocket Hideout, Silph Co, Torre Pokémon), longe
demais do spawn pra alcançar num teste de navegador dentro do tempo desta sessão; a lógica está
validada a fundo pelos 17 casos headless. Publicado.

**Próximo passo**: Fase 8 é só checklist (confirmado — o bug de posição já não existe mais, porque
nenhuma batalha troca de cena). Fase 9 (skill flutuando + cooldown visual, o pedido original do
print) e Fase 10 (densidade de spawn por profundidade na floresta) ainda faltam.

---

## Motor de combate em tempo real — Fase 6 (2026-09-02, sessão seguinte)

**Sistema de captura em tempo real revivido, corrigido.** `CaptureSystem.gd` já existia pronto
desde muito antes (arremesso em arco, fórmula de chance) mas nunca tinha sido ligado a nada —
órfão, sem autoload, sem tecla. **Achado o bug real dele**: gravava o Pokémon capturado numa
lista local (`team`/`pc_box`) do próprio script, nunca no save de verdade — a captura "funcionava"
visualmente mas o Pokémon sumia ao recarregar o jogo. Corrigido reaproveitando o MESMO caminho que
o combate por turno já usa (`BattlePokemon.create()` gera IVs/nature/moveset novos de verdade,
`SaveManager.make_caught_data()` já sabe montar o formato de save completo, `SaveManager.
add_pokemon()` grava pra valer). Tecla "pokebola" (Espaço) **já existia no mapa de input, nunca
usada** — mais uma peça pronta esperando ligação. Pokémon de treinador ganhou um campo
`is_trainer_owned` (hoje sempre false — todo `WildPokemon` é selvagem — mas pronto pra Fase 7)
que trava a captura.

**Achado de infraestrutura (2ª vez na mesma sessão)**: `CaptureSystem.gd` tinha um `class_name
CaptureSystem` cravado do código órfão original, que colidiu com o autoload de mesmo nome que
acabei de registrar ("hides an autoload singleton") — removido; o nome já é o do autoload, não
precisa de `class_name`. E de novo o cache global de classes ficou desatualizado até rodar
`godot4 --headless --editor --quit-after 3`.

**Testado**: 8 conferências novas headless (captura vai pro save de verdade, moveset/IVs/nature
completos, Pokémon de treinador nunca capturável) + suíte inteira (40 arquivos, 0 falhas) +
navegador real confirmando a tecla funcionando de ponta a ponta (mensagem "não tem selvagem por
perto" aparecendo certo). Publicado.

**Fases 0 a 6 do plano — TODAS entregues.** Só falta a mais arriscada (Fase 7: desligar de vez a
tela de batalha por turno, migrar treinador/ginásio pro mesmo motor) e o polimento (Fase 8
checklist, Fase 9 UI de skill flutuando, Fase 10 densidade de spawn por profundidade). Plano
completo em `/root/.claude/plans/adaptive-tickling-reddy.md`.

---

## Motor de combate em tempo real — Fase 5 (2026-09-02, sessão seguinte)

**Fim-de-combate (XP/level-up/loot/Pokédex/quest) unificado pra qualquer batalha em tempo real.**
Antes, `WildPokemon._die()` só tinha sua própria versão simplificada (`_roll_loot()` — item por
espécie, sem XP, sem level-up, sem contar na Pokédex). `BattleResolver.gd` novo (autoload) porta a
mesma fórmula que o combate por turno já usava (`BattleManager._end_battle()`, reaproveitando até
a função estática de EXP base de lá, sem duplicar) e emite `EventBus.battle_ended` no MESMO
formato que o `QuestManager` já espera — quest de "derrote 5 Rattata" funciona sem tocar
`QuestManager.gd`. `_roll_loot()` aposentada (usava uma tabela de item por espécie desconectada da
`LootTable` oficial, que já dá bônus de sorte do Treinador).

**Testado**: 12 conferências novas headless (XP somando, level-up de verdade, Pokédex, sinal de
quest no formato certo, sem duplicar XP em derrotas repetidas) + suíte inteira (39 arquivos, 0
falhas) + navegador real sem erros. Publicado.

**Próximo passo**: Fase 6 (reviver o sistema de captura em tempo real que já existe no código,
órfão desde sempre — corrigindo o bug real dele: hoje grava o Pokémon capturado numa lista própria,
não no save de verdade).

---

## Motor de combate em tempo real — Fase 3 e Fase 4 (2026-09-02, sessão seguinte)

**Fase 3 — `moves.json` ganhou cooldown/target_type/radius de verdade.** Antes disso, todo golpe
em tempo real caía num valor fixo cravado no código (2s, sempre corpo-a-corpo, sempre mira única)
porque esses campos nunca existiam no JSON. Script de migração (`scripts/tools/
migrate_moves_realtime.py`, guardado no repositório) preencheu os 158 golpes: cooldown
proporcional à força do golpe (mais forte = recarrega mais devagar, evita spam de graça),
6 golpes canonicamente de área no Pokémon de verdade (Terremoto, Surf, Nevasca, Deslizamento de
Rochas, Autodestruição, Explosão) marcados `target_type:"area"` com um raio, resto continua
`"single"`. **Achado ao editar**: usei `json.dump` sem cuidado uma vez e ele reformatou o arquivo
inteiro (o `species.json` é escrito num estilo compacto, uma linha por Pokémon, à mão) — desfeito
e reaplicado como edição cirúrgica só nas 2 linhas certas.

**Fase 4 — função de dano em área, não existia nenhuma antes.** `AreaTargeting.gd` novo busca
alvos num raio reaproveitando os mesmos grupos (`wild_pokemon`/`follower_pokemon`/`player`) que
o resto do combate já usa. Ligado em `FollowerPokemon`/`WildPokemon`: golpe de área bate em todo
mundo do lado oposto dentro do raio, **nunca no próprio time** (decisão confirmada com o Gabriel —
sem fogo amigo). Também resolvido o pedido do Gabriel sobre seleção de alvo: golpe de área
funciona SEM precisar de alvo selecionado (mira a partir da própria posição), golpe de mira única
continua travado sem seleção — regra completa agora.

**Achado de infraestrutura pro projeto (vale lembrar em sessões futuras)**: criar um script `.gd`
novo com `class_name` (caso do `AreaTargeting.gd`) não é reconhecido de imediato pelos testes
headless — nem `godot4 --headless --import` resolve. Precisa rodar
`godot4 --headless --editor --quit-after 3` uma vez pra registrar de verdade no cache de classes
globais antes de qualquer teste que use a classe nova.

**Testado**: 38 conferências novas headless (30 na Fase 3, 8 na Fase 4) + suíte inteira (38
arquivos, 0 falhas) + navegador real sem erros novos no console. Publicado.

**Próximo passo**: Fase 5 (unificar fim-de-combate — XP/level-up/loot/quest — pra qualquer batalha
em tempo real) e Fase 6 (reviver o sistema de captura em tempo real que já existe no código, órfão).

---

## Motor de combate em tempo real — Fase 1 e Fase 2 (2026-09-02, sessão seguinte)

**Fase 1 — Ligar `ability` (Overgrow/Blaze/Torrent/Guts) fora do turno.** Já existia por espécie
e já era testada dentro de `BattleManager`, só nunca era lida por `WildPokemon`/`FollowerPokemon`.
Copiado (não movido, pra não arriscar o teste do turno já existente) pra `DamageCalculator.gd`
como função separada, recebendo primitivos em vez de um `BattlePokemon`. Guts fica sem efeito no
tempo real por ora — falta status persistente (queimadura/paralisia), lacuna conhecida, não bug.

**Fase 2 — Habilidade passiva NOVA, disparando sozinha (pedido do Gabriel com 2 exemplos
concretos).** Mega Drain do Vileplume: a cada tanto tempo (aleatório), bate em quem estiver
atacando ele e cura a mesma soma causada. Counter Helix do Scyther: devolve pro atacante mais
recente o dano total recebido desde o último disparo. O timer fica MAIS CURTO quanto mais
atacantes distintos bateram desde a última vez — "mais frequente quando cercado", como o próprio
Gabriel descreveu (não é convenção de nenhum jogo pesquisado, é design nosso). Guardado como
campo novo `"passive"` por espécie em `species.json` — só Vileplume e Scyther por ora, os únicos
2 exemplos pedidos; extensível pra qualquer espécie depois.

**Testado**: 21 conferências novas headless (10 na Fase 1, 11 na Fase 2) + suíte inteira (36
arquivos, 0 falhas) + navegador real sem erros novos no console. Publicado.

**Próximo passo**: Fase 3 (estender `moves.json` com cooldown/alcance/área — hoje nenhum golpe
tem isso, cai sempre no padrão fixo) e Fase 4 (função de dano em área, ainda não existe nenhuma).

---

## Motor de combate em tempo real — Fase 0 e Fase 0.5 (2026-09-02, sessão seguinte)

Plano completo (10+ fases) desenhado com o Gabriel e aprovado — ver
`/root/.claude/plans/adaptive-tickling-reddy.md` — pra transformar toda batalha (selvagem e
treinador/ginásio) na mesma mecânica em tempo real, direto no mapa, sem tela separada, inspirada
no Tibia/PokéTibia/PokeXGames que o Gabriel pediu pra estudar. Duas fases já entregues:

**Fase 0 — HP/dano/desmaio do Treinador.** Achado que encolheu o trabalho: `WildPokemon` já
tentava atacar o jogador quando o Follower estava ausente (regra que o Gabriel pediu), e já
guardava com `has_method("take_damage")` antes de bater — só nunca fazia nada porque o Treinador
não tinha esse método. Sinais `trainer_hp_changed`/`trainer_died` já existiam no `EventBus`, nunca
emitidos. Ao desmaiar: cura o time e volta pro último Centro Pokémon visitado (as duas funções já
existiam, só nunca eram chamadas nesse fluxo) — sem perda permanente, convenção clássica.

**Fase 0.5 — Seleção de alvo por clique/toque + barra de vida/nível (pedido do Gabriel na
sequência, percebendo que faltava).** Achado parecido: `FollowerPokemon.use_skill()` já exigia
`current_target` setado, só que nada nunca setava esse valor — a mira de golpe único nunca
funcionava. Agora clicar/tocar no Pokémon selvagem seleciona ele (destaque visual), e cada
selvagem mostra sua própria barra de vida (verde/amarelo/vermelho) + nível acima da cabeça. Sem
alvo selecionado, nenhum golpe do Follower funciona (regra confirmada com o Gabriel).

**Testado**: 14 conferências headless novas nas duas fases + suíte inteira (34 arquivos, 0
falhas). Achado à parte, não corrigido (pré-existente, confirmado comparando com o build anterior
a esta sessão, mesmo roteiro): aviso de física no console ao andar ("Index p_layer_id = 0 is out
of bounds") — falta camada de colisão configurada em `overworld.tres`. **Fase 0.5 não confirmada
ao vivo em condição real de jogo ainda** — o Pokémon selvagem hoje ainda troca pra tela de batalha
por turno antes de dar tempo de clicar nele andando livre; só vai dar pra ver de ponta a ponta
depois da Fase 7 (quando o turno for desligado de vez). Publicado.

**Próximo passo**: Fase 1 (ligar `ability` — Overgrow/Blaze/Guts — no combate em tempo real, já
existe e testado, só nunca foi lido fora do turno) e Fase 2 (habilidade passiva nova por timer
aleatório — Mega Drain/Counter Helix, pedido do Gabriel com exemplos concretos).

---

## 🔖 Cronograma reorganizado — 3 pedidos novos do Gabriel (2026-09-02, sessão seguinte)

Gabriel mandou um print de outro jogo (habilidade "Poison Bomb"/"Acid" aparecendo flutuando em
cima do Pokémon, direto no mapa, sem trocar de tela) e pediu 3 coisas. Triei pelo critério que ele
mesmo deu: **simples e de baixo impacto → fica pra depois; difícil de mudar depois → fazer um
plano e começar agora.** Investigação de código pedida a um agente **falhou por limite de uso da
sessão** (não é erro do projeto, é cota da própria ferramenta) — retomando depois do intervalo que
o Gabriel pediu (30 min). Nada foi construído ainda, isto é só o trieamento.

**Item 1 — Bug: depois da batalha, o jogador volta pro ponto INICIAL do jogo, não pro lugar onde
a batalha começou.** Provavelmente simples e isolado (a cena do mundo deve estar recarregando do
zero com a posição padrão, em vez de restaurar a posição salva de antes da batalha) — **fica pra
corrigir assim que a investigação confirmar a causa**, não deve depender do Item 2.

**Item 2 — Batalha devia acontecer NO MAPA, em tempo real (sem tela separada, sem turno), com
skill de cooldown aparecendo flutuando como no print.** Achado importante, já confirmado por mim
mesmo lendo `WildPokemon.gd` nesta mesma sessão (antes do agente falhar): **o jogo já tem esse
sistema construído** — `FollowerPokemon.gd`/`WildPokemon.gd` já lutam em tempo real, com cooldown
por skill (`_cooldowns`, `use_skill(slot)`), hitbox/hurtbox e HP, exatamente como o Gabriel
descreveu. O problema é que, quando o encontro "esquenta" (Pokémon selvagem entra em estado
ATTACK), o jogo dispara `EventBus.wild_encounter_started` que aciona um SEGUNDO sistema, por
turnos, numa tela separada (`BattleManager`/`scenes/battle/BattleScene.tscn`) — é esse segundo
sistema que assume a "batalha de verdade" (captura, XP, prêmio de ginásio). **Isto se encaixa no
critério "fica mais difícil de mudar depois"**: quanto mais mecânica (Zona Safari com isca/pedra,
recompensa de ginásio, progresso de quest) for encostando no sistema por turnos, mais caro fica
tirar ele depois. **Por isso vira plano agora, não fica pra depois** — mas só depois de entender
exatamente tudo que hoje depende do `BattleManager` (investigação que falhou, será refeita).

**Item 3 — Mapa geral reorganizado: menos "tabuleiro de blocos de cor", mais continentes/ilhas
orgânicas ligadas por terra/túnel de pedra/mar, cada cidade com tema visual do próprio ginásio**
(Pewter=rochoso, Cerulean=aquático azul/ciano, Saffron=amarelo/rosa luxuoso+psíquico,
Lavender=roxo/preto veneno+fantasma, Fuchsia=verde/marrom planta+veneno, Cinnabar=vulcânico
vermelho/lava, Vermilion=amarelo/vermelho elétrico, Celadon=comercial+marítimo; Pallet como já
está). **Também se encaixa em "fica mais difícil de mudar depois"**: os mapas hoje são desenhados
à mão como texto (uma "arte ASCII" por mapa, em `MapLayouts.gd`) e NPCs/portas/pontos de spawn são
coordenadas fixas amarradas a esse desenho (foi exatamente o que tornou a migração do tile 16→32,
mais cedo hoje, uma mudança de ~160 posições em 40+ arquivos) — quanto mais conteúdo for
construído em cima da geografia de hoje, mais caro fica redesenhar depois. **Vira plano também**,
mas em segundo lugar depois do Item 2 (mudar o motor de batalha primeiro evita ter que mexer duas
vezes no mesmo mapa). Tem uma dependência direta com o trabalho de arte que já começou hoje
(v0.6.6/v0.6.7): se cada cidade vai ganhar um visual próprio, o tileset novo não pode ser só 1
genérico — precisa nascer pensando nas variações por bioma, pra não ter que gerar tudo de novo.

**Ordem de execução decidida**: 1) corrigir o bug de posição (rápido, isolado) → 2) investigar e
planejar o motor de batalha em tempo real no mapa (arquitetura, o mais arriscado de deixar pra
depois) → 3) planejar a reorganização do mapa geral + variações de bioma no tileset (depende da
decisão do Item 2 estar tomada). Nenhum código foi alterado ainda.

---

## v0.6.7 — Primeira arte nova de verdade do tileset do mapa (2026-09-02, sessão seguinte)

**Continuação direta da v0.6.6** (mapa dobrado pra 32px), mesma sessão. Gerada a primeira arte de
verdade dos 16 tiles do mapa (grama, caminho, flor, areia, água, árvore, rocha, parede, porta,
telhado, cerca, sebe, piso, tapete, grama clara, caminho escuro), no estilo da referência Stardew
Valley que o Gabriel mandou em 02/09 — sombra/textura de verdade, não bloco de cor lisa.

**Técnica**: 1 geração só (modelo `gpt-image-2`, bom pra grade/múltiplos painéis numa imagem só),
pedindo os 16 tiles numa grade 8×2 igual à ordem que o jogo já usa (`CHAR_MAP` em
`MapLayouts.gd`) — assim a arte nova entra nos MESMOS 16 lugares de sempre, sem mexer em nenhum
mapa nem no código de desenho. Cota diária bateu de novo depois de 3 das 4 variações pedidas —
as 3 que saíram foram comparadas, a mais limpa escolhida, recortada (16 quadrados, cada um
centralizado dentro da célula) e reduzida pra 32×32 com filtro que não borra pixel art. As outras
2 variações guardadas em `docs/referencias/tileset-gerado-ia-opcao-A/B.png` pra comparação futura.

**Achado, ainda não corrigido**: os tiles de Caminho e Piso mostram uma "costura" visível quando
repetidos lado a lado (a textura não fecha 100% nas bordas) — dá pra ver de longe no mapa. Os
outros 14 tiles (grama, água, flor, árvore, rocha, cerca, porta, telhado, sebe, tapete...) ladrilham
bem. Fica pra um próximo lote, regerando só esses 2.

**Testado**: suíte inteira de novo (32 arquivos, 0 falhas — troca de imagem não mexe em lógica) +
navegador de verdade (Chromium/Playwright): partida nova, andei, câmera e seguidor continuam
corretos com a arte nova. Publicado.

**Próximo passo**: corrigir a costura de Caminho/Piso quando a cota liberar, depois seguir pra
sprites individuais (jogador + cada Pokémon nas 4 posições + shiny), um lote por dia.

---

## v0.6.6 — Mapa dobrado de 16px pra 32px por tile, base pra arte nova (2026-09-02, sessão seguinte)

**Sessão anterior fechou abruptamente de novo**, bem no meio de preparar a geração da primeira
arte nova (mapa). Retomada com `git status` (limpo, nada perdido).

**Pedido do Gabriel**: começar a melhoria gráfica do jogo pelo mapa. Antes de gerar qualquer
arte, achei uma decisão de arquitetura real: o tile do mundo é 16×16px hoje, e a mesma descoberta
já feita com a sprite da Bicicleta ("16×16 vira ruído ilegível pra IA") ia valer pro mapa também.
**Gabriel escolheu dobrar o mapa pra 32×32** (opção recomendada) — mesmo isso tocando câmera,
colisão e distância de aparição de Pokémon selvagem em código.

**Levantamento completo antes de mexer** (pedido a um agente, sem tocar em nada): achou 6
constantes `TILE_SIZE` independentes (não uma só) espalhadas em 6 arquivos `.gd`, zoom de câmera
fixo em 33 cenas, colisão (`CapsuleShape2D`/`CircleShape2D`/`RectangleShape2D`) hardcoded em
pixel absoluto em 43 cenas, e o achado mais importante: **163 posições de spawn de jogador/NPC/
treinador** em todo mapa também em pixel absoluto — nada disso calculado a partir de uma
constante central, tudo manual. `zones.json` e o resto dos dados em JSON já usavam índice de
tile (não pixel), então ficaram de fora, seguros.

**Migração feita com um script Python auditável** (`scripts/tools/migrate_tile32.py`, mantido no
repositório) que dobra automaticamente posição/raio/altura/tamanho de colisão/limite de câmera em
`scenes/world`, `scenes/entities` e `scenes/combat` (nunca em `scenes/ui` nem `scenes/battle`,
que são tela/menu, não mundo) — e ajusta o zoom da câmera pra metade (3,0 → 1,5) pra manter a
mesma área visível de antes, já que o mundo dobrou fisicamente de tamanho. **Achado no meio do
caminho, corrigido antes de aplicar**: o próprio script quase dobrou `spawn_radius` (Pokémon
selvagem, em TILES) por engano, só porque o nome contém a palavra "radius" — o raio de colisão de
verdade (pixels) tem esse nome sem prefixo. Corrigido com uma exceção no regex, e os 3 valores
afetados (Pallet Town/Rota 1/Viridian) revertidos à mão antes de seguir.

**Overworld.png ampliado 2x sem perda** (ImageMagick, `-filter point`, upscale "quadrado a
quadrado" sem borrar) — os mesmos 16 tiles de sempre, só maiores; a arte nova de verdade (mais
detalhada, parecida com a referência que o Gabriel mandou) fica pro próximo passo, feito à parte
pra isolar risco de arte do risco de mecânica. Sprites antigas de personagem/Pokémon (ainda em
16px — `player.png`, `npc_*.png`, `mon_*.png`) ganharam `scale` dobrado (Treinador/NPC: 1→2;
Pokémon selvagem/seguidor: 2→4) só pra continuar do tamanho certo dentro do tile novo, até
ganharem arte nativa em 32px de verdade.

**Testado**: suíte inteira rodada de novo (32 arquivos, 0 falhas reais — 2 testes que faziam
conversão manual pixel→tile com `/16` cravado no código foram corrigidos pra `/32`). **Confirmado
em navegador de verdade** (Playwright/Chromium): partida nova, andei nas 4 direções — Pokémon
seguidor sempre no quadro certo, sem sobrepor; câmera enquadrando bem; colisão bloqueando cerca
corretamente; voltei andando e a câmera acompanhou certo, revelando um prédio novo fora da tela
anterior. Publicado.

**Próximo passo**: gerar a arte nova de verdade do tileset (grade de tiles no estilo da segunda
referência que o Gabriel mandou, 02/09 — sombra/textura de verdade), depois seguir pros sprites
individuais (jogador + cada Pokémon nas 4 posições + shiny), gerando aos poucos por causa da cota
diária da ferramenta de imagem (decisão já tomada pelo Gabriel: dia a dia).

---

## v0.6.5 — Pokémon seguidor nunca mais sobrepõe o Treinador (2026-09-02, sessão seguinte)

**Sessão anterior fechou abruptamente de novo**, no meio da verificação em navegador desta mesma
correção. Retomada com `git status` (achado: os 3 arquivos de código já modificados e corretos,
nada perdido — só faltava rodar a suíte de novo e confirmar visualmente antes do commit).

**Pedido do Gabriel**: o Pokémon que segue o treinador não pode, em hipótese alguma, sobrepor o
sprite dele — precisa ficar sempre 1 quadro de distância no sentido oposto a pra onde o treinador
está olhando (Norte→Sul, Sul→Norte, Leste→Oeste, Oeste→Leste), nunca na diagonal.

**O que havia antes**: o seguidor perseguia um "rastro" de posições passadas do Treinador
(gravado a cada frame, ~24px atrás) — ficava mais natural em linha reta, mas numa curva podia
passar um instante fora do eixo cardeal, sobrepondo os dois sprites (o do Pokémon é desenhado 2x
maior que o padrão do jogo, então a sobreposição ficava bem visível).

**Corrigido**: removido o mecanismo de rastro inteiro (`_trail`/`_record_trail`/
`_update_follower`/`set_target_position`, em `TrainerEntity.gd` e `FollowerPokemon.gd`) — o
seguidor agora sempre calcula sozinho `trainer.global_position - facing_vector * FOLLOW_DISTANCE`,
nunca guarda histórico. Mais simples e sem essa classe de bug ser possível.

**Testado**: 5 conferências novas em `teste_fase4_mecanicas_movimento.gd` (as 4 direções +
"nunca fica na diagonal") — suíte inteira, 32 arquivos, 0 falhas. **Confirmado em navegador de
verdade** (Chromium via Playwright, container `mcr.microsoft.com/playwright`, contra o build Web
servido com os headers `Cross-Origin-*` exigidos pelo Godot Web export — o servidor Python simples
usado antes não tinha esses headers e travava o jogo no carregamento): joguei uma partida nova
(Bulbasaur) e andei nas 4 direções — Pokémon sempre 1 quadro atrás, nunca sobreposto, nas 4
capturas de tela. Publicado.

**Achado à parte, corrigido no mesmo commit**: `docs/referencias/sprite-bike-gerado-ia.png.import`
estava sem versionar desde o commit da sprite da Bicicleta (02/09, sessão anterior) — mesma
classe de esquecimento já vista antes neste projeto, adicionado ao Git agora.

**Próximo passo**: melhoria gráfica do jogo (mapa + sprites individuais do jogador e de cada
Pokémon nas 4 posições — frente/costas/lateral esquerda/lateral direita — e versões shiny) — pedido
pelo Gabriel na mesma sessão que fechou abruptamente, **ainda não iniciado**. Precisa de uma
conversa de escopo antes de começar a gerar sprite (é trabalho grande, cota diária da ferramenta
de imagem é limitada).

**Precisa de decisão do Gabriel?** Sim, sobre o escopo da melhoria gráfica (ver "Próximo passo").

---

## v0.6.4 — botão "Voar" da HUD/pausa virou "Teleporte" (2026-09-02, sessão seguinte)

**Sessão anterior (a que criou v0.6.1-v0.6.3) fechou abruptamente de novo**, bem no meio de eu
resumir o que tinha ficado pronto. Retomada com `git status` (limpo — nada perdido, tudo já
commitado) e lendo o fim da conversa anterior pra achar o que ficou sem resposta.

**O que aconteceu**: no resumo que fechou a sessão passada, o botão "Voar" da HUD tinha ficado
descrito como "abre a lista de cidades direto" — um teletransporte. O Gabriel corrigiu: Voar
**não é teleporte**, é uma mecânica de movimento (montar num Pokémon Voador pra atravessar a água
mais rápido) — que, aliás, já tinha sido construída certa desde o v0.6.1 (TrainerEntity.gd,
`is_flying`/`_pode_voar`). O erro foi só o botão extra que eu tinha adicionado no HUD/menu de
pausa, chamado "Voar", fazendo uma coisa completamente diferente (viajar pra outra cidade).

**Pergunta feita ao Gabriel**: o que fazer com esse botão de teletransporte — remover, ou manter
como outra coisa? **Resposta**: reaproveitar pra Pokémon do tipo **Psíquico que sabem o golpe
Teleporte** (efeito clássico dos jogos — Abra e evoluções já aprendem Teleporte no nível 1, sem
precisar de MT/MO nova). Corrigido: botão renomeado "Teleporte" (HUD e menu de pausa), trava
trocada de `team_has_move_of_type("fly","Flying")` pra `team_has_move_of_type("teleport",
"Psychic")`, textos do seletor de destino atualizados. Voar (a mecânica de movimento) não mudou
nada — já estava certa. 2 testes novos (Pidgeot com Voar NÃO destrava Teleporte; Abra com
Teleporte destrava) — suíte inteira reconferida (34 arquivos, 0 falhas). Publicado.

---

## v0.6.1 a v0.6.3 — correções de Surf/Voar/Montaria + HUD + sprite da Bicicleta (2026-09-02, sessão seguinte)

**Sessão anterior fechou abruptamente com trabalho pronto mas sem commit** — retomada
conferindo `git status` primeiro (achado: 5 arquivos modificados, tudo testado, só não publicado).
Commitado, suíte reconferida (570 conferências, 0 falhas) e publicado como v0.6.1 antes de seguir.

**v0.6.1 — correções pedidas pelo Gabriel:** Surfar agora exige que o Pokémon que sabe o golpe
seja do tipo Água (antes valia qualquer um sabendo o golpe); mesma regra pro Voar exigindo tipo
Voador. **Montaria nova**: Tauros/Dodrio/Rhyhorn/Rhydon/Arcanine/Ponyta/Rapidash no time dá uma
marcha mais rápida que a Bicicleta, mais lenta que Voar — 4 marchas agora, prioridade fixa
Voar > Surfar > Montaria > Bicicleta > Andar.

**v0.6.2 — HUD personalizado, sem pausar o jogo.** Pedido do Gabriel: acesso às funções de
locomoção sem abrir menu. Indicador de marcha (texto colorido, some quando "a pé") cobre o
feedback visual enquanto o sprite não muda por marcha ainda. Botão "Voar" na HUD abre o seletor
de destino direto (`PauseMenu.open_fly_picker_direct`, reaproveita a mesma lista/warp do Menu de
Pausa, não duplicada) — só pausa o necessário pra escolher a cidade, painel de pausa inteiro nunca
abre. `EventBus.movement_mode_changed` novo, emitido só quando a marcha muda de verdade.

**v0.6.3 — primeiro lote de "sprites melhoradas": Bicicleta.** Gabriel escolheu "IA gera os
desenhos agora" entre 3 opções que dei (as outras eram indicador simples ou esperar arte dele).
Achado que definiu a técnica: pedir um grid 2x2 com as 4 direções (down/up/left/right) NUMA
imagem só funciona bem e sai bem mais barato que gerar direção por direção — usado pras próximas
também. Processado com ImageMagick (recortar quadrantes, tirar fundo branco, centralizar,
montar spritesheet 96×128). **32×32, não 16×16** (o resto do jogo) — testei os dois, 16×16 virava
ruído ilegível; a decisão já estava prevista em `docs/customizacao-personagem.md` ("sprite maior,
footprint de colisão continua pequeno"). `SpriteBuilder` ganhou parâmetro `tile` (default 16,
compatível com o resto do jogo); `TrainerEntity` compensa a posição Y na troca de sprite.

**Bloqueio real, não escolha:** só a Bicicleta ganhou arte nova — gerar Montaria/Surf/Voar bateu
na cota diária GRÁTIS da ferramenta de imagem (ElevenLabs) depois de 2 gerações bem-sucedidas +
1 tentativa (Montaria, "pessoa montada num Tauros") bloqueada pelo filtro de conteúdo da própria
ferramenta (parece falso positivo — vou reformular o prompt na próxima tentativa). A lógica de
marcha das 3 já funciona normal, só não mudam a cara do personagem ainda.

**Testado:** suíte inteira (32 arquivos, 570 conferências, 0 falhas — nenhuma nova, mudanças de
HUD/sprite não tocam lógica de jogo) + headless import limpo, nas 3 versões. **Não confirmado em
navegador real desta vez** — o container Playwright usado em sessões anteriores deu um erro de
ambiente (`npm error Tracker "idealTree"`) que não consegui contornar a tempo; validado por
import sem erro de script + revisão de código + build/deploy real com `curl` confirmando 200.

**Próximo passo:** gerar Montaria/Surf/Voar assim que a cota da ferramenta de imagem renovar
(pedir com o prompt reformulado pra Montaria). Grid original da Bicicleta salvo em
`docs/referencias/sprite-bike-gerado-ia.png` pra não perder o material.

**Precisa de decisão do Gabriel?** Não por enquanto — só esperar a cota renovar.

---

## v0.6.0 — Mecânicas de movimentação: Bicicleta, Surfar e Voar (2026-09-02)

**Pedido do Gabriel: seguir com as mecânicas de movimentação, com autonomia total.** As 3
mecânicas planejadas desde 31/08 (Bicicleta/Surfar/Voar; Moto e montaria ficaram de fora — não
citadas de novo desde o plano original, sem prioridade clara) — todas construídas, ligadas de
ponta a ponta e publicadas na mesma sessão.

**Achado que virou a primeira correção: a "corrida" já existia solta, de graça, sem a Bicicleta.**
`TrainerEntity.gd` já lia `Input.is_action_pressed("run")` (Shift no teclado, botão B no toque) e
dobrava a velocidade — desde antes de qualquer uma dessas mecânicas existir, sem checar posse de
item nenhum. Corrigido: corrida agora exige `SaveManager.has_item("bicycle")`.

**Bicicleta (UTIL-03) destravada de ponta a ponta** — a quest já existia no `quests.json` desde o
plano original, mas nunca tinha NPC nem objetivo que funcionasse:
- NPC novo "Loja de Bicicletas" em Cerulean (referência real do Kanto original), `starts_quest_id
  = UTIL-03`. Posição conferida tile a tile contra o `MapLayouts` de verdade antes de usar
  (`location_tile` original do plano, (265,48), nunca bateu com a Cerulean construída — trocado
  por (245,19), chão aberto confirmado por teste).
- Objetivo original era `"type": "deliver"` (item/destino) — tipo sem handler no motor, mesma
  classe de ajuste já feita 6+ vezes na sessão anterior (história principal). Trocado por `"talk"`
  com o Marinheiro de Vermilion (NPC `vermilion_local`, já existia, só flavor).

**Surfar** — `TrainerEntity._is_tile_walkable()` agora permite o jogador (só o jogador — NPC
continua barrado de água, de propósito) entrar num tile de água SE algum Pokémon do time já sabe
o golpe "surf" (ensinado via MT11, já era 100% funcional — `PauseMenu._teach_and_finish` — só
precisava de alguém ensinando isso na prática). `is_surfing` é derivado (recalculado a cada tile
que o jogador entra), sobe/desce sozinho na água igual ao clássico. MT11 agora é recompensa do
GYM-05 (Koga/Fuchsia) — o `POKEMOBILE_MASTER.md` já previa "Badge 5 = Surf", só nunca tinha
entrado no reward de verdade.

**🔴 Achado no caminho, corrigido: GYM-02 (Misty) tinha `"hms": ["surf"]` — lista de texto solto**
(não de objetos `{id:...}`), formato que `QuestManager._give_rewards()` não sabe ler —
**derrubava o jogo com SCRIPT ERROR pra qualquer jogador de verdade que completasse o Ginásio da
Cerulean**, não só no teste. Removido (o Surfar de verdade já mora no GYM-05 com o id certo).

**Voar** — botão novo "Voar" no Menu de Pausa, só visível pra quem já tem o golpe "fly" no time
(recompensa nova do GYM-07/Sabrina — `POKEMOBILE_MASTER.md` também já prometia isso). Lista as
cidades que o jogador JÁ VISITOU (não precisa ter curado lá, só ter pisado — igual ao jogo
original) e teleporta pra 2 tiles ao sul da porta do Centro Pokémon de cada uma (posição real das
`WarpZone`s do `WorldMap.tscn`, também conferida tile a tile, não chutada — longe o suficiente pra
não cair dentro da área de gatilho do warp e entrar sozinho no Centro). **Achado: o save já tinha
um campo `world.visited_maps` preparado desde sempre, nunca escrito nem lido em lugar nenhum**
(mesma classe do achado de `reach_floor` antes de ganhar handler) — só precisou ligar no
`EventBus.zone_changed`. Indigo Plateau fica de fora de propósito (no jogo original também não dá
pra Voar até lá, só chegando por Victory Road).

**Testado**: suíte inteira headless (33 arquivos, 585 conferências, 0 falhas — 18 novas num
arquivo dedicado, `teste_fase4_mecanicas_movimento.gd`) + navegador real (Chromium via Playwright
num container Docker à parte): novo jogo, andar, abrir o Menu de Pausa — confirma que "Voar" fica
escondido certinho (sem quebrar o layout dos outros botões) até o jogador ter o golpe. **Não
testado ao vivo**: chegar de fato em Cerulean/Fuchsia/Saffron andando (são muito longe do spawn
pra um script de teclado navegar às cegas, mesma limitação já registrada em sessões anteriores
com a Pesca) — a lógica foi conferida pelo motor de testes, direto contra os mesmos dados e mapa
reais do jogo, não simulada à parte. Publicado (`docker service update --force`), `curl` confirma
200. Tag `v0.6.0`.

**Pendente, se o Gabriel quiser continuar depois**: Moto/montaria em Tauros-Dodrio (item do plano
original de 31/08, sem prioridade clara desde então); indicador visual de "surfando" (hoje o
sprite do jogador não muda ao entrar na água, só a lógica de movimento muda).

---

## v0.5.0 — A história principal está destravada (2026-09-02)

**Pedido do Gabriel: finalizar "Pokémon e estruturas" e destravar a história principal (MAIN-01
a MAIN-09), terminando no Ginásio de Viridian/Giovanni.** Maior entrega de conteúdo numa sessão
só até agora.

**Descoberta que mudou o escopo do trabalho**: o `QuestManager` já sabia, desde a Fase 0
(31/08), AUTO-INICIAR a próxima quest da cadeia (`unlocks`) assim que uma anterior completa —
só nunca tinha sido exercitado ponta a ponta. Isso significa que eu não precisei criar um NPC
"gatilho" pra cada quest da história — só fechar os OBJETIVOS de cada uma com conteúdo/mecânica
real, e a cascata inteira (Prof. Carvalho → ... → Giovanni) roda sozinha.

**Conteúdo novo construído**:
- **Agente Sombra 1** (Mt Moon) — MAIN-03.
- **Handler novo, reutilizável**: `defeat_count` por TIPO de Pokémon (ex: "water_pokemon"), não só
  por espécie/nome de treinador — resolve MAIN-04 e já deixa UTIL-11 pronta de graça.
- **Game Corner de Celadon** (cassino fachada da Equipe Rocket) com o Bruno — MAIN-06.
- **Quartel General da Equipe Rocket**, escondido embaixo do Game Corner (2 andares): Prof.
  Carvalho preso (resgate) + Agente Sombra Final (chefe) — MAIN-08.
- **Mansão Pokémon** (Cinnabar) ganhou 3 andares de verdade — MAIN-07.
- **Giovanni no Ginásio de Viridian** — só destrava DEPOIS que MAIN-08 completa. Peça de motor
  nova: `MapLayouts.gd` ganhou o ÚNICO tile do jogo condicionado a estado de save (consulta
  `QuestManager` via busca dinâmica de nó, não por nome solto — não quebra os testes headless).
  `BaseMap.gd` escuta `quest_completed` e repinta o `world_map` na hora, sem precisar recarregar.

**3 ajustes editoriais em quests.json** (mesma classe já usada 6+ vezes nesta sessão): MAIN-01
simplificada pra só "talk" (o resto dos objetivos originais não tinha como disparar com a
implementação real de Novo Jogo); MAIN-06 trocou "stealth" (não existe no motor) por conversa
normal; MAIN-07 trocou "traverse_dungeon" (sem handler) por "reach_floor" (handler já existia);
MAIN-08 trocou "rescue" (sem handler) por "talk" com o Carvalho preso.

**Também fechado**: Celadon Mart (v0.4.1) e Silph Co./Torre Pokémon (v0.4.2) já tinham saído
nesta mesma sessão — com isso, toda cidade construída até agora tem as próprias estruturas
funcionando (Ginásio, Centro, e quando aplicável loja/estrutura de história), exceto o **S.S.
Anne** (Vermilion), que segue só fachada — não tem nenhuma quest pedindo o interior dele, fica
pra quando você quiser essa peça específica.

**Testado**: `teste_fase2_historia_principal.gd` novo (37 conferências — a cascata inteira
MAIN-01→MAIN-09 rodada de ponta a ponta, incluindo a porta do Ginásio de Viridian fechada→aberta
de verdade) + os 7 testes de warps indevidos ganharam as exceções novas. **Suíte inteira: 31
arquivos, 549 conferências, 0 falhas.** Publicado, `curl` confirma 200.

**Não construído (fora do pedido de hoje)**: MAIN-10 em diante (Cerulean Cave/Mewtwo — pós-jogo),
ROCKET-01 a 04 e ROCKET-06 (cadeia paralela da Equipe Rocket, não bloqueiam a história principal),
os quests UTIL-* e COLETOR-* (secundárias).

---

## v0.4.2 — Silph Co. e Torre Pokémon ganham interior de verdade (2026-09-02)

**Gabriel autorizou a exceção de warp** pros dois (perguntado na sessão anterior: nenhum dos dois
é caverna/subterrâneo, mas ele topou abrir mesmo assim, igual já tinha feito pra Zona Safari).

**Torre Pokémon (Lavender) — 5 andares, ligada à MAIN-05** ("A Torre dos Que Partem", Sr. Fuji).
Cada andar é uma cena própria (padrão de sempre: `BaseMap.gd` + `MapLayouts.gd`, sala 18×14
reaproveitando o mesmo desenho do Rocket Hideout), com escada pro andar seguinte. Fantasmas
selvagens (Zubat/Gastly/Haunter, spawn pré-cadastrado do plano mestre original) nos 4 primeiros
andares; o 5º troca Zubat por Cubone (referência clássica do Gen 1: o Cubone órfão da torre) e
tem o "Agente Sombra 2" (Equipe Rocket, time de 3) guardando o topo — bate exatamente com os 2
objetivos da MAIN-05 (`reach_floor` andar 5 + `defeat agente_sombra_2`).

**Silph Co. (Saffron) — 3 andares, ligada à ROCKET-05** ("Operação Saffron"). 4 "Agentes Silph"
espalhados pelos 3 andares (1+2+1, o último mais forte — "última barreira antes da sala do
presidente", sem resolver o mistério do Giovanni, que continua bloqueado por história).

**Peça nova de motor**: `BaseMap.gd` ganhou `structure_id`/`floor_number` (mesmos campos que já
existiam no antigo `FloorMap.gd`, órfão desde antes da arquitetura atual — unificado aqui, porque
todo andar novo usa `BaseMap`+`MapLayouts`, não mais aquele sistema velho de `TileMapLayer`).
Emite `EventBus.floor_reached` na hora certa, reaproveitando o handler que a Fase 2 (01/09) já
tinha construído no `QuestManager` — zero mudança de motor nesse handler.

**2 ajustes editoriais nas quests** (mesma classe já usada em GYM-05/GYM-07 antes): MAIN-05 não
exige mais MAIN-04 (nunca foi ligada a nenhum NPC, deixaria a quest pra sempre inalcançável) —
agora só depende do Sr. Fuji oferecer. ROCKET-05 trocou o objetivo `help_npc`/`expel_agents`
(tipo sem handler nenhum no motor) por `defeat_count` de 4 Agentes Silph — mesmo padrão já
testado em ROCKET-07.

**Testado**: `teste_fase2_silph_torre.gd` novo (47 conferências — os 8 andares carregam, escadas
encadeiam certo, NPCs com time real, zonas com spawn certo, quests com objetivo alcançável).
7 testes antigos ganharam a exceção "PokemonTower"/"SilphCo" na lista de warps indevidos (mesma
lição de sempre). Suíte inteira: 30 arquivos, **512 conferências, 0 falhas**. Publicado, `curl`
confirma 200.

---

## v0.4.1 — Celadon Mart ganha vendedor de verdade (2026-09-02)

**Pedido do Gabriel**: "por enquanto tá bom [o mapa], vamos seguir em frente" — primeiro passo
real da fase "Pokémon e estruturas" (item 2 da ordem geral, depois do Mapa).

A Loja de Departamentos de Celadon existia desde o Tier 4 (31/08) só como prédio — igual Silph
Co./Torre Pokémon. Diferente delas (que exigiriam warp — e a regra do Gabriel é "warp só pra
caverna/subterrâneo/submarino/troca de continente"), uma loja neste jogo não precisa de warp:
o sistema inteiro já funciona como um NPC parado dentro do prédio, no próprio world_map, que abre
a tela de loja ao fim do diálogo (mesmo mecanismo já usado em Viridian desde 31/08). Bastou
colocar o NPC (`CeladonMartVendedor`) dentro do prédio de Celadon, com fala própria
(`celadon_shopkeeper`) — a loja em si é genérica (mesmo catálogo de sempre, `GameData.items`),
não precisa de estoque específico por cidade.

**Testado**: novo `teste_fase2_celadon_mart.gd` (8 conferências — posição cai no piso do prédio,
NPC configurado com `opens_shop_on_dialog_end`, diálogo próprio existe). Suíte inteira: 29
arquivos, 465 conferências, 0 falhas. Publicado, `curl` confirma 200.

**Precisa de decisão do Gabriel**: Silph Co. e a Torre Pokémon continuam só fachada — os dois
Itens maiores que sobraram de "Pokémon e estruturas" (interior de Silph Co. + "Operação
Saffron"/ROCKET-05; andares da Torre Pokémon com fantasmas, ligada à MAIN-05, que já tem o motor
`reach_floor` pronto desde a Fase 2) exigiriam um warp de verdade em cada um — e nenhum dos dois é
caverna/subterrâneo/submarino. Pra continuar essa frente, preciso saber se o Gabriel quer abrir
uma exceção nova à regra de warp pra esses dois (como já abriu pra Zona Safari, "espaço fechado
com um único ponto de acesso"), ou se prefere deixar como está por enquanto.

---

## v0.4.0 — Reorganização geográfica: mapa deixa de ser uma linha reta (2026-09-02)

**Pedido do Gabriel**, com uma imagem de referência do Kanto real: Saffron embaixo de Cerulean,
Vermilion embaixo de Saffron, Celadon à esquerda de Saffron (mar de verdade separando de
Viridian — só atravessa por Saffron, ou nadando quando Surf existir), Lavender à direita de
Saffron, Fuchsia embaixo de Lavender. Antes disso, Vermilion→Celadon→Fuchsia→Saffron→Lavender
eram uma fileira reta a leste de Cerulean (assim desde os Tiers 3-7, 31/08-01/09) — geografia que
funcionava mas não parecia com o Kanto de verdade.

**Duas perguntas resolvidas com o Gabriel antes de mexer em código** (decisão registrada, não
assumida): (1) Lavender continua ligada por uma rota que reaproveita a antiga Rota 9/10 + a boca
do Rock Tunnel, só que agora saindo de Saffron (Rota 8), não mais de Cerulean; (2) o mar entre
Celadon e Viridian separa de verdade — não é só decoração, precisa de Surf/barco no futuro pra
atravessar.

**O que mudou por dentro:** o "espinhaço" Cerulean→Saffron→Vermilion virou uma coluna vertical
nova (Rota 5 desce de Cerulean, Rota 6 desce de Saffron), com Saffron virando um cruzamento de 4
saídas (norte=Cerulean, sul=Vermilion, oeste=Rota 7→Celadon, leste=Rota 8→Lavender). Cada cidade
manteve o PRÓPRIO desenho interno (Ginásio/Centro/etc. nas mesmas posições relativas de sempre) —
só mudou onde ela é ancorada no mapa; o código de cada cidade foi extraído pra uma função própria
reutilizável, não importa de que direção se chega nela. O litoral de Vermilion (praia→Arquipélago
→Seafoam→Power Plant) e a Rota 11→Diglett's Cave (agora a leste de Vermilion, não mais ao norte —
o norte e o sul dela já são ocupados por Cerulean/costa) viajaram junto com a cidade.

**Pewter↔Cerulean (Rota 3/Mt Moon/Rota 4), o norte de Cerulean (Rota 24/25/Casa do Bill/Nugget
Bridge) e o oeste de Viridian (Rota 22/Victory Road/Indigo Plateau) continuam EXATAMENTE iguais**
— não fazem parte da fileira reta que foi desmontada.

**🔴 Achado no caminho, corrigido antes de terminar**: um ramo em linha/coluna negativa só pode
pintar a largura/altura INTEIRA do eixo compartilhado se for o único ocupante dele (mesma lição
do Tier 19, mas essa não se repetiu aqui — os ramos novos já nasceram pintando só a própria
faixa). O que apareceu de novo desta vez foi puramente aritmético (off-by-one nos limites de
linha entre Rota 5/Saffron/Rota 6/Vermilion) — pego pela suíte de testes antes de qualquer commit,
nunca chegou a rodar em produção.

**Trabalho mecânico grande, sem risco de lógica nova**: recalculadas TODAS as posições de NPC e
warp em `WorldMap.tscn` que pertenciam às 5 cidades reancoradas (Lt. Surge, Erika, Koga, Sabrina,
Fuji, os moradores/vendedores locais, o Capitão e o Pescador de Vermilion, os 5 Centros Pokémon,
os warps de Rock Tunnel/Zona Safari/Rocket Hideout/Diglett's Cave) — cada posição recalculada
preservando a MESMA posição relativa dentro da própria cidade (não foi um redesenho, só uma
re-ancoragem), conferida depois por teste, não de cabeça.

**Também mesclado nesta versão**: uma sessão-filha em worktree isolada construiu o Rocket
Hideout enquanto essa reorganização acontecia (arquivos disjuntos, sem conflito real) — 3
capangas da Equipe Rocket com times reais e a quest `ROCKET-07` ("Capangas no Esconderijo"),
achando e corrigindo um handler do `QuestManager` que só contava derrota por espécie, nunca por
nome de treinador (quebraria "vencer 3 capangas iguais").

**27 arquivos de teste reescritos** pra bater com a geografia nova (a maioria só trocou número
cravado por constante do `MapLayouts`, pra não quebrar de novo se a geografia mudar outra vez) +
1 arquivo novo do Rocket Hideout. **Suíte inteira: 28 arquivos, 457 conferências, 0 falhas.**

**Segunda referência visual guardada pro futuro** (não implementada agora): Gabriel mandou um
screenshot de um jogo estilo Stardew Valley mostrando o nível de detalhe de sprite que quer pra
fase "sprites mais legais" — ver `docs/tileset-referencia-visual.md`.

**Precisa de decisão do Gabriel?** Não pro que foi feito — mas o mapa ainda tem ~13 "gavetas
vazias" nunca tocadas desde o plano original de 31/08 (Rotas 12-21, Floresta de Viridian, Caverna
de Cerulean) — perguntei se ele quer que essas também entrem, ainda sem resposta.

---

## v0.3.13 — ZoneManager corrigido: zona por map_id, não mais por coordenada crua (2026-09-01)

**Pedido:** "siga com o pokemobile" (retomada de sessão) — antes de seguir com mapa/estruturas
novas, resolvido o achado sistêmico registrado como pendência no Tier 15 (ver acima), porque
achei a correção JÁ COMEÇADA e sem terminar no diretório (código quebrado sem commit: `zones.json`
com `map_id` novo em 5 zonas, `ZoneManager.gd` chamando uma função `find_zone_id` que ainda não
existia em lugar nenhum — o jogo quebraria se rodasse assim).

**O problema:** `ZoneManager.get_zone_id_at()` varria TODAS as zonas de `zones.json` só pela
coordenada de tile, sem saber em qual cena/mapa o jogador está. Como Mt Moon (20×30), Rock
Tunnel (36×36), Safari Zone (44×44), Rocket Hideout (18×14) e Cinnabar Island (40×40) são cenas
próprias e todas têm `tile_rect` começando perto de (0,0) na própria cena, a mesma coordenada
bruta batia em várias zonas ao mesmo tempo — e como a função devolvia a PRIMEIRA da lista que
batesse, Mt Moon (a primeira no JSON) sempre vencia. Rock Tunnel e Safari Zone estavam,
possivelmente desde os Tiers 10/12, puxando a tabela de spawn selvagem de Mt Moon por engano.

**Corrigido:** cada zona de cena própria ganhou `"map_id"` em `zones.json` (bate com o `@export
var map_id` que a cena (`BaseMap.gd`) já declarava desde sempre — conferido nos 5 arquivos
`.tscn`, os valores já batiam). `ZoneManager` agora lê o `map_id` do seu próprio pai (a cena onde
foi instanciado) e só considera zonas com o MESMO `map_id` (zona sem `map_id` próprio pertence ao
mundo aberto, `"world_map"`, o padrão). Lógica de busca virou função estática
(`find_zone_id`/`_zone_contains`), testável isolada sem precisar montar a cena inteira.

**Testado:** teste novo `scripts/tests/teste_zone_manager.gd` (8 conferências) — prova
explicitamente que a MESMA coordenada (5,5) resolve pra zonas DIFERENTES dependendo só do
`map_id` (as 5 cenas próprias, uma a uma), que o mundo aberto não cai em nenhuma delas, e que uma
coordenada fora de qualquer rect devolve vazio. Suíte inteira: **19 arquivos, 322 conferências, 0
falhas** (nenhum teste antigo tocado).

**Também mesclada nesta versão:** a branch `fase2-safari-quests` (Zona Safari com regra clássica
do Gen 1 — Bola Safari 30/visita, Isca/Pedra — e o motor `reach_floor`/`traverse_floors` no
`QuestManager.gd`, que destrava MAIN-05/MAIN-10/UTIL-05), que rodou em paralelo ao Tier 15 numa
worktree isolada e ficou pendente de mesclar. Sem conflito de código (arquivos diferentes dos que
o Tier 15 tocou); só `progresso.md` pediu resolução manual (as duas frentes editaram a partir do
mesmo ponto de partida).

**Próximo passo:** voltar pra "resto do Kanto" (S.S. Anne, Silph Co., Nugget Bridge, Pokémon
Mansion) ou seguir pra "Pokémon e estruturas" agora que a Zona Safari já tem mecânica própria.

---

## v0.3.12 — Tier 15: Rocket Hideout — entrada/porão em Celadon (2026-09-01)

**Pedido:** "siga em frente" — continuando "resto do Kanto", rodado EM PARALELO com uma outra
sessão-filha isolada numa worktree própria, trabalhando na Fase 2 (Zona Safari + motor de
quests `reach_floor`) numa branch separada (`fase2-safari-quests`), ainda não mesclada.

**Construído:** prédio novo em Celadon (cols locais 24-31, rows 21-30 — abaixo do corredor
leste-oeste, não colide com Ginásio/Centro/Mart já existentes nem com os Jardins), com porta de
verdade. Diferente de Silph Co./Torre Pokémon (só fachada, sem warp — interior é Fase 2),
Rocket Hideout ganhou **warp de verdade** porque é "subterrâneo" — mesma exceção já usada em Mt
Moon/Rock Tunnel/Safari Zone (regra do Gabriel de 31/08: warp só pra caverna/subterrâneo/
submarino/troca de continente). Cena própria nova (`RocketHideout.tscn`), sala de entrada
18×14, vazia — sem Team Rocket, sem grunts, sem mecânica de infiltração ainda (isso é "Pokémon
e estruturas", Fase 2, que a outra sessão-filha está começando a atacar em paralelo, mas ainda
não chegou nesta zona).

**Achado no caminho:** `zones.json` já tinha `rocket_hideout` pré-cadastrado (Zubat/Grimer/
Raticate) desde o plano mestre original, com um `tile_rect` genérico que não batia com nada —
corrigido pra `{x:0,y:0,w:18,h:14}` (coordenada local da cena própria, mesmo padrão de Mt Moon/
Rock Tunnel/Safari Zone), e documentada a exceção de warp nas `notes`.

**Achado à parte, NÃO corrigido (fora do escopo deste Tier, registrado pra decisão futura):**
o casamento de "zona atual do jogador" (`ZoneManager._tile_in_zone`) é só por coordenada de
tile, sem levar em conta QUAL cena/mapa o jogador está — e várias zonas de cena própria
(`mt_moon` 0,0,20,30 / `rock_tunnel` 0,0,36,36 / `safari_zone` 0,0,44,44 / agora `rocket_hideout`
0,0,18,14) têm `tile_rect` que se sobrepõem entre si em números brutos, porque todas começam
perto de (0,0) na sua própria cena. Como `get_zone_id_at` varre a lista inteira e devolve o
PRIMEIRO que bater (`mt_moon` vem primeiro no `zones.json`), é bem possível que Rock Tunnel e
Safari Zone estejam, desde os Tiers 10/12, puxando a tabela de spawn selvagem de Mt Moon por
engano em vez da própria (não percebido até agora porque as espécies se parecem — Zubat aparece
nas três). Rocket Hideout herda o mesmo risco. **Não é um bug introduzido por este Tier** — é
sistêmico, existe desde o Tier 10 — e corrigi-lo (fazer o `ZoneManager` saber em qual cena está)
é maior que "resto do Kanto"; fica registrado aqui pra quando o Gabriel quiser investigar/
corrigir, ou quando eu voltar com foco em Mecânicas/motor.

**Testado:** `teste_fase3_tier15.gd` novo (25 conferências: prédio/porta/telhado/interior da
cena/zones.json/warp de entrada de verdade/warp de saída de verdade, ida e volta). 7 arquivos
antigos (`teste_fase3_mapa`, tiers 2-7) ganharam a exceção nova `RocketHideout` na lista de
"warps indevidos" — mesma lição do Tier 10. **Suíte inteira: 19 arquivos, 314 conferências, 0
falhas.**

**Publicado:** export Web, imagem Docker reconstruída, `docker service update --force
pokemobile_pokemobile_app`, `curl` confirma 200 em https://poke.workprog.pro (primeiro `curl`
voltou 404 — janela normal de propagação do Traefik, 200 alguns segundos depois).

**Próximo passo:** dentro de "resto do Kanto" ainda faltam: S.S. Anne (fachada no cais de
Vermilion), Silph Co. (entrada em Saffron — prédio já existe), Nugget Bridge, Pokémon Mansion
(interior — fachada já existe em Cinnabar), e os itens sem posição geográfica decidida ainda
(Victory Road/Elite Four/Indigo Plateau, Diglett's Cave/Route 11, Power Plant). Viridian Gym/
Giovanni segue bloqueado por história. Quando a Fase 2 (rodando em paralelo) terminar, juntar as
duas branches, testar tudo junto e fazer um deploy final combinado.

**Precisa de decisão do Gabriel?** Não pro Tier em si — mas o achado do `ZoneManager` (acima)
é uma decisão dele quando quiser: investigar/corrigir agora, ou deixar registrado pra mais tarde.

---

## v0.3.11 — Tier 14: Seafoam Islands (2026-09-01)

**Pedido:** "siga com o plano de ação do PokéMobile" — sem pedido específico novo, seguindo a
ordem já combinada com o Gabriel (Mapa → Pokémon e estruturas → Mecânicas → Sprites), item 1
ainda em aberto: "resto do Kanto original". Escolhido Seafoam Islands por ser o item mais
simples/isolado da lista (mesmo padrão do Tier 13, risco mínimo).

**Construído:** 3 ilhotas dentro do mar aberto, continuando ao sul do Arquipélago Tropical
(Tier 13) — mesma faixa de colunas de Vermilion, sem gastar largura nova no mapa. **De propósito:
SEM warp, SEM prédio, SEM NPC** — mesma regra dos Tiers 11/13 (só alcançável quando existir Surf
ou Fly, nenhum dos dois construído ainda).

**Tema deliberadamente OPOSTO ao Arquipélago Tropical** (regra permanente de tematização de
bioma do Gabriel, 01/09): onde o arquipélago é denso/verde (T/F/G), Seafoam é frio/rochoso —
praia pálida em anel fino, interior de piso escuro ("D") + rochedo esparso ("R"), **zero
vegetação**. O teste trava isso explicitamente (conta T/F/G e exige zero). Spawn real do Gen 1
já estava pré-cadastrado em `zones.json` desde o plano mestre original (Zubat/Dewgong/Seel/
Articuno) — só precisou atualizar o `tile_rect` (era um placeholder genérico, x=50/y=260, sem
relação com o mapa real) pra bater com a posição de verdade construída (x=400, y=117, w=60,
h=40) e adicionar as `notes` explicando a regra "sem warp", igual foi feito pro arquipélago.

**Arquitetura:** mesma técnica do Tier 13 — a área ao sul do arquipélago já era borda vazia,
então Seafoam entrou direto no array principal, sem linha negativa nem coluna nova. Zero
mudança em código já testado.

**Testado:** `teste_fase3_tier14.gd` novo (16 conferências, incluindo checar que NENHUM warp foi
criado — mesmo padrão do Tier 13). **17 arquivos de teste juntos: 289 conferências, 0 falhas** —
nenhum teste anterior tocado (não precisou de exceção nova na lista de "warps indevidos" porque
não criou warp nenhum).

**Publicado:** export Web, imagem Docker reconstruída, `docker service update --force
pokemobile_pokemobile_app`, `curl` confirma 200 em https://poke.workprog.pro.

**Não feito nesta sessão** (ficou só em Seafoam, por escolha — 1 item bem testado em vez de
vários pela metade): nenhuma estrutura adicional (S.S. Anne/Rocket Hideout/Silph Co. entrada)
entrou neste Tier.

**Próximo passo:** dentro de "resto do Kanto", ainda faltam (sem posição geográfica decidida
ainda no mapa atual, que já divergiu da geografia canônica): Victory Road/Elite Four/Indigo
Plateau (dependem de Route 22/23 a oeste de Viridian, nunca mapeadas), Diglett's Cave/Route 11,
Power Plant, S.S. Anne (fachada no cais de Vermilion), Rocket Hideout (porão em Celadon), Silph
Co. (entrada em Saffron — o prédio já existe), Nugget Bridge, Pokémon Mansion (interior —
fachada já existe em Cinnabar). Viridian Gym/Giovanni segue bloqueado por história (não é tarefa
de mapa). Qualquer um desses é candidato ao próximo Tier — pedir ao Gabriel se prefere continuar
"resto do Kanto" ou já passar pra fase 2 (Pokémon e estruturas).

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## Fase 2 (paralela ao Tier 14 do mapa) — Zona Safari + motor reach_floor/traverse_floors (2026-09-01)

**✅ Mesclada em v0.3.13 (acima)** — este registro é o detalhe original de quando o trabalho
ainda estava isolado na branch `fase2-safari-quests`, antes do merge.

**Contexto:** rodou numa sessão-filha isolada (git worktree própria, branch `fase2-safari-quests`),
em PARALELO com outra sessão que seguia expandindo o mapa (Tier 14). Por isso os dois trabalhos
NÃO tocam nos mesmos arquivos de propósito (nada de `MapLayouts.gd`/`WorldMap.tscn`/
`data/world/zones.json` aqui) e **este trabalho ainda não foi mesclado nem publicado** — fica
pendente até alguém revisar e fazer o merge com o resultado do Tier 14.

**1. Mecânica própria da Zona Safari** (pendência registrada desde o Tier 12, 01/09): Bola Safari
limitada por visita (30, restaura ao ENTRAR na zona, não a cada batalha), Isca (mais fácil o
Pokémon ficar, mais difícil capturar) e Pedra (mais fácil capturar, mais fácil fugir) — papéis
opostos, regra clássica do gênero. **Sem lutar/fugir de verdade**: os 4 botões do menu de ação
são reaproveitados (LUTAR→BOLA, MOCHILA→ISCA, POKÉMON→PEDRA, FUGIR continua FUGIR) em vez de
desenhar UI nova — `BattleScene` só troca texto/handler quando `BattleManager.is_safari_battle`
é verdadeiro. Fórmula de captura é a mesma de sempre (shake count), só troca o multiplicador da
bola pelo acumulado de isca/pedra da batalha. `WildPokemon` ganhou campo `zone_id` (setado pelo
`SpawnManager` a partir da zona onde nasceu) — é como `BattleManager` sabe que está numa batalha
Safari.

**Achado no caminho, virou decisão de arquitetura**: pra deixar a detecção "é batalha Safari?"
testável sem disparar `SceneTransition.fade_to()` (troca de cena assíncrona, arriscada em teste
headless — ver próximo parágrafo), extraí a lógica pra uma função isolada
(`_is_safari_zone_entity()`) chamada por `_on_wild_encounter_started()`.

**2. Motor `reach_floor`/`traverse_floors`** (achado registrado no Tier 7, 01/09): o
`_get_objective_required()` do `QuestManager` já sabia calcular o alvo (lia `floor`/`floors` do
JSON), mas nada nunca chamava `update_objective()` pra esses dois tipos — MAIN-05 (Sr. Fuji/Torre
Pokémon), MAIN-10 (Cerulean Cave) e UTIL-05 (Seafoam) ficariam pra sempre travadas em 0/N.
Sinal novo `EventBus.floor_reached(structure_id, floor)`, emitido por `FloorMap._ready()` quando a
cena declara `structure_id`+`floor_number` (2 campos novos, opcionais — todo `FloorMap` que já
existia, incluindo Mt Moon/Rock Tunnel/Torre Pokémon, continua com os padrões vazios e não emite
nada, retrocompatível). `QuestManager` usa o MAIOR andar já visto (voltar não regride o
progresso). Não constrói o conteúdo da Torre Pokémon/Cerulean Cave em si — só o motor que faltava.

**Testado:** 2 arquivos novos, headless (`godot4 --headless --script`):
`teste_fase2_safari.gd` (20 conferências) e `teste_fase2_quest_floors.gd` (13 conferências).
**Suíte inteira: 18 arquivos, 306 conferências, 0 falhas** (16 arquivos antigos continuam
passando sem nenhuma mudança).

**Escopo deliberadamente fora dos testes automatizados**: captura bem-sucedida e fuga de verdade
do Pokémon na Zona Safari não são exercitadas ponta a ponta pelos testes — as duas caem em
`BattleManager._end_battle()`, que usa `await create_timer(...)` seguido de
`SceneTransition.fade_to()` (tween + troca de cena). Uma sonda descartável confirmou que `await`
dentro do ciclo `_process()` de um script `--script` headless não é resumido de forma confiável
(o processo termina antes da continuação rodar) — o MESMO caminho que nenhum teste do projeto já
testava ponta a ponta antes (nem a captura normal, fora da Zona Safari, tinha esse tipo de
cobertura). Os testes cobrem tudo que é síncrono e determinístico (contagem de bolas, matemática
de isca/pedra, bloqueio de Lutar/Mochila/Pokémon, detecção de zona) e documentam essa lacuna no
próprio cabeçalho do arquivo de teste. Fica pra confirmação visual ao vivo (mesmo padrão já usado
noutras partes do projeto) quando alguém puxar essa branch pro navegador.

**Pendente:** revisar e mesclar `fase2-safari-quests` com o resultado do Tier 14 (mapa), depois
publicar os dois juntos (build Web + Docker + deploy).

**Precisa de decisão do Gabriel?** Não pra construir — só quando alguém for mesclar/publicar.

---

## v0.3.1 — Tier 4: Rota 7 → Celadon City (Erika) (2026-08-31, continuação)

**Pedido:** "continue com o mapa". Rota 7 → Celadon City, a leste de Vermilion (mapa cresceu
de 460 pra **580 de largura**). Celadon ganhou Ginásio (Erika, time real: Vileplume Nv.29 +
Victreebel Nv.30), Centro Pokémon e a Loja de Departamentos (Celadon Mart, só o prédio por
enquanto — sem vendedor ligado ainda, fica pra quando "estruturas" virar foco de verdade).

**Spawn selvagem real do Gen 1**: Rota 7 (Oddish/Bellsprout/Venonat/Abra). Oddish já também
existe na Rota 5 — junto, dão o "capturar 3 Oddish" da GYM-04 bem alcançável.

**Testado:** `teste_fase3_tier4.gd` (13 conferências) — caminho contínuo, Ginásio/Centro
Pokémon/Loja de Celadon existem, Erika com time real iniciando GYM-04, Oddish alcançável.
1 teste do Tier 3 ajustado (largura total mudou de novo, mesma classe de sempre). **7 arquivos
de teste juntos: 143 conferências, 0 falhas.** Publicado, testado ao vivo sem erro.

**Mapa hoje**: Pallet→Viridian→Pewter→(Mt Moon)→Cerulean→Vermilion→Celadon — **4 badges reais**
(Brock/Misty/Lt.Surge/Erika) funcionando de ponta a ponta.

**Próximo passo:** Tier 5 (Fuchsia/Koga ou Saffron/Sabrina — ou o desvio de Rota 24/25 +
Bill's House perto de Cerulean, que ainda falta).

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## v0.3.2 — Tier 5: Rota 8 → Fuchsia City (Koga) (2026-08-31, continuação)

**Pedido:** "continue com o mapa". Rota 8 → Fuchsia City, a leste de Celadon (mapa cresceu de
580 pra **700 de largura**). Fuchsia ganhou Ginásio (Koga, time real: Koffing Nv.37 + Weezing
Nv.43, badge Soul), Centro Pokémon e um recinto cercado só decorativo pra Zona Safari (sem
sistema ligado ainda — fica pra "estruturas").

**Achado antes de construir**: `quests.json` já tinha a GYM-05 inteira escrita desde o plano
mestre original, mas com objetivo `alpha_arbok`/`south_lake` — mecânica "alpha" que não existe
no motor (mesma classe do `alpha_tentacruel` da GYM-02, corrigido no Tier 2). Trocado por
`defeat_count ekans ×5 zona route_8` — Ekans é o Pokémon de Veneno real da Rota 8 no Gen 1,
tematicamente combina com o Koga, e é alcançável de verdade.

**Testado:** `teste_fase3_tier5.gd` (12 conferências) — caminho contínuo, Ginásio/Centro Pokémon
de Fuchsia existem, Koga com time real iniciando GYM-05, Ekans alcançável, GYM-05 sem mecânica
inexistente. 1 teste do Tier 4 ajustado (largura mudou de novo). **8 arquivos de teste juntos:
155 conferências, 0 falhas.** Publicado, `curl` confirma 200.

**Mapa hoje**: Pallet→Viridian→Pewter→(Mt Moon)→Cerulean→Vermilion→Celadon→Fuchsia — **5 badges
reais** (Brock/Misty/Lt.Surge/Erika/Koga) funcionando de ponta a ponta.

**Próximo passo:** Tier 6 — próximo gym real em ordem de badge é Sabrina (Saffron, Marsh Badge).
`quests.json` já tem GYM-07 escrita pra ela, com um objetivo `defeat_count rocket_agent` que
também vai precisar de ajuste editorial (mecânica de "agente Rocket" ainda não existe fora das
MAIN quests).

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## v0.3.3 — Tier 6: Rota 9 → Saffron City (Sabrina) (2026-08-31, continuação)

**Pedido:** "continue com o mapa". Rota 9 → Saffron City, a leste de Fuchsia (mapa cresceu de
700 pra **820 de largura**). Saffron ganhou Ginásio (Sabrina, time real: Kadabra Nv.38 +
Alakazam Nv.43, badge Marsh), Centro Pokémon e o prédio da Silph Co. (só o prédio, sem interior
ligado — a "operação Silph" é conteúdo de história futura).

**Dois achados antes de construir**, mesma classe dos ajustes de GYM-02/GYM-05: (1) `quests.json`
já tinha a GYM-07 escrita desde o plano mestre com objetivo `defeat_count rocket_agent` — mecânica
de "agente Rocket" fora das MAIN quests que não existe no motor. Trocado por `capture_count abra
×3 zona saffron_city` (Abra é o Pokémon Psíquico real de Kanto ligado a Saffron). (2) GYM-07
exigia `requires: GYM-06` (Blaine/Cinnabar) — mas Cinnabar precisa de travessia de oceano, ainda
fora de escopo. Como o mapa seguiu a ordem geográfica (Fuchsia→Saffron), não a ordem de badge
oficial do jogo (que tem Sabrina como 6ª e Blaine como 7ª), troquei a exigência pra `GYM-05`
(Koga) — senão a quest da Sabrina nunca inicializaria de verdade (ficaria muda, sem erro
visível). **Documentado aqui pra reconsiderar quando Cinnabar for construída.**

**Testado:** `teste_fase3_tier6.gd` (14 conferências) — caminho contínuo, Ginásio/Centro
Pokémon/Silph Co. existem, Sabrina com time real iniciando GYM-07 com o `requires` corrigido,
Abra alcançável. 1 teste do Tier 5 ajustado (largura mudou de novo). **9 arquivos de teste
juntos: 169 conferências, 0 falhas.** Publicado (o primeiro `curl` logo após o redeploy voltou
404 — janela normal de propagação do Traefik, confirmado 200 poucos segundos depois).

**Mapa hoje**: Pallet→Viridian→Pewter→(Mt Moon)→Cerulean→Vermilion→Celadon→Fuchsia→Saffron —
**6 badges reais** (Brock/Misty/Lt.Surge/Erika/Koga/Sabrina) funcionando de ponta a ponta.

**Próximo passo:** o que falta pro "mapa terminado" (mundo aberto contíguo, sem contar
ilha/oceano): Viridian ainda não tem Giovanni de verdade (é o "líder sumido" da lore — GYM-08 já
existe em quests.json); Cinnabar (Blaine) e Lavender Town/Pokémon Tower exigem litoral/travessia
de água, fora de escopo até Surf existir; Rota 24/25 + Bill's House (desvio ao norte de
Cerulean) ainda não foi construído.

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## v0.3.4 — Tier 7: Rota 10 → Lavender Town (2026-09-01)

**Pedido:** "vamos continuar" (retomando pela lista de pendências deixada na memória). Rota 10 →
Lavender Town, a leste de Saffron (mapa cresceu de 820 pra **940 de largura**). Lavender ganhou
a Torre Pokémon (só a fachada — a torre de verdade com andares/fantasmas fica pra quando
"Pokémon e estruturas" virar foco, mesmo tratamento já dado à Silph Co./Celadon Mart) e Centro
Pokémon. Sr. Fuji e um morador local com diálogo, sem quest ligada ainda (MAIN-05 não é wireable
hoje — ver achado abaixo).

**Achado importante antes de construir**: `MAIN-05` (a quest do Sr. Fuji) usa o tipo de
objetivo `reach_floor`, e conferindo `QuestManager.gd` de verdade — **esse tipo nunca foi
implementado**, só existe como dado no JSON (mesma classe dos achados de `alpha_arbok`/
`rocket_agent`, mas dessa vez é a cadeia MAIN inteira: nenhuma quest MAIN-01 a MAIN-12 tem um
NPC de verdade no mundo que a inicie — só as 6 GYM têm `starts_quest_id` real). Decisão: não
tentar wire a MAIN-05 agora (seria inventar mecânica nova, fora do escopo "mapa") — Sr. Fuji
fica só com diálogo de sabor por enquanto, documentado pra quando a cadeia de história virar
foco de verdade.

**🔴 Bug achado e corrigido no caminho, sem relação com Lavender**: o Centro Pokémon de Saffron
(construído no Tier 6) tinha o prédio no mapa mas **o warp de entrada nunca foi criado** — só a
`RectangleShape2D` ficou órfã no arquivo, nenhum `WarpZone` a usava. Corrigido (node
`WarpPokeCenter_Saffron` adicionado). Novo teste trava essa classe de bug pra sempre: conta
quantos Centros Pokémon têm prédio construído (9) contra quantos têm warp de entrada — se
algum dia meu divergir de novo, o teste quebra.

**Segundo achado, mesma sessão**: telhado da Torre Pokémon caiu na faixa `r<=2` que
`_leste_de_pewter_cell` trata como borda absoluta (mesma classe de seam de sempre) — corrigido
movendo o telhado pra `r==4`, igual ao padrão já usado na Silph Co.

**Testado:** `teste_fase3_tier7.gd` (10 conferências, incluindo a trava anti-regressão dos
warps de Centro Pokémon) + ajuste de 1 asserção desatualizada no teste do Tier 6. **10 arquivos
de teste juntos: 179 conferências, 0 falhas.** Publicado, `curl` confirma 200.

**Mapa hoje**: Pallet→Viridian→Pewter→(Mt Moon)→Cerulean→Vermilion→Celadon→Fuchsia→Saffron→
Lavender — ainda 6 badges reais (Lavender não é ginásio).

**Próximo passo (pendências, em ordem — ver memória do PokéMobile):** Rota 24/25 + Casa do Bill
(desvio ao NORTE de Cerulean — precisa de arquitetura nova, não é só continuar pra leste);
litoral/mar/ilhas de verdade (pré-requisito pra Cinnabar/Blaine); Rock Tunnel.

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## v0.3.5 — Tier 8: Rota 24 → Rota 25 → Casa do Bill (2026-09-01)

**Pedido:** "vamos continuar" (item 1 da lista de pendências deixada na memória). Primeiro
**desvio** do mapa — não é continuar pra leste, é um ramo ao NORTE de Cerulean, terminando na
Casa do Bill. Bill ganhou diálogo de sabor (referência clássica do Gen 1: o acidente do
teletransportador com um Clefairy), e um treinador na Rota 24 com time real (Nidoran-M+F).

**Decisão de arquitetura, a mais importante desta sessão até aqui**: os Tiers 1-7 sempre
continuaram pra LESTE (largura crescendo), então bastava "traduzir" o número da coluna sem
tocar em nada. Um ramo pra CIMA (norte) é outra categoria de problema — geograficamente, "norte"
só existe deslocando TODA LINHA de todo NPC/warp/zona já testado (a mesma técnica usada pra criar
Pewter/Rota 2 ao norte de Viridian, no início do projeto). **Em vez disso, usei linha NEGATIVA**:
o Godot aceita coordenada de tile negativa de verdade (confirmado), então o ramo novo (Rota 24 →
Rota 25 → Casa do Bill) vive em `r < 0`, pintado à PARTE do array principal — e por isso **nenhum
NPC, warp ou zona dos Tiers 1-7 precisou mudar uma linha sequer**. Resultado prático: os 7
arquivos de teste anteriores passaram **sem tocar em nenhum deles** — a primeira vez nesta série
de tiers que isso acontece.

**Achado no meio do design, corrigido antes de testar**: a primeira versão colocava a Casa do
Bill **em cima do próprio corredor** (bloqueando a única passagem entre Rota 24 e Rota 25) —
corrigido pra ficar AO LADO do caminho principal, com um trecho curto ligando a porta ao
corredor, mesmo padrão usado em toda cidade (Ginásio/Centro Pokémon nunca ficam em cima do
caminho, sempre ao lado).

**Testado**: `teste_fase3_tier8.gd` (16 conferências) — esse teste é diferente dos anteriores:
em vez de só ler `tiles[row][col]` do array (que não cobre o ramo, de propósito), ele **pinta um
`TileMap` de verdade** via `MapLayouts.paint()` e lê de volta com `get_cell_atlas_coords()` —
validando o código de pintura de verdade, não só os dados. **11 arquivos de teste juntos: 195
conferências, 0 falhas** (os 7 anteriores intocados). Web build exportado, imagem Docker
reconstruída e redeployada, publicado — `curl` confirma 200 (o primeiro veio 404, mesma janela
de propagação do Traefik já documentada, resolvido em ~5s) — e smoke test ao vivo (Playwright)
sem erro de página novo.

**Mapa hoje**: o corredor leste-oeste principal (Pallet→...→Lavender, 940 de largura) ganhou seu
primeiro desvio real — Rota 24/25 saindo de Cerulean pra norte, terminando na Casa do Bill.

**Próximo passo (pendências, ver memória do PokéMobile)**: litoral/mar/ilhas de verdade
(pré-requisito pra Cinnabar/Blaine); Rock Tunnel; resto do Kanto original.

**Precisa de decisão do Gabriel?** Não — seguindo a ordem combinada.

---

## v0.3.6 — Tier 9: Litoral de Vermilion — praia + mar aberto (2026-09-01)

**Pedido:** "Continue" + regra nova e permanente do Gabriel: **todo bioma precisa ter identidade
visual própria** — caverna com piso diferente/estruturas geológicas/rotas não-lineares (erosão
natural ou escavação de Pokémon tipo Pedra/Terra), litoral com aspecto de praia de verdade, e
quando o mapa **submarino** existir, ele tem que ter **exatamente o mesmo tamanho e formato** do
oceano de superfície, com camadas de profundidade pra quests/raids no futuro. Registrado como
regra permanente na memória (não só pra este tier).

**Construído**: praia + mar ao SUL de Vermilion City (cidade portuária, já tinha decoração de
"doca" desde o Tier 3 — fazia sentido geográfico). Linha da costa **orgânica** (função `sin()`,
`shore_de_vermilion()`), não um corte reto — a areia avança e recua por coluna, com rochedos de
maré espalhados, sem árvore/flor (não combina com praia). Zona nova `mar_de_vermilion` **guarda
a função que define seu formato exato como nota** — é a fonte única de verdade que o mapa
submarino (fase de mecânicas, precisa de Mergulho) vai reusar pra bater o contorno certinho,
conforme pedido.

**Arquitetura**: mais simples que o Tier 8 — como a área ao sul de Vermilion já era borda vazia
(Rota 2 só existe a oeste), o litoral entrou direto no array principal, sem precisar de linha
negativa nem pintura à parte. Mesmo assim é um "desvio" (fora do corredor leste-oeste), então
usei o mesmo cuidado de seam: a orla inteira de Vermilion (linhas 35-36) virou areia, corrigido
pra não bloquear a entrada na praia.

**Testado**: `teste_fase3_tier9.gd` (12 conferências, incluindo checar que a curva da praia
varia por coluna — não é uma linha reta). **12 arquivos de teste juntos: 207 conferências, 0
falhas** — de novo nenhum teste anterior precisou de ajuste. Publicado, `curl` confirma 200.

**Ainda pendente da lista**: Mt Moon (Tier 2) foi construído ANTES dessa regra de tematização
existir — é uma caverna bem simples (retângulo + rochas espalhadas), sem estrutura geológica ou
rota não-linear de verdade. Não retrofitei agora (o pedido foi "continue", não "arrume o que já
existe") — fica registrado que Mt Moon não bate com o padrão novo, e o Rock Tunnel (próximo item
da lista, ainda não construído) é a primeira chance de aplicar o padrão logo de cara.

**Próximo passo**: Rock Tunnel (aplicando a regra de caverna não-linear pela primeira vez) ou
seguir esticando o litoral (mais praia, rumo a uma futura Ilha Cinnabar).

**Precisa de decisão do Gabriel?** Não — mas vale perguntar se ele quer que eu retrofite Mt Moon
pro padrão novo antes de seguir, ou se deixa pra depois.

---

## v0.3.7 — Tier 10: Rock Tunnel — a primeira caverna não-linear (2026-09-01)

**Pedido:** "Continue" + referência visual de tileset mandada pelo Gabriel (guardada em
`docs/tileset-referencia-visual.md` + `docs/referencias/tileset-visual-referencia.png`, é pra
implementar só quando "sprites mais legais" virar foco de verdade — não agora).

**Construído**: Rock Tunnel, dungeon lateral opcional com entrada na Rota 10 (moldura de rocha
ao redor de uma boca caminhável, mesmo tratamento visual do Mt Moon). Zubat/Geodude/Onix (spawn
real do Gen 1, já estava certo no `zones.json`, só precisou virar cena de verdade).

**A parte importante**: é a PRIMEIRA caverna construída depois da regra de tematização de bioma
do Gabriel (01/09) — em vez do padrão do Mt Moon (retângulo + rochas espalhadas em grade), o
interior é gerado por **caminhada aleatória** (`_rocktunnel_carve`, "drunkard's walk") com
**seed fixa** (determinístico — sempre gera a mesma caverna, mas o RESULTADO parece
erosão/escavação de verdade): 1 túnel principal sinuoso de 500 passos + 3 ramos secundários de
120 passos cada, sempre partindo de um ponto JÁ escavado (nunca ficam isolados). Piso usa "D"
(caminho escuro) em vez de "I", pra já ter identidade visual diferente do Mt Moon mesmo sem
sprite novo.

**🔴 Bug achado e corrigido antes de publicar**: a primeira versão da moldura de rocha da boca da
caverna checava a área ANTES de checar o corredor leste-oeste principal — isso bloqueava a
travessia de Saffron até Lavender em 4 colunas (as que flanqueiam a entrada). Corrigido: o
corredor principal SEMPRE vence, a moldura só existe acima dele, nunca atravessando. **Achado
relacionado, investigado e descartado como bug real**: o Mt Moon usa a mesma ordem de código
(moldura antes do corredor) — mas lá isso nunca bloqueia de verdade a travessia, porque fora da
faixa de linhas 12-24 (onde fica a moldura) o resto da Rota 3/4 já é grama livre nessa mesma
coluna, então dá pra contornar por cima ou por baixo. Não é um bloqueio funcional, só um desenho
um pouco menos consistente que o do Rock Tunnel — não precisa de correção.

**Testado**: `teste_fase3_tier10.gd` (16 conferências) — inclui prova de determinismo (gerar
duas vezes dá exatamente a mesma caverna), prova de não-linearidade (piso se espalha por mais de
15 linhas E colunas), prova de que ainda é MAIS rocha que piso (238 piso / 1056 rocha — continua
parecendo caverna, não virou sala aberta), e um flood-fill provando que os 238 tiles de piso são
TODOS alcançáveis a partir da porta (nenhum ramo secundário isolado). 2 testes antigos ajustados
(mesma classe de sempre: warp novo — Rock Tunnel — precisava entrar na lista de exceções
permitidas nos testes anteriores). **13 arquivos de teste juntos: 223 conferências, 0 falhas.**
Publicado, `curl` confirma 200.

**Próximo passo**: mais litoral/ilhas (rumo a Cinnabar) ou seguir com outro item da lista.

**Precisa de decisão do Gabriel?** Não.

---

## v0.3.8 — Tier 11: Cinnabar Island de barco (2026-09-01)

**Pedido:** "Continue". Como a travessia de água aberta era uma decisão de arquitetura de verdade
(ainda não existe Surf), perguntei ao Gabriel como seguir — ele escolheu **barco por enquanto**
(reaproveitando o que o próprio plano mestre já previa: a quest "Filho do Mar" desbloqueando
"boat_to_cinnabar").

**Construído**: Cinnabar Island, alcançável só de barco a partir do Capitão de Vermilion.
Conversar com o Capitão inicia a UTIL-02 ("derrotar o Gyarados que ronda a baía"); só depois
dela completa o diálogo dele muda (`_liberado`) e a viagem de verdade acontece. Ilha própria
(cena separada, 40×40) com contorno ORGÂNICO (mesma técnica `sin()`/distância do litoral de
Vermilion — regra de tematização), Ginásio do Blaine (GYM-06, time real Growlithe Nv.42 +
Arcanine Nv.47, Volcano Badge), Centro Pokémon, e a Mansão Pokémon só de fachada (interior fica
pra "Pokémon e estruturas"). Rochedo vulcânico esparso dá identidade de ilha vulcânica mesmo sem
sprite de lava ainda.

**Peça de motor nova (não só conteúdo)**: `NpcEntity` ganhou viagem condicionada a quest —
`requires_quest_for_travel`/`travel_target_map`/`travel_spawn_tile`. Reaproveita a mesma
infraestrutura de diálogo reativo que já existia (`_effective_dialog_id()`, usada antes só pra
cura/presente) — agora também troca de fala e libera viagem de verdade conforme o estado real da
quest (`QuestManager.is_quest_complete`), não um "flag" novo desconectado do sistema de quests.

**Dois achados de quest corrigidos antes de testar** (mesma classe de sempre): UTIL-02 pedia
`alpha_gyarados` (mecânica "alpha" que não existe) — trocado por `defeat gyarados` de verdade
(Gyarados+Magikarp adicionados ao Mar de Vermilion). GYM-06 (Blaine) pedia `fetch_item` numa
`pokemon_mansion_floor2` que não existe — trocado por `defeat_count growlithe ×3`, Pokémon real
de Cinnabar no Gen 1.

**Testado**: `teste_fase3_tier11.gd` (24 conferências) — inclui a prova mais importante: forçar
`UTIL-02` completa via `QuestManager` e confirmar que o diálogo do Capitão muda de verdade
(`capitao_vermilion` → `capitao_vermilion_liberado`), não só checar que os campos existem.
**14 arquivos de teste juntos: 247 conferências, 0 falhas.** Publicado, `curl` confirma 200.

**Próximo passo**: resto do Kanto original (Elite Four, Power Plant, S.S. Anne etc. — placeholders
em `zones.json`, nada construído) ou aguardar novo pedido do Gabriel.

**Precisa de decisão do Gabriel?** Não — decisão da travessia já tomada nesta sessão.

---

## v0.3.9 — Tier 12: Zona Safari com warp de verdade (2026-09-01)

**Pedido:** "siga com as próximas implementações de mapa, inclusive precisa criar a safari zone
que utilizará warp" — pedido explícito do Gabriel de usar warp aqui, mesmo Zona Safari não sendo
caverna/subterrâneo/submarino (a exceção de sempre). Justificativa: é um espaço fechado só
acessível por um ponto (o portão), mesma lógica de uma caverna.

**Construído**: Zona Safari virou cena própria (44×44) — o cercado decorativo que existia em
Fuchsia desde o Tier 5 ganhou um portão de verdade, com warp pra dentro. Interior: reserva
cercada (cerca "E" ao redor, não árvore — dá identidade de espaço controlado, diferente de mata
selvagem), 2 lagoas de contorno orgânico (mesma técnica `sin()`/distância do litoral), mato mais
denso (identidade de reserva fechada). Guarda Florestal com diálogo de sabor logo na entrada.
**Mecânica de captura especial (Bola Safari, sem fugir durante o turno do jogador) fica pra
depois** — é sistema de batalha, não de mapa; por ora usa captura normal, igual ao resto do jogo.
Spawn selvagem real do Gen 1 (Tauros, Kangaskhan, Chansey, Tangela, Rhyhorn, Psyduck) já estava
certo no `zones.json` desde o plano mestre, só precisou de coordenada nova.

**Testado**: `teste_fase3_tier12.gd` (13 conferências, incluindo a prova de que o corredor
leste-oeste principal continua passável nas colunas do cercado — mesma classe de regressão do
Tier 10). 7 testes antigos ajustados (novo warp precisa entrar na lista de exceções, mesmo
ajuste do Tier 10). **15 arquivos de teste juntos: 260 conferências, 0 falhas.**

---

## v0.3.10 — Tier 13: Arquipélago Tropical — construído, ainda inalcançável (2026-09-01)

**Pedido, no meio do trabalho anterior**: "o barco só irá levar a cinnabar, para as outras ilhas
o usuário terá que conseguir um pokemon aquático que use surf ou um voador com fly para
acessá-las, mas construa as ilhas e deixe-as prontas com uma temática tropical". Ou seja: as
próximas ilhas NÃO usam barco (isso é exclusivo de Cinnabar) — ficam só esperando Surf/Fly, que
ainda não existem. Construir mesmo assim, prontas.

**Construído**: 2 ilhas tropicais dentro do mar aberto, continuando ao sul do litoral de
Vermilion (Tier 9) — mesma faixa de colunas, sem gastar largura nova no mapa. Contorno orgânico
(mesma técnica `sin()`/distância), praia ao redor, vegetação tropical densa (mistura de árvore/
flor/mato mais fechada que o resto do jogo). Spawn real do Gen 1 combinando com o tema
(Exeggcute, Tangela, Krabby, Slowpoke). **De propósito: SEM warp, SEM prédio, SEM NPC** — não faz
sentido povoar um lugar que ninguém consegue visitar ainda. O teste até confirma isso
explicitamente (nenhum warp foi criado).

**Arquitetura**: mesma técnica dos Tiers 9 (litoral simples, array principal) — a área ao sul do
litoral de Vermilion já era borda vazia, então o arquipélago entrou direto ali, sem precisar de
linha negativa nem coluna nova.

**Testado**: `teste_fase3_tier13.gd` (13 conferências, incluindo checar que NENHUM warp foi
criado — o oposto do padrão de todo tier anterior, e documentado como intencional). **16 arquivos
de teste juntos: 273 conferências, 0 falhas** — nenhum teste anterior tocado.

**Ambos os tiers publicados juntos**: Web build exportado, imagem Docker reconstruída e
redeployada, `curl` confirma 200.

**Próximo passo**: Ginásio de Viridian/Giovanni (bloqueado por história) ou resto do Kanto
original (Elite Four, Power Plant, S.S. Anne — placeholders sem construir).

**Precisa de decisão do Gabriel?** Não.

---

## v0.3.0 — Tier 3: Rota 5 → Rota 6 → Vermilion City (Lt. Surge) (2026-08-31, continuação)

**Pedido do Gabriel:** deixar mecânica de locomoção por último; ordem definida: **mapa →
Pokémon e estruturas → mecânicas → sprites**. Continuar terminando o mapa.

**Construído:** Rota 5 → Rota 6 → Vermilion City, a leste de Cerulean (mundo aberto contínuo,
sem warp — mapa cresceu de 280 pra **460 de largura**). Vermilion ganhou Ginásio (Lt. Surge,
time real: Voltorb Nv.20 + Raichu Nv.24) e Centro Pokémon. Diferente do Tier 2, essa junção
não teve o "bug de emenda" (a função da cidade anterior — Cerulean — não tinha nenhum corte de
borda leste pra colidir, então a Rota 5 encaixou direto sem precisar de correção no meio).

**Spawn selvagem real do Gen 1**: Rota 5 (Meowth/Jigglypuff/Oddish/Bellsprout/Nidoran♂♀), Rota
6 (Meowth/Jigglypuff/Grimer/Sandshrew). **Um ajuste editorial**: a GYM-03 pede derrotar 8
Voltorb — no jogo original ele mora na Power Plant (área que ainda não existe aqui) — colocado
na Rota 6 por enquanto, pra a missão continuar completável; quando a Power Plant for
construída dá pra mover o Voltorb pra lá e ficar 100% fiel.

**Testado:** `scripts/tests/teste_fase3_tier3.gd` (12 conferências) — caminho contínuo,
Ginásio/Centro Pokémon de Vermilion existem, Lt. Surge com time real iniciando GYM-03, Voltorb
alcançável. 1 teste do Tier 2 precisou de ajuste (a largura total do mapa mudou de novo — mesma
classe de achado de teste de sempre, não de jogo). **6 arquivos de teste juntos: 130
conferências, 0 falhas.** Publicado, testado ao vivo sem erro no console.

**Próximo passo:** continuar o mapa (Tier 4 — provavelmente Celadon City, GYM-04/Erika, ou o
desvio de Rota 24/25 + Bill's House que ainda falta perto de Cerulean).

**Precisa de decisão do Gabriel?** Não — ordem combinada (mapa → Pokémon/estruturas →
mecânica → sprite) sendo seguida à risca.

---

## v0.2.9 — Tier 2: Rota 3 → Mt Moon → Rota 4 → Cerulean City (Misty) (2026-08-31, continuação)

**Pedido do Gabriel:** mandou o mapa real de Kanto (imagem) e pediu pra construir tudo —
ilhas, mar, spawn de Pokémon por localização real, mapa grande o bastante pra levar ~30 min
andando de ponta a ponta (reduzido depois por Fly/montaria/bike), e continuar pro próximo
pedaço. **Registro honesto de escopo**: reconstruir o Kanto inteiro pixel a pixel igual à
imagem (litoral, baías, ilhas) e os sistemas de Fly/Surf-pra-atravessar/Bike/montaria são,
juntos, o maior trabalho que este projeto já teve pela frente — não cabe numa sessão só. Este
Tier 2 é progresso real e testado na mesma direção, não a coisa inteira ainda.

**Construído:** Rota 3 → Mt Moon → Rota 4 → Cerulean City, a LESTE de Pewter (mesma faixa de
linhas, mundo aberto contínuo — mapa cresceu de 100 pra **280 de largura**). Mt Moon virou
**cena própria** (a exceção de warp que o próprio Gabriel autorizou: "só em caverna,
subterrâneo, submarino ou trocando de continente") — entrada ao sul (Rota 3), saída ao norte
(Rota 4), sem volta pela superfície, tem que atravessar a caverna de verdade. Cerulean City
ganhou Ginásio (Misty, time real: Staryu Nv.18 + Starmie Nv.21) e Centro Pokémon.

**Spawn selvagem real do Gen 1** (pesquisado, não inventado) — Rota 3: Rattata/Spearow/
Nidoran♂/Nidoran♀/Mankey/Jigglypuff. Mt Moon: Zubat/Paras/Geodude/Clefairy (rara). Rota 4:
Rattata/Spearow/Sandshrew/Nidoran♂/Nidoran♀.

**Achado corrigido no caminho, mesma classe de sempre**: o próprio código de Pewter tratava
suas 3 últimas colunas como borda leste (fazia sentido quando Pewter era o fim do mapa) — virava
parede bem no meio do caminho principal agora que a Rota 3 continua pra leste. Corrigido só
nas linhas do caminho (16-20), sem tocar em mais nada de Pewter.

**GYM-02 simplificado**: o objetivo original exigia derrotar um "alpha_tentacruel" — mecânica
de Alpha que não existe de verdade no jogo (nunca é marcada, mesmo achado do GYM-01/Pewter
com Pewter/Brock). Removido; agora só exige derrotar a Misty, igual ao padrão real dos jogos
(badge = vencer o líder).

**❌ Ainda não construído, registrado pra não esquecer** (fora do escopo desta sessão):
- Litoral/mar/ilhas de verdade batendo com a imagem (hoje o "oceano" nem existe — o mapa é só
  terra firme com uma cidade seguindo a outra).
- **Fly, Surf-pra-atravessar-mapa, Bike/Moto e montaria (Tauros/Dodrio)** — sistemas de
  movimento novos, nenhum construído ainda. Pesca (Fase 2) já usa "Surf" como conceito de
  água, mas surfar PARA ATRAVESSAR o mapa é outra coisa, não existe.
- Calibração fina de "~30 min de ponta a ponta" — as rotas ficaram bem mais longas que antes
  (Rota 3+Mt Moon+Rota 4 juntas têm ~120 tiles de caminho principal, contra ~13 da Rota 2), mas
  não tem como cronometrar direito sem o mapa inteiro pronto nem os sistemas de velocidade.
- Restante do Kanto: Rota 24/25 (Bill's House), Celadon City, Rota 5-9, Vermilion City, Rota
  10 (Rock Tunnel), Lavender Town, Saffron City, Fuchsia City, Safari Zone, Cinnabar Island,
  Seafoam Islands, Indigo Plateau — tudo já mapeado em `zones.json` (52 zonas no total,
  pesquisa que já existia antes desta sessão), falta construir peça por peça.

**Testado:** `scripts/tests/teste_fase3_tier2.gd` (21 conferências) — caminho contínuo até a
boca do Mt Moon, Mt Moon carrega e tem entrada/saída certas, Misty com time real, spawn real
de cada zona. Os 5 arquivos de teste juntos (Fases 0-3 + Tier 2): **118 conferências, 0
falhas**. 2 testes antigos precisaram de ajuste (achado de teste, não de jogo: a largura do
mapa mudou de tier pra tier, e a lista de "warp que não deveria existir" precisava aceitar o
Mt Moon como exceção válida). Publicado; confirmado ao vivo sem erro no console.

**Próximo passo:** proponho perguntar ao Gabriel se prefere (a) continuar emendando tiers de
conteúdo (Tier 3: Rota 24/25 → Celadon, no mesmo estilo simplificado) ou (b) parar a expansão
de mapa por ora e priorizar Fly/Bike/Surf-pra-atravessar (que tornam qualquer mapa grande
worth it) antes de continuar esticando o território.

**Precisa de decisão do Gabriel?** Sim — ver "Próximo passo" acima. E vale saber do
recorte de escopo (litoral/ilhas e sistemas de transporte ainda não existem).

---

## v0.2.8 — Correção de arquitetura: mundo aberto de verdade, sem warp entre cidade/rota (2026-08-31, continuação)

**Regra do Gabriel:** warp só serve pra caverna, subterrâneo, submarino ou troca de
continente. Cidade e rota têm que ser **o mesmo mapa contínuo**, andável, com Surf/Voar/
Teleporte como formas de atravessar mais rápido no futuro. A v0.2.7 (Rota 2 + Pewter como
cenas separadas, ligadas por warp) contrariava essa regra — desfeita e reconstruída certa.

**O que mudou:** `Route2.tscn` e `PewterCity.tscn` foram apagados. Pewter City e Rota 2 agora
são **parte do mesmo `world_map` único** que já continha Pallet/Rota 1/Viridian — o jogador
anda direto do Ginásio do Brock até Pallet Town sem nenhuma transição de tela no meio (só
existe warp pra dentro do Centro Pokémon, que é "interior", não mundo aberto — a mesma
exceção que já valia antes).

- `world_map` cresceu de 100×120 pra **100×192** — as 72 linhas novas (Pewter + Rota 2)
  entraram ao NORTE de Viridian.
- Decisão de segurança pra não arriscar o que já estava testado: o código de Viridian/Rota 1/
  Pallet (`_viridian_cell`/`_route1_cell`/`_pallet_cell`) **não foi tocado** — só ganhou um
  "tradutor" de número de linha (`old_r = r - 72`) na função que decide qual pedaço do mapa é
  qual. Toda a lógica interna de cada um continua exatamente igual a antes.
- **Achado no caminho**: Viridian tratava as 3 primeiras linhas como "borda norte" (fazia
  sentido quando era literalmente o topo do mapa) — isso criava uma parede de 3 tiles bem no
  meio do corredor, agora que a Rota 2 continua pra cima. Corrigido só nas colunas do
  corredor, sem mexer em mais nada de Viridian.
- Brock, o Colecionador de Insetos e o Centro Pokémon de Pewter viraram NPCs/warp dentro do
  `WorldMap.tscn` (não mais de uma cena própria) — reaproveitado tudo que já tinha sido
  escrito na v0.2.7 (time do Brock, `starts_quest_id`, diálogos), só reposicionado.
- `zones.json` atualizado: os y de pallet_town/route_1/viridian_city subiram 72 (mesmo
  deslocamento), pewter_city e route_2 ganharam tile_rect de verdade no frame único.

**Testado:** `teste_fase3_mapa.gd` reescrito pra provar mundo aberto de verdade — o teste mais
importante novo é "anda reto do topo do mapa até quase o fim de Pallet pela coluna do
corredor, sem nenhuma quebra" (190 linhas conferidas, 0 quebras) — e que nenhum warp de
cidade/rota sobrou no WorldMap.tscn (só os do Centro Pokémon). `teste_fase2_pesca.gd` também
precisou de ajuste (o lago da Rota 1 continuava certo no jogo, só o TESTE checava a linha
antiga, sem saber do deslocamento novo — achado de teste, não de jogo). Os 4 arquivos de
teste juntos (Fases 0-3): **97 conferências, 0 falhas**. Publicado; confirmado ao vivo sem
erro nenhum no console, andando de verdade por Pallet → Rota 1 → Viridian sem nenhuma tela de
carregamento no meio. Não cheguei a ver Pewter com os próprios olhos desta vez — a distância
até lá dobrou (a viagem agora é ~146 tiles a pé, o dobro de antes), e minha navegação
automática por script não é rápida o bastante pra isso num tempo razoável; pra um jogador de
verdade segurando a tecla, é uma caminhada de talvez 1 minuto.

**Próximo passo:** Tier 2 da expansão de mapa (Rota 3 → Mt Moon → Rota 4 → Cerulean City,
destrava a Misty) — mesmo padrão agora validado (mundo único, sem warp, código antigo
intocado, só a tradução de linha).

**Precisa de decisão do Gabriel?** Não — a arquitetura pedida está implementada e testada.
Vale confirmar Pewter/Brock ao vivo quando puder (é uma caminhada mais longa agora).

---

## v0.2.7 — Fase 3 do Diário, Tier 1: Rota 2 + Pewter City + Ginásio do Brock (2026-08-31, continuação)

**Correção do Gabriel:** Brock é o Líder de Pewter City, não de Viridian (eu tinha sugerido
reaproveitar Viridian como workaround, errado). Pedido: expandir o mapa de verdade — todas as
estradas e cidades — antes de continuar com Ginásios.

**Achado de escopo antes de começar:** `data/world/zones.json` já tem os **52 zonas do Kanto
inteiro** planejadas (todas as 10 cidades + ~25 rotas + dungeons), com tile_rect definido pra
cada uma — mas numa escala de mapa (~260×305 tiles) que nunca foi construída, e cujas
coordenadas **colidem** com o mapa real de 100×120 que já existe (Rota 2, por exemplo, tinha
tile_rect sobrepondo o espaço da Rota 1 e Pallet já construídas). Confirma: "todas as
estradas e cidades" é o maior trabalho de conteúdo da história do projeto — várias sessões,
não uma. Construí este Tier 1 (o pedaço que já destrava o primeiro Ginásio) com uma decisão de
arquitetura importante: **em vez de esticar o world_map único** (arriscado — exigiria
deslocar linha por linha tudo que já existe e está testado), cada cidade/rota nova vira **cena
própria**, conectada por warp — mesmo padrão já usado pelo Centro Pokémon.

**Construído:**
- **Rota 2** (16×50, cena nova) — liga o norte de Viridian a Pewter, grama com árvore/flor
  esparsa igual a Rota 1, um Colecionador de Insetos treinador, e **Geodude no spawn
  selvagem** (não existia Geodude em lugar acessível nenhum antes).
- **Pewter City** (40×30, cena nova) — Ginásio do Brock a oeste, Centro Pokémon a leste,
  praça central, pedras decorativas. Brock tem time real (Geodude Nv.12 + Onix Nv.14) e
  **inicia a quest GYM-01 sozinho** ao ser abordado.
- **NpcEntity ganhou `starts_quest_id`** — flag genérica (mesmo padrão de `heal_on_dialog_end`/
  `opens_shop_on_dialog_end`) pra qualquer NPC futuro poder disparar uma quest ao fim do
  diálogo, sem precisar de código específico por NPC.

**2 achados de bug corrigidos no caminho, mesma classe dos anteriores:**
- **A saída do Centro Pokémon sempre voltava pro mesmo lugar fixo** (perto de Pallet), mesmo
  entrando por Viridian — nunca dava pra notar com só 2 entradas indo pro mesmo destino por
  coincidência. Agora cada entrada guarda de onde veio (`WorldManager.
  remember_pokemon_center_return`) e a saída usa isso — testado com a 3ª entrada nova (Pewter)
  sem quebrar as 2 antigas.
- **Nenhum NPC treinador do jogo (nem o "Treinador" da Rota 1, que já existia) tinha
  `trainer_team` de verdade configurado** — `is_trainer=true` sozinho nunca bastava
  (`_on_dialog_ended` exige o time não-vazio pra iniciar a luta). O Treinador da Rota 1 nunca
  bateu em ninguém a vida inteira do jogo. Corrigido nele também, de brinde.
- Bônus: `register_map()` tocava sempre a música do Centro Pokémon fixa pra qualquer mapa fora
  do world_map — agora busca a música certa em zones.json pelo map_id.

**Testado:** `scripts/tests/teste_fase3_mapa.gd` (21 conferências) — as duas cenas carregam
sem erro, o layout de cada uma bate tile a tile com o desenhado, Brock existe com o nome e
time certos, Geodude está mesmo na tabela de spawn da Rota 2. Rodei os 4 arquivos de teste
juntos (Fases 0-3, 97 conferências) sem nenhuma regressão. Publicado; confirmado ao vivo que
o jogo sobe e joga sem erro nenhum, e que **dá pra alcançar a Rota 1 andando de verdade** —
não consegui, desta vez, fazer a navegação cega por script cobrir terreno rápido o bastante
pra chegar até a Rota 2/Pewter de propósito (ficava perdendo tempo em encontros selvagens);
isso é limitação da forma como eu testo, não indício de bug — tudo que dá pra conferir sem
jogar ao vivo já foi conferido com cuidado.

**Próximo passo:** continuar expandindo o mapa (Tier 2: Rota 3 → Mt Moon → Rota 4 → Cerulean,
destrava a Misty) — ou, se o Gabriel preferir, pausar a expansão de mapa aqui e confirmar
Pewter/Brock jogando primeiro antes de eu seguir construindo mais cidades.

**Precisa de decisão do Gabriel?** Sim — vale ele confirmar Pewter/Brock ao vivo (suba a Rota
1 até o fim, vire a esquina em Viridian pro corredor central e continue subindo) antes de eu
emendar direto pro Tier 2, já que é MUITO conteúdo pra construir sem checkpoint nenhum.

---

## v0.2.6 — Fase 2 do Diário: skills do Treinador ligadas à batalha real + Pesca (2026-08-31, continuação)

**Pedido:** Fase 2 — skills do Treinador (já existia, ver Fase 0) e Pesca (não existia).

**Achado antes de construir pesca: 3 bônus da árvore de skills, prontos desde sempre, nunca
eram lidos pela batalha de verdade** — mesma classe dos achados anteriores (held_item na
Fase 1, o motor de quest na Fase 0):
- `_attempt_capture()` lia `species.get("capture_rate", 45)` — campo real é `"catch_rate"`.
  Igual ao bug de stats da Fase 1: todo Pokémon, capturado com a MESMA chance base (45),
  nunca a chance real da espécie (Pidgey era tão difícil de capturar quanto um raro).
  Corrigido, e aproveitado pra ligar o bônus do ramo "mestre_captura" (nunca era somado).
- Loot de vitória sempre chamava `roll_drop(nivel, 0)` — o bônus do ramo "sorte" nunca
  chegava a valer nada. Corrigido pra ler o ponto de verdade do Treinador.

**Pesca construída do zero** (não existia nada, só os 3 itens de vara — sem nenhum código
neles, e nem um tile de água no mapa inteiro):
- **Lago pequeno** criado na Rota 1 (não existia água em lugar nenhum do jogo até agora).
- **Pescador** (NPC novo) no lago, dá uma Vara Velha de presente (só 1 vez).
- Ficar de frente pra água + apertar interagir com vara no inventário → chance de fisgar
  (varia por vara: comum só Magikarp, boa Magikarp/Goldeen, super mistura rara incluindo
  Gyarados) → vira uma batalha selvagem de verdade, pelo mesmo sistema de sempre.
- Achado no caminho: `BaseEntity.interact()` não avisava se achou alguém — precisei fazer
  virar `true`/`false` pra pesca só tentar quando não tem NPC na frente (não quebrou nada
  que já chamava, ninguém usava o retorno antes).

**Testado:** `scripts/tests/teste_fase2_pesca.gd` (14 conferências) — o lago existe de
verdade nos dados do mapa, taxa de mordida e faixa de nível de cada vara batendo com a
tabela, Gyarados raro aparecendo em milhares de tentativas, bônus de captura/sorte batendo
o número certo depois de gastar ponto de skill. Publicado; testado ao vivo (sem erro no
console, "Route 1" alcançada de verdade andando) mas **não confirmei visualmente pescar de
verdade** — a navegação cega por script até o lago específico não teve sucesso em tempo
razoável (esbarrei em várias batalhas selvagens no caminho). Vale você mesmo ir lá quando
puder: suba por Rota 1, saia do corredor central pro lado leste, o lago e o Pescador ficam
perto do meio da rota.

**Próximo passo:** Fase 3 (primeiro Ginásio jogável — usa a Fase 0, mas precisa de uma
quest nova apontando pro Ginásio de Viridian de verdade, não pro GYM-01 que aponta pra
Pewter/Brock, que não existem).

**Precisa de decisão do Gabriel?** Não pra continuar — só peço que confirme a pesca ao vivo
quando puder, já que eu não consegui visualmente desta vez.

---

## v0.2.5 — Fase 1 do Diário: Nature, Ability, Item segurado, Bestiary — e um bug crítico achado no caminho (2026-08-31, continuação)

**Pedido:** seguir a Fase 1 do Diário — Nature, Ability passiva, Held Item ativo em batalha
(o dado já existia, nunca era lido), Bestiary com contagem de derrota.

**🔴 Achado crítico no meio do caminho, corrigido:** escrevendo o teste da Nature, o número
batido a mão não fechava com o jogo. Causa: `BattlePokemon._calculate_stats()` (o cálculo de
ataque/defesa/velocidade usado em TODA batalha do jogo, sempre foi assim) lia as chaves
`"atk"/"def"/"spa"/"spd"/"spe"` — só que `species.json` usa `"attack"/"defense"/"sp_atk"/
"sp_def"/"speed"`. Como a chave nunca batia, `.get(chave, 45)` sempre caía no valor-padrão
**45, pra qualquer Pokémon, sempre** — só o HP estava certo (a chave "hp" bate nos dois
lados por coincidência). Na prática: todo Pokémon do jogo, em toda batalha desde que o
sistema foi escrito, lutava com ataque/defesa/velocidade genéricos, nunca com a estatística
real da espécie (um Golem não batia mais forte que um Caterpie). Mesmo bug encontrado e
corrigido em `FollowerPokemon.gd` e `WildPokemon.gd` (o sistema de "bodyguard" do overworld,
hoje sem uso real, mas corrigido igual por consistência).

**O que foi construído, com essa base agora corrigida:**
- **Nature**: 25 natures clássicas (`GameData.NATURES`), sorteada ao criar/capturar um
  Pokémon, ±10% numa stat (nunca HP) — aplicada dentro do próprio cálculo que acabou de ser
  corrigido acima.
- **Ability passiva**: campo novo em `species.json`, preenchido pra 19 espécies alcançáveis
  no jogo hoje (as 3 linhas dos iniciais + Pidgey/Rattata/Zubat/Geodude, cada linha evolutiva
  com a ability real da série) — as outras 132 espécies ficam sem ability por enquanto
  (padrão seguro, sem quebrar nada, é conteúdo pra preencher aos poucos). Efeito de dano
  implementado pra 4 delas: Overgrow/Blaze/Torrent (+50% no próprio tipo com HP ≤ 1/3) e Guts
  (+50% em golpe físico quando statusado).
- **Held Item ativo**: 4 itens novos (Charcoal/Mystic Water/Miracle Seed/Magnet, categoria
  "held", +20% de dano no tipo correspondente) — achável como loot raro (tier épico) e
  equipável de verdade (`SaveManager.equip_held_item`/`unequip_held_item`, com troca segura
  se já tinha outro item). Sem tela pra isso ainda (Fase de layout).
- **Bestiary**: `SaveManager.record_defeat(species_id)`/`get_defeat_count()` — contagem por
  espécie, incrementada em toda vitória contra Pokémon selvagem (não conta treinador).

**Testado:** `scripts/tests/teste_fase1_pokemon.gd` (headless, mesmo padrão da Fase 0), 36
conferências — Nature aplicada certo no stat final (valor batido a mão contra a fórmula
real), ability ativando/desativando conforme HP e status, item segurado afetando só o tipo
certo, equipar/desequipar trocando com o inventário, Bestiary sobrevivendo a salvar/
recarregar. Publicado e confirmado ao vivo: batalha selvagem real (Bulbasaur vs Rattata)
funcionando normal, sem erro no console.

**Próximo passo:** Fase 2 (árvore de skills do Treinador — já existe, só nunca foi salva/
instanciada até a Fase 0 arrumar isso — e Pesca, que não existe ainda).

**Precisa de decisão do Gabriel?** Não pra continuar. Vale saber do achado do bug de stats —
é a correção mais importante feita no jogo até agora, mesmo não sendo o que foi pedido.

---

## v0.2.4 — Fase 0 do Diário: motor de Quests/Ginásios ligado de verdade (2026-08-31, continuação)

**Pedido do Gabriel:** seguir o "Diário PokéMobile" (plano de fases) em ordem de execução,
motor antes de layout. Fase 0 era "ligar o QuestManager" — parecia 1 sessão curta (registrar
1 autoload + 1 método). Na prática, abrir o arquivo revelou que ele nunca teria funcionado
mesmo ligado: usava `Engine.has_singleton()`/`get_singleton()` pra falar com EventBus/
SaveManager/GameData — API errada pra autoload do Godot (é só pra singleton nativo/C++, os
autoloads deste projeto sempre foram chamados direto pelo nome). Isso fazia TODO o motor de
recompensa/progresso ser, na prática, morto silencioso.

**O que foi corrigido/construído, tudo em `scripts/systems/QuestManager.gd` e ao redor:**
- Trocado `Engine.has_singleton(...)` por chamada direta (`SaveManager.x()`, `EventBus.x`,
  `GameData.x()`) em todo o arquivo.
- 5 dos 6 sinais que o QuestManager escutava tinham nome/formato diferente do EventBus real
  (ex: esperava `pokemon_caught(species_id, is_alpha)`, o sinal real é
  `capture_success(pokemon_data: Dictionary)`; esperava `dialog_ended(npc_id)`, o real é
  `dialog_ended()` sem nenhum argumento). Todos os 6 handlers reescritos pros sinais de
  verdade — o de diálogo agora lembra qual NPC foi o último (`dialog_started` guarda, `dialog_ended`
  usa e limpa).
- `battle_ended` já existia mas não carregava o que a quest precisa (quem venceu, se era
  selvagem, nome da espécie/treinador) — `BattleManager._end_battle()` ganhou esses campos
  novos no resultado, sem tirar os que já existiam.
- **Achado sério à parte**: nunca existia um "carregar progresso salvo" — só um "salvar",
  nunca um par que lesse de volta. Todo progresso de quest sumiria ao reabrir o jogo mesmo
  funcionando perfeitamente durante a sessão. Corrigido (`reload_from_save()`), e chamado
  duas vezes: no boot do autoload E de novo depois que a TitleScreen carrega um save de
  verdade (achado no meio do caminho: o autoload sobe ANTES da Title decidir se há save pra
  carregar — sem a segunda chamada, "Continuar" sempre mostraria progresso zerado).
- `SaveManager.gd` ganhou os métodos que faltavam pras recompensas funcionarem de verdade:
  `award_badge`/`has_badge`/`get_badges`, `unlock_title`/`has_title`/`get_titles`,
  `save_quest_progress`/`get_all_quest_progress`, `add_pokemon_to_party` (alias),
  `add_trainer_exp` (**XP e nível do Treinador não existiam em lugar nenhum** — só uma
  entrada morta no save; construído com a mesma curva cúbica do Pokémon, por consistência),
  `get_trainer_stats`/`add_skill_points`/`spend_skill_point` (o "TrainerStats" 5-ramos já
  existia mas nunca foi instanciado/salvo por ninguém — agora o SaveManager é o dono de
  verdade dos dados, TrainerStats só faz a conta).
- `GameData.get_species_id_by_name()` — os alvos de missão são escritos por nome
  ("geodude"), o dado de espécie é indexado por ID numérico; helper novo resolve isso.

**🔴 Achado de conteúdo, não de motor — importante pra Fase 3:** as 54 quests de
`data/quests/quests.json` (inclusive os 8 Ginásios) foram escritas pra um mundo bem maior do
que o que existe hoje — Pewter City, Brock, Mt Moon, Rota 25, "Cerulean" não existem no mapa
atual (só Pallet Town + Rota 1 + Viridian City). Isso significa: o motor agora funciona
perfeitamente (provado no teste), mas nenhuma das 54 quests originais é jogável hoje sem
reescrever o alvo pra algo que já existe no jogo. A Fase 3 (Ginásio jogável) vai precisar de
uma quest nova apontando pro Ginásio de Viridian de verdade, não usar o GYM-01 como está.

**Testado:** Novo teste `scripts/tests/teste_quest_manager.gd` (headless, `godot4 --headless
--script ...`, roda sem precisar de navegador) — 26 conferências, simula 3 quests reais
(ROCKET-01, GYM-01, UTIL-11) de ponta a ponta: iniciar → progresso parcial → progresso
completo → recompensa (XP, item, TM, insígnia, pontos de skill) → encadeamento (`unlocks`)
→ sobrevive a salvar e recarregar. Achado no caminho: rodar via `--script` não dá acesso aos
autoloads pelo nome direto (só quando o jogo sobe pela cena normal) — resolvido buscando por
`/root/NomeDoAutoload`. Publicado e confirmado ao vivo no navegador: jogo sobe normal, zero
erro de script, sem regressão em nada que já funcionava.

**Próximo passo:** Fase 1 do Diário (Nature, Ability, Held Item ativo em batalha, Bestiary
com contagem de derrotas) — também "motor", sem UI nova.

**Precisa de decisão do Gabriel?** Não pra continuar a Fase 1. Vale avisar sobre o achado de
conteúdo acima (quests.json não bate com o mundo construído) antes da Fase 3.

---

## v0.2.3 — Loja física em Viridian + lore/NPCs novos + colisão de verdade (árvore/parede) (2026-08-31, continuação)

**Pedido do Gabriel:** "próxima etapa do cronograma — lore, interações com NPCs, criar as lojas
pra comprar itens, Pokémon selvagem derrotado dropar item vendável na loja." No meio do trabalho,
ele mandou um segundo pedido: "árvores/paredes estão intangíveis, usar construção de mapa
baseado em Poketibia."

**Antes de construir, conferi o que já existia** (loja Comprar/Vender e loot dropável/vendável
já estavam prontos e testados desde mais cedo hoje — não recriei). O que faltava de verdade:

1. **Loja física em Viridian City.** Achado bom: o prédio da loja **já estava desenhado no mapa**
   (`MapLayouts.gd`, paredes/telhado/porta, cols 50-60) — só vazio por dentro. Um diálogo antigo
   da Pesquisadora até já dizia "existe uma loja ali ao norte", uma pista nunca resolvida. Coloquei
   um NPC "Vendedor" lá dentro (`opens_shop_on_dialog_end` — reaproveita a MESMA `ShopScene` do
   menu de Pausa, só chamada por diálogo em vez de botão).
2. **Lore.** Expandi todos os diálogos existentes e criei o gancho central: o Líder do Ginásio de
   Viridian sumiu, e um Ancião novo (NPC) conta uma lenda de um Pokémon guardião nas montanhas —
   a Pesquisadora e o Guarda também dão pistas que apontam pro mesmo mistério. Nada resolvido
   ainda de propósito (é gancho de história, não quest).
3. **NPC reativo.** A Enfermeira Joy agora fala diferente se ninguém no time está machucado
   (`nurse_joy_healthy`) — pequena interação de verdade, usa o HP salvo, não é só decoração.

**Depois, achado ao construir #1: o ponto de interação do jogador tinha um bug nunca antes
exercido.** `BaseEntity.interact()` (usado por todo NPC pra ser "falado com") checava
`params.collision_mask = collision_layer` — a própria camada da entidade, não quem ela queria
detectar (devia ser `= collision_mask`). Nunca deu pra notar porque **o jogador nunca chamava essa
função** — tinha a própria versão em pixel, separada. Corrigido junto (ver item 4).

4. **🔴 Pedido do meio da sessão: árvores/paredes intangíveis.** Causa raiz: o `TrainerEntity`
   (jogador) tinha o próprio sistema de movimento contínuo em pixel (`move_and_slide`, sem checar
   o mapa nenhuma vez) — **nunca usava** o `WorldManager.is_tile_walkable()` que os NPCs já usam
   desde sempre (por isso NPC nunca atravessava parede, só o jogador). Reescrito: `TrainerEntity`
   agora **herda de `BaseEntity`** (mesma classe-base do NPC) e usa o mesmo `try_move()` tile a
   tile com checagem real contra o mapa — exatamente o "estilo Poketibia" pedido (segurar uma
   tecla anda um tile de cada vez, bate na árvore/parede e para). Ganho de bônus: como
   `try_move()` já vira de frente sem andar quando esbarra, ganhou o "bump" clássico de graça.
   O sistema do Pokémon seguidor (rastro em pixel) não precisou mudar — só a fórmula de
   "quantos frames atrás" foi ajustada pra nova velocidade tile a tile.

**Testado:** Recompilado e publicado. Confirmado AO VIVO no navegador, numa partida real: jogador
bloqueado de verdade pela fileira de árvores da borda do mapa (não atravessa mais), transição
Pallet Town → Rota 1 funcionando, Pokémon seguidor continua acompanhando, batalha selvagem abre e
"Fugir" funciona, **zero erro de script no console** em várias partidas seguidas.
**Não confirmado ao vivo** (por dificuldade de navegar às cegas por script até lá, não por dúvida
no código): abrir a Loja falando com o Vendedor, e o diálogo novo do Ancião — os dois foram lidos
com cuidado linha por linha e conferidos contra `godot4 --headless --import` sem erro, mas vale
você mesmo conferir jogando (é rápido: suba até Viridian City e entre no prédio à esquerda do
corredor central).

**Próximo passo:** o Gabriel jogar e confirmar Loja + Ancião + a sensação da colisão nova.

**Precisa de decisão do Gabriel?** Não — os dois pedidos (lore/loja e colisão) foram atendidos
como descritos.

---

## v0.2.2 — Distância do Pokémon seguidor + derrota leva ao Centro Pokémon (2026-08-31, continuação)

**Pedido do Gabriel:** o Pokémon seguidor precisa ficar pelo menos 2 blocos (tiles) atrás do
treinador andando, pra não sobrepor o sprite; e ao ser derrotado numa batalha, o jogador deve ir
ao Centro Pokémon curar o time, não só "reaparecer curado" em qualquer lugar.

**O que foi feito:**
- `FollowerPokemon.FOLLOW_DISTANCE` (a distância de repouso atrás do treinador) subiu de 24px
  (1,5 tile) pra 32px — exatamente 2 tiles de 16px, o pedido do Gabriel. `TrainerEntity.
  _update_follower()` calculava a mesma distância só que com o número 24.0 solto e repetido
  (duplicação que já podia dessincronizar os dois) — trocado pra referenciar a constante do
  `FollowerPokemon` em vez de duplicar o número.
- Tela de "Você perdeu" (`GameOverScene`) já existia e já curava o time (`SaveManager.
  heal_team()`, que reanima até o Pokémon desmaiado — `hp_current = hp_max`) — só que o botão
  "Continuar" levava pro `WorldMap.tscn` num ponto qualquer. Trocado pra levar pro
  `PokemonCenter.tscn` de verdade (mesmo mapa que já existe e já é usado quando o jogador visita
  a Enfermeira Joy manualmente — reaproveitado, não inventado do zero). Texto da tela ajustado
  pra "você foi levado ao Centro Pokémon" (antes só dizia "desmaiaram", sem explicar pra onde ia).

**Testado:** Recompilado e publicado. Confirmado ao vivo no navegador (Chromium automatizado):
andando, o Pokémon segue com folga visível, nunca sobrepõe o treinador; parado por 6s seguidos,
a distância não fecha (não gruda no treinador). **Não confirmado ao vivo**: o fluxo completo de
derrota → Centro Pokémon (exigiria derrotar o time inteiro em batalhas reais, o que não desse pra
forçar rápido nesta sessão) — conferido só pelo código: reaproveita a mesma função de cura e o
mesmo mapa que já funcionam comprovadamente noutro fluxo (visita manual à Enfermeira Joy), e a
checagem `godot4 --headless --import` não achou erro de script depois da mudança.

**Próximo passo:** o Gabriel confirmar ao vivo que perder uma batalha de verdade leva ao Centro
Pokémon como esperado.

**Precisa de decisão do Gabriel?** Não — só pediu essas duas coisas e as duas foram feitas.

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
