import re,io,sys,subprocess
subprocess.run(["python3","tools/gerar_painel.py"],capture_output=True)
t=io.open("docs/painel/index.html",encoding="utf-8").read()
ok=fail=0
def c(n,cond,d=""):
    global ok,fail
    if cond: ok+=1; print("  OK   "+n)
    else: fail+=1; print("  FALHOU "+n+"  "+d)

m=re.search(r'<ol class="passos">.*?</ol>',t,re.S)
c("a lista de próximos passos existe", m is not None)
itens=re.findall(r'<li class="passo[^"]*">(.*?)</li>',m.group(0),re.S) if m else []
c("ela tem itens", len(itens)>3, str(len(itens)))
# 🔴 O defeito de 21/09: linhas de documentação entrando como tarefa.
lixo=[i for i in itens if re.sub('<[^>]+>','',re.search(r'<div class="oque"><p>(.*?)</p>',i,re.S).group(1)).strip() in ("Onde","Diz","O quê","1,60 m","1,75 m","1,750 m")]
c("nenhuma linha de documentação virou tarefa", not lixo,
  "a extração voltou a pegar tabelas de subseção")
c("toda tarefa diz de quem é", all('class="dono' in i for i in itens))
# Item concluído não aparece: ele vive no histórico do QUADRO.
# ⚠️ A régua é "COMEÇA com ✅", a mesma do gerador — e não "contém ✅".
# Uma linha pode citar uma aprovação no meio do texto e continuar pendente:
# "RFC-002 ✅ aprovada pelo Gabriel" é trabalho A FAZER pelo Codex. Conferir
# por "contém" reprovava a linha certa.
def _texto(i):
    return re.sub('<[^>]+>','',re.search(r'<div class="oque"><p>(.*?)</p>',i,re.S).group(1)).strip()
feitos=[i for i in itens if _texto(i).startswith("✅")]
c("item concluído não aparece na lista", not feitos, str(len(feitos))+" começam com ✅")
# O travado vai pro fim — lista que começa pelo bloqueado ensina a ignorá-la.
trav=[n for n,i in enumerate(itens) if 'travado' in i[:40]]
livres=[n for n,i in enumerate(itens) if 'travado' not in i[:40]]
c("o travado fica depois do que dá pra fazer",
  (not trav) or (not livres) or min(trav)>max(livres), str(trav)+" x "+str(livres))
c("existe a caixa de mandar tarefa", 'id="tarefaTexto"' in t and 'data-para="claude"' in t)
c("e ela oferece os dois agentes", 'data-para="codex"' in t and 'data-para="ambos"' in t)
c("o espelho avisa que é espelho", 'id="avisoEspelho"' in t)
c("os botões de decisão existem", 'class="decidir"' in t)

# ── O atalho /v3d/ (21/09) ─────────────────────────────────────────────────
# O Gabriel usava esse endereço havia semanas e ele nunca existiu. Agora
# existe, e estas conferências impedem que ele volte a sumir em silêncio.
ng = io.open("nginx.conf", encoding="utf-8").read()
c("a rota /v3d/ existe", "location /v3d/" in ng)
c("e /v3d sem barra redireciona", "location = /v3d" in ng)
# O simétrico que mais importa: o jogo PRECISA dos cabeçalhos, o painel não.
bloco_v3d = ng.split("location /v3d/")[1].split("}")[0] if "location /v3d/" in ng else ""
c("/v3d/ tem os cabeçalhos que o WebAssembly exige",
  "Cross-Origin-Embedder-Policy" in bloco_v3d and "Cross-Origin-Opener-Policy" in bloco_v3d,
  "sem eles o jogo não sobe em /v3d/")
bloco_pn = ng.split("location /painel/")[1].split("}")[0] if "location /painel/" in ng else ""
c("e /painel/ continua SEM eles", "Cross-Origin" not in bloco_pn,
  "herdar isso bloqueia a fonte do Google no painel, em silêncio")
c("usa alias, não root", "alias /usr/share/nginx/html/" in bloco_v3d,
  "com root o nginx procuraria /v3d/index.js, que não existe")
ts = io.open("scripts/ui/TitleScreen.gd", encoding="utf-8").read()
c("a tela inicial lê o endereço", "_endereco_pede_o_laboratorio" in ts)
c("e ainda oferece o botão pra quem entra pela raiz", 'Gameplay V3 (3D)' in ts)

print("\n=== Resultado: %d ok, %d falhas ===" % (ok,fail))
sys.exit(1 if fail else 0)
