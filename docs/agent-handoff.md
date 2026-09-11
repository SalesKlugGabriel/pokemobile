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

