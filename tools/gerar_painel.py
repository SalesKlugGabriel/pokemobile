#!/usr/bin/env python3
"""gerar_painel.py — O painel de acompanhamento do Gabriel, GERADO dos documentos.

🔴 Por que é gerado, e não escrito à mão:

Este projeto já tinha SETE documentos de coordenação quando o `QUADRO.md` foi
criado, e nenhum deles respondia "o que falta agora" — porque cada um envelheceu
sozinho, num dia em que ninguém lembrou de atualizar. Um painel escrito à mão
seria o oitavo.

Então ele não tem conteúdo próprio. Ele LÊ `docs/rfc/*.md` e `docs/QUADRO.md`,
que são os documentos que os dois agentes já atualizam por obrigação, e mostra.
Se o painel mentir, é porque a fonte mentiu — e aí o conserto é na fonte, que é
onde ele tem de ser.

    python3 tools/gerar_painel.py          # escreve docs/painel/index.html

O painel é só leitura. "Aprovar" aqui é o Gabriel LER e responder no chat; não
há botão que mude estado, de propósito — estado que muda em dois lugares é como
os dois passam a discordar.
"""

import html
import os
import re
from datetime import date

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_RFC = os.path.join(RAIZ, "docs", "rfc")
QUADRO = os.path.join(RAIZ, "docs", "QUADRO.md")
SAIDA = os.path.join(RAIZ, "docs", "painel", "index.html")

# ──────────────────────────────────────────────────────────────────────────────
# Leitura das fontes
# ──────────────────────────────────────────────────────────────────────────────

# Cada estado vira uma classe de cor. O mapeamento é por PREFIXO porque os
# status reais carregam ressalva ("ACCEPTED (laboratório) · borda de chunk
# segue PENDENTE") — e essa ressalva é justamente o que o Gabriel precisa ler,
# então ela é preservada inteira no texto e só a cor é derivada.
ESTADOS = [
    ("ACCEPTED", "aceita", "aceita"),
    ("IMPLEMENTED", "aceita", "implementada"),
    ("DONE", "aceita", "fechada"),
    ("APROVADO", "aceita", "aprovada"),
    ("REVIEW", "espera", "em revisão"),
    ("PROPOSED", "espera", "esperando decisão"),
    ("DRAFT", "espera", "rascunho"),
    ("REJECTED", "recusada", "recusada"),
    # Aposentada pela V3 (21/09): não é recusa nem decisão pendente — é um
    # contrato da era 2D que deixou de fazer sentido. Contá-la como "esperando"
    # inflaria o número que o Gabriel usa pra saber o que falta dele.
    ("OBSOLETA", "obsoleta", "aposentada pela V3"),
]


def classificar(status):
    alto = status.upper()
    for chave, classe, rotulo in ESTADOS:
        if alto.startswith(chave):
            return classe, rotulo
    return "espera", "sem estado declarado"


def ler_rfcs():
    """Cada RFC vira um dicionário. O corpo inteiro vem junto: o Gabriel pediu
    pra LER os contratos, não pra ver um resumo que alguém escolheu por ele."""
    rfcs = []
    if not os.path.isdir(DIR_RFC):
        return rfcs
    for nome in sorted(os.listdir(DIR_RFC)):
        if not nome.endswith(".md"):
            continue
        caminho = os.path.join(DIR_RFC, nome)
        with open(caminho, encoding="utf-8") as f:
            texto = f.read()

        titulo = nome[:-3]
        m = re.search(r"^#\s+(.+)$", texto, re.M)
        if m:
            titulo = m.group(1).strip()

        def campo(rotulo):
            m = re.search(r"^\*\*%s:?\*\*\s*(.+)$" % rotulo, texto, re.M)
            return m.group(1).strip() if m else ""

        numero = ""
        mn = re.match(r"RFC-(\d+)", nome)
        if mn:
            numero = mn.group(1)

        status = campo("Status")
        classe, rotulo_estado = classificar(status)
        rfcs.append({
            "arquivo": nome,
            "numero": numero,
            "titulo": titulo,
            "status": status,
            "classe": classe,
            "rotulo": rotulo_estado,
            "dono": campo("Owner"),
            "revisor": campo("Reviewer"),
            "corpo": texto,
        })
    # Mais recente primeiro: é a ordem em que o Gabriel precisa das coisas.
    rfcs.sort(key=lambda r: r["numero"], reverse=True)
    return rfcs


## O que exatamente está sendo decidido, e como seria executado.
##
## Sai de uma seção `## O pedido` da própria RFC — nunca de um resumo meu. O
## Gabriel pediu isso com todas as letras: *"bem claro do que está sendo
## solicitado e como deveria ser executado"*, logo acima dos botões.
##
## Sem a seção, o painel diz que ela falta em vez de inventar: um resumo
## fabricado aqui seria uma segunda versão do contrato, e é exatamente assim
## que as duas passam a discordar.
def pedido(texto):
    linhas = texto.split("\n")
    dentro = False
    fora = []
    for l in linhas:
        if l.startswith("## "):
            if dentro:
                break
            dentro = l.strip().lower().startswith("## o pedido")
            continue
        if dentro:
            fora.append(l)
    return "\n".join(fora).strip()


