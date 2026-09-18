# GAMEPLAY V3 — 3D · direção atual e autoritativa

> ⚠️ **O estado atual vive em [`QUADRO.md`](QUADRO.md)**, não aqui. Este arquivo é
> o painel detalhado da migração — fase por fase, com as medições de cada uma.
> Em caso de divergência, o quadro ganha.

> **Leia este arquivo primeiro ao retomar a V3.** Ele é o painel de controle da
> migração e o único lugar onde o estado de cada fase é atualizado.
>
> Em qualquer conflito entre V2 e V3, **V3 vence** — mas sistema da V2 que
> continua compatível é **preservado**, não reescrito.

**Aberto em:** 14/09/2026 · **Base:** commit `bef3146`
**Documentos irmãos:** [RFC](rfc/RFC-GAMEPLAY-V3-3D.md) ·
[migração](MIGRATION_V2_TO_V3.md) · [mundo](WORLD_3D_ARCHITECTURE.md) ·
[combate 1ª pessoa](COMBAT_FIRST_PERSON.md) · [surf e voo](TRAVERSAL_SURF_FLY.md)

---

## A fantasia que precisa ser provada

> **Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
> controle do meu Pokémon.**

Tudo que não contribui direto pra provar isso fica em segundo plano.

**Não é MOBA.** Combate 1v1, no próprio terreno, sem arena. Valorant, Paladins e
Smite entram só como referência de **controle, câmera, mira e resposta**. ARK
entra como referência de **mundo, relevo, escala e verticalidade**. A identidade
continua Pokémon.

---

## 📍 ONDE ESTAMOS

| | |
|---|---|
| **Fase atual** | **9 — ataque básico** (0 a 8 fechadas) |
| **Branch** | `agent/claude-v3` · `main` segue com a V2 |
| **Código V3 escrito** | input, locomoção, 2 câmeras, treinador, terreno, Pokémon, companheiro, transferência |
| **Bloqueio** | nenhum — as 3 decisões estão fechadas |

### Decisões em aberto (precisam do Gabriel)

| # | Decisão | Quando trava |
|---|---|---|
| 1 | ~~Billboard ou modelo?~~ | ✅ **MODELO 3D** (Gabriel, 14/09). Ver abaixo |
| 2 | ~~Manter `gl_compatibility`?~~ | ✅ **RESOLVIDO** — medido, aguenta. Ver abaixo |
| 3 | ~~`Terrain3D` de terceiros ou malha própria?~~ | ✅ **malha própria** (Claude, 14/09). Ver abaixo |

### 📦 Primeiro modelo entregue — Charizard (Codex, 14/09)

**Certo em tudo, e deitado.** Formato, materiais, as 4 animações e a escala
**exata** — mas o eixo de altura foi exportado no −Z (Blender Z-up sem
conversão). Girando +90° em X: altura **1,700 m** (a Pokédex, exata) e pés em
**0,000**.

Construído `ValidadorDeModelo.gd`: mede todo modelo contra `heights.json`,
reprova o que não bate, e corrige **só** o giro de 90° — que tem assinatura
própria — gritando "conserte o export, não o jogo". Não inventa correção pra
modelo que está só errado, e há teste provando isso.

Retorno ao Codex em `docs/agent-reviews/claude/2026-09-14-modelo-charizard.md`.
**Esperando o reexport.** Se a altura sair 1,700 direto, o contrato está provado
e os outros 150 vêm em fila sem conferência manual.

### ✅ Decisão 1 — modelo 3D (Gabriel, 14/09)

Os Pokémon serão **modelos 3D**, não sprites em billboard.

**O que isso custa, declarado:** os **605 sprites deixam de servir** para o
mundo (continuam valendo para Pokédex, HUD e menus, que são `Control`). A
produção de modelos vira o **caminho crítico** do projeto — não o código.

