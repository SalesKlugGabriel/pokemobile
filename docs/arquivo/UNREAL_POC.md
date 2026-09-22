# UNREAL ENGINE 5 — POC · FASE 0: AUDITORIA DO AMBIENTE

> **Arquivado em 22/09/2026.** Vivia em `/root/pokemon-unreal-poc/`, fora de
> qualquer repositório, e viria a se perder na limpeza do servidor. É a decisão
> que manteve o projeto no Godot, e o motivo dela continua valendo.

**Data:** 18/09/2026 · **Máquina:** `srv1882307.hstgr.cloud` (VPS Hostinger)
**Executor:** Claude · **Método:** medição direta, nenhum valor presumido

> Este documento é a Fase 0 do prompt do Gabriel. A instrução era explícita:
> *"Se alguma dependência essencial estiver ausente: identificar exatamente.
> Não inventar que está instalada."*
>
> **Resultado: a Fase 1 não pode começar nesta máquina.** O detalhe está abaixo,
> item por item, com o que foi medido e como.

---

## 1. O que foi medido

| Item | Resultado | Como |
|---|---|---|
| **Unreal Engine instalado** | ❌ **Ausente** | `which UnrealEditor/UnrealEditor-Cmd/UE5Editor` → nada; `find /` por `UnrealEngine`/`UE_5*` → nada |
| **GPU** | ❌ **Nenhuma** | sem `/dev/dri`, sem `nvidia-smi`, `lspci` nem existe na imagem |
| **CPU** | ⚠️ **2 núcleos** | `nproc` |
| **RAM** | ⚠️ **7,8 GB** (3,5 em uso, 4,2 disponíveis) | `free -h` |
| **Swap** | ❌ **Nenhum** | `swapon --show` |
| **Disco livre** | ⚠️ **67 GB** de 96 GB | `df -h /` |
| **Compilador C++** | ✅ g++ 13.3.0 | `g++ --version` |
| **CMake** | ❌ ausente | `cmake --version` |
| **Blender** | ✅ **4.2.9 LTS** | `blender --version` |
| **Git** | ✅ 2.43.0 | `git --version` |
| **Python** | ✅ 3.12.3 | `python3 --version` |
| **SO / arquitetura** | Ubuntu 24.04.4 LTS · x86_64 | `/etc/os-release`, `uname -m` |

---

## 2. Os três bloqueios, em ordem de gravidade

### 🔴 1. Não existe saída web no Unreal Engine 5 — e o jogo HOJE É web

Este é o achado que muda a pergunta inteira, e ele não depende de hardware.

O jogo é servido como **WebAssembly** em `poke.workprog.pro`. Conferido no que
está no ar agora mesmo:

```
imagem publicada: pokemobile-v3d:20260918-r2
conteúdo:         index.wasm · index.pck · index.js · index.html
pipeline:         tools/exportar_web.sh → godot4 --export-release "Web"
```

A Epic **removeu o alvo HTML5 do Unreal na versão 4.24**, e a UE5 não tem alvo
web de primeira parte. Migrar para Unreal significa, na prática, **abrir mão da
distribuição por navegador** — que é exatamente como o Gabriel abre o jogo hoje,
como ele testa no celular, e como ele mostra pra outra pessoa (um link).

Trocar isso por instalador de desktop é uma decisão de **produto**, não de
engine. E é ela que decide se o POC vale a pena ser rodado: se o navegador é
requisito, o resultado do POC não muda nada — a Unreal já está fora antes do
primeiro teste. Se o navegador é conveniência, o POC faz sentido.

**Esta pergunta precisa de resposta antes de gastar qualquer hora em POC.**

### 🔴 2. Sem GPU, o Editor da Unreal não abre

Não é "fica lento": o Editor da UE5 exige uma GPU com Vulkan. Esta máquina não
tem GPU **nenhuma** — nem integrada. Não há `/dev/dri`, que é o dispositivo por
onde qualquer renderização por hardware passaria.

Isso derruba direto os itens 10 a 16 e 30 do prompt (Golden Test Scene,
Landscape, vegetação, Trainer, câmera, animação): todos exigem o Editor aberto.
E derruba o critério de sucesso inteiro (item 40), que é uma lista de coisas que
só se verificam **jogando**.