def secao_do_quadro(titulo_contem):
    """Devolve o texto de uma seção `## ...` do QUADRO, pelo trecho do título."""
    if not os.path.exists(QUADRO):
        return ""
    with open(QUADRO, encoding="utf-8") as f:
        texto = f.read()
    partes = re.split(r"^## ", texto, flags=re.M)
    for p in partes:
        primeira = p.split("\n", 1)[0]
        if titulo_contem.lower() in primeira.lower():
            return p
    return ""


def tabela_do_quadro(titulo_contem):
    """As linhas de dado de uma tabela markdown dentro de uma seção do QUADRO."""
    bloco = secao_do_quadro(titulo_contem)
    linhas = []
    for linha in bloco.split("\n"):
        linha = linha.strip()
        if not linha.startswith("|"):
            continue
        celulas = [c.strip() for c in linha.strip("|").split("|")]
        # Cabeçalho e a linha de tracinhos do markdown não são dado.
        if all(set(c) <= set("-: ") for c in celulas):
            continue
        if celulas and celulas[0].lower() in ("#", "rfc"):
            continue
        linhas.append(celulas)
    return linhas


def suite_do_quadro():
    if not os.path.exists(QUADRO):
        return "—"
    with open(QUADRO, encoding="utf-8") as f:
        m = re.search(r"\*\*(\d+ arquivos[^*]*)\*\*", f.read())
    return m.group(1) if m else "—"


# ──────────────────────────────────────────────────────────────────────────────
# Markdown → HTML (o mínimo que estes documentos usam, e nada além)
# ──────────────────────────────────────────────────────────────────────────────

def inline(t):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", t)
    return t


def markdown(texto):
    """Conversor deliberadamente pequeno. Cobre o que as RFCs usam: títulos,
    listas, tabelas, blocos de código, citação e parágrafo. Qualquer coisa
    além disso sai como parágrafo — nunca como erro, porque um painel que
    quebra num documento novo é pior que um painel com formatação pobre."""
    saida = []
    linhas = texto.split("\n")
    i = 0
    em_lista = None
    def fechar_lista():
        nonlocal em_lista
        if em_lista:
            saida.append("</%s>" % em_lista)
            em_lista = None

    while i < len(linhas):
        linha = linhas[i]
        bruta = linha.rstrip()

        if bruta.startswith("```"):
            fechar_lista()
            i += 1
            corpo = []
            while i < len(linhas) and not linhas[i].startswith("```"):
                corpo.append(linhas[i])
                i += 1
            i += 1
            saida.append("<pre><code>%s</code></pre>"
                         % html.escape("\n".join(corpo)))
            continue

        if not bruta.strip():
            fechar_lista()
            i += 1
            continue

        if re.match(r"^-{3,}$", bruta.strip()):
            fechar_lista()
            saida.append("<hr>")
            i += 1
            continue

        m = re.match(r"^(#{1,6})\s+(.*)$", bruta)
        if m:
            fechar_lista()
            n = min(len(m.group(1)) + 1, 6)
            saida.append("<h%d>%s</h%d>" % (n, inline(m.group(2)), n))
            i += 1
            continue

        if bruta.lstrip().startswith("|"):
            fechar_lista()
            tabela = []
            while i < len(linhas) and linhas[i].lstrip().startswith("|"):
                cs = [c.strip() for c in linhas[i].strip().strip("|").split("|")]
                if not all(set(c) <= set("-: ") for c in cs):
                    tabela.append(cs)
                i += 1
            if tabela:
                cab = tabela[0]
                saida.append('<div class="rolar"><table><thead><tr>'
                             + "".join("<th>%s</th>" % inline(c) for c in cab)
                             + "</tr></thead><tbody>")
                for l in tabela[1:]:
                    saida.append("<tr>" + "".join("<td>%s</td>" % inline(c)
                                                  for c in l) + "</tr>")
                saida.append("</tbody></table></div>")
            continue

        m = re.match(r"^\s*>\s?(.*)$", bruta)
        if m:
            fechar_lista()
            saida.append("<blockquote>%s</blockquote>" % inline(m.group(1)))
            i += 1
            continue

        m = re.match(r"^\s*([-*+])\s+(.*)$", bruta)
        if m:
            if em_lista != "ul":
                fechar_lista()
                saida.append("<ul>")
                em_lista = "ul"
            saida.append("<li>%s</li>" % inline(m.group(2)))
            i += 1
            continue

        m = re.match(r"^\s*(\d+)[.)]\s+(.*)$", bruta)
        if m:
            if em_lista != "ol":
                fechar_lista()
                saida.append("<ol>")
                em_lista = "ol"
            saida.append("<li>%s</li>" % inline(m.group(2)))
            i += 1
            continue

        fechar_lista()
        # Junta linhas seguidas num parágrafo só: estes documentos quebram a
        # linha em 80 colunas, e respeitar isso no HTML viraria texto picotado.
        paragrafo = [bruta]
        i += 1
        while i < len(linhas) and linhas[i].strip() \
                and not re.match(r"^\s*([-*+>|#]|\d+[.)]|```)", linhas[i]):
            paragrafo.append(linhas[i].rstrip())
            i += 1
        saida.append("<p>%s</p>" % inline(" ".join(paragrafo)))

    fechar_lista()
    return "\n".join(saida)


