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
    partes.append("<title>Painel PokéMobile</title>")
    partes.append('<link rel="preconnect" href="https://fonts.gstatic.com" '
                  'crossorigin>')
    partes.append('<link rel="stylesheet" href="https://fonts.googleapis.com/'
                  'css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex'
                  '+Sans:wght@400;500;600;700&display=swap">')
    partes.append("<style>%s</style>" % CSS)

    partes.append('<div class="envelope">')

    # ── Cabeçalho
    partes.append('<header class="topo">')
    partes.append('<p class="etiqueta">PokéMobile · estado do projeto</p>')
    partes.append("<h1>O que está feito, o que falta,<br>e o que depende de "
                  "você</h1>")
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

    # ── O bloco que é o ponto da página
    partes.append('<section class="voce-bloco"><h2>Precisa de você</h2>')
    partes.append('<p class="nota">Nada nesta lista anda sem uma resposta sua. '
                  'O resto da página é contexto.</p>')
    partes.append(bloco_fila(fila_gabriel))
    if esperando:
        partes.append('<p class="nota" style="margin-top:20px">E <strong>%d '
                      "contrato(s)</strong> aguardando decisão — estão abertos "
                      "logo abaixo, com o texto inteiro.</p>" % len(esperando))
    partes.append("</section>")

    # ── RFCs
    partes.append("<section><h2>Contratos (RFC)</h2>")
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
        partes.append('<div class="leitura">%s</div>' % markdown(r["corpo"]))
        partes.append("</details>")
    partes.append("</section>")

    # ── Os documentos de desenho
    if desenho:
        partes.append("<section><h2>Desenho de referência</h2>")
        partes.append('<p class="nota">Estes dois não são decisão esperando '
                      "resposta: descrevem <em>como o jogo funciona</em>. "
                      "Ficam aqui porque são a fonte de onde as regras saem "
                      "— e porque a V3 vence a V2 em qualquer conflito.</p>")
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

    # ── Fases
    partes.append("<section><h2>As 20 fases da V3</h2>")
    partes.append('<p class="nota">A ordem existe porque cada fase depende da '
                  "anterior estar de pé. Pular é como se constrói seis sistemas "
                  "pela metade.</p>")
    partes.append(bloco_fases(fases))
    partes.append("</section>")

    # ── Filas
    partes.append("<section><h2>Fila do Claude — regras, IA, testes</h2>")
    partes.append(bloco_fila(fila_claude))
    partes.append("</section>")

    partes.append("<section><h2>Fila do Codex — arte, HUD, modelos, mundo</h2>")
    partes.append(bloco_fila(fila_codex))
    partes.append("</section>")

    partes.append("<footer>")
    partes.append("<p>Gerado por <code>tools/gerar_painel.py</code>. "
                  "Atualizar: <code>python3 tools/gerar_painel.py</code>.</p>")
    partes.append("<p>Esta página é só leitura. Aprovar é responder no chat — "
                  "estado que muda em dois lugares é como os dois passam a "
                  "discordar.</p>")
    partes.append("</footer></div>")

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w", encoding="utf-8") as f:
        f.write("\n".join(partes))
    print("painel escrito em %s" % SAIDA)
    print("  %d contratos (%d esperando decisão) · %d itens na fila do Gabriel"
          % (len(rfcs), len(esperando), len(fila_gabriel)))


if __name__ == "__main__":
    gerar()
