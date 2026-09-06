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
cd "$(dirname "$0")/.." || exit 1
falhas=0; total=0; nomes=()
for f in scripts/tests/teste_*.gd; do
  total=$((total+1))
  saida=/tmp/saida_teste.txt
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
echo "=== $total arquivos, $falhas com falha ==="
[ "$falhas" -eq 0 ] || printf '%s\n' "${nomes[@]}"
exit "$falhas"
