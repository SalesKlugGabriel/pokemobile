# 🔴 TAREFA NOVA DO GABRIEL — PLAYER 3D V1 (18/09/2026)

Leia: `docs/agent-proposals/gabriel/2026-09-18-player-3d-v1.md`
na branch **`agent/claude-v3`** (ou faça o merge dela — ela já contém a sua arte
da Golden Scene, mesclada em 18/09 sem conflito).

## Em uma frase

O Gabriel quer o **primeiro modelo 3D definitivo do PLAYER**, feito no Blender,
visualmente próximo a uma folha de concept art que ele montou — não "um modelo
que funcione".

## Três coisas antes de começar

1. ⚠️ **A folha de referência NÃO está no repositório.** Foi enviada na conversa
   e não chegou ao disco da VPS. **Peça a imagem ao Gabriel** — ela é a
   referência principal, e a FASE 1 do pedido dele é justamente analisá-la.
2. Já existe `assets/models/trainer/player.glb` (seu, 14–15/09), e **nada no
   jogo o carrega** — conferido por `git grep` em todas as branches. O treinador
   em cena hoje é uma **cápsula amarela** montada em código. O player_v1 não
   substitui nada: é o primeiro a entrar de verdade.
3. 🔴 **Frente no −Z, origem nos pés, 1 unidade = 1 metro.** Desde 18/09 o corpo
   do treinador **encara a mira do mouse**. Um modelo apontando pra +Z aparece
   andando de costas o tempo todo — que é exatamente a queixa que acabamos de
   resolver, e seria cruel reintroduzi-la pelo asset.

## O processo que ele pediu, e que importa

Ele foi explícito: **não entregar tudo de uma vez.** Modelo sem rig → turnaround
→ **parar e comparar com a referência** → só então rig, skinning, três animações
(idle/walk/run, só essas), export, cena de teste no Godot com terreno,
vegetação e Pokémon de verdade, e screenshots de escala.

E a regra que ele grifou: **low-poly não é baixa qualidade.**

## Ao terminar

Atualize `docs/QUADRO.md` na mesma sessão — regra dele de 17/09. Você já está
listado lá como dono do item 0 (prioridade).