# ──────────────────────────────────────────────────────────────────────────────
# A página
# ──────────────────────────────────────────────────────────────────────────────

CSS = """
:root{
  --fundo:#f4f5f3; --papel:#ffffff; --tinta:#16191c; --tinta-fraca:#5d666e;
  --linha:#dfe3e0; --linha-forte:#c3cac5;
  --acento:#0f6b52;          /* verde-instrumento: a cor de "medido" */
  --acento-fraco:#e3f0eb;
  --ok:#1d7a4f; --ok-fundo:#e6f4ec;
  --espera:#9a6510; --espera-fundo:#fdf1dd;
  --parado:#a33125; --parado-fundo:#fbe9e6;
  --voce:#5b3ea8; --voce-fundo:#efeafb;
  --mono:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace;
  --texto:"IBM Plex Sans",system-ui,-apple-system,Segoe UI,sans-serif;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --fundo:#111417; --papel:#181c20; --tinta:#e7ebe8; --tinta-fraca:#9aa4ab;
    --linha:#2a3036; --linha-forte:#3a424a;
    --acento:#4fd1a5; --acento-fraco:#16302a;
    --ok:#5bd39b; --ok-fundo:#14301f;
    --espera:#e0ad5c; --espera-fundo:#332612;
    --parado:#f08b7d; --parado-fundo:#341a17;
    --voce:#b4a0f0; --voce-fundo:#241d38;
  }
}
:root[data-theme="dark"]{
  --fundo:#111417; --papel:#181c20; --tinta:#e7ebe8; --tinta-fraca:#9aa4ab;
  --linha:#2a3036; --linha-forte:#3a424a;
  --acento:#4fd1a5; --acento-fraco:#16302a;
  --ok:#5bd39b; --ok-fundo:#14301f;
  --espera:#e0ad5c; --espera-fundo:#332612;
  --parado:#f08b7d; --parado-fundo:#341a17;
  --voce:#b4a0f0; --voce-fundo:#241d38;
}

*{box-sizing:border-box}
body{margin:0;background:var(--fundo);color:var(--tinta);
  font-family:var(--texto);font-size:16px;line-height:1.55;
  -webkit-text-size-adjust:100%}
.envelope{max-width:960px;margin:0 auto;padding:0 20px 80px}

/* Cabeçalho */
header.topo{padding:40px 0 26px;border-bottom:2px solid var(--tinta)}
.etiqueta{font-family:var(--mono);font-size:11px;letter-spacing:.16em;
  text-transform:uppercase;color:var(--acento);margin:0 0 10px}
h1{font-size:clamp(28px,6vw,42px);line-height:1.08;margin:0 0 14px;
  font-weight:700;letter-spacing:-.02em;text-wrap:balance}
.resumo{color:var(--tinta-fraca);margin:0;max-width:60ch}
.medidores{display:flex;flex-wrap:wrap;gap:10px;margin-top:20px}
.medidor{background:var(--papel);border:1px solid var(--linha);
  border-radius:3px;padding:8px 13px;font-family:var(--mono);font-size:12px}
.medidor b{display:block;font-size:17px;font-weight:600;letter-spacing:-.01em}
.medidor span{color:var(--tinta-fraca);font-size:10px;letter-spacing:.1em;
  text-transform:uppercase}

/* Seções */
section{margin-top:46px}
h2{font-size:12px;font-family:var(--mono);letter-spacing:.16em;
  text-transform:uppercase;color:var(--tinta-fraca);margin:0 0 4px;
  padding-bottom:8px;border-bottom:1px solid var(--linha)}
.nota{color:var(--tinta-fraca);font-size:14px;margin:12px 0 18px;max-width:64ch}

/* O bloco que é o ponto da página */
.voce-bloco{background:var(--voce-fundo);border:1px solid var(--voce);
  border-radius:4px;padding:4px 18px 18px;margin-top:14px}
.voce-bloco h2{border-color:color-mix(in srgb,var(--voce) 40%,transparent);
  color:var(--voce)}

/* Itens de fila */
.item{display:flex;gap:14px;padding:14px 0;border-bottom:1px solid var(--linha)}
.item:last-child{border-bottom:0}
.marca{font-family:var(--mono);font-size:11px;color:var(--tinta-fraca);
  min-width:34px;padding-top:3px}
.corpo-item{flex:1;min-width:0}
.corpo-item p{margin:0}
.porque{color:var(--tinta-fraca);font-size:13.5px;margin-top:5px!important}

/* RFC */
.rfc{background:var(--papel);border:1px solid var(--linha);border-radius:4px;
  margin-top:12px;overflow:hidden}
.rfc>summary{cursor:pointer;padding:15px 17px;list-style:none;
  display:grid;grid-template-columns:auto 1fr;gap:4px 13px;align-items:start}
.rfc>summary::-webkit-details-marker{display:none}
.rfc>summary:hover{background:var(--acento-fraco)}
.rfc>summary:focus-visible{outline:2px solid var(--acento);outline-offset:-2px}
.num{font-family:var(--mono);font-size:19px;font-weight:600;
  color:var(--tinta-fraca);grid-row:span 2;padding-top:1px}
.nome{font-weight:600;line-height:1.3}
.meta{font-size:12.5px;color:var(--tinta-fraca);font-family:var(--mono)}
.selo{display:inline-block;font-family:var(--mono);font-size:10.5px;
  letter-spacing:.09em;text-transform:uppercase;padding:2px 8px;
  border-radius:99px;font-weight:500;vertical-align:1px}
.aceita{background:var(--ok-fundo);color:var(--ok)}
.espera{background:var(--espera-fundo);color:var(--espera)}
.recusada{background:var(--parado-fundo);color:var(--parado)}
.obsoleta{background:var(--linha);color:var(--tinta-fraca)}
.leitura{padding:2px 17px 22px;border-top:1px solid var(--linha);
  font-size:15px}
.leitura h2,.leitura h3,.leitura h4{font-family:var(--texto);
  text-transform:none;letter-spacing:0;color:var(--tinta);border:0;
  padding:0;font-size:16.5px;margin:22px 0 6px}
.leitura h2{font-size:19px}
.leitura hr{border:0;border-top:1px solid var(--linha);margin:22px 0}
.leitura blockquote{margin:14px 0;padding:2px 0 2px 15px;
  border-left:3px solid var(--acento);color:var(--tinta-fraca)}
.abrir{font-family:var(--mono);font-size:11px;color:var(--acento);
  grid-column:2;letter-spacing:.06em}
details[open] .abrir{visibility:hidden}

/* Tabelas e código */
.rolar{overflow-x:auto;margin:14px 0}
table{border-collapse:collapse;width:100%;font-size:14px;min-width:420px}
th,td{text-align:left;padding:8px 11px;border-bottom:1px solid var(--linha);
  vertical-align:top}
th{font-family:var(--mono);font-size:11px;letter-spacing:.08em;
  text-transform:uppercase;color:var(--tinta-fraca);
  border-bottom:1px solid var(--linha-forte)}
code{font-family:var(--mono);font-size:.87em;background:var(--acento-fraco);
  padding:1px 5px;border-radius:3px;word-break:break-word}
pre{background:var(--papel);border:1px solid var(--linha);border-radius:4px;
  padding:13px 15px;overflow-x:auto;font-size:13px;line-height:1.5}
pre code{background:none;padding:0;font-size:inherit}

/* Fases */
.fases{display:grid;gap:7px;margin-top:14px}
.fase{display:grid;grid-template-columns:52px 1fr;gap:13px;
  background:var(--papel);border:1px solid var(--linha);border-left-width:3px;
  border-radius:3px;padding:11px 14px;align-items:baseline}
.fase.feita{border-left-color:var(--ok)}
.fase.meio{border-left-color:var(--espera)}
.fase.nao{border-left-color:var(--linha-forte)}
.fase .n{font-family:var(--mono);font-size:13px;color:var(--tinta-fraca)}
.fase .d{font-size:14px;min-width:0}
.fase .e{display:block;color:var(--tinta-fraca);font-size:12.5px;margin-top:3px}

footer{margin-top:60px;padding-top:20px;border-top:1px solid var(--linha);
  font-size:12.5px;color:var(--tinta-fraca);font-family:var(--mono)}
footer p{margin:5px 0}
@media(max-width:560px){
  .envelope{padding:0 15px 60px}
  .item{gap:10px}.marca{min-width:26px}
  .rfc>summary{padding:13px 14px;gap:3px 10px}
}
"""

