FROM nginx:alpine

COPY builds/web/ /usr/share/nginx/html/

# O painel do Gabriel, servido em `/painel`. Copiado de `docs/painel/` e **não**
# de `builds/web/`, de propósito: `builds/web/` é saída de build, reescrita a
# cada `tools/exportar_web.sh` — o painel sumiria no próximo export, e sumiria
# em silêncio, que é o pior jeito de uma página desaparecer.
COPY docs/painel/ /usr/share/nginx/html/painel/

COPY nginx.conf /etc/nginx/conf.d/default.conf
