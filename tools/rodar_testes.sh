#!/usr/bin/env bash
# rodar_testes.sh — A suíte inteira, pelo CÓDIGO DE SAÍDA (05/09).
#
# 🔴 Por que existe: eu vinha rodando a suíte com `grep FALHOU`. Só que 32 dos
# 68 arquivos imprimem "FALHA" e 36 imprimem "FALHOU" — quase metade da suíte
# podia estar vermelha sem eu ver. Quatro testes ficaram falhando por dias
# assim.
#
# O `quit(1 if _fail > 0 else 0)` que todo teste já fazia sempre foi o sinal
# certo. Este script usa ELE, e não o texto.
#
# 🔴 SEGUNDA CAMADA (06/09), depois do mesmo erro numa forma nova: ao apagar o
# motor de combate por turno, TRÊS testes que o citavam pararam de compilar — e
# a suíte disse "73 arquivos, 0 com falha". Um teste que morre antes de rodar
# sai com código 0 e não imprime resultado nenhum: ele não reprova, ele só não
# participa. É exatamente o mesmo ponto cego que `teste_tudo_compila.gd` fechou
# pro código do jogo, e que continuava aberto pros próprios testes.
#
# Por isso agora um arquivo precisa das DUAS coisas pra passar: sair com código
# 0 E ter impresso a linha de resultado. Silêncio deixou de ser aprovação.
#
# 🔴 MODO SELETIVO (11/09). Medido: a suíte inteira leva 470 s, e ~262 s disso
# (56%) é só o Godot abrindo 105 vezes — cada arranque custa 2,5 s contra 1,5 s
# de teste de verdade. Rodar tudo a cada mudança é pagar 8 minutos pra conferir
# uma linha.
#
#     ./tools/rodar_testes.sh              # a suíte inteira
#     ./tools/rodar_testes.sh --so combate # só os que casam com "combate"
#
# A REGRA: seletivo enquanto você trabalha; **a suíte inteira antes de commitar
# e antes de publicar**. O seletivo acha o erro rápido; só a suíte inteira prova
# que você não quebrou o resto.
#
# (Paralelizar foi testado e descartado: 12 testes levam 98,6 s em série e
# 82,2 s com 2 em paralelo — só 17%, porque o gargalo é disco, não CPU, e os
# 2 núcleos são compartilhados com a produção.)
cd "$(dirname "$0")/.." || exit 1

padrao=""
if [ "${1:-}" = "--so" ]; then
  padrao="${2:-}"
  if [ -z "$padrao" ]; then echo "uso: $0 --so <padrão>"; exit 2; fi
fi

# 🔴 LOG POR WORKTREE (19/09). Era `/tmp/saida_teste.txt`, um caminho global —
# e o `ARCHITECTURE.md` já avisava pra não rodar duas instâncias no mesmo
# servidor. O aviso não bastou: com Claude e Codex em worktrees diferentes na
# mesma VPS, os dois escrevem e LEEM o mesmo arquivo, e o resultado de um teste
# some no meio do outro.
#
# O sintoma é traiçoeiro porque não parece contenção: dá "não chegou a rodar
# (nenhuma linha de resultado)" — a mesma mensagem de um teste que morreu ao
# compilar. Custou 5 reprovações falsas numa suíte só; as 5 passaram sozinhas
# depois, 4 vezes seguidas.
#
# O caminho agora carrega o nome da worktree, então duas suítes simultâneas
# deixam de se ver. Continua valendo NÃO rodar as duas ao mesmo tempo (são 2
# núcleos, e a lentidão ainda pode estourar o `timeout 300`) — mas agora, se
# alguém rodar, o resultado é lento, não falso.
saida="/tmp/saida_teste_$(basename "$(pwd)").txt"

falhas=0; total=0; nomes=()
for f in scripts/tests/teste_*.gd; do
  if [ -n "$padrao" ] && ! echo "$f" | grep -qi -- "$padrao"; then continue; fi
  total=$((total+1))
  ruim=0
  if ! timeout 300 godot4 --headless --script "res://$f" >"$saida" 2>&1; then
    ruim=1
  elif ! grep -q "=== Resultado:" "$saida"; then
    # Rodou "sem erro" mas não chegou a concluir nada — quase sempre erro de
    # compilação/identificador (o teste cita algo que não existe mais).
    ruim=1
    echo "### $(basename "$f") — não chegou a rodar (nenhuma linha de resultado)"
    grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$saida" | head -3
  fi
  if [ "$ruim" -eq 1 ]; then
    falhas=$((falhas+1)); nomes+=("$f")
    grep -E "FALHOU|FALHA -" "$saida" | head -4
  fi
done
# ── Conferência de ARTE (11/09) ───────────────────────────────────────────────
# Asset ruim reprova como código ruim. Só roda no modo completo, e só sobre o
# que o pipeline de render produz (`assets/gerado/`) — a arte antiga, desenhada
# por outro caminho, não é medida por estas réguas.
#
# Pasta vazia ou inexistente: pula em silêncio. É infraestrutura pronta pra
# quando o Codex começar a entregar, não uma reprovação por ainda não haver nada.
if [ -z "$padrao" ] && [ -d assets/gerado ]; then
  pngs=$(find assets/gerado -name "*.png" 2>/dev/null | head -400)
  if [ -n "$pngs" ]; then
    total=$((total+1))
    if ! python3 tools/pixelart/conferir_asset.py $pngs > "/tmp/saida_arte_$(basename "$(pwd)").txt" 2>&1; then
      falhas=$((falhas+1)); nomes+=("assets/gerado (conferência de arte)")
      grep "✗" "/tmp/saida_arte_$(basename "$(pwd)").txt" | head -6
    fi
  fi
fi

if [ -n "$padrao" ] && [ "$total" -eq 0 ]; then
  echo "=== nenhum teste casa com '$padrao' ==="
  exit 2
fi
if [ -n "$padrao" ]; then
  echo "=== $total arquivos (filtro '$padrao'), $falhas com falha ==="
  echo "    ⚠ modo seletivo — rode a suíte INTEIRA antes de commitar"
else
  echo "=== $total arquivos, $falhas com falha ==="
fi
[ "$falhas" -eq 0 ] || printf '%s\n' "${nomes[@]}"
exit "$falhas"
