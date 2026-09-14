# RFC-GAMEPLAY-V3-3D — Pivô para Action RPG 3D

**Status:** REVIEW · **Owner:** Claude (arquitetura) · **Reviewer:** Gabriel
**Base:** `bef3146` · aberto em 14/09/2026
**Autoridade:** a partir deste documento, **V3 vence V2 em qualquer conflito**.

---

## 1. Contexto

O projeto recebeu a Gameplay V2 (Action RPG 2D top-down) e a implementou: o
protótipo vertical fecha o laço movimentação → exploração → combate →
loot/captura → progressão, com 114 arquivos de teste e 0 falhas.

O Gabriel decidiu pivotar para **3D**: treinador em terceira pessoa no mundo, e
**controle direto do Pokémon em primeira pessoa** quando a batalha começa.

Isto não é reinício. É migração progressiva, e o que a V2 construiu de regra
continua valendo.

## 2. Estado atual (medido, não suposto)

| | |
|---|---|
| Godot | 4.2.2 · renderer **`gl_compatibility`** |
| Código | 121 scripts, 27.856 linhas (fora testes) |
| Cenas | 120 `.tscn`, **todas 2D** |
| Testes | 114 arquivos, 0 falhas · **47 tocam em 2D** |
| Dados | 151 espécies, 192 golpes, 61 quests, 100+ zonas |
| Arte | **638 PNG, zero modelo 3D** |
| 3D existente | **nenhum** — conferido: 0 arquivos citam `Node3D` |
| Git | limpo, 4 branches, 4 worktrees |

**Conferido em cena real:** `Node3D`, `Camera3D`, `MeshInstance3D` e
`CharacterBody3D` carregam e instanciam neste projeto. O 3D funciona.

## 3. Problemas da arquitetura atual (para a V3)

1. **Movimento em grid.** `BaseEntity.try_move()` é tile + tween. A V2 já tinha
   começado a sair disso com `CorpoLivre`; a V3 termina.
2. **Mundo pintado com caracteres.** `MapLayouts` tem 4.531 linhas de char-grid.
   Não existe caminho de conversão pra terreno 3D — é substituição.
3. **Câmera fixa por cena.** 120 `Camera2D` com zoom cravado.
4. **Combate indireto.** Na V2 o jogador manda o Pokémon atacar. Na V3 ele **é**
   o Pokémon. A `MesaDeComandos` perde o papel central.
5. **Um só controlador de input.** Não existe arbitragem entre treinador,
   Pokémon, surf e voo — e a §12 exige que nunca haja dois.

## 4. Nova visão

> **Eu exploro o mundo como treinador. Quando a batalha começa, eu assumo o
> controle do meu Pokémon.**

Dois estados: **WORLD** (3ª pessoa, treinador) e **COMBAT** (1ª pessoa,
Pokémon). Combate 1v1, no próprio terreno, sem arena separada. **Não é MOBA.**

## 5. Sistemas preservados

As **18 classes puras** (`RefCounted`, zero referência a `Vector2`/`Node2D`):
dano, stats, natures, IVs, livro de efeitos, status, XP, corpo/captura,
lendário, ultimate, kit, troca de kit, passivas, sinergia, papel de golpe,
stamina, régua central e depuração de combate.

Mais: `species.json`, `moves.json`, `SaveManager`, `GameData`, `EventBus`,
`RNGManager`, `PonteDeFeedback`, `PerigoDaZona` e os contratos de leitura do
combate (`golpe_resolvido`, `status_aplicado`).

🔴 **O save atravessa o pivô sem migração.** Conferido: ele não guarda posição
nem `Vector2` — só `current_map` (texto), time, IV, nature, golpes, held,
inventário, pokédex e dinheiro.

Tabela completa em `docs/MIGRATION_V2_TO_V3.md`.

## 6. Sistemas adaptados

`FormaDeArea`, `Telegrafia`, `Empurrao`, `Locomocao`, `ComportamentoSelvagem`,
`SelvagemV2`, `Corpo`, `WarpZone`, `Mergulho`, `zones.json`, `QuestManager`,
HUD e `FeedbackDeImpacto`. Em todos, **a regra fica e a interface muda**.

## 7. Sistemas substituídos

`CorpoLivre`, `TreinadorV2`, `PokemonAtivoV2`, `HitBox`/`HurtBox`,
`ProjectileBase`, `Contorno`, `SpawnManager`, câmera.

**Depreciados** (ficam no repositório até a V3 andar): `try_move`, `MapLayouts`,
tilesets, as 120 cenas 2D, `MesaDeComandos`, `AreaTargeting`.

