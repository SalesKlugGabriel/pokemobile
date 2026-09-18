# PLAYER 3D V1 — Fase 1: análise da referência e do jogo

**18/09/2026 · branch `agent/codex-v3` · base `f593738`**
Referência principal **disponível e inspecionada**: `docs/referencias/player_v1/folha-player-v1.png` (1536 × 1024). A transcrição em `FOLHA-DE-REFERENCIA.md` é apoio; a imagem prevalece.

## Leitura visual da folha

O personagem deve ser reconhecido a distância pelo **triângulo vermelho do boné, massa azul da jaqueta e volume escuro da mochila**, com sola branca/vermelha marcando os pés. A prancha mostra frente, 3/4, lado e costas, mais corrida, enquadramento de jogo e escala com Pokémon. O modelo precisa ser julgado nos mesmos ângulos; um render só de frente esconderia precisamente as partes mais importantes (mochila, aba, cabelo da nuca e lateral do tênis).

| Elemento | O que a imagem exige | Risco do procedimento atual |
|---|---|---|
| Silhueta | adolescente magro, pernas longas, ombros estreitos; boné e mochila separados | cápsula ou peças arredondadas não têm identidade |
| Jaqueta | azul, aberta sobre camiseta branca, gola levantada, mangas dobradas | pintar uma faixa branca num torso azul não cria roupa |
| Cabeça | cabelo em mechas angulares sob boné, rosto juvenil com mandíbula/nariz | esfera única com olhos colados parece boneco genérico |
| Mãos | luva sem dedos e punho com detalhe vermelho | mão lisa não permite leitura da luva |
| Calça | cargo escura, bolsos laterais, joelho e barra definidos | caixa reta não deforma bem em caminhada |
| Tênis | cabedal vermelho/preto/branco e sola clara espessa | bota escura apaga o contraste do passo |
| Mochila | corpo e bolso frontal, alças, faixas vermelhas, rolo opcional no topo | caixa fundida às costas perde silhueta e clipa |

Para material, partir dos hex **declarados no pedido** (`#B84242`, `#315FA8`, `#252831`, `#E5E3DF`, `#201D1D`); os pixels da folha estão sombreados e não devem ser copiados como cor-base. A referência pede ~1,60 m e 6–6,5 cabeças, com estilização controlada: não chibi, não adulto realista. Na volta de 3/4, preservar leitura da mochila e do boné antes de detalhes finos de rosto.

## Estado real no repositório

- `TrainerController3D._montar_corpo()` usa cápsula amarela de **1,75 m**, raio 0,35 m; `CameraTerceiraPessoa` usa braço de 5 m e altura de ombro 1,5 m. A escala visual do novo asset é 1 unidade = 1 m, origem nos pés, frente **−Z**. Ajustar cápsula/câmera para 1,60 m mexe em gameplay/contrato misto e deve ser revisado com Claude; a cena de teste isolada não exige alterar isso agora.
- O GLB existente `assets/models/trainer/player.glb` tem **283.332 bytes**, 1 mesh, **1.820 triângulos**, 7 materiais, 1 skin e 8 animações. `gerar_trainer_glb.py` revela torso em cubo, cabeça/braços em UV spheres, mochila como cubo vermelho, pesos rígidos por componente e ossos dos membros ligados diretamente ao root. É um **protótipo técnico**, não base de qualidade para deformação de adolescente vestido.
- Nenhum código de jogo carrega `player.glb`; o jogador em tela é a cápsula montada no controlador. O V1 novo não vai sobrescrever um asset em uso. Não reutilizar o arquivo antigo como “resultado” só por já ter rig e Actions.
- Há três modelos de Pokémon aprovados (#6, #18, #130), com altura de espécie em `PokemonScale.gd`. A cena de teste deve usar estes recursos nas alturas reais, sem escalá-los para compensar o player. O enquadramento da câmera real deve ser a régua, não um fundo cinza.

## Pipeline existente e abordagem da Fase 2

O Blender headless e geradores em `tools/blender/generators/` já existem. O script antigo prova exportação GLB, conversão para +Z no Blender e Actions/NLA, mas é monolítico e a anatomia/weights não são reutilizáveis. `render_ortogonal.py` é uma ferramenta de **sprites 2D**; para o personagem 3D, usar Workbench em turnaround dedicado, sem pixelizar/quantizar o modelo.

Proposta modular, reproduzível e sem tocar no oficial:

```
tools/blender/player/
  create_player.py       # malha e collections, idempotente
  materials_player.py    # poucos materiais PBR simples
  validate_player.py     # escala, origem, −Z, silhueta, polígonos
  preview_player.py      # 5 ângulos Workbench + pose neutra
  rig_player.py          # só depois da aprovação estrutural
  export_player.py       # GLB só depois dos testes
assets/characters/player_v1/
```

**Fase 2 é somente a malha sem rig.** Modelar grandes volumes com topologia que permita ombro/cotovelo/quadril/joelho; roupa, mochila e boné como formas próprias; medir perfil e costas. Fase 3 renderiza frente, 3/4, lado, 3/4 de costas e costas e compara com a folha. Se a silhueta continuar parecendo primitivas, corrigir modelagem **antes** de rig, animação ou export.

## Gates antes de integração

1. Altura final 1,60 m ± tolerância de modelagem; pés em Y=0 no Godot; frente −Z; escala aplicada.
2. Silhueta de adolescente e roupas separadas aprovada nos cinco ângulos; mochila legível no enquadramento real de 5 m.
3. Triângulos, vértices, materiais, texturas, tamanho GLB e draw calls medidos; o alvo de 8–15 mil triângulos é orçamento orientativo, **não meta para preencher**.
4. Somente após aprovação estrutural: rig humano, pesos e poses extremas, depois idle/walk/run in-place; sem animar o objeto raiz como substituto de membros.
5. Importar em cena isolada com terreno, vegetação, rocha e Pokémon pequeno/médio/grande. Nenhuma troca no `TrainerController3D` sem revisão cruzada e aceite humano.

**Estado em 18/09/2026:** Fase 1 concluída. Fase 2 segue em refinamento em `assets/characters/player_v1/`: malha modular sem rig, 1,600 m, **3.674 triângulos**, 9 materiais, cinco previews e validação técnica reproduzível. As passagens recentes estreitaram ombros/braços, separaram melhor calça, tornozelo e tênis, converteram os olhos em formas planas e corrigiram perfil de mochila, nuca e nariz. A revisão mais recente também encurtou as mechas laterais que escondiam os olhos, reduziu visualmente as alças frontais da mochila e trocou os grandes joelheiras por painéis de costura; são melhorias de leitura, não aprovação final. O gate visual da Fase 3 **continua falhando**: rosto, volumes de roupa e proporção frente/3/4 ainda estão próximos de blockout. O manifesto `player_v1.json` marca `BLOCKOUT_NOT_READY`. Não exportar GLB, rigar, animar ou substituir o jogador oficial antes de refinar e aprovar a silhueta nos cinco ângulos. Nenhuma cena ou código de gameplay foi alterado.
