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
feitos=[i for i in itens if "✅" in i]
c("item concluído não aparece na lista", not feitos, str(len(feitos))+" com ✅")
# O travado vai pro fim — lista que começa pelo bloqueado ensina a ignorá-la.
trav=[n for n,i in enumerate(itens) if 'travado' in i[:40]]
livres=[n for n,i in enumerate(itens) if 'travado' not in i[:40]]
c("o travado fica depois do que dá pra fazer",
  (not trav) or (not livres) or min(trav)>max(livres), str(trav)+" x "+str(livres))
c("existe a caixa de mandar tarefa", 'id="tarefaTexto"' in t and 'data-para="claude"' in t)
c("e ela oferece os dois agentes", 'data-para="codex"' in t and 'data-para="ambos"' in t)
c("o espelho avisa que é espelho", 'id="avisoEspelho"' in t)
c("os botões de decisão existem", 'class="decidir"' in t)
print("\n=== Resultado: %d ok, %d falhas ===" % (ok,fail))
sys.exit(1 if fail else 0)