# A primeira folha preserva a paleta e todos os seletores do painel original.
# Estes ajustes são deliberadamente colocados depois: deixam a geração pequena,
# não mudam nenhuma fonte de conteúdo e priorizam a leitura com uma mão.
CSS += """
/* ── O bloco de decisão (21/09) ─────────────────────────────────────────── */
.decidir{margin-top:26px;border:2px solid var(--voce);border-radius:8px;
  padding:16px 16px 14px;background:var(--voce-fundo)}
.decidir h4{margin:0 0 10px;font-family:var(--mono);font-size:11px;
  letter-spacing:.14em;text-transform:uppercase;color:var(--voce)}
.decidir .pedido>*:first-child{margin-top:0}
.decidir .pedido>*:last-child{margin-bottom:0}
.semPedido{margin:0;font-size:14px;color:var(--tinta-fraca)}
.botoes{display:flex;flex-wrap:wrap;gap:9px;margin-top:15px}
.bt{flex:1 1 30%;min-width:112px;min-height:46px;border-radius:7px;
  border:1px solid var(--linha-forte);background:var(--papel);
  color:var(--tinta);font:600 15px var(--texto);cursor:pointer;
  padding:10px 12px}
.bt:hover{border-color:var(--voce)}
.bt:disabled{opacity:.5;cursor:not-allowed}
.bt.aprovar{border-color:var(--ok);color:var(--ok)}
.bt.reprovar{border-color:var(--parado);color:var(--parado)}
.bt.escolhido{background:var(--voce);border-color:var(--voce);color:#fff}
.caixaComentario{margin-top:12px;display:flex;flex-direction:column;gap:9px}
.caixaComentario textarea{width:100%;border:1px solid var(--linha-forte);
  border-radius:7px;padding:11px;font:400 15px/1.5 var(--texto);
  background:var(--papel);color:var(--tinta);resize:vertical}
.estadoDecisao{margin:11px 0 0;font-size:13.5px;color:var(--tinta-fraca);
  min-height:1.2em}
.jaDecidido{margin-top:12px;padding:11px 13px;border-radius:7px;
  background:var(--papel);border:1px solid var(--linha);font-size:14px}
""" + """
:root{
  --fundo:#f7f8fa; --papel:#ffffff; --tinta:#17212b; --tinta-fraca:#607080;
  --linha:#dce3ea; --linha-forte:#bac6d1; --acento:#166b5c;
  --acento-fraco:#e4f4ef; --ok:#16724a; --ok-fundo:#e5f6ec;
  --espera:#9a5b06; --espera-fundo:#fff1d6; --parado:#b03732;
  --parado-fundo:#ffebe8; --voce:#503eaa; --voce-fundo:#f0edff;
  --sombra:0 9px 28px rgba(26,42,58,.08); --raio:14px;
}
:root[data-theme="dark"]{
  --fundo:#101720; --papel:#18222e; --tinta:#edf3f7; --tinta-fraca:#a6b4c2;
  --linha:#2b3947; --linha-forte:#405263; --acento:#69d7bc;
  --acento-fraco:#173930; --ok:#70dda7; --ok-fundo:#143b2b;
  --espera:#ffc56e; --espera-fundo:#463313; --parado:#ff9d93;
  --parado-fundo:#4b2524; --voce:#c5b8ff; --voce-fundo:#2d2750;
  --sombra:0 12px 30px rgba(0,0,0,.22);
}
body{font-size:16px;line-height:1.62;background:var(--fundo)}
.envelope{max-width:820px;padding:0 18px 72px}
header.topo{padding:24px 0 18px;border:0}
.topo-linha{display:flex;justify-content:space-between;gap:12px;align-items:start}
.tema{appearance:none;border:1px solid var(--linha-forte);border-radius:999px;
  background:var(--papel);color:var(--tinta);padding:8px 11px;font:600 11px var(--mono);
  letter-spacing:.05em;white-space:nowrap;cursor:pointer}
.tema:focus-visible{outline:3px solid var(--acento);outline-offset:2px}
h1{font-size:clamp(31px,9vw,49px);max-width:12ch;margin:0 0 12px;letter-spacing:-.045em}
.resumo{font-size:15px;line-height:1.52}
.medidores{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:18px}
.medidor{border-radius:10px;padding:10px 11px;box-shadow:0 1px 0 rgba(0,0,0,.02)}
.medidor b{font-size:14px;line-height:1.25}.medidor span{font-size:9px}
.atalhos{position:sticky;top:0;z-index:10;display:flex;gap:7px;overflow-x:auto;
  padding:10px 0;background:linear-gradient(var(--fundo) 78%,transparent);scrollbar-width:none}
.atalhos a{flex:0 0 auto;border:1px solid var(--linha);border-radius:999px;color:var(--tinta-fraca);
  background:var(--papel);padding:6px 10px;text-decoration:none;font:600 10px var(--mono);letter-spacing:.04em}
.atalhos a:first-child{border-color:var(--voce);color:var(--voce)}
section{margin-top:34px;scroll-margin-top:48px}
section>h2{font-size:11px;letter-spacing:.14em;margin-bottom:0}
.nota{font-size:14px;line-height:1.48;margin:8px 0 13px}
.voce-bloco{padding:16px;margin-top:4px;border-radius:var(--raio);border:1px solid var(--voce);box-shadow:var(--sombra)}
.voce-bloco h2{font-size:12px}.voce-bloco .nota{color:var(--tinta);opacity:.78}
.item{gap:10px;padding:15px 0}.marca{min-width:25px;color:var(--voce);font-size:12px;font-weight:600}
.corpo-item p:first-child{font-size:16px;line-height:1.42}.porque{font-size:13px;line-height:1.45;margin-top:5px!important}
.rfc{border-radius:var(--raio);margin-top:10px;box-shadow:0 2px 0 rgba(0,0,0,.015)}
.rfc>summary{padding:15px;grid-template-columns:auto 1fr;gap:4px 10px}
.rfc>summary:hover{background:var(--acento-fraco)}
.num{font-size:16px;min-width:30px}.nome{font-size:16px;line-height:1.35}.meta{font-size:11px;line-height:1.42;grid-column:1 / -1;padding-top:2px}.abrir{grid-column:1 / -1;font-size:10px;padding-top:3px}
.selo{font-size:9px;padding:3px 7px;margin-left:4px;vertical-align:2px}
.leitura{padding:1px 15px 20px;font-size:15px;line-height:1.62}.leitura h2{font-size:20px;line-height:1.25;margin-top:20px}.leitura h3{font-size:17px;line-height:1.3}.leitura h4{font-size:16px}
.leitura p,.leitura li{overflow-wrap:anywhere}.leitura ul,.leitura ol{padding-left:21px}
table{font-size:13px}th,td{padding:8px;min-width:100px}.rolar{border:1px solid var(--linha);border-radius:8px}
.fases{gap:8px}.fase{grid-template-columns:42px 1fr;gap:9px;border-radius:10px;padding:12px}.fase .n{font-weight:600}.fase .d{font-size:14px}.fase .e{font-size:12px;line-height:1.38}
footer{margin-top:42px;padding-top:18px;font-size:11px;line-height:1.5}
@media(min-width:620px){
  .envelope{padding-left:28px;padding-right:28px}.medidores{grid-template-columns:repeat(5,1fr)}
  .medidor{padding:11px}.medidor b{font-size:13px}.meta{grid-column:2}.abrir{grid-column:2}
  .leitura{padding-left:20px;padding-right:20px}
}
"""


