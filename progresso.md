# Progresso — PokéMobile

> Formato de cada entrada: Lote, o que foi feito, o que foi testado, próximo passo,
> se precisa de decisão do Gabriel. Mais recente primeiro.
>
> A partir de 31/08, cada evolução de progresso ganha uma tag de versão no Git
> (`git tag`, ex: v0.2.1) e é enviada ao GitHub — assim dá pra voltar ou comparar
> qualquer momento anterior. Ver lista de versões: `git tag`.

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
