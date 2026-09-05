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
cd "$(dirname "$0")/.." || exit 1
falhas=0; total=0; nomes=()
for f in scripts/tests/teste_*.gd; do
  total=$((total+1))
  if ! timeout 300 godot4 --headless --script "res://$f" >/tmp/saida_teste.txt 2>&1; then
    falhas=$((falhas+1)); nomes+=("$f")
    echo "### $(basename "$f")"
    grep -E "FALHOU|FALHA -" /tmp/saida_teste.txt | head -4
  fi
done
echo "=== $total arquivos, $falhas com falha ==="
[ "$falhas" -eq 0 ] || printf '%s\n' "${nomes[@]}"
exit "$falhas"