## O bloco de decisão: o pedido em destaque e os três botões.
##
## ⚠️ Os botões só FUNCIONAM na versão publicada como Artifact, onde a página
## alcança `claude.use("db")` — é de lá que eu leio as decisões depois. No
## espelho servido pelo nginx (`poke.workprog.pro/painel`) não existe esse
## runtime, então eles aparecem desligados, com o motivo escrito. Degradar
## dizendo por quê é melhor que um botão que não faz nada em silêncio, que é
## justamente o defeito que este projeto passou o mês caçando.
def bloco_de_decisao(r):
    if r["classe"] not in ("espera",):
        return ""
    ped = pedido(r["corpo"])
    fora = ['<div class="decidir" data-rfc="%s">' % html.escape(r["arquivo"])]
    fora.append('<h4>O que está sendo decidido</h4>')
    if ped:
        fora.append('<div class="pedido">%s</div>' % markdown(ped))
    else:
        fora.append('<p class="semPedido">⚠️ Esta RFC ainda não tem a seção '
                    "<code>## O pedido</code>. O painel não inventa um resumo: "
                    "leia o texto inteiro acima antes de decidir, e cobre a "
                    "seção de quem abriu a RFC.</p>")
    fora.append('<div class="jaDecidido" hidden></div>')
    fora.append('<div class="botoes">'
                '<button class="bt aprovar" data-ac="aprovada">Aprovar</button>'
                '<button class="bt reprovar" data-ac="reprovada">Reprovar</button>'
                '<button class="bt comentar" data-ac="comentario">Comentar</button>'
                "</div>")
    fora.append('<div class="caixaComentario" hidden>'
                '<textarea rows="4" placeholder="O que você quer dizer sobre '
                'esta decisão? Vai junto com ela."></textarea>'
                '<button class="bt enviar">Enviar</button></div>')
    fora.append('<p class="estadoDecisao" role="status"></p>')
    fora.append("</div>")
    return "".join(fora)