**O que isso NÃO bloqueia:** a §16 do pedido permite placeholder, e o slice
precisa de **3 Pokémon** (um terrestre, um aquático, um voador), não de 151.
Então a Fase 5 anda com cápsulas e formas primitivas enquanto o modelo real não
existe.

**A consequência de arquitetura, e é a que importa:** `PokemonInstance3D` tem de
carregar o visual **por dado**, nunca por espécie cravada em script. Um modelo
que chega depois entra trocando um caminho de arquivo, sem tocar em entidade,
combate ou IA. O contrato do que um modelo precisa entregar está em
`docs/POKEMON_MODEL_PIPELINE.md`.

O Blender 4.2.9 headless já está instalado nesta VPS desde 11/09, com pipeline
de render e validação de asset — é por ali que a produção começa.

### ✅ Decisão 3 — malha própria, sem plugin (Claude, 14/09)

Terreno gerado por código, não `Terrain3D` de terceiros. Três motivos:

1. O renderer é `gl_compatibility`; plugin de terreno costuma assumir Forward+.
2. O slice é **pequeno de propósito** (§10) — ferramenta de edição de terreno
   resolve um problema que ainda não temos.
3. Dependência externa num pivô que já tem risco suficiente.

Reversível: se o mundo grande pedir ferramenta, troca-se a geração mantendo o
contrato de colisão e altura.

### ✅ A medição da Fase 2 (14/09, desktop, navegador real)

`gl_compatibility` · 1592×720 · 20.000 instâncias em MultiMesh + 40 corpos com
física + sombra direcional ligada.

| Vegetação | FPS |
|---:|---:|
| 0 | 83,5 |
| 500 | 86,0 |
| 2.000 | 83,5 |
| 8.000 | 76,0 |
| **20.000** | **67,0** |

**Piso de 67 FPS no pior caso, acima da meta de 60.** A curva cai ~20% ao
adicionar 20 mil plantas — o MultiMesh está fazendo o trabalho dele.

⚠️ **Ruído de ~3 FPS**: 500 plantas mediu *mais* que 0. Diferença abaixo disso
não é real, e não vale tirar conclusão dela.

⚠️ **Isto é DESKTOP.** O celular é o aparelho fraco e é o que decide de verdade.
Medir nele antes da Fase 19 (polimento), quando a vegetação real existir.

🔵 **Achado de brinde:** na captura dá pra ver a HUD da V2 e o botão de feedback
desenhando **por cima da cena 3D**. Os autoloads sobrevivem ao pivô sem nenhuma
adaptação — prova visual do que a tabela de migração afirmava.

---

## As 20 fases

Marcar aqui a cada sessão. **Uma fase só vira ✅ quando tem teste e foi vista
rodando** — não quando o código existe.

