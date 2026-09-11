# RFC-005 — Pipeline Blender → pixel art para assets

**Status:** PROPOSED
**Owner:** Codex (client/UI) — o pipeline de asset seria dele
**Reviewer:** Claude (gameplay) — medi a VPS e o que já existe
**Aberto por:** Claude · 11/09/2026, a pedido do Gabriel

---

## 1. A proposta do Gabriel

Instalar **Blender headless** na VPS para o Codex gerar assets por script:

```
Codex → create_tree.py → Blender --background → render → pixel art → /assets → Godot
```

E, para personagens, usar modelo rigado + animação para gerar as 4 direções de
caminhada automaticamente — resolvendo *consistência de perspectiva, escala e
animação*.

**A técnica é real e bem documentada.** Blender roda sem interface gráfica com
API Python oficial. Não há nada de duvidoso na proposta.

## 2. O que já existe (para não pagar duas vezes)

Medi antes de opinar:

| Peça do plano | Estado real |
|---|---|
| **Godot headless** | ✅ **já instalado** (4.2.2) e usado toda sessão — 105 arquivos de teste rodam por `--headless --script` |
| Validador/builder de jogo | ✅ **já existe** — `tools/rodar_testes.sh` e `tools/exportar_web.sh` |
| **Pipeline de asset por script** | ✅ **já existe**, sem Blender: **16 scripts Python** em `tools/` que geram pixel art com Pillow |
| Python + Pillow + ImageMagick | ✅ instalados |
| **Blender** | ❌ ausente |
| numpy | ❌ ausente (Blender traz o dele) |

O ciclo *"agente escreve script → gera asset → Godot importa → teste valida"*
**já está fechado hoje**. `tools/gerar_biomas.py`, por exemplo, gerou o terreno
de 6 biomas inteiros (pântano, montanha, deserto, ruínas, casa assombrada, mata
fechada) — chão, variantes, detalhes e estruturas 2×3.

São **638 PNGs, 46 MB** de arte já produzida por esse caminho.

**O que o Blender acrescenta não é o ciclo — é a fonte da imagem: render 3D em
vez de desenho procedural em Python.**

## 3. A VPS aguenta?

| Recurso | Valor | Veredito |
|---|---|---|
| CPU | **2 núcleos** (EPYC 9354P) | ok para render ortográfico pequeno; lento para qualquer coisa além |
| RAM | 7,8 GB (3,2 em uso) | suficiente para low-poly |
| Disco | **64 GB livres** | Blender ocupa ~400 MB — irrelevante |
| GPU | **nenhuma** | render por CPU apenas |

Para o caso de uso (câmera ortográfica, low-poly, render de 32 a 64 px) **CPU
basta**. Um tile ou sprite pequeno leva segundos, não minutos.

⚠️ **Ressalva que não estava no plano:** esta VPS não é só o jogo. Ela roda
**Docker Swarm com n8n, Evolution API, Postgres, o dashboard, o app de visitas
e o próprio PokéMobile publicado**. São 2 núcleos compartilhados. Render em lote
pode competir com serviço de produção. Recomendo `nice` nos renders e **nunca**
rodar lote pesado junto de um deploy.

## 4. O risco real, que é de arte e não de infraestrutura

Este é o ponto que eu levantaria antes de instalar qualquer coisa.

O jogo tem **638 PNGs num estilo já estabelecido**, com direção de arte escrita
(`docs/direcao-de-arte-mestre.md`, `docs/art-direction.md`). Esse estilo nasceu
de **desenho procedural**, não de render.

**Render 3D convertido em pixel art quase nunca combina com pixel art desenhada
à mão.** Luz, contorno, paleta e o modo como a forma "lê" em 16 px são
diferentes. O resultado típico de misturar os dois é o jogo ficar **inconsistente**
— não mais feio em absoluto, mas visivelmente de duas origens.

Isso não é motivo para não fazer. É motivo para **testar em algo isolado antes
de adotar como pipeline**, que é exatamente o MVP que o Gabriel propôs.

## 5. Onde o Blender ganha de forma clara

Duas coisas que o caminho procedural faz mal e o render faz bem:

### a) As laterais das construções
Pendência antiga do Gabriel, **reportada 2× (09/09 e 10/09) e nunca resolvida**:
*paredes laterais de casa usando a mesma sprite da frente*. Uma casa modelada em
3D dá **as quatro faces de graça**, com perspectiva coerente entre si. Desenhar
quatro lados coerentes à mão é justamente o que não aconteceu.

### b) Ciclos de caminhada de NPC
4 direções × 3-4 quadros = 12 a 16 sprites por personagem, que precisam ser
coerentes entre si. É onde o render automatizado é imbatível e o desenho manual
é caro e propenso a inconsistência. O Gabriel identificou isso corretamente.

## 6. MVP que eu proporia (e é o dele)

Fechar **um** ciclo completo antes de generalizar:

```
Codex → script Blender → casa low-poly → render ortográfico das 4 faces
      → pipeline de pixel art (quantizar paleta, reduzir, contornar)
      → assets/buildings/casa_XX.png
      → Claude: Godot importa, char no CHAR_MAP, aparece no mapa
      → comparação lado a lado com a casa atual
```

**Critério de aceite:** a casa nova, colocada ao lado da arte existente, parece
do mesmo jogo? Se sim, expande. Se não, o pipeline serve para outra coisa
(talvez só NPCs) ou não serve.

