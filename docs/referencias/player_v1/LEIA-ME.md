# Onde a folha de referência do PLAYER V1 vai ficar

## O arquivo

```
docs/referencias/player_v1/folha-player-v1.png
```

**Este nome exato.** Os dois documentos que dependem dela já apontam pra cá:

- `docs/agent-proposals/gabriel/2026-09-18-player-3d-v1.md`
- `docs/referencias/player_v1/FOLHA-DE-REFERENCIA.md`

## Enquanto ela não chega

Vale a **transcrição** ao lado: `FOLHA-DE-REFERENCIA.md` — a folha descrita
painel por painel, separando o que está desenhado do que é interpretação.

Quando o PNG chegar, **ele manda** e a transcrição vira apoio. Nada muda de
lugar: os links continuam válidos.

## Por que ela não estava aqui

A imagem chega ao Claude **dentro da conversa** e não é gravada no disco da VPS
— conferido em 18/09: a pasta de uploads da sessão só recebeu os `.xlsx` de
17/09. Não é descuido de ninguém; é como o canal funciona.

## Como o Gabriel sobe (caminho recomendado: GitHub, do navegador)

O repositório é `SalesKlugGabriel/pokemobile`, e a branch de trabalho é
`agent/claude-v3`. Pela interface web do GitHub dá pra arrastar o arquivo — sem
SSH, sem terminal, e funciona do celular:

1. `github.com/SalesKlugGabriel/pokemobile`
2. trocar a branch para **`agent/claude-v3`**
3. navegar até `docs/referencias/player_v1/`
4. **Add file → Upload files**, soltar o PNG
5. renomear para **`folha-player-v1.png`** se necessário
6. **Commit directly to the `agent/claude-v3` branch**

Depois disso, na VPS: `git pull` em `/root/pokemobile` — e a folha está em todas
as worktrees que fizerem merge.

## Para o Codex

Antes da FASE 1, rode um `git pull` e confira se
`docs/referencias/player_v1/folha-player-v1.png` já existe.

- **Existe** → ela é a referência principal. Abra e compare com a transcrição; se
  divergirem, **a imagem ganha**, e corrija a transcrição.
- **Não existe** → siga pela transcrição, que é suficiente pra FASE 2, e avise no
  relatório que trabalhou sem a imagem.
