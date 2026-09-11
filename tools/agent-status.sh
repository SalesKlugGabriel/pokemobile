#!/usr/bin/env bash
# agent-status.sh — o estado da ponte entre Claude (gameplay) e Codex (client/UI).
#
# Responde, sem abrir arquivo nenhum: que RFCs estão abertas, quem deve o quê, e
# o que cada lado commitou por último. Pensado pra ser a primeira coisa que
# qualquer uma das duas sessões roda ao começar.
set -u
cd "$(dirname "$0")/.." || exit 1

azul()  { printf '\033[1;34m%s\033[0m\n' "$1"; }
cinza() { printf '\033[0;90m%s\033[0m\n' "$1"; }

azul "RFCs abertas"
achou=0
for f in docs/rfc/RFC-*.md; do
  [ -e "$f" ] || continue
  status=$(grep -m1 '^\*\*Status:\*\*' "$f" | sed 's/.*Status:\*\* *//')
  owner=$(grep -m1 '^\*\*Owner:\*\*' "$f" | sed 's/.*Owner:\*\* *//')
  rev=$(grep -m1 '^\*\*Reviewer:\*\*' "$f" | sed 's/.*Reviewer:\*\* *//')
  titulo=$(head -1 "$f" | sed 's/^# *//')
  case "$status" in
    DONE|REJECTED) ;;
    *) echo "  $titulo"
       echo "     status: $status · dono: $owner · revisor: $rev"
       echo "     $f"
       achou=1 ;;
  esac
done
[ "$achou" = 0 ] && cinza "  (nenhuma)"

echo
azul "Pendente de revisão"
pend=0
for f in docs/rfc/RFC-*.md; do
  [ -e "$f" ] || continue
  if grep -qm1 '^\*\*Status:\*\* *REVIEW' "$f"; then
    rev=$(grep -m1 '^\*\*Reviewer:\*\*' "$f" | sed 's/.*Reviewer:\*\* *//')
    echo "  $rev deve revisar: $(basename "$f")"
    pend=1
  fi
done
[ "$pend" = 0 ] && cinza "  (nada pendente)"

echo
azul "Decisões fechadas"
if grep -q '^## [0-9]' docs/agent-decisions.md 2>/dev/null; then
  grep '^## ' docs/agent-decisions.md | sed 's/^## /  /'
else
  cinza "  (nenhuma ainda)"
fi

echo
azul "Últimos commits"
git log --oneline -5 2>/dev/null | sed 's/^/  /'

echo
azul "Arquivos em uso nesta árvore (não commitados)"
sujo=$(git status --short 2>/dev/null | grep -v '^??' | head -20)
if [ -n "$sujo" ]; then
  echo "$sujo" | sed 's/^/  /'
  cinza "  A outra sessão NÃO deve editar estes arquivos enquanto estiverem aqui."
else
  cinza "  (árvore limpa)"
fi

echo
azul "Worktrees"
git worktree list 2>/dev/null | sed 's/^/  /'