## 8. Arquitetura 3D

```
scripts/gameplay_v3/
  controle/    ControlModeManager.gd      ← WORLD / COMBAT / SURF / FLY
               TrainerInputController.gd
               PokemonCombatInputController.gd
  entidades/   TrainerController3D.gd
               PokemonInstance3D.gd
  pokemon/     PokemonSpeciesData.gd · MovementProfile.gd
               CombatProfile.gd · CameraProfile.gd
  camera/      CameraManager.gd + 4 perfis
  mundo/       Terreno3D.gd · ZonaDeVoo.gd
  travessia/   SurfProfile.gd · FlightProfile.gd
scenes/gameplay_v3/
  Laboratorio3D.tscn      ← o vertical slice (§10)
```

**A V2 fica onde está.** `scripts/gameplay_v2/` e `scenes/gameplay_v2/`
continuam funcionando enquanto a V3 não substituir de verdade — mesma disciplina
de isolamento que a D-001 estabeleceu, e que funcionou.

## 9. Arquitetura de input

`ControlModeManager` é o único árbitro. Um modo ativo por vez, sempre.

```
WORLD  → TrainerInputController
COMBAT → PokemonCombatInputController
SURF   → SurfInputController
FLY    → FlightInputController
```

Quem não está no modo ativo tem `set_process_input(false)` — não basta ignorar
o evento, porque "ignorar" é onde nasce o bug de dois controladores reagindo.

Bindings no `InputMap`, nunca cravados (§18): `LMB` básico, `Q E R F` skills.

## 10. Arquitetura de câmera

`CameraManager` com 4 perfis e transição suave, **sem destruir e recriar**
(§13). O contrato `contexto_de_camera(nome, prioridade)` da D-003 é reaproveitado
inteiro: o gameplay diz **qual** contexto, a apresentação decide **quanto**.

`CameraProfile` por espécie (§19): altura, FOV, pitch, offset, sensibilidade,
clipping. **Jogabilidade acima de anatomia.**

## 11. Arquitetura de combate

Combate 1v1, no terreno, sem arena. O treinador **permanece no mundo** enquanto
o jogador controla o Pokémon.

Acerto por **geometria, nunca por RNG de precisão** (§22) — e isto já é a regra
da V2, então não muda nada nas fórmulas. `RayCast3D` / `ShapeCast3D` / `Area3D`
conforme a natureza da skill. Hitbox de ataque e hurtbox separadas.

Dano determinístico, sem crítico e sem variância: `DanoV2` **como está**.

## 12. Arquitetura de Pokémon

```
PokemonInstance3D  = nó (corpo, colisor, hurtbox, animação)
PokemonSpeciesData = o dado (já existe: species.json)
MovementProfile    = como se move (GROUND / AQUATIC / FLYING / …)
CombatProfile      = alcance, hitbox, cadência
CameraProfile      = como se vê em 1ª pessoa
```

**Nenhum comportamento dentro de script por espécie** (§14). Composição, não
herança por bicho.

### 🔴 A decisão mais cara do pivô, e ela é sua

O projeto tem **605 sprites de Pokémon e zero modelos**. Dois caminhos:

| | Billboard (sprite no mundo 3D) | Modelo 3D |
|---|---|---|
| Arte existente | **aproveita os 605** | descarta |
| Custo | baixo | 151 modelos + rig + animação |
| `gl_compatibility` | leve | pesa |
| Web | viável | arriscado |
| Visual | estilizado, coeso | "3D de verdade" |

Em 1ª pessoa você quase não vê o próprio Pokémon — o que precisa ler bem de
qualquer ângulo é o **inimigo**, e billboard resolve isso.

**Recomendo billboard para o slice**, com `MovementProfile` desenhado pra aceitar
modelo depois sem reescrita. **Decisão sua, e ela pode esperar até a Fase 5.**

## 13. Arquitetura de terreno

`Terrain3D` com altura, encostas, falésias, praia, água e caverna. **Não**
construir Kanto (§23). A `zones.json` sobrevive: a fauna e os níveis por zona
são dados, e o `tile_rect` vira volume.

## 14. Surf

`SurfProfile`: entrar na água, flutuar, acelerar, desacelerar, girar. **Não é
teletransporte** (§27). O `Mergulho.gd` da V2 (oxigênio, profundidade, roupa) é
regra pura e se adapta.

## 15. Fly