def selo(rfc):
    return '<span class="selo %s">%s</span>' % (rfc["classe"], rfc["rotulo"])


def bloco_fila(linhas, cor_marca=""):
    if not linhas:
        return '<p class="nota">Nada na fila.</p>'
    fora = []
    for l in linhas:
        marca = l[0] if l else ""
        texto = l[1] if len(l) > 1 else ""
        porque = l[2] if len(l) > 2 else ""
        extra = ('<p class="porque">%s</p>' % inline(porque)) \
            if porque and porque != "—" else ""
        fora.append(
            '<div class="item"><div class="marca">%s</div>'
            '<div class="corpo-item"><p>%s</p>%s</div></div>'
            % (inline(marca), inline(texto), extra))
    return "".join(fora)


def bloco_fases(linhas):
    fora = []
    for l in linhas:
        if len(l) < 3:
            continue
        n, nome, estado = l[0], l[1], l[2]
        classe = "nao"
        if estado.startswith("✅"):
            classe = "feita"
        elif estado.startswith("🟡"):
            classe = "meio"
        fora.append(
            '<div class="fase %s"><span class="n">%s</span>'
            '<span class="d">%s<span class="e">%s</span></span></div>'
            % (classe, inline(n), inline(nome), inline(estado)))
    return '<div class="fases">%s</div>' % "".join(fora)