| # | Fase | Estado | Nota |
|---|---|---|---|
| 0 | Auditoria | ✅ | 14/09 · `MIGRATION_V2_TO_V3.md` |
| 1 | Documentação / RFC | ✅ | 6 documentos |
| 2 | Cena 3D experimental isolada | ✅ | 14/09 · **medido em navegador real: piso de 67 FPS** |
| 3 | Treinador em 3ª pessoa | ✅ | 14/09 · 36 conferências · `ControlModeManager` + `Locomocao3D` + `CameraTerceiraPessoa` |
| 4 | Terreno 3D | ✅ | 14/09 · altura, falésia, praia contínua e água · 17 conferências |
| 5 | Pokémon 3D | ✅ | 14/09 · composição, 8 arquétipos declarados e 5 implementados · 36 conferências |
| 6 | Companion Pokémon | ✅ | 14/09 · distância derivada do tamanho dos dois · 18 conferências |
| 7 | Transferência Treinador → Pokémon | ✅ | 14/09 · ida, volta, e a queda devolvendo o controle · 40 conferências |
| 8 | Pokémon em 1ª pessoa | ✅ | 14/09 · câmera por espécie, corpo segue a mira |
| 9 | Ataque básico | ✅ | 17/09 · `AtaqueBasico` + `RelatorioDeGolpe.montar_3d` · 50 conferências |
| 10 | 4 skills | ✅ | 17/09 · `FormaDeArea3D` + `UsoDeSkill` · single/circle/cone/line, aviso e drenagem · 61 conferências |
| 11 | Wild Pokémon | ✅ | 17/09 · `RegraDeSpawn` + `IASelvagem3D` + `SpawnerSelvagem3D` · 63 conferências |
| 12 | Combate 1v1 | ✅ | 18/09 · `RegraDeCombate` + `Combate1v1` · 34 conferências |
| 13 | Combate → Mundo | ✅ | 18/09 · `RegraDeRetorno` + `RetornoAoMundo` · 50 conferências |
| 14 | Surf | ✅ | 18/09 · `RegraDeTravessia` |
| 15 | Fly | ✅ | 18/09 · zonas de voo e teto relativo |
| 16 | TM/HM | 🔵 próxima | `TrocaDeKit` já existe |
| 17 | Move Pool | ⬜ | `KitDeCombate` já existe |
| 18 | Alpha | ⬜ | regras já existem |
| 19 | Polimento | ⬜ | **Codex entra aqui** |
| 20 | Performance | ⬜ | |

**Não pular fase.** A ordem existe porque cada uma depende da anterior estar de
pé — e porque pular é como se constrói seis sistemas pela metade.

---

## Critério de sucesso da primeira etapa

Funcionando de ponta a ponta, sem travar:

entrar no mundo → andar → correr → olhar ao redor → atravessar terreno →
encontrar um Pokémon → iniciar batalha → **assumir o Pokémon** → lutar em 1ª
pessoa → encerrar → **voltar a ser o treinador**.

Mais, do lado da engenharia:

- **FPS medido em navegador real.** Nunca alegado a partir de teste headless.
- A suíte das 18 classes puras continua verde **sem uma linha alterada**.
- Um save da V2 carrega na V3 **sem migração**.

---

## O que NÃO fazer agora

MMO, servidores, matchmaking, ranking, economia, market, housing, PvP
competitivo, persistência massiva. Também: converter dezenas de Pokémon, criar
mil golpes, construir Kanto, ou produzir gráfico final.

Primeiro single-player local. Depois PvE. Depois 1v1 online. **Muito depois**,
MMO.

---

## Divisão de trabalho

**Nesta fundação, só o Claude conduz** (§45 do pedido): auditoria, arquitetura,
documentação, migração, controller, câmera, combate, integração e testes. A
razão é ter uma autoridade arquitetural única enquanto a fundação se forma.

**O Codex entra na Fase 19**, e só depois de existir o slice funcional com
treinador 3D + terreno + Pokémon 3D + transferência + 1ª pessoa + ataque básico
+ 4 skills + volta ao treinador + surf e voo básicos. Aí ele assume terreno,
vegetação, árvores, grama, água, praia, VFX, animação, HUD e polimento.

⚠️ **Ele tem trabalho não integrado** na branch `agent/codex-gameplay-v2` (HUD,
câmera e telegrafia da V2, commit `28a764e`). O aviso do pivô está escrito em
`docs/agent-proposals/claude/2026-09-14-PIVO-PARA-3D.md` e a fila dele em
`FILA-DO-CODEX-V3.md` — **os dois commitados, mas ele ainda não foi disparado.**

Na fila, o item que mais importa é o **modelo 3D dos Pokémon**: com a decisão do
Gabriel, ele virou o caminho crítico do projeto inteiro, e é a única coisa que
o Codex pode começar a *pensar* antes da vez dele.

---

## Como retomar em outra sessão

1. Ler este arquivo (o painel acima diz a fase).
2. Ler a [RFC](rfc/RFC-GAMEPLAY-V3-3D.md) se a dúvida for de arquitetura, ou a
   [tabela de migração](MIGRATION_V2_TO_V3.md) se for "o que faço com o sistema X".
