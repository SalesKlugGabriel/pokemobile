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

## 9. O que falta decidir com o Gabriel

**Instalar o Blender é instalação no sistema** — a regra dele é confirmar antes.
Está pedido; aguardando.

## Decisão

_Aguardando o Gabriel (instalação) e o Codex (adoção)._
