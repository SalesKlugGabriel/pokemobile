# PokéMobile — regras compartilhadas

## Missão e leitura inicial

Claude Code é o **Gameplay Engineer**; Codex é o **Game Client/UI Engineer**.
Trabalhamos no mesmo repositório, em worktrees diferentes, com contratos explícitos.
O jogo atual é um RPG de ação single-player em Godot 4; referências a MMOs descrevem
usabilidade e arte, não autorizam implementar rede/multiplayer.

Antes de editar: `git status --short`, `git worktree list`, ler
[arquitetura](ARCHITECTURE.md), [handoff](docs/agent-handoff.md) e o documento da área.
Pesquisar a implementação existente. Código real prevalece sobre documentação antiga.
Não inventar classes, autoloads, sinais, nós ou APIs; não duplicar sistemas.

## Responsabilidades

- **Claude:** arquitetura, combate, fórmulas, stats, progressão, IA, bosses, spawn,
  save/load, estado, dados/learnsets, performance lógica e testes de gameplay.
- **Codex:** HUD, menus, cenas visuais, sprites, tilesets, animação visual, efeitos,
  shaders, apresentação dos dados, acessibilidade, responsividade e integração visual.
- Arquivos mistos (`FollowerPokemon.gd`, `WildPokemon.gd`, `BaseMap.gd`, cenas de
  entidades/chefes): alteração mínima, sem refatoração alheia; justificar no handoff.
  Preferir componentes visuais separados. Divisão por responsabilidade, não exclusão
  absoluta: cada agente valida suas alterações e os pontos de integração afetados.

## Contratos obrigatórios

- UI consome estado do gameplay; nunca recalcula HP, stats, capacidade, dano ou recarga.
- Usar os sinais reais do [contrato](docs/frontend-ui.md); exemplos de APIs não são implementação.
- Priorizar sinais, referências em cache e atualização incremental. Sem reconstruir HUD
  a cada frame, procurar nós repetidamente ou alocar efeitos sem limite.
- Capacidade de golpes é de 4–8, definida por `KitDeCombate.capacidade()`; o runtime
  expõe `FollowerPokemon.move_slots`. UI renderiza essa lista, inclusive slots vazios.
  Regra e exemplos estão em [combate](docs/combat.md), não duplicar na apresentação.
- Codex não muda fórmulas, poder, cooldown, multiplicadores, tipos ou XP por conta
  própria. Registrar problemas de gameplay para Claude, com evidência.
- Claude não redesenha HUD, hierarquia, escala de sprites ou timing exclusivamente
  visual por conta própria. Expor o estado necessário e registrar para Codex.
- Sem regras por nome de espécie na UI; dados existentes são a fonte.

## Revisão cruzada (RFC)

Regra do Gabriel, 11/09. Antes de mudar algo que afeta o domínio do outro agente:

1. abrir uma RFC em `docs/rfc/` (`RFC-NNN-assunto.md`);
2. descrever problema, contrato pretendido e perguntas ao outro;
3. **não implementar a suposição cruzada ainda**;
4. o outro agente revisa no mesmo arquivo, na seção `## Decisão`;
5. registrar o acordo em `docs/agent-decisions.md`;
6. só então implementar o contrato compartilhado.

Status de uma RFC: `PROPOSED` → `REVIEW` → `ACCEPTED` → `IMPLEMENTING` → `DONE`
(ou `REJECTED`). `./tools/agent-status.sh` mostra o que está aberto e com quem.

**Exige revisão cruzada:** sinais e eventos · estrutura de cenas · APIs internas ·
formato do save · slots de skill · dados que a HUD desenha · estados de chefe ·
animação que depende de gameplay · entrada (input) · sistema compartilhado novo.

**Não exige:** padding de menu, cor, fórmula interna que não muda contrato,
teste, refactor dentro do próprio domínio.

Nenhum agente aceita sozinho uma mudança de contrato compartilhado. Mudança
interna, sim; mudança que cruza gameplay/apresentação, precisa do outro.

Claude pergunta *"que dados você precisa para desenhar isso?"*.
Codex pergunta *"que estado real de gameplay isso representa?"*.
**Codex não decide fórmula. Claude não decide layout.**

## Arte, mundo e desempenho

Seguir [direção de arte](docs/art-direction.md) e [mundo](docs/world-design.md).
Pixel art legível, luz consistente, biomas distintos, HUD moderno e responsivo.
Leitura do combate vem antes de efeitos decorativos. Meta: 60 FPS em gameplay normal;
medir e informar ambiente/limitações, nunca apresentar meta como resultado medido.
Preservar colisões, warps, escala geográfica e fauna ao mudar gráficos.
Manter fonte reproduzível e backup em `assets/old/` antes de substituir um asset.

## Git, colaboração e entrega

- Uma worktree por agente. Nunca editar, limpar, fazer stash, reset ou rebase na
  worktree da outra sessão. Não sobrescrever trabalho não commitado.
- Sincronizar commits revisados por merge/cherry-pick na própria branch. Fetch/pull
  só com árvore própria em condição adequada; nenhum pull/rebase automático em `main`
  enquanto outra sessão trabalha nela. Nunca force-push.
- Registrar arquivos compartilhados em uso, branch, commit-base e mudanças de contrato
  em [handoff](docs/agent-handoff.md). Handoff descreve fatos: separar pronto, em teste
  e proposto. Documento não significa que a outra sessão já o leu.
- Antes de entregar: revisar diff, validar carregamento de cenas e interação visual
  (desktop e mobile); mudanças mistas exigem também os testes lógicos pertinentes.
  Comandos estão em [arquitetura](ARCHITECTURE.md). Não apagar/enfraquecer testes.
- Export web usa `tools/exportar_web.sh`, preservando a ponte de toque. Build/teste
  local precede publicação; não publicar trabalho parcial da outra sessão.
- Gabriel autorizou autonomia de execução dentro desta divisão. Não pedir novamente
  aprovação de paleta/etapas já autorizadas. Respeitar limites de ferramentas e
  permissões reais; não enviar mensagens externas sem autorização específica.

Referências de configuração: [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
e [worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees).
