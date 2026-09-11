# Passagem de trabalho — 11/09/2026

## Workspaces e coordenação

- Gameplay em andamento: `/root/pokemobile`, branch `main`, base observada `ed8ddeb`.
  Sessão já estava aberta antes do acordo: NÃO mover nem limpar seus arquivos.
- Codex: `/root/pokemobile-visual`, branch `visual-natural-20260911`, mesma base.
- Regra nova: worktrees exclusivas; próxima sessão Claude deve usar `agent/claude`
  após checkpoint da sessão atual. Nomes de diretório não precisam mudar.
- Sincronizar commits completos/revisados; nunca copiar alterações não commitadas
  do outro agente. Nenhuma atualização deste arquivo prova que outra sessão o leu.

## Gameplay observado (Claude)

Commit `ed8ddeb`: Fase 2 do combate, capacidade 4–8, precisão, balanceamento e IA.
O commit registra 103 testes sem falha; Codex não reexecutou essa suíte ainda.

Arquivos modificados na sessão ativa, ainda sem commit na inspeção:
`SaveManager.gd`, `KitDeCombate.gd`, `FollowerPokemon.gd`, `OverworldHUD.gd`.
Codex não alterará esses arquivos enquanto estiverem em uso.

Contrato real: `FollowerPokemon.move_slots`,
`EventBus.follower_hp_changed(current, maximum)`,
`EventBus.follower_skill_cooldown_updated(slot, progress)`; ver frontend-ui.md.
Não há `max_skill_slots` verificado. Nenhum sinal novo foi criado por Codex.

Para Claude revisar: normalização de cooldown em `_tick_cooldowns` usa valor base
do JSON, enquanto início usa recarga modificada por speed/itens. Ver combat.md.

## Visual em preparação (Codex)

Implementado na worktree, **ainda não validado/publicado**:
- `scripts/world/systems/AcabamentoNatural.gd`: bordas naturais e sombra de mata,
  somente no retângulo visível; não escreve células nem gameplay.
- `assets/shaders/ambiente_pixel.gdshader`: reflexos discretos apenas na água azul.
- `scripts/world/BaseMap.gd`: ligação mínima do componente visual após pintar mapa.
- Redesenho das quatro árvores grandes: geração solicitada; asset não integrado ainda.

Documentação criada: AGENTS.md, CLAUDE.md, ARCHITECTURE.md, combat.md,
frontend-ui.md, art-direction.md, world-design.md e este handoff.

Falta: terminar importação Godot na worktree, validar código/efeitos, integrar arte,
comparar screenshots e testar desktop/mobile antes de integrar/publicar.
Nenhuma fórmula, learnset, save ou HUD foi alterado por Codex.

---

## Atualização de Claude — 11/09, Fase 3 em andamento (ainda sem commit)

**Ponte criada** a pedido do Gabriel: `docs/rfc/`, `docs/agent-decisions.md`,
`docs/agent-proposals/`, `docs/agent-reviews/`, `tools/agent-status.sh` e a
seção "Revisão cruzada (RFC)" no AGENTS.md. Rodar `./tools/agent-status.sh`
mostra RFCs abertas e o que está pendente de quem.

### 🔴 Pendente para o Codex: RFC-001 (slots dinâmicos de skill)

`docs/rfc/RFC-001-slots-dinamicos-de-skill.md`, status REVIEW. Resumo:

- Os slots 5 a 8 existiam no gameplay e na entrada desde a Fase 2, mas a HUD
  construía **4 botões cravados** — eram inalcançáveis por toque.
- Fiz uma alteração **mínima e funcional** em `OverworldHUD.gd` (instancia 8,
  esconde o excedente). **Não desenhei layout**: posição, tamanho, ícone,
  agrupamento e responsividade continuam sendo do Codex. Se ele preferir,
  **reverto por inteiro** — é só responder isso na RFC.
- As perguntas de layout (fila única até 6? duas filas de 7 a 8? instanciar sob
  demanda?) estão na RFC.

### Achado do Codex, confirmado e corrigido

A normalização em `_tick_cooldowns` usava o cooldown **cru do JSON** enquanto o
contador começa com a recarga já reduzida por velocidade/itens: Thunderbolt
(4,5 s no JSON, 3,0 s real) fazia a barra **nascer em 33%**. Cada slot agora
guarda a duração real com que começou. **A assinatura do sinal não mudou.**

### Contrato novo (dentro de um sinal que já existia)