Escolhi a casa e não a árvore de propósito: ela é a pendência real do Gabriel,
e é o caso onde o 3D tem vantagem estrutural.

## 7. Divisão de trabalho

A proposta dele (Codex = Asset Pipeline, Claude = Game Pipeline) é
**compatível com o `AGENTS.md` atual** — é a mesma divisão, com nomes melhores.
Não vejo necessidade de reescrever o acordo.

O que eu acrescentaria é o protocolo de tarefa que ele descreveu, porque resolve
um problema real (asset entregue fora da medida):

```
Claude: TASK-042 — casa 32×48, colisão 20×12, 4 faces
Codex:  gera → TASK-042 READY
Claude: godot --headless → importa → valida medida e colisão → PASS / REVISION_REQUIRED
```

Isso encaixa em `docs/agent-decisions.md` sem estrutura nova.

## 8. Perguntas para o Codex

1. Você **quer** o Blender? O pipeline seria seu — se preferir continuar no
   caminho procedural em Python, ele já funciona e tem 638 PNGs de resultado.
2. Se sim: **começamos pela casa** (a pendência real) ou por um teste mais
   barato?
3. Que **pipeline de pixelização** você quer? Quantização de paleta, redução,
   contorno — posso instalar o que faltar.
4. O protocolo TASK-NNN te serve, ou prefere continuar só por RFC?

## 9. INSTALADO — e o MVP rodou. Resultado honesto abaixo.

O Gabriel autorizou. **Blender 4.2.9 LTS** instalado em `/opt/blender`
(1,3 GB), atalho em `/usr/local/bin/blender`. Funciona headless com API Python.

### Três coisas que custaram tempo e ficam registradas

**1. A câmera do Blender nasce olhando pra BAIXO (-Z).** Posicionar sem girar
faz ela filmar o chão: o PNG sai **vazio**, sem erro e sem aviso. Perdi duas
rodadas inteiras achando que era o motor de render.

**2. EEVEE não serve nesta VPS.** Sem GPU ele cospe `EGL_BAD_MATCH`, leva
**43 a 75 segundos** por render de 64×64 **e entrega imagem vazia**. O motor
certo é o **WORKBENCH**:

| Motor | Tempo por render 64×64 | Resultado |
|---|---:|---|
| EEVEE Next | **43–75 s** | **vazio** |
| **Workbench** | **0,01–0,5 s** | correto |

Quatro mil vezes mais rápido, e é o motor feito pra cor chapada.

**3. Gire o OBJETO, não a câmera.** Girando a câmera, a luz muda junto e as
quatro faces saem com iluminação diferente. Girando o objeto, luz e
enquadramento ficam idênticos — que é justamente a "consistência de
perspectiva" que motivou tudo isso.

### Ferramentas entregues

| Arquivo | O que faz |
|---|---|
| `tools/blender/render_ortogonal.py` | renderiza 1, 4 ou 8 direções em tamanho de sprite. Cuida de câmera, luz e motor |
| `tools/blender/generators/casa.py` | exemplo de script de CENA: só monta geometria, não toca em câmera |
| `tools/pixelart/pixelizar.py` | render → pixel art: recorta, reduz (vizinho mais próximo), quantiza paleta, contorna |

```bash
blender --background --python tools/blender/render_ortogonal.py -- \
    --cena tools/blender/generators/casa.py --saida /tmp/casa --tamanho 64 --direcoes 4
python3 tools/pixelart/pixelizar.py /tmp/casa_sul.png saida.png --tamanho 32 --cores 12 --contorno
```

**Medido:** 4 faces de 64×64 em **0,47 s**. As quatro são comprovadamente
diferentes entre si. A pixelização levou 140 cores → **10 cores** em 32×32.

### 🔴 O MVP FALHOU no critério de aceite, e isso é o resultado mais útil aqui

O critério era: *"a casa nova, ao lado da arte existente, parece do mesmo
jogo?"*

**Não parece.** A arte atual do jogo tem textura de madeira, janela com
moldura, sombreado e paleta rica. A casa renderizada, depois de reduzida a
32×32, é **uma mancha marrom**: telhado e corpo se fundem, a porta some.

É exatamente o risco que eu tinha levantado na seção 4 antes de instalar —
render 3D pixelizado não casa com pixel art desenhada. Agora está **medido**,
não suposto.

**Isso NÃO invalida o pipeline.** O que ele mostra é que o gargalo mudou de
lugar: a infraestrutura funciona e é rápida; o que falta é **direção de arte no
modelo 3D** — material com textura em vez de cor chapada, mais geometria de
detalhe, iluminação pensada pro tamanho final, e talvez renderizar maior e
reduzir menos.

**Isso é trabalho seu, Codex, não meu.** Eu entreguei a ferramenta afiada e
provei que ela corta. Se a peça sai feia, é o modelo — e modelar é arte.

### Onde eu ainda apostaria no pipeline

1. **Geometria de referência**, mesmo que a arte final seja desenhada: o render
   das 4 faces dá a forma e a perspectiva certas pra desenhar em cima.
2. **Ciclos de caminhada de NPC** — 4 direções × 4 quadros coerentes é onde o
   desenho manual mais erra e o render mais ganha.
3. **Sombra projetada** de estruturas, que é geometria pura e não depende de
   estilo.

## Decisão

_Instalado e provado tecnicamente. **A adoção é do Codex** — a ferramenta está
pronta; o resultado depende de direção de arte no modelo._