3. `git branch` — a V3 vive em `agent/claude-v3`; `main` tem a V2.
4. `tools/rodar_testes.sh` antes de começar, pra saber de onde partiu.
5. ⚠️ **Nunca rodar a suíte com outro `godot4` ativo** (`ps aux | grep godot4`).
   Duas suítes em 2 núcleos produzem reprovação falsa — já aconteceu.
6. Ao terminar: atualizar a tabela de fases **aqui**, `progresso.md`, e commitar.

**Nada da V2 é apagado nesta migração.** `MapLayouts`, as 120 cenas 2D e os
tilesets ficam no repositório mesmo depreciados, até a V3 substituir de verdade.

---

## ✅ BUG DE CONTROLE CORRIGIDO (17/09) — eram TRÊS, não dois

O Gabriel relatou: *"se aperto W ele vem em direção da câmera e não na direção
do mouse"*. Diagnosticado em 16/09, **corrigido em 17/09** — e ao medir apareceu
um **terceiro** bug que o diagnóstico de leitura não tinha visto.

Travado por `scripts/tests/teste_controles_v3.gd` (11 conferências). Suíte
inteira: **113 arquivos, 0 com falha.**

São **três bugs somados**:

### 1. `Locomocao3D.girar_para()` está 180° errado

Medido, isolando a conta:

| Indo para | Ângulo que devolve | Correto |
|---|---:|---:|
| −Z (frente) | −3,14 | 0,00 |
| +Z | 0,00 | −3,14 |
| +X | 1,57 | −1,57 |

Em Godot, um nó com `rotation.y = 0` olha pra **−Z**. Pra olhar na direção `d`,
o ângulo é `atan2(-d.x, -d.z)` — e o código usa `atan2(d.x, d.z)`.

### 2. A câmera é FILHA do corpo que gira — realimentação

`CameraTerceiraPessoa` é filha do `TrainerController3D`, então o yaw dela é
**relativo** ao corpo. E o corpo gira pra direção do movimento.

O laço: aperta W → corpo anda pra −Z → `girar_para` vira o corpo 180° (bug 1) →
a câmera, sendo filha, vira junto → agora "frente da câmera" é +Z → W passa a
andar pro outro lado. **É exatamente o "ele vem em direção da câmera".**

### 3. `velocidade_alvo` usava o sinal errado do `intencao.y` ← ACHADO AO MEDIR

O que o diagnóstico de leitura **não** viu. Depois de consertar os dois de cima,
medi a cena rodando:

```
Camera3D olhava pra          (−0,874 · 0 · +0,438)
o personagem andava pra      (+0,894 · 0 · −0,448)     ← o oposto exato
```

`intencao.y` segue a convenção de tela — **−1 é pra frente**, o que
`Input.get_axis("move_up","move_down")` produz e o que a V2 já usava. E a linha
era `frente * i.y`, ou seja `frente * (−1)` com o W apertado.

**É esta a frase do Gabriel, literal.** Os dois primeiros bugs deixavam o
personagem de costas e a câmera girando junto; este é o que fazia o W andar em
direção à câmera.

### A correção, aplicada

1. `girar_para` → `atan2(-d.x, -d.z)`.
2. `camera.top_level = true` + a câmera segue só a POSIÇÃO do treinador.
3. `velocidade_alvo` → `frente * -i.y`.

**Um efeito colateral que o conserto 2 criava, e foi tratado:** com `top_level`,
`position.y = ALTURA_DO_OMBRO` deixa de ser relativo e vira altura ABSOLUTA de
1,5 m no mundo — o treinador numa encosta de 40 m sairia de quadro. A câmera
ganhou `seguir(pes_do_dono)`, que aplica o próprio offset. Conserto que quebra
outra coisa em silêncio é exatamente o padrão que esta sessão passou o dia
caçando.