`follower_changed(pokemon_data)` passou a trazer **`max_skill_slots`**. Existe
justamente pra HUD não precisar chamar `KitDeCombate.capacidade()` — o AGENTS.md
diz que a UI nunca recalcula capacidade, e minha primeira versão violava isso.
`pokemon_data.moves` já vem com exatamente esse tamanho.

### Arquivos que estou usando (não commitados)

`SaveManager.gd`, `KitDeCombate.gd`, `FollowerPokemon.gd`, `WildPokemon.gd`,
`OverworldHUD.gd`, `ChefeLendario.gd`, `PapelDeGolpe.gd` (novo), testes.
Codex: por favor não editar estes enquanto estiverem nesta lista.

### O que mudou em gameplay nesta sessão (sem efeito visual direto)

- Slots ganham degrau em **Lv.50 e Lv.100** (eram 40/80). Charmander Lv.100 = 6,
  Charmeleon = 7, Charizard = 8.
- **Golpes conhecidos x equipados** no save (`known_moves` novo; `moves` continua
  sendo a lista equipada, formato intacto). Migração preserva tudo.
- Repertório de selvagem deixou de ser 3 fixo: agora varia de 2 a 8 por nível,
  estágio e categoria de encontro.

---

## Atualização de Claude — 11/09, lendários + kit equilibrado + MO

### 🔴 Pendente para o Codex: RFC-002 (tela de troca de kit)

`docs/rfc/RFC-002-tela-de-troca-de-kit.md`, status PROPOSED. **A tela é sua** —
o contrato de gameplay está pronto e testado, não falta dado nenhum do meu lado.

Duas operações com peso diferente na mesma ideia: trocar golpe equipado é
**grátis**; trocar usando uma MO custa **25 níveis** e precisa mostrar o preço
ANTES da confirmação (`SaveManager.previsao_de_troca` devolve nível, vida e
slots antes/depois). Se o jogador perder 25 níveis sem ter visto o preço, é
bug de produto.

RFC-001 (slots dinâmicos de skill) **continua em REVIEW** — não esqueci.

### Contrato novo (funções, nenhum sinal novo)

`SaveManager.usar_mo(i, hm_id)` · `previsao_de_troca(i)` · `trocar_kit(i, ids)`.
`trocar_kit` emite `follower_changed` com `max_skill_slots` já atualizado.

### Gameplay desta rodada (sem efeito visual direto)

- Lendário selvagem sempre Lv.100, menor taxa de captura do jogo (3 contra 25
  do segundo lugar) e **zerado pro nível 1 ao ser capturado** — vida, kit e
  experiência recalculados; IV, nature e shiny preservados.
- **Learnsets reequilibrados**: 53 espécies receberam golpes, mais 11 que não
  tinham um único golpe de dano do próprio tipo. Sobram 6 pobres, **todas de
  propósito** (larvas, Magikarp, Ditto).
- Mew estava com taxa de captura 45, igual a um Bulbasaur. Corrigido.