`FlightProfile`: horizontal, vertical, aceleração, pitch, yaw, altitude. Controle
agradável acima de física realista (§28). Zonas por volume configurável:
`FLY_ALLOWED` / `FLY_RESTRICTED` / `NO_FLY` (§29), nunca cravado por mapa.

## 16. TM/HM

HM pode afetar combate, traversal ou os dois — **não presumir que faz sempre as
duas coisas** (§30). TM adiciona ao Move Pool e **não equipa sozinha** (§31).
A regra dos 25 níveis (§33) é preservada e **configurável**: vale para alteração
de kit por HM, não para qualquer troca de skill. `TrocaDeKit.gd` já é assim.

## 17. Move Pool

Muitos golpes conhecidos, **4 ativos** (Q E R F). `KitDeCombate` já resolve
capacidade por nível e estágio evolutivo — fica como está.

## 18. Migração V2 → V3

Ver `docs/MIGRATION_V2_TO_V3.md`. Resumo: 24 KEEP, 14 ADAPT, 8 REBUILD,
9 DEPRECATE, 1 REMOVE LATER.

## 19. Riscos

| # | Risco | Prob. | Mitigação |
|---|---|---|---|
| 1 | **`gl_compatibility` limita o 3D.** Sem SDFGI, sombras limitadas, sem compute. A §24 pede vegetação densa estilo ARK | **Alta** | MultiMesh + LOD + visibility range desde o início (§42). Se não bastar, a decisão é trocar de renderer **e perder o export web**, ou aceitar visual mais simples. **Medir antes de decidir** |
| 2 | **Web export com 3D.** O jogo vive em `poke.workprog.pro` | Alta | Medir FPS no navegador na Fase 2, antes de investir |
| 3 | **605 sprites, 0 modelos** | Certa | Decisão billboard vs modelo, §12 acima |
| 4 | 47 testes 2D vão reprovar aos poucos | Certa | Só apagar teste quando houver substituto 3D testado |
| 5 | Perder o que a V2 provou | Média | A V2 fica isolada e funcionando; a V3 nasce ao lado |
| 6 | **Pivô no meio de um pivô.** A V2 tem 2 dias | Média | Por isso a V2 não é apagada. Se a V3 não convencer, o rollback é real |
| 7 | Codex tem trabalho não integrado (HUD, câmera) | Alta | Ele fica de fora até o slice existir (§46). Avisar antes que ele invista mais |
| 8 | 4.531 linhas de `MapLayouts` viram legado | Certa | É custo assumido do pivô, declarado aqui |

## 20. Dependências

Godot 4.2.2 (já instalado) · Blender 4.2.9 headless (já instalado, útil se a
decisão for modelo) · nenhum plugin novo até aqui. **Terrain3D de terceiros não
foi adotado** — decidir na Fase 4.

## 21. Rollback

- A V3 nasce em `scripts/gameplay_v3/` + `scenes/gameplay_v3/`, e numa **branch
  própria** (`agent/claude-v3`). O `main` continua com a V2 funcionando.
- Rollback total = não fazer merge da branch. Custo zero.
- Rollback parcial = apagar as duas pastas da V3.
- **Nada da V2 é apagado nesta migração.** `MapLayouts`, as 120 cenas e os
  tilesets ficam onde estão, mesmo depreciados.

## 22. Vertical slice

Um laboratório 3D pequeno (§10): campo, floresta pequena, grama alta, colina,
pedras, praia, água rasa e profunda, caverna pequena, área de voo, área de surf.
**Funcional, não bonito.**

Um Pokémon terrestre, um aquático, um voador. Placeholders bastam.

## 23. Critérios de sucesso

A §51 do pedido, literal:

1. Entrar no mundo 3D
2. Andar como treinador
3. Correr
4. Olhar ao redor
5. Subir e atravessar terreno
6. Encontrar um Pokémon
7. Iniciar uma batalha
8. **Transferir o controle para o Pokémon**
9. Controlar o Pokémon em 1ª pessoa
10. Encerrar a batalha
11. Retomar o controle do treinador

Mais, do meu lado:

- **FPS medido em navegador real**, não em headless. Meta: 60 no caso normal.
- A suíte das 18 classes puras continua verde sem uma linha alterada.
- Um save da V2 carrega na V3 sem migração.

---

## Decisão

_Aguardando o Gabriel._ Nenhum código da V3 foi escrito.

**Uma pergunta que eu preciso responder antes da Fase 5**, e que vale saber
agora: **billboard ou modelo 3D para os Pokémon?** É a decisão que define se os
605 sprites vivem ou morrem, e ela pode esperar — mas não muito.