def gerar():
    todas = ler_rfcs()
    # ⚠️ Os documentos sem número (RFC-GAMEPLAY-*) são **desenho**, não decisão:
    # descrevem como o jogo funciona, e ninguém está parado esperando resposta
    # deles. Misturá-los inflaria "esperando decisão", que é o número mais
    # importante desta página — e um número inflado é pior que número nenhum.
    rfcs = [r for r in todas if r["numero"]]
    desenho = [r for r in todas if not r["numero"]]
    esperando = [r for r in rfcs if r["classe"] == "espera"]
    suite = suite_do_quadro()

    fila_gabriel = [l for l in tabela_do_quadro("Pendente — Gabriel")
                    if not (len(l) > 1 and l[1].startswith("✅"))]
    fila_claude = tabela_do_quadro("Pendente — Claude")
    fila_codex = tabela_do_quadro("Pendente — Codex")
    fases = tabela_do_quadro("As 20 fases")

    partes = []
    partes.append('<!doctype html><html lang="pt-BR"><head>')
    partes.append('<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    partes.append("<title>Painel PokéMobile</title>")
    partes.append('<link rel="preconnect" href="https://fonts.gstatic.com" '
                  'crossorigin>')
    partes.append('<link rel="stylesheet" href="https://fonts.googleapis.com/'
                  'css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex'
                  '+Sans:wght@400;500;600;700&display=swap">')
    partes.append("<style>%s</style></head><body>" % CSS)

    partes.append('<div class="envelope">')

    # ── Cabeçalho
    partes.append('<header class="topo">')
    partes.append('<div class="topo-linha"><p class="etiqueta">PokéMobile · estado do projeto</p>'
                  '<button class="tema" type="button" aria-label="Alternar tema">◐ tema</button></div>')
    partes.append("<h1>O que pede sua decisão agora.</h1>")
    partes.append('<p class="resumo">Gerado direto de <code>docs/QUADRO.md</code>'
                  ' e <code>docs/rfc/</code> — os documentos que o Claude e o '
                  'Codex já atualizam por obrigação. Se algo aqui estiver '
                  'errado, é a fonte que está errada.</p>')
    partes.append('<div class="medidores">')
    partes.append('<div class="medidor"><span>suíte</span><b>%s</b></div>'
                  % html.escape(suite.replace(" arquivos", " arq.")))
    partes.append('<div class="medidor"><span>contratos</span><b>%d</b></div>'
                  % len(rfcs))
    partes.append('<div class="medidor"><span>esperando decisão</span><b>%d</b>'
                  "</div>" % len(esperando))
    partes.append('<div class="medidor"><span>na sua fila</span><b>%d</b></div>'
                  % len(fila_gabriel))
    partes.append('<div class="medidor"><span>gerado em</span><b>%s</b></div>'
                  % date.today().strftime("%d/%m/%Y"))
    partes.append("</div></header>")
    partes.append('<nav class="atalhos" aria-label="Ir para seção">'
                  '<a href="#voce">Sua decisão</a><a href="#rfcs">Contratos</a>'
                  '<a href="#fases">Fases V3</a><a href="#claude">Claude</a>'
                  '<a href="#codex">Codex</a></nav>')

    # ── O bloco que é o ponto da página
    partes.append('<section id="voce" class="voce-bloco"><h2>Precisa de você</h2>')
    partes.append('<p class="nota">Nada nesta lista anda sem uma resposta sua. '
                  'O resto da página é contexto.</p>')
    partes.append(bloco_fila(fila_gabriel))
    if esperando:
        partes.append('<p class="nota" style="margin-top:20px">E <strong>%d '
                      "contrato(s)</strong> aguardando decisão — estão abertos "
                      "logo abaixo, com o texto inteiro.</p>" % len(esperando))
    partes.append("</section>")

    # ── RFCs
    partes.append('<section id="rfcs"><h2>Contratos (RFC)</h2>')
    partes.append('<p class="nota">Um contrato é uma decisão que trava trabalho '
                  'de alguém até ser respondida. Toque para abrir e ler inteiro '
                  '— nenhum resumo escolhido por mim fica entre você e o texto.'
                  "</p>")
    for r in rfcs:
        aberto = " open" if r["classe"] == "espera" else ""
        partes.append('<details class="rfc"%s>' % aberto)
        partes.append("<summary>")
        partes.append('<span class="num">%s</span>' % html.escape(r["numero"]))
        partes.append('<span class="nome">%s %s</span>'
                      % (inline(re.sub(r"^RFC-\d+\s*—\s*", "", r["titulo"])),
                         selo(r)))
        partes.append('<span class="meta">%s</span>'
                      % inline("constrói: %s · revisa: %s"
                               % (r["dono"] or "—", r["revisor"] or "—")))
        partes.append('<span class="abrir">▸ ler o contrato inteiro</span>')
        partes.append("</summary>")
        partes.append('<div class="leitura">%s%s</div>'
                      % (markdown(r["corpo"]), bloco_de_decisao(r)))
        partes.append("</details>")
    partes.append("</section>")

    # ── O que liga os botões de decisão ao armazenamento
    #
    # Só funciona onde `claude.use("db")` existe — a versão publicada como
    # Artifact. No espelho do nginx o runtime não existe, e aí os botões ficam
    # desligados COM O MOTIVO ESCRITO: botão que não faz nada em silêncio é o
    # defeito que este projeto passou o mês caçando.
    partes.append("""<script>
(function () {
  var blocos = Array.prototype.slice.call(document.querySelectorAll('.decidir'));
  if (!blocos.length) return;

  function diz(b, txt) { b.querySelector('.estadoDecisao').textContent = txt; }
  function trava(b, motivo) {
    Array.prototype.forEach.call(b.querySelectorAll('button'), function (x) {
      x.disabled = true;
    });
    diz(b, motivo);
  }

  // Sem runtime, nada de botão mudo.
  if (!(window.claude && typeof window.claude.use === 'function')) {
    blocos.forEach(function (b) {
      trava(b, 'Esta cópia é só leitura. Para decidir, abra o painel pelo link '
             + 'do Claude — é lá que a decisão fica guardada.');
    });
    return;
  }

  window.claude.use('db').then(function (db) {
    if (!db) {
      blocos.forEach(function (b) {
        trava(b, 'Esta cópia é só leitura. Para decidir, abra o painel pelo '
               + 'link do Claude.');
      });
      return;
    }

    blocos.forEach(function (b) {
      var rfc = b.getAttribute('data-rfc');
      var doc = db.doc('decisoes/' + rfc.replace(/[^A-Za-z0-9_.-]/g, '_'));
      var caixa = b.querySelector('.caixaComentario');
      var ja = b.querySelector('.jaDecidido');

      function mostrar(d) {
        if (!d || !d.estado) { ja.hidden = true; return; }
        var quando = d.quando ? new Date(d.quando).toLocaleString('pt-BR') : '';
        ja.hidden = false;
        ja.textContent = 'Você já respondeu: ' + d.estado
          + (d.comentario ? ' — “' + d.comentario + '”' : '')
          + (quando ? ' · ' + quando : '');
        Array.prototype.forEach.call(b.querySelectorAll('.bt[data-ac]'), function (x) {
          x.classList.toggle('escolhido', x.getAttribute('data-ac') === d.estado);
        });
      }

      // Uma assinatura por documento, nunca dentro de render.
      doc.onSnapshot(function (snap) { mostrar(snap && snap.data); });

      function gravar(estado, comentario) {
        diz(b, 'gravando…');
        doc.set({
          estado: estado, comentario: comentario || '',
          rfc: rfc, quando: new Date().toISOString()
        }).then(function () {
          diz(b, 'Guardado. O Claude lê isto e transcreve a decisão na própria '
               + 'RFC — que continua sendo a fonte de verdade.');
        }).catch(function (e) {
          diz(b, 'Não consegui guardar: ' + ((e && e.code) || 'erro') + '. '
               + 'Nada foi registrado.');
        });
      }

      Array.prototype.forEach.call(b.querySelectorAll('.bt[data-ac]'), function (bt) {
        bt.addEventListener('click', function () {
          var ac = bt.getAttribute('data-ac');
          if (ac === 'comentario') {
            caixa.hidden = !caixa.hidden;
            if (!caixa.hidden) caixa.querySelector('textarea').focus();
            return;
          }
          // Aprovar/reprovar levam junto o que estiver escrito: separar os dois
          // faria o comentário do Gabriel se perder ao clicar em Aprovar.
          gravar(ac, caixa.querySelector('textarea').value.trim());
        });
      });

      b.querySelector('.enviar').addEventListener('click', function () {
        var txt = caixa.querySelector('textarea').value.trim();
        if (!txt) { diz(b, 'Escreva algo antes de enviar.'); return; }
        gravar('comentario', txt);
      });
    });
  });
})();
</script>""")

    # ── Fases
    partes.append('<section id="fases"><h2>As fases da V3</h2>')
    partes.append('<p class="nota">A ordem existe porque cada fase depende da '
                  "anterior estar de pé. Pular é como se constrói seis sistemas "
                  "pela metade.</p>")
    partes.append(bloco_fases(fases))
    partes.append("</section>")

    # ── Filas
    partes.append('<section id="claude"><h2>Fila do Claude — regras, IA, testes</h2>')
    partes.append(bloco_fila(fila_claude))
    partes.append("</section>")

    partes.append('<section id="codex"><h2>Fila do Codex — arte, HUD, modelos, mundo</h2>')
    partes.append(bloco_fila(fila_codex))
    partes.append("</section>")

    # ── Documentos de desenho ficam depois da fila operacional. Não são uma
    # decisão nem uma fase; deixá-los antes ocultava o que o Gabriel veio ver.
    if desenho:
        partes.append("<section><h2>Desenho de referência</h2>")
        partes.append('<p class="nota">Não pede decisão: descreve como o jogo '
                      'funciona e permanece acessível sem disputar atenção com a fila.</p>')
        for r in desenho:
            partes.append('<details class="rfc"><summary>')
            partes.append('<span class="num">§</span>')
            partes.append('<span class="nome">%s %s</span>'
                          % (inline(r["titulo"]), selo(r)))
            partes.append('<span class="meta">%s</span>' % inline(r["arquivo"]))
            partes.append('<span class="abrir">▸ ler inteiro</span>')
            partes.append("</summary>")
            partes.append('<div class="leitura">%s</div>' % markdown(r["corpo"]))
            partes.append("</details>")
        partes.append("</section>")

    partes.append("<footer>")
    partes.append("<p>Gerado por <code>tools/gerar_painel.py</code>. "
                  "Atualizar: <code>python3 tools/gerar_painel.py</code>.</p>")
    partes.append("<p>Esta página é só leitura. Aprovar é responder no chat — "
                  "estado que muda em dois lugares é como os dois passam a "
                  "discordar.</p>")
    partes.append("</footer></div>")
    partes.append("""<script>
(() => {
  const root = document.documentElement, button = document.querySelector('.tema');
  const saved = localStorage.getItem('painel-tema');
  if (saved) root.dataset.theme = saved;
  button.addEventListener('click', () => {
    const current = root.dataset.theme ||
      (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    const next = current === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next; localStorage.setItem('painel-tema', next);
  });
})();
</script></body></html>""")

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w", encoding="utf-8") as f:
        f.write("\n".join(partes))
    print("painel escrito em %s" % SAIDA)
    print("  %d contratos (%d esperando decisão) · %d itens na fila do Gabriel"
          % (len(rfcs), len(esperando), len(fila_gabriel)))


if __name__ == "__main__":
    gerar()