### 🔴 3. 2 núcleos, 7,8 GB de RAM e 67 GB livres — e a máquina é de produção

Mesmo que houvesse GPU, o tamanho não fecha. A UE5 pede ordem de grandeza
bem acima disto para compilar e rodar um projeto C++ (dezenas de GB só de
engine, mais o Derived Data Cache do projeto, e compilação que em 2 núcleos se
mede em horas).

E há um risco que não é técnico: **esta VPS está em produção.** Ela roda agora:

```
n8n (editor, worker, webhook)   automação WhatsApp ↔ CVCRM
evolution_api + redis            a ponte do WhatsApp
dashboard-backend / frontend     dashboard comercial, no ar
postgres                         banco de n8n, evolution e dashboard
traefik / portainer              roteamento e HTTPS de 8 subdomínios
pokemobile_app / editor          o próprio jogo
```

Uma compilação de Unreal aqui competiria por 2 núcleos e 4 GB disponíveis com a
automação de WhatsApp e o dashboard comercial. **Não recomendo** — e não farei
sem uma autorização explícita.

---

## 3. O que isto NÃO invalida

A premissa do Gabriel continua correta, e é boa:

> *"Essas informações são ESPECIFICAÇÃO DO JOGO. Elas NÃO pertencem ao Godot."*

Isso está certo, e o projeto já é construído assim, por acidente feliz: as regras
de gameplay vivem em **classes puras** (`RegraDeCombate`, `RegraDeTravessia`,
`RegraDeMaquina`, `RegraDeMovePool`, `RegraDeAlpha`, `KitDeCombate`,
`IASelvagem3D`…) que não citam nó, cena nem autoload, e que são testadas sem
subir o jogo. São ~20 arquivos de regra com **mais de 700 conferências
automatizadas**.

Numa migração real, esse é o material que **atravessa** — não como tradução
linha a linha, mas como especificação já desambiguada e já provada. É o ativo
mais caro do projeto e ele não está preso à engine.

---

## 4. Caminhos possíveis

| # | Caminho | O que custa | O que responde |
|---|---|---|---|
| **A** | **Responder a pergunta do navegador primeiro** | 5 minutos do Gabriel | Se web é requisito, **o POC não precisa acontecer** — a Unreal já está descartada por plataforma, e economizamos o resto |
| **B** | Rodar o POC **no PC do Gabriel** (Windows, com GPU) | Instalar Unreal + Claude Code na máquina dele | É o caminho normal de Unreal, e o único que responde às 14 perguntas do item 8 de verdade |
| **C** | Alugar uma máquina com GPU por hora só pro POC | Custo por hora, e o tempo de montar tudo | Mesmo que B, sem mexer no PC dele |
| **D** | Não fazer POC agora | Zero | Nada — fica a dúvida |

**Minha recomendação: A, e depois B se a resposta liberar.**

O A é barato e pode encerrar a questão sozinho. O B é o caminho certo se ela
não encerrar — porque o que o Gabriel quer medir ("é mais fácil criar o mundo?
a animação é melhor? o combate é responsivo?") só se responde com o Editor
aberto e um controle na mão, e isso nunca vai acontecer numa VPS sem GPU.

---

## 5. Os outros documentos pedidos

O prompt pede quatro documentos. **Só este existe**, de propósito:

| Documento | Estado | Por quê |
|---|---|---|
| `UNREAL_POC.md` | ✅ este arquivo | tem medição por trás |
| `UNREAL_ARCHITECTURE.md` | ⬜ não criado | seria arquitetura de uma engine que não abriu aqui — teoria com cara de entrega |
| `ENGINE_COMPARISON.md` | ⬜ não criado | comparar exige os dois lados medidos; só há um |
| `UNREAL_MIGRATION_PLAN.md` | ⬜ não criado | plano de migração antes do POC inverte a ordem que o próprio prompt define |

É o item 45 do prompt aplicado a ele mesmo: *"A resposta deve vir do protótipo.
Não da teoria."* Escrever os três agora seria produzir exatamente a teoria que
ele mandou não produzir.

---

## 6. Estado do projeto Godot

**Intacto.** Nada foi alterado, movido ou apagado. Este documento vive fora do
repositório do jogo, em `/root/pokemon-unreal-poc/`, como o item 5 do prompt
pede.
