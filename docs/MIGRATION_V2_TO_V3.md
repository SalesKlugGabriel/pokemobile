# MIGRAÇÃO V2 → V3 (3D) — tabela sistema a sistema

**Auditoria feita em:** 14/09/2026 · commit `bef3146` · Godot 4.2.2
**Método:** leitura do código real, não da documentação. Onde os dois
discordarem, **o código ganha** (regra da casa).

---

## O número que governa esta migração

```
18 de 42 classes de combate NÃO mencionam Vector2, Node2D nem global_position.
```

Não foi sorte. Foi a disciplina de manter regra em classe pura (`RefCounted`) e
deixar o corpo (nó, cena, física) fora dela. **Essas 18 atravessam o pivô sem
uma linha alterada** — elas nunca souberam que o jogo era 2D.

É o ativo mais valioso do projeto e o motivo de esta migração ser viável.

---

## Legenda

| Ação | Significado |
|---|---|
| **KEEP** | Entra na V3 sem alteração |
| **ADAPT** | A regra fica; muda só a interface (Vector2 → Vector3, nó 2D → 3D) |
| **REBUILD** | Refeito do zero na V3; o conceito sobrevive, o código não |
| **DEPRECATE** | Sai da direção principal, mas **fica no repositório** até a V3 andar |
| **REMOVE LATER** | Some quando a V3 substituir de verdade — nunca antes |

---

## 1. Regras de combate — o núcleo que sobrevive inteiro

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `DamageCalculator` | funcional, 0 referências 2D | **KEEP** | A fórmula não tem dimensão |
| `DanoV2` | funcional, determinístico (§13) | **KEEP** | idem |
| `CombatBalance` · `BalanceV2` | funcional | **KEEP** | Régua central de números |
| `StatsDePokemon` | funcional, 25 natures, IVs | **KEEP** | Stat é conta, não geometria |
| `LivroDeEfeitos` | funcional, ligado (§16–24) | **KEEP** | Buff/debuff/status |
| `StatusEffectController` | funcional | **KEEP** | Interpreta o `effect` dos golpes |
| `RegrasDeXP` | funcional, ligado (§32–34) | **KEEP** | |
| `RegrasDeCorpo` | funcional, ligado (§28–31) | **KEEP** | Captura e loot |
| `RegrasDeLendario` · `RegrasDeUltimate` | funcional | **KEEP** | |
| `KitDeCombate` · `TrocaDeKit` | funcional | **KEEP** | Slots, HM, os 25 níveis (§33) |
| `Passivas` | funcional, 151 espécies | **KEEP** | |
| `Sinergia` · `PapelDeGolpe` · `CombateDebug` | funcional | **KEEP** | |
| `Stamina` | funcional (§5) | **KEEP** | 3 linhas, 3 degraus de exaustão |
| `RelatorioDeGolpe` | funcional (14/09) | **ADAPT** | `origem`/`destino`/`direcao` viram `Vector3` |

**14 linhas, e 13 delas são KEEP.** Tudo que a §34 do pedido manda preservar
— espécies, XP, IV, Nature, tipos, STAB, efetividade, imunidade, status, buffs,
Held, regen, drain, captura, Alpha, Shiny, lendário — já está aqui e já é
independente de dimensão.

## 2. Geometria de combate — mesma matemática, outro espaço

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `FormaDeArea` | funcional: círculo, cone, linha, retângulo, anel, global | **ADAPT** | As 6 formas existem em 3D. Círculo vira esfera ou cilindro (decisão de design, §22 do RFC) |
| `Telegrafia` | funcional, geometria resolvida em px | **ADAPT** | Mesmo papel, `Vector3` e unidades de metro |
| `Empurrao` | funcional | **ADAPT** | Direção ganha eixo Y |
| `Contorno` | funcional (desencalhe, §61) | **REBUILD** | Em 3D quem resolve isso é `NavigationAgent3D`, não um desvio de 90° |
| `AreaTargeting` · `TelegraphDeArea` | V1, 2D | **DEPRECATE** | Substituídos por `FormaDeArea` + telegrafia 3D |
| `ProjectileBase` | V1, 2D | **REBUILD** | Projétil 3D com `ShapeCast3D` (§22 do pedido) |
| `HitBox` · `HurtBox` | `Area2D` | **REBUILD** | Viram `Area3D`. O pedido §22 exige os dois separados — já são |

