#!/usr/bin/env bash
# publicar.sh — Exportar, empacotar, publicar e CONFERIR. Nesta ordem.
#
# 🔴 Por que este script existe (21/09/2026):
#
# O Gabriel abriu o jogo e achou uma página fora do ar. Investigando, o 404 era
# de um endereço que nunca existiu — mas o achado de verdade foi outro: **o jogo
# no ar estava 3 dias e 28 commits atrás do código.**
#
# A causa é uma armadilha de processo, não um bug. O `Dockerfile` faz
#
#     COPY builds/web/ /usr/share/nginx/html/
#
# ou seja, ele **copia** o build; não o gera. Eu vinha rodando `docker build`
# várias vezes por dia pra publicar o painel, e cada uma dessas vezes
# republicava fielmente um `builds/web/` de 18/09. Duas fases inteiras (20 e
# 21), três RFCs e a ponte visual do treinador estavam commitadas e invisíveis.
#
# O perigo é o disfarce: `docker service update ... converged` imprime sucesso,
# o site responde 200, e o carimbo de versão muda de tag mas não de conteúdo.
# **Parecia deploy.**
#
# Então: publicar passou a ser UM comando, que exporta antes e confere depois.
#
#     ./tools/publicar.sh
#
# Ele recusa publicar se o export não tiver rodado, em vez de publicar velho.
set -e
cd "$(dirname "$0")/.."

echo "── 1/4 · exportando o jogo ─────────────────────────────────────────────"
./tools/exportar_web.sh >/tmp/export_pokemobile.log 2>&1 \
  || { echo "❌ o export falhou — veja /tmp/export_pokemobile.log"; exit 1; }

CARIMBO="$(cat builds/web/versao.txt)"
echo "   carimbo: $CARIMBO"

# A trava que o incidente de 21/09 pede. O export acabou de rodar, então o
# `index.pck` tem de ser de agora — se for velho, alguma coisa falhou em
# silêncio e publicar seria repetir exatamente o erro que este script existe
# pra impedir.
IDADE=$(( $(date +%s) - $(stat -c %Y builds/web/index.pck) ))
if [ "$IDADE" -gt 600 ]; then
  echo "❌ builds/web/index.pck tem ${IDADE}s — o export não gerou nada novo."
  echo "   Publicar agora republicaria um build velho com cara de novo."
  exit 1
fi

echo "── 2/4 · empacotando ───────────────────────────────────────────────────"
# O painel é copiado de docs/painel/ pelo Dockerfile; regerar antes garante que
# ele reflita o QUADRO de agora.
python3 tools/gerar_painel.py >/dev/null
TAG="pokemobile-v3d:$(date +%Y%m%d-%H%M)"
docker build -q -t "$TAG" . >/dev/null
echo "   imagem: $TAG"

echo "── 3/4 · publicando ────────────────────────────────────────────────────"
# ⚠️ `--force` é obrigatório: a lição da migração de domínio de 20/08 — sem ele
# o Swarm pode não recriar o container.
docker service update --image "$TAG" --force pokemobile_pokemobile_app >/dev/null
echo "   serviço atualizado"

echo "── 4/4 · conferindo NO AR ──────────────────────────────────────────────"
# Espera o Traefik parar de apontar pro container antigo. Sem isto a conferência
# lê o serviço anterior e aprova o deploy errado — aconteceu em 19/09.
NO_AR=""
for _ in $(seq 1 20); do
  sleep 3
  NO_AR="$(curl -s --max-time 10 https://poke.workprog.pro/versao.txt || true)"
  [ "$NO_AR" = "$CARIMBO" ] && break
done

if [ "$NO_AR" != "$CARIMBO" ]; then
  echo "❌ o carimbo no ar ($NO_AR) não é o que acabei de publicar ($CARIMBO)."
  exit 1
fi

JOGO=$(curl -s -o /dev/null -w "%{http_code}" https://poke.workprog.pro/)
PAINEL=$(curl -s -o /dev/null -w "%{http_code}" https://poke.workprog.pro/painel/)
echo "   carimbo no ar: $NO_AR ✅"
echo "   jogo: $JOGO · painel: $PAINEL"
[ "$JOGO" = "200" ] && [ "$PAINEL" = "200" ] || { echo "❌ algo não respondeu 200"; exit 1; }

echo
echo "✅ no ar: https://poke.workprog.pro/  ·  painel: /painel"
echo "⚠️  200 não prova que o jogo RODA — abra no navegador antes de dar por"
echo "    testado. A V3 é o botão 'Gameplay V3 (3D) — teste' na tela inicial."
