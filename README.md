# PokéMobile

> *"Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
> controle do meu Pokémon."*

Um RPG de ação em tempo real, single-player, feito em **Godot 4.2.2** e jogado
**no navegador** — inclusive no celular.

> ## ⚠️ Leia isto antes de qualquer coisa — estado real em 22/09/2026
>
> **1. Toda a parte gráfica precisa ser criada do zero no Blender.**
> O que existe hoje é *blockout*: formas de prova, feitas pra validar
> proporção, colisão e pipeline — não arte. Modelos de Pokémon, treinador,
> vegetação, rochas e cenário **serão refeitos**. Nada do visual atual deve ser
> tratado como definitivo, nem como base.
>
> **2. As mecânicas NÃO foram testadas nem aprovadas.**
> A suíte de **149 arquivos** passa, e é preciso entender o que ela prova e o
> que não prova. Ela prova que **cada regra faz o que diz que faz**: a fórmula
> de dano, a janela de captura, a chance de Alpha, a travessia, a máscara de
> spawn. Ela **não** prova que o jogo é bom, que o ritmo funciona, que o
> combate é gostoso ou que a coisa é divertida — **isso só se descobre
> jogando, e ninguém jogou o suficiente ainda.**
>
> O Gabriel é quem aprova, e ele não aprovou. Trate cada número de
> balanceamento como **hipótese**, não como decisão fechada.

**Esteve no ar** em `https://poke.workprog.pro` até 22/09/2026, quando o
projeto saiu desta VPS. Republicar exige `tools/publicar.sh` num servidor com
Docker + Traefik. O código está inteiro aqui.

---

## Por onde começar

| Se você quer… | Abra |
|---|---|
| **saber o estado do projeto** — o que está feito, o que falta, de quem é cada coisa | **[`docs/QUADRO.md`](docs/QUADRO.md)** |
| ver e decidir os contratos abertos | `docs/painel/index.html` (gerado por `tools/gerar_painel.py`) |
| entender a direção do jogo | [`docs/GAMEPLAY_V3.md`](docs/GAMEPLAY_V3.md) |
| o mapa do código | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| o que um agente precisa saber ao entrar | [`AGENTS.md`](AGENTS.md) e [`docs/agent-handoff.md`](docs/agent-handoff.md) |

⚠️ **O `QUADRO.md` ganha de qualquer outro documento em caso de divergência.**
Ele é o estado; o resto é desenho e histórico.

---

## O jogo, em três decisões

⚠️ **O que "feito" significa neste repositório.** Uma fase fechada quer dizer
que a regra existe, está isolada em classe pura e tem conferência automatizada
— nunca que ela foi validada jogando. A distinção vale pra tudo abaixo.

**3D, terceira pessoa no mundo, primeira pessoa no combate.** Você anda como
treinador; quando a briga começa, você **vira** o seu Pokémon. Combate 1v1 no
próprio terreno, sem arena separada — e o treinador continua no mundo enquanto
você luta.

**Regra fora do nó.** As regras de gameplay vivem em **classes puras**
(`RefCounted`, sem cena e sem autoload) e são testadas sem subir o jogo. Foi
isso que tornou o pivô de 2D pra 3D possível: 18 das 42 classes de combate nunca
souberam se o jogo era 2D ou 3D. São mais de 800 conferências automatizadas.

**Navegador é requisito, não conveniência.** A migração para Unreal Engine 5 foi
avaliada e **descartada** por isso: a UE5 não tem saída web (a Epic removeu o
alvo HTML5 na 4.24), e o navegador é a única via de distribuição disponível.
Isso valida retroativamente a escolha do renderer `gl_compatibility`.

---

## V1, V2 e V3

A **V3 (3D) é a direção atual e autoritativa.** A V1 e a V2 (2D) foram
aposentadas em 21/09/2026 — **nos documentos**, não no código.

🔴 **Por que o código da V2 continua aqui:** a V3 **roda sobre** as classes puras
dela. Medido pelo fecho transitivo a partir da cena principal, dos autoloads e
de `gameplay_v3/`: **254 dos 432 arquivos** são alcançados com o jogo rodando.
`RegrasDeCorpo`, `Stamina`, `DamageCalculator`, `KitDeCombate`, `StatsDePokemon`,
`ComportamentoSelvagem` e mais vinte são V2 e estão em uso. A própria tela
inicial é 2D — é dela que sai o botão que abre a V3.

Os planos e auditorias da era 2D foram removidos e estão no histórico do git.

---

## O que está pronto, e o que não está

| | |
|---|---|
| ✅ **Regras** | 21 fases: combate, IA selvagem, travessia, captura, loot, save. 149 arquivos de teste |
| ⚠️ **Balanceamento** | **hipótese.** Nenhum número foi validado jogando |
| 🔴 **Arte** | **blockout.** Tudo será refeito do zero no Blender |
| 🔴 **Mundo** | só o laboratório de 160 × 160 m. Não há mapa de jogo |
| 🔴 **Salvar pela V3** | o save existe e é usado, mas quem o aciona é o jogo antigo |
| 🔴 **Multiplayer** | não existe |

## Rodar e publicar

```bash
# a suíte inteira (exige código de saída 0 E a linha de resultado)
./tools/rodar_testes.sh
./tools/rodar_testes.sh --so combate     # seletivo, enquanto se trabalha

# publicar: exporta, empacota, publica e CONFERE o carimbo no ar
./tools/publicar.sh
```

⚠️ **Nunca use `docker build` solto para publicar.** O `Dockerfile` **copia**
`builds/web/` — ele não gera. Em 21/09 isso deixou o jogo no ar 3 dias e 28
commits atrás do código, e nada acusava: o Docker dizia `converged`, o site
respondia 200 e a tag da imagem mudava. `publicar.sh` existe por causa disso e
recusa publicar um build velho.

⚠️ **Uma suíte por vez na VPS.** São 2 núcleos compartilhados com produção.

⚠️ **`class_name` novo exige uma passagem de importação** antes da suíte:
`godot4 --headless --editor --import --quit`.

---

## Quem faz o quê

| Agente | Responsabilidade |
|---|---|
| **Claude** | gameplay: regras, combate, IA, save, dados, testes lógicos |
| **Codex** | apresentação: HUD, câmera, modelos, animação, arte, mundo visual |
| **Gabriel** | direção de produto — e as decisões que nenhum dos dois pode tomar |

Decisões que atravessam a fronteira viram uma **RFC** em [`docs/rfc/`](docs/rfc/),
com dono e revisor declarados. O revisor **mede** antes de aceitar; aceitar
lendo o diff não conta.

## Branches

| Branch | O que é |
|---|---|
| `main` | linha integrada — o estado que vale |
| `agent/claude-v3` | trabalho do Claude |
| `agent/codex-v3` | trabalho do Codex |
| `arquivo/*` | worktrees aposentadas, guardadas por segurança |

## Licença e uso

Projeto pessoal do Gabriel, privado. Pokémon é marca da Nintendo/Game Freak;
este é um trabalho de estudo, sem fim comercial.
