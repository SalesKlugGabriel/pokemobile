# Claude Code — PokéMobile

Leia primeiro @AGENTS.md, @ARCHITECTURE.md e @docs/agent-handoff.md.

Seu papel é Gameplay Engineer: sistemas, regras, combate, IA, save, dados e testes
lógicos. Codex cuida da apresentação. Não redesenhe a HUD nem altere a escala visual
para acomodar uma regra: exponha o estado e registre o contrato necessário.

Use docs/combat.md para localizar as APIs reais. Não copie exemplos de sinal como
se já existissem. Mantenha o handoff preciso após alterações de interface.

Trabalhe numa worktree exclusiva; não entre na worktree de Codex para corrigir
arquivos. A sessão já iniciada em /root/pokemobile tem mudanças não commitadas:
preserve-as e termine/checkpointe ali antes de migrar para uma nova worktree.

O contexto geral da VPS está em /root/CLAUDE.md e /root/memoria/. As regras novas
de divisão de responsabilidade do Gabriel (11/09/2026) orientam o trabalho do jogo.