## 3. Movimento e controle — o que mais muda

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `BaseEntity.try_move()` | funcional, **grid + tween** | **DEPRECATE** | Movimento por tile. A V2 já tinha saído disso |
| `Locomocao` | funcional, contínuo 2D | **ADAPT** | Aceleração, atrito e histerese valem igual; o vetor ganha Y |
| `CorpoLivre` | funcional, `CharacterBody2D` | **REBUILD** | Vira `CharacterBody3D` com gravidade e inclinação |
| `TreinadorV2` | funcional | **REBUILD** | Vira `TrainerController3D`, 3ª pessoa (§11) |
| `PokemonAtivoV2` | funcional, ordens (§7) | **REBUILD** | Na V3 o jogador **controla** o Pokémon em 1ª pessoa (§17). A `MesaDeComandos` perde o papel central |
| `MesaDeComandos` | funcional | **DEPRECATE** | Ordens a distância eram a V2. A V3 é controle direto |
| `SelvagemV2` | funcional, 7 personalidades | **ADAPT** | O cérebro (`ComportamentoSelvagem`) fica; o corpo vira 3D |
| `ComportamentoSelvagem` | funcional | **ADAPT** | Raios em tiles viram metros. A lógica não muda |
| `Corpo` (cadáver) | funcional | **ADAPT** | Só a posição muda de dimensão |
| Input (`ControlModeManager`) | **não existe** | **NOVO** | §12: nunca dois controladores no mesmo input |

## 4. Câmera

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `Camera2D` por cena, zoom 0.75 | 120 cenas | **DEPRECATE** | |
| `contexto_de_camera(nome, prioridade)` | funcional (D-003) | **KEEP** | O conceito de contexto com prioridade vale igual em 3D |
| `CameraDeCombate` (Codex) | na branch dele | **REBUILD** | Vira `CameraManager` com 4 perfis (§13) |

## 5. Mundo — a maior perda, e ela é real

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `MapLayouts` | **4.531 linhas**, 36 mapas por char-grid | **DEPRECATE** | Terreno 3D não se pinta com caracteres |
| `zones.json` | 100+ zonas, `tile_rect` + fauna | **ADAPT** | A **fauna por zona e os níveis sobrevivem**; o `tile_rect` vira volume 3D |
| `PerigoDaZona` | funcional (14/09) | **KEEP** | Lê nível médio da zona, não geometria |
| `SpawnManager` | funcional, por terreno/char | **REBUILD** | Spawn em superfície 3D, não em tile |
| `WorldManager.filtrar_velocidade` | funcional | **REMOVE LATER** | Colisão 3D é do motor |
| `WarpZone` | funcional | **ADAPT** | Vira volume `Area3D` |
| `Mergulho` | funcional (§ fundo do mar) | **ADAPT** | Vira o `SurfProfile`/mergulho 3D (§27) |
| Tilesets e atlas | 638 PNG | **DEPRECATE** | |
| 120 cenas `.tscn` 2D | funcionais | **DEPRECATE** | Ficam no repositório |

## 6. Dados e persistência — intocados

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| `species.json` (151) | completo, auditado 14/09 | **KEEP** | |
| `moves.json` (192) | completo, auditado 14/09 | **KEEP** | `MoveDefinition` reaproveitado (§21 do pedido) |
| `SaveManager` | funcional | **KEEP** | 🔴 **Conferido: o save NÃO guarda posição nem Vector2.** Ele guarda `current_map` (texto), time, IV, nature, moves, held, inventário, pokédex, dinheiro. **Um save da V2 carrega na V3 sem migração** |
| `QuestManager` · quests.json (61) | funcional | **ADAPT** | `location_tile` vira ponto 3D |
| `GameData` · `EventBus` · `RNGManager` | funcionais | **KEEP** | |
| `PonteDeFeedback` | funcional, com fontes e linha do tempo | **KEEP** | Vale igual em 3D, e vale mais ainda num protótipo novo |

## 7. Apresentação (Codex)

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| HUD (`Control`) | V1 + `HudV2` na branch do Codex | **ADAPT** | `Control` não tem dimensão. A HUD sobrevive quase inteira |
| `golpe_resolvido` / `status_aplicado` | funcional (14/09) | **KEEP** | O contrato de leitura do combate vale igual |
| `FeedbackDeImpacto` | funcional, 2D | **ADAPT** | |
| 605 sprites de Pokémon | completos | **🔴 decisão em aberto** | Ver RFC §12: billboard ou modelo. É a decisão mais cara do pivô |

## 8. Testes

| Sistema | Estado atual | Ação | Motivo |
|---|---|---|---|
| 114 arquivos, 0 falhas | funcionais | **ADAPT** | **47 tocam em 2D** e vão reprovar conforme a V3 substituir sistemas |
| Testes das 18 classes puras | funcionais | **KEEP** | Continuam válidos sem uma linha alterada |
| `teste_auditoria_de_dados` | funcional, 87 conferências | **KEEP** | |
| `tools/rodar_testes.sh` | funcional | **KEEP** | |

**Regra desta migração:** um teste 2D só é apagado quando a funcionalidade que
ele protege tiver substituto 3D **testado**. Nunca antes — apagar teste pra
ficar verde é como se perde a rede de segurança inteira.

---

## Resumo em números

| Ação | Sistemas |
|---|---:|
| KEEP | 24 |
| ADAPT | 14 |
| REBUILD | 8 |
| DEPRECATE | 9 |
| REMOVE LATER | 1 |

**O que sobrevive é quase tudo que é regra. O que morre é quase tudo que é
geometria 2D.** Era exatamente essa a fronteira que o projeto vinha mantendo.