⚠️ **Falta o Gabriel sentir.** O teste prova direção e independência da câmera;
**não prova sensação de controle** — velocidade, sensibilidade do mouse,
aceleração, distância da câmera. Isso só o playtest diz.

## ✅ RESOLVIDO (17/09) — o contrato de nascimento

Era o bloqueio da Fase 11, e a causa não era a que eu supunha.

**O sintoma:** dois Pokémon parados a 1,2 m, velocidade zero, e o Charizard vai
pra cima do Rattata — 1,264 m em um quadro, determinístico.

**O que eu perdi tempo descartando:** as cápsulas não se sobrepõem (0,476 +
0,180 = 0,656 < 1,2), o `.glb` não traz colisor, ninguém segue ninguém, e não
existe atribuição de `global_position` na entidade. Tudo isso estava certo — e
nada disso era a causa.

**A causa, achada instrumentando `move_and_slide`:** a colisão acontecia com
normal `(0, 1, 0)` — o Charizard **pousava** no Rattata. Um `CharacterBody3D`
passa **um quadro de física** com o colisor onde nasceu, antes de o servidor
acompanhar um `global_position` atribuído depois do `add_child`. Nesse quadro o
Charizard pousa nele; quando o colisor salta pro lugar certo, o Godot **carrega**
quem está em pé — é o comportamento de plataforma móvel.

```
posição definida ANTES  do add_child   deslocamento 0,000 m
posição definida DEPOIS do add_child   deslocamento 1,265 m
```

**E é pior do que parecia:** o corpo de ordem errada nasce na **origem do
mundo** (a posição do pai), não perto do destino. Então ele catapulta quem
estiver na origem — a quantos metros for o destino. No experimento, um Rattata
destinado a 300 m carregou um Charizard que estava na origem.

### O conserto

`PokemonInstance3D.nascer(pai, especie, nivel, posicao, arquetipo)` — posição
**antes** de entrar na árvore, numa porta só. E um detector que dispara no único
quadro em que o erro é perigoso: reposicionar depois do `add_child` e antes do
primeiro quadro de física. Ele **avisa** em vez de corrigir — mover o nó por
conta própria esconderia o erro de quem chamou, e a próxima vez seria em outro
lugar.

Travado por `scripts/tests/teste_nascimento_v3.gd`, que confere os dois sentidos:
pelo `nascer()` ninguém se desloca, **e o jeito errado ainda catapulta** — se ele
parar de catapultar, o primeiro teste passa a provar nada e ninguém saberia.

⚠️ **A Fase 11 usa `nascer()` pra todo spawn de selvagem.** Um spawner que erre a
ordem catapulta o jogador, e o sintoma (personagem voando) não parece nada com a
causa (ordem de duas linhas).

## 🎮 Primeiro playtest do 3D (Gabriel, 14/09)

**Veredito dele:** *"temos um motor rodando e funcionando"*. Primeira vez que
alguém jogou a V3. O Charizard aparece **em pé** — o conserto do eixo funcionou.

**Os dois pedidos, e de quem é cada um:**

| Pedido | Dono | Onde entra |
|---|---|---|
| **Melhorar os controles** | Claude | Fase 19 (polimento) — mas vale antes, é o que a §68 pergunta |
| **Melhorar a qualidade gráfica** | **Codex** | A fila dele: terreno, vegetação, árvores, grama, água |

⚠️ **"Controles" é vago de propósito no relato, e não dá pra adivinhar.** Antes
de mexer, perguntar o que incomodou: velocidade, sensibilidade do mouse,
aceleração/atrito, a virada do personagem, a distância da câmera, ou a troca de
corpo. São seis ajustes diferentes e cada um muda uma coisa distinta.

Os números atuais, pra facilitar a conversa (todos em `Locomocao3D`):
caminhada 4,5 m/s · corrida 8,0 m/s · aceleração 40 · atrito 55 ·
sensibilidade 0,0035 · câmera a 5 m.