⚠️ **Atenção pra você:** `data/moves/moves.json` tem nomes misturados —
a maioria em inglês ("Fire Blast", "Ice Beam") e alguns em português ("Bomba de
Lodo", "Garra de Dragão", "Mega Chifre"). Isso **aparece na tela**, então é do
seu lado decidir. Eu não mexi pra não invadir apresentação.

### Arquivos que estou usando (não commitados)

Os da atualização anterior, mais `RegrasDeLendario.gd`, `TrocaDeKit.gd`,
`PapelDeGolpe.gd`, `Sinergia.gd`, `CaptureSystem.gd`, `NinhoLendario.gd`,
`data/pokemon/learnsets.json`, `data/pokemon/species.json`.

---

## 🔴 Atualização de Claude — 11/09: o mapa-múndi, e o backlog visual inteiro

O Gabriel reclamou direto: *"o mapa está uma porcaria e as cidades não se
conectam, não existe os biomas e nem o formato do continente que eu pedi"*, e
definiu que **toda a parte gráfica é sua**. Medi antes de repassar.

**Ele está certo, e é pior do que eu tinha registrado:**

| Medida | Valor real | Pedido dele |
|---|---|---|
| Mapa-múndi | **465 × 374 tiles** = 0,5 km × 0,4 km | continente; uma rota sozinha tem 12 km |
| Borda | **100% árvore, 0% água** | *"nenhuma borda pode ser parede de árvore"* |
| Costa oeste | coluna 0 sempre, desvio **0,0 tiles** | costa orgânica |
| Formato | retângulo perfeito | continente com ilhas cercado de mar |

A reestruturação de 10/09 refez **as rotas** e **Cinnabar**. O **mapa-múndi
nunca foi refeito** — minha própria auditoria já dizia isso e eu não resolvi.

**"As cidades não se conectam":** funcionalmente **conectam** (medi a pé, toda
cidade alcança suas portas, a cadeia inteira está íntegra). Mas não existe
**estrada visível** entre elas — as antigas foram seladas quando as rotas
viraram cenas próprias. Andar pra dentro de uma moita e reaparecer noutro lugar
não parece continente. **A queixa dele é de leitura, e é legítima.**

### Dois documentos pra você

- **`docs/rfc/RFC-003-reconstrucao-do-mapa-mundi.md`** (PROPOSED) — a medição
  completa, **três caminhos possíveis** (A: continente novo · B: só borda e
  biomas · C: estrada visível barata) e os meus contratos que não podem
  quebrar. **A decisão de forma é sua.**
- **`docs/backlog-visual-gabriel.md`** — **tudo** que ele já pediu em visual,
  com estado medido. Inclui 5 pendências antigas que estão paradas esperando
  decisão de arte, sendo a mais repetida: **parede lateral de casa usando a
  sprite da frente, "feio", reportado 2× (09/09 e 10/09)**.

### Como eu ajudo, sem invadir

Me diga a forma que você quer e **eu reposiciono os warps e re-provo a
conectividade** — isso é meu lado. Você não precisa tocar em warp nenhum.
Se faltar dado pra desenhar alguma coisa, peça: eu exponho o estado.

Agora são **3 RFCs abertas** (001 slots de skill, 002 tela de kit, 003 mapa).
`./tools/agent-status.sh` mostra o que está com quem.

### Segunda leva do Gabriel, no mesmo dia — medida e repassada

Ele completou o pedido: *"também envie para ele as demandas de melhoria de HUD,
NPC's, tela inicial, itens, estruturas, diversidade de tiles, diversidade de
biomas, geografia em geral"*. Medi tudo antes de repassar. Está em
`docs/backlog-visual-gabriel.md`, itens 10 a 17. Os três achados que valem
destaque:

**1. O gerador alcança ~3% do atlas.** `overworld.png` tem **3.200 células**, o
TileSet declara **185** e o `CHAR_MAP` do gerador conhece **92**. Existe arte no
arquivo que nenhum mapa pinta — nunca. **O gargalo é meu** (char), não seu
(arte). → **RFC-004**.

**2. As cavernas têm 2 texturas cada.** Mt Moon, Rock Tunnel e Victory Road
usam 3 chars, e 2 deles cobrem 90% do mapa. Uma caverna de 36×36 pintada com
dois tiles é uma parede e um chão. É o **maior ganho visual pelo menor risco de
gameplay** da lista toda: a caverna é gerada por escavação, então variar textura
não mexe em geometria nenhuma. Se for escolher por onde começar, comece aqui.

**3. Área submersa: 0 cenas, não existe nada.** É o único item da lista dele sem
absolutamente nada. E **não é problema de arte** — é mecânica (como entra, como
sai, o que acontece se o ar acabar). Precisa de decisão do Gabriel antes, e
provavelmente vira RFC minha. Deixei fora da RFC-004 de propósito.

Os outros: HUD tem 10 nós e não desenha status, nível/XP nem alvo selecionado
(os sinais existem, listei quais); 40 NPCs e 72 diálogos existem, variedade
visual é sua; 213 itens com dado rico, apresentação é sua; tela inicial tem 5
nós visuais.

**Agora são 4 RFCs abertas.** `./tools/agent-status.sh`.

### RFC-005 — pipeline Blender (proposta do Gabriel, medida)

Ele propôs instalar **Blender headless** pra você gerar asset por script
(3D low-poly → render ortográfico → pixel art). `docs/rfc/RFC-005`.

O que medi antes de opinar, e que muda a conversa:

- **Godot headless já está instalado** e é usado toda sessão. Metade do plano
  já existe.
- **O pipeline de asset por script também já existe**, sem Blender: são **16
  scripts Python** em `tools/` (`gerar_biomas.py` fez o terreno de 6 biomas
  inteiros). **638 PNGs, 46 MB** vieram desse caminho. O ciclo "script → asset →
  Godot importa → teste valida" já está fechado.
- O que o Blender acrescenta **não é o ciclo — é a fonte da imagem**.
- VPS: 2 núcleos, 7,8 GB, **sem GPU**, 64 GB livres. Para render ortográfico
  pequeno, **basta**. Ressalva: esses 2 núcleos são compartilhados com n8n,
  Postgres, Evolution e o jogo publicado — render em lote compete com produção.

**O risco que levantei, e é de arte, não de infra:** o jogo tem 638 PNGs num
estilo estabelecido, nascido de desenho procedural. Render 3D pixelizado quase
nunca casa com pixel art desenhada — o resultado típico é o jogo ficar
*inconsistente*, não mais feio. **Você é quem sabe avaliar isso**; eu só
registrei antes de alguém instalar.

**Onde o Blender ganha claramente**, e aqui eu concordo com ele: (a) **as
quatro faces de uma construção** — que é justamente a pendência dele reportada
2× e nunca resolvida; (b) **ciclos de caminhada de NPC** em 4 direções.

Proponho o MVP na **casa**, não na árvore: é a pendência real e é onde o 3D tem
vantagem estrutural. Critério de aceite: colocada ao lado da arte atual, parece
do mesmo jogo?

**A decisão de adotar é sua. A de instalar é do Gabriel** — instalação no
sistema exige confirmação dele, e está pedida.

### Plano de otimização do ciclo (11/09) — `docs/plano-operacao-por-ia.md`

Cronometrei cada etapa antes de propor. Dois resultados que interessam a você:

**1. O gargalo é ARRANQUE, não trabalho.** Blender: 4,85 s abrindo contra 0,47 s
renderizando 4 faces — **91% do custo é ligar a máquina**. Por isso o render em
LOTE (um processo pra N peças) é o maior ganho: 53 s → 9,6 s pra 10 peças.

**2. Paralelizar a suíte NÃO ajuda** — testei: 98,6 s → 82,2 s, só 17%. Não é
processador, é disco. E disputa com a produção. Descartado.

**3. `tools/pixelart/conferir_asset.py`** — o validador de asset. Responde "isso
combina com o jogo?" com número e sai com erro se não combinar. As réguas saíram
de medir os tiles que o jogo já tem: distância de paleta (tile real = 23),
**densidade de detalhe (jogo = 0,51)**, ocupação e consistência entre faces.

🔴 **Ele inverteu meu diagnóstico do MVP, e isso muda o que você precisa fazer.**
Eu tinha dito "mancha marrom, paleta errada". Medindo: **paleta 30,8 contra 23,0
de um tile real — estava CERTA**. O problema é **densidade: 0,01 contra 0,51**.

**A arte deste jogo é DENSA** — quase um tom por pixel, porque nasceu de geração
procedural com ruído. Duas consequências pra você:

- o meu `pixelizar.py` está **errado** (quantiza pra 10 cores e achata tudo) —
  vou corrigir;
- o modelo 3D precisa de **material com textura**, não cor chapada, senão nunca
  vai passar na régua de densidade.

Rode `python3 tools/pixelart/conferir_asset.py --grupo "seus_assets_*.png"`
antes de entregar. É a mesma régua que eu uso pra aceitar — se passar pra você,
passa pra mim, e a ida e volta some.

### Otimização do ciclo — FEITA (11/09). O que muda pra você:

**1. `pixelizar.py` estava errado e está corrigido.** Ele fazia NEAREST +
quantizar em 10 cores, que é a receita clássica de pixel art — e aqui é a
receita errada, porque a fonte é um render suave, não pixel art. Medido:

    NEAREST 0,09 · BOX 0,19 · BILINEAR 0,26 · **LANCZOS 0,44** (alvo do jogo: 0,51)
    quantizar sempre piora: sem 0,19 · 48 cores 0,15 · 10 cores 0,03

**Receita certa: renderize em 256 e desça com LANCZOS, sem quantizar.** A casa
de exemplo passou de 0,02 (reprovada) pra **0,28** (aprovada em tudo).

**2. Render em LOTE** — `--lote arquivo.json`. Medido **6,2× mais rápido**
(3 peças: 16,2 s → 2,63 s), porque 91% do custo era abrir o Blender.
Exemplo em `tools/blender/lotes/exemplo.json`.

**3. `./tools/rodar_testes.sh --so <padrão>`** — os testes de combate em 7,4 s
em vez dos 470 s da suíte inteira. Regra: seletivo enquanto trabalha, **suíte
inteira antes de commitar**.

**4. Conferência de arte dentro da suíte.** Tudo em `assets/gerado/` passa por
`conferir_asset.py` no modo completo. Asset chapado reprova como código
quebrado. A pasta ainda não existe — nasce quando você entregar a primeira
peça. A arte antiga não é medida por essas réguas.

**O que sobra pro seu lado:** o modelo 3D precisa de **material com textura**,
não cor chapada. Mesmo com o pipeline corrigido, a casa de exemplo passa raspando
(0,28 contra 0,51 do jogo) porque o modelo é liso. É aí que se decide se o
Blender fica.

