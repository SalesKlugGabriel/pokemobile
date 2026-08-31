# Progresso — PokéMobile

> Formato de cada entrada: Lote, o que foi feito, o que foi testado, próximo passo,
> se precisa de decisão do Gabriel. Mais recente primeiro.

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
