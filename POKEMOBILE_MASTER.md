# PokéMobile — Game Design Document v3.1
## Action RPG Top-Down | Godot 4.x | Mundo Aberto Seamless estilo PokeTibia

---

## PROTOCOLO DE OPERAÇÃO — CLAUDE CODE

### Início de cada sessão
1. Ler este arquivo (POKEMOBILE_MASTER.md)
2. Ler POKEMOBILE_WORLD.md
3. Ler progress.json
4. Ler session_notes.md
5. Confirmar sprint ativo e tarefas pendentes

### Regras de modificação
- Nunca alterar schemas JSON sem atualizar este documento
- Toda nova mecânica deve ter entrada em Fórmulas e Constantes
- Sprints só avançam quando todas as tarefas do sprint atual estiverem DONE
- Testes mínimos: rodar cena principal sem erros antes de marcar tarefa DONE

### Arquivos de referência obrigatória
- `data/pokemon/species.json` — dados de todas as espécies
- `data/moves/moves.json` — todas as moves
- `data/moves/learnsets.json` — learnsets por espécie
- `data/pokemon/evolutions.json` — árvores de evolução
- `data/quests/quests.json` — banco de quests
- `data/world/regions.json` — regiões do mundo
- `data/world/zones.json` — zonas e spawn tables

---

## ARQUITETURA TÉCNICA

### Estrutura de Pastas

```
pokemobile/
├── project.godot
├── export_presets.cfg
├── progress.json
├── session_notes.md
├── POKEMOBILE_MASTER.md
├── POKEMOBILE_WORLD.md
│
├── assets/
│   ├── sprites/
│   │   ├── pokemon/          # spritesheet por espécie (idle/walk/attack/faint)
│   │   ├── trainer/          # spritesheet do treinador (8 direções)
│   │   ├── ui/               # ícones, frames, badges
│   │   └── effects/          # partículas, hit effects
│   ├── tilesets/
│   │   ├── kanto_overworld.png
│   │   ├── kanto_interior.png
│   │   └── dungeon_generic.png
│   ├── audio/
│   │   ├── bgm/              # músicas por zona
│   │   ├── sfx/              # efeitos sonoros
│   │   └── voice/            # cry de pokémons (opcional)
│   └── fonts/
│       ├── pokemon_classic.ttf
│       └── ui_sans.ttf
│
├── scenes/
│   ├── world/
│   │   ├── KantoWorld.tscn
│   │   ├── KantoDungeons.tscn
│   │   └── RegionPortal.tscn
│   ├── entities/
│   │   ├── Trainer.tscn
│   │   ├── PokemonFollower.tscn
│   │   ├── WildPokemon.tscn
│   │   ├── NPC.tscn
│   │   └── Boss.tscn
│   ├── combat/
│   │   ├── CombatManager.tscn
│   │   ├── SkillBar.tscn
│   │   └── CombatHUD.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── Inventory.tscn
│   │   ├── PokemonBox.tscn
│   │   ├── QuestLog.tscn
│   │   ├── Map.tscn
│   │   ├── ShopDialog.tscn
│   │   ├── CaptureOverlay.tscn
│   │   └── SkillTree.tscn
│   └── menus/
│       ├── MainMenu.tscn
│       ├── CharacterSelect.tscn
│       └── PauseMenu.tscn
│
├── scripts/
│   ├── world/
│   │   ├── WorldManager.gd
│   │   ├── ChunkLoader.gd
│   │   ├── ZoneManager.gd
│   │   └── DungeonManager.gd
│   ├── entities/
│   │   ├── Trainer.gd
│   │   ├── PokemonFollower.gd
│   │   ├── WildPokemon.gd
│   │   ├── NPC.gd
│   │   └── Boss.gd
│   ├── combat/
│   │   ├── CombatManager.gd
│   │   ├── DamageCalculator.gd
│   │   ├── SkillSystem.gd
│   │   └── StatusEffects.gd
│   ├── systems/
│   │   ├── CaptureSystem.gd
│   │   ├── LootSystem.gd
│   │   ├── QuestSystem.gd
│   │   ├── EXPSystem.gd
│   │   ├── EvolutionSystem.gd
│   │   └── PrestigeSystem.gd
│   ├── ui/
│   │   ├── HUD.gd
│   │   ├── Inventory.gd
│   │   ├── PokemonBox.gd
│   │   ├── QuestLog.gd
│   │   ├── Map.gd
│   │   └── SkillTree.gd
│   ├── data/
│   │   ├── DataLoader.gd
│   │   ├── SaveSystem.gd
│   │   └── PlayerData.gd
│   └── utils/
│       ├── MathUtils.gd
│       ├── AnimUtils.gd
│       └── AudioManager.gd
│
└── data/
    ├── pokemon/
    │   ├── species.json
    │   └── evolutions.json
    ├── moves/
    │   ├── moves.json
    │   └── learnsets.json
    ├── items/
    │   └── items.json
    ├── quests/
    │   └── quests.json
    ├── biomes/
    │   └── biomes.json
    ├── dialogs/
    │   └── dialogs.json
    └── world/
        ├── regions.json
        └── zones.json
```

### Singleton Autoloads (project.godot)
| Nome | Script | Função |
|------|--------|--------|
| GameState | scripts/data/PlayerData.gd | FSM global + save/load |
| DataLoader | scripts/data/DataLoader.gd | Cache de todos os JSONs |
| AudioManager | scripts/utils/AudioManager.gd | BGM/SFX centralizado |
| QuestSystem | scripts/systems/QuestSystem.gd | Estado de quests globais |
| EventBus | scripts/utils/EventBus.gd | Sinais globais desacoplados |

---

## CONTROLES E INTERFACE

### Movimentação
- **WASD / D-pad** — mover treinador (8 direções, interpolação suave)
- **Shift** — correr (1.6× velocidade, consome stamina)
- **Bicicleta** — 2.4× velocidade em rotas com Cycling Road
- **Surf** — atravessa água (requer HM Surf)

### Câmera
- Follow camera com dead zone central 96×72 px
- Zoom out suave ao entrar em dungeons grandes
- Minimap HUD canto superior direito (toggle M)

### Combate
- **Clique / Tap** — mover para posição / atacar alvo corpo a corpo
- **1, 2, 3, 4** — usar skill do treinador
- **Q, E** — skill do Pokémon Follower (2 slots expostos)
- **F** — interagir com NPC / objeto
- **Tab** — abrir inventário rápido
- **Esc / P** — menu de pausa

### Interface HUD
```
┌─────────────────────────────────────────────────────┐
│ [MINI MAP]           [ZONE NAME]    [CLOCK] [MENU]  │
│                                                      │
│                    VIEWPORT                          │
│                                                      │
│ [HP BAR TRAINER]  [HP BAR FOLLOWER]   [EXP BAR]    │
│ [1][2][3][4]         [Q][E]           [ITEMS]       │
└─────────────────────────────────────────────────────┘
```

---

## COMBATE — SISTEMA 2×1 EM TEMPO REAL

### Filosofia
Combate de Action RPG: treinador e Pokémon Follower atacam juntos no overworld. Não há tela de batalha separada — tudo acontece no mapa seamless.

### Estrutura de combate
- **Treinador** — agente primário, controlado pelo jogador, tem 4 skills ativas
- **Pokémon Follower** — bodyguard autônomo com IA, segue o treinador e ataca inimigos próximos
- **Alvo compartilhado** — ambos focam o mesmo alvo (clique do jogador define prioridade)
- **Aggro** — inimigos agressivos atacam quem está mais próximo (treinador ou follower)

### Sequência de combate
1. Jogador entra em range de ataque (ou clica em inimigo)
2. Treinador ataca com skill equipada (ou auto-attack básico)
3. Follower ataca automaticamente com sua move mais forte disponível (cooldown próprio)
4. Inimigo responde atacando o alvo com maior ameaça
5. Inimigo morre → loot drop → EXP dividida entre treinador e follower

### Stats de combate
| Stat | Treinador | Pokémon |
|------|-----------|---------|
| HP | 50 + 5×nivel | formula stat_atual |
| ATK | 10 + skill_tree | stat_atual |
| DEF | 5 + skill_tree | stat_atual |
| SPD | 4.0 tiles/s base | 3.5–5.0 tiles/s |
| Range ataque | 1.5–6.0 tiles (por skill) | 1.0–4.0 tiles |

### Status effects
| Status | Efeito | Duração |
|--------|--------|---------|
| Paralise | SPD ÷ 2, 25% chance skip | 8s |
| Veneno | 6% HP/s | até cura |
| Queimadura | 4% HP/s + ATK −25% | 10s |
| Congelado | imóvel | 3–6s aleatório |
| Sono | imóvel | 4s |
| Confusão | 33% chance auto-dano | 6s |

### Pokémon Follower IA
- Estado IDLE: segue treinador a ≤2 tiles
- Estado COMBAT: ataca inimigo em range (prioridade: alvo do treinador)
- Estado GUARD: interpõe-se entre treinador e inimigo agressivo
- Estado RETURN: volta ao treinador se distância > 8 tiles

---

## SISTEMA DE POKÉMONS

### Stat Base → Stat Atual
Ver seção Fórmulas e Constantes para cálculo completo.

### Atributos de espécie (species.json)
```
id, name, types[2], base_stats{hp,atk,def,spatk,spdef,spd},
catch_rate, base_exp, growth_rate, abilities[2], hidden_ability,
learnset (via learnsets.json), evolution (via evolutions.json),
height_m, weight_kg, flavor_text, category
```

### Growth rates
| Taxa | Pokémons | Fórmula EXP para nível N |
|------|---------|--------------------------|
| Fast | Gastly, Dratini | 0.8 × N³ |
| Medium-Fast | Bulbasaur, Pikachu | N³ |
| Medium-Slow | Squirtle, Charmander | 1.2 × N³ − 15N² |
| Slow | Mewtwo, Dragonite | 1.25 × N³ |
| Erratic | Caterpie | variável por faixa |
| Fluctuating | Shedinja | variável por faixa |

### Progressão de nível
- Nível máximo base: **100**
- Após prestige: capacidade de ir até **150** (Prestige 1), **200** (Prestige 2)
- EXP ao matar inimigo: formula EXP (ver Fórmulas)
- EXP ao capturar: 1.5× EXP de matar

### Sistema de Prestige
- Disponível ao atingir nível máximo do tier atual
- Reset de nível para 1, mantendo 20% dos stats base acumulados
- Ganho: título visual (cor do nome), bônus de drop rate +5%, acesso a moves Prestige exclusivas
- Prestige máximo: 3 (P3 = "Lendário" — aura visual especial)

### Evolução
- **Por nível**: automática ao atingir nível (pode cancelar com Everstone)
- **Por pedra**: usar item no inventário sobre o Pokémon
- **Por troca**: simulada via NPC "Câmara de Troca" nas Pokémon Centers
- **Por amizade**: contador de amizade 0–255, evolui ao atingir 220+
- **Por item equipado**: hold item + condição (ex: Metal Coat + nivel 30)

### Moveset
- Máximo 4 moves ativas por Pokémon
- Aprender nova move: substituir ou descartar
- TMs: ensináveis uma vez (TM padrão) ou infinitas vezes (TM Gold — drop raro)
- Move Tutor: NPCs específicos em cidades

---

## SISTEMA DO TREINADOR — SKILL TREE

### 5 Atributos base (pontos distribuídos ao subir de nível)
| Atributo | Efeito primário | Efeito secundário |
|----------|-----------------|-------------------|
| **Força** | +ATK físico | desbloqueia skills corpo a corpo |
| **Agilidade** | +SPD movimento | +dodge chance passivo |
| **Intelecto** | +SPATKbuff ao follower | desbloqueia debuffs |
| **Vitalidade** | +HP máx | +regeneração HP fora combate |
| **Sorte** | +drop rate | +crit chance |

### Progressão da Skill Tree
- Cada atributo tem 3 níveis de especialização (ramos)
- Nível 1–10: 1 ponto por nível → 10 pontos totais fase inicial
- Nível 11–50: 1 ponto a cada 2 níveis
- Nível 51–100: 1 ponto a cada 5 níveis
- Total de pontos: 10 + 20 + 10 = **40 pontos** ao nível 100

### Exemplos de skills desbloqueáveis
| Skill | Atributo | Efeito |
|-------|----------|--------|
| Tackle Boost | Força 1 | auto-attack +30% dano |
| Quick Step | Agilidade 1 | dash curto sem cooldown |
| Pokémon Sync | Intelecto 2 | follower copia status buff do treinador |
| Iron Skin | Vitalidade 2 | absorve 1 hit crítico por combate |
| Lucky Find | Sorte 1 | +10% item drop rate |
| Master Ball Affinity | Sorte 3 | +15% catch rate geral |

---

## SISTEMA DE SKILLS E TMs

### Skills do Treinador (slots 1–4)
- Equipáveis no menu de inventário
- Cooldown individual por skill (2–15s)
- Tipos: Ofensiva, Defensiva, Utilitária, de Suporte ao Follower

### TMs (Technical Machines)
| Tier | Cor | Fonte | Reutilizável |
|------|-----|-------|--------------|
| TM normal | Cinza | Lojas, drop comum | Não (one-use) |
| TM Gold | Dourado | Boss drop, quest reward | Sim (infinitas) |
| HM | Roxo | Badges, eventos | Sim, permanente |

### HMs disponíveis
| HM | Move | Requisito | Efeito mundo |
|----|------|-----------|--------------|
| HM01 | Cut | Badge 1 | Corta arbustos bloqueadores |
| HM02 | Fly | Badge 6 | Fast travel para cidades visitadas |
| HM03 | Surf | Badge 5 | Atravessa água |
| HM04 | Strength | Badge 4 | Move rochas pesadas |
| HM05 | Flash | Badge 3 | Ilumina dungeons escuras |
| HM06 | Rock Smash | Badge 2 | Quebra rochas rachadas |
| HM07 | Waterfall | Badge 7 | Sobe cascatas |
| HM08 | Dive | Badge 8 | Mergulha em pontos marcados |

---

## SISTEMA DE LOOT E ECONOMIA

### Tiers de drop
| Tier | Cor | Chance base | Exemplos |
|------|-----|-------------|----------|
| Comum | Branco | 60% | Potion, Poké Ball, Antidote |
| Incomum | Verde | 25% | Super Potion, Great Ball |
| Raro | Azul | 12% | Hyper Potion, Ultra Ball, TM |
| Épico | Roxo | 3% | Full Restore, TM Gold, raros |
| Lendário | Laranja | 0.1% | Master Ball, Rare Candy ×5 |

### Modificadores de drop rate
- Sorte do treinador: +0–15%
- Prestige P1: +5%, P2: +10%, P3: +20%
- Item Amulet Coin equipado: +15% ouro
- Pokémon follower com Compound Eyes: +10%
- Primeiro kill de espécie (First Blood): +25% one-time

### Economia de lojas
| Loja | Localização | Itens |
|------|-------------|-------|
| PokéMart básico | Viridian | Potion, Poké Ball, Antidote |
| PokéMart médio | Cerulean, Vermilion | Super Potion, Revive, Great Ball |
| PokéMart avançado | Celadon, Saffron | Hyper Potion, Ultra Ball, Max Repel |
| Dept Store | Celadon | TMs, Hold Items, Evolution Stones |
| Market Secreto | Rocket Hideout (pós-quest) | Itens raros, TM Black |

### Berries (encontradas no overworld)
- Oran Berry: recupera 10 HP
- Sitrus Berry: recupera 25% HP
- Lum Berry: cura qualquer status
- Salac Berry: +SPD temporário em combate
- Liechi Berry: +ATK temporário em combate

---

## SISTEMA DE BOSSES

### Alpha Pokémons (overworld)
- Versão 3× tamanho normal com aura vermelha
- HP ×5, ATK ×3, DEF ×2
- Spawn em horários específicos (sistema de ciclo dia/noite)
- Drop garantido: Raro ou melhor
- 1 Alpha por zona, respawn 24h real

### Ginásios (8 líderes)
| Ginásio | Cidade | Líder | Tipo | Badge | Recompensa |
|---------|--------|-------|------|-------|------------|
| 1 | Pewter | Brock | Rock | Boulder Badge | HM06 |
| 2 | Cerulean | Misty | Water | Cascade Badge | HM06 alt |
| 3 | Vermilion | Lt. Surge | Electric | Thunder Badge | HM05 |
| 4 | Celadon | Erika | Grass | Rainbow Badge | HM04 |
| 5 | Fuchsia | Koga | Poison | Soul Badge | HM03 |
| 6 | Saffron | Sabrina | Psychic | Marsh Badge | HM02 |
| 7 | Cinnabar | Blaine | Fire | Volcano Badge | HM07 |
| 8 | Viridian | Giovanni | Ground | Earth Badge | HM08 |

### Mecânica de Ginásio
- Ginásio é dungeon linear com trainers bloqueando passagem
- Boss fight com líder: Pokémon da Equipe do líder (3–6 Pokémons)
- Sistema de 2×1: líder tem follower próprio
- Derrota do líder → Badge + TM exclusiva + diálogo de conclusão
- Rematch disponível após 7 dias (líder mais forte)

### Pokémons Lendários
| Lendário | Localização | Nível | Respawn |
|----------|-------------|-------|---------|
| Articuno | Seafoam Islands B4 | 50 | 72h real |
| Zapdos | Power Plant final | 50 | 72h real |
| Moltres | Victory Road sala final | 50 | 72h real |
| Mewtwo | Cerulean Cave B2 | 70 | 168h real (semanal) |
| Mew | Event especial | 30 | Único (event) |

### Raid Battles (futuro Sprint 4B)
- Evento periódico: lendário ataca cidade
- 4 jogadores cooperam (quando multiplayer ativo)
- Drop exclusivo: fita de cor especial para Pokémon capturado

---

## SISTEMA DE CAPTURA

### Fórmula de captura
```
catch_value = ((3 × HP_max − 2 × HP_atual) × catch_rate × ball_modifier) / (3 × HP_max)
catch_prob = catch_value / 255
```

### Modificadores de pokébola
| Pokébola | Modificador | Condição especial |
|----------|-------------|-------------------|
| Poké Ball | 1.0× | — |
| Great Ball | 1.5× | — |
| Ultra Ball | 2.0× | — |
| Master Ball | 255× | captura garantida |
| Net Ball | 3.0× | contra Water/Bug |
| Dusk Ball | 3.5× | à noite ou dungeon |
| Quick Ball | 5.0× | primeiro turno |
| Timer Ball | até 4× | aumenta com tempo |
| Heal Ball | 1.0× | Pokémon capturado com HP cheio |

### Animação de captura (overworld)
1. Jogador seleciona pokébola no inventário e clica em Pokémon selvagem
2. Pokébola voa em arco (trajetória parabólica) do treinador ao alvo
3. Pokébola abre ao contato → flash de luz → Pokémon encolhe e entra
4. Pokébola cai e treme 1–3 vezes (animação por probabilidade)
5. Se sucesso: estrelinhas + som de captura + mensagem
6. Se falha: Pokémon sai e fica com HP reduzido, possivelmente foge

### Condições que aumentam captura
- HP abaixo de 25%: +25% efetividade
- Status paralise/sono: +30%
- Status veneno/queimadura: +10%
- Amigo de fishing (Pokémon com ability): +5%
- Prestige P3 Sorte 3: +15%

---

## NPCs E QUESTS

### Tipos de NPC
| Tipo | Interação | Ícone overhead |
|------|-----------|----------------|
| Quest Giver | diálogo + quest | ! amarelo |
| Quest Active | atualização | ? laranja |
| Quest Complete | entrega | ! verde |
| Lojista | shop dialog | moeda |
| Move Tutor | ensina move | livro |
| Pokémon Center | cura grátis | cruz |
| PC Box | gerenciar caixa | computador |
| Informante | lore/dica | balão |
| Treinador | combate trigger | espadas |

### Sistema de Quests
- Quest log: máximo 20 ativas simultâneas
- Categorias: MAIN, GYM, ROCKET, UTIL, COLETOR
- Status: LOCKED → AVAILABLE → ACTIVE → COMPLETED → CLAIMED
- Rewards: EXP, itens, dinheiro, desbloqueio de área, título

### Total de quests: 54
- MAIN: 12 quests
- GYM: 8 quests
- ROCKET: 6 quests
- UTIL: 18 quests
- COLETOR: 10 quests

---

## LORE E NARRATIVA

### Premissa
O mundo Pokémon agora é um MMORPG-like persistente. Kanto foi "digitalizado" — treinadores de todo o mundo podem explorar simultaneamente. A Team Rocket aproveitou o caos da digitalização para se reorganizar e agora controla rotas inteiras com bloqueios e comércio ilegal de Pokémons raros.

### Arco principal
1. Jogador acorda em Pallet Town sem memórias (convenção de gênero)
2. Prof. Oak entrega starter e explica o mundo digitalizado
3. Progressão pelos 8 ginásios enquanto descobre fragmentos de memória
4. Team Rocket está por trás da digitalização — querem usar Mewtwo para controlar todos os Pokémons
5. Confronto final em Cerulean Cave: Mewtwo é salvo, Giovanni foge
6. Elite Four + Campeão: conclusão do arco Kanto
7. Portal para Johto se abre (continuação)

### Tom e estilo
- Nostálgico mas moderno: referências à geração 1, mas mecânicas contemporâneas
- Sem morte permanente: treinador "desconecta" e reconecta no último Pokémon Center visitado
- Humor leve: NPCs têm diálogos espirituosos, referências meta
- Lore dark opcional: Team Rocket tem crueldade com Pokémons (logs colecionáveis)

---

## ROTEIRO DE QUESTS

### MAIN (Campanha Principal)

**MAIN-01 — "Primeiro Passo"**
- Giver: Prof. Oak (Pallet Town Lab)
- Objetivo: Escolher starter, sair de Pallet Town
- Reward: Starter Pokémon, 5× Poké Ball, Pokédex
- Desbloqueio: MAIN-02, UTIL-01, UTIL-02

**MAIN-02 — "Viridian Road"**
- Giver: Guarda de Viridian (bloqueio Route 2)
- Objetivo: Entregar pacote de Oak para Loja de Viridian
- Reward: Running Shoes (item), 200 coins
- Desbloqueio: Route 2 desbloqueada, MAIN-03

**MAIN-03 — "A Floresta Assustadora"**
- Giver: Pesquisador na entrada de Viridian Forest
- Objetivo: Atravessar Viridian Forest e chegar a Pewter City
- Sub-objetivo: Capturar 3 Pokémons diferentes na floresta
- Reward: 500 EXP, Antidote ×3, MAIN-04

**MAIN-04 — "Pedra e Determinação"**
- Giver: Rival (entrada de Pewter Gym)
- Objetivo: Derrotar Brock no Pewter Gym
- Reward: Boulder Badge, TM39 (Rock Tomb), HM06 ensinado, MAIN-05

**MAIN-05 — "Ponte para o Futuro"**
- Giver: Youngster na Nugget Bridge
- Objetivo: Completar Nugget Bridge (5 trainers + recompensa do Rocket infiltrado)
- Reward: Nugget (item valioso), 1000 coins, MAIN-06

**MAIN-06 — "Águas de Cerulean"**
- Giver: Misty (fora do ginásio)
- Objetivo: Derrotar Misty, depois investigar roubo na casa do Bill
- Reward: Cascade Badge, TM45 (Attract), Bill resgatado → SS Anne ticket

**MAIN-07 — "O Navio dos Sonhos"**
- Giver: Bill (Cerulean)
- Objetivo: Embarcar na SS Anne em Vermilion, encontrar o Capitão
- Sub-objetivo: Derrotar Rival a bordo
- Reward: HM01 (Cut), MAIN-08

**MAIN-08 — "Raio e Trovão"**
- Giver: Guarda elétrico em Vermilion
- Objetivo: Derrotar Lt. Surge no Vermilion Gym
- Pré-requisito: HM01 para acessar ginásio
- Reward: Thunder Badge, TM24 (Thunderbolt)

**MAIN-09 — "Torre dos Espíritos"**
- Giver: Sr. Fuji (resgatado na Pokémon Tower)
- Objetivo: Limpar Pokémon Tower de Rockets, chegar ao 7º andar, resgatar Sr. Fuji
- Reward: Poké Flute, acesso a Snorlax (Routes 12/16)

**MAIN-10 — "Coração da Corporação"**
- Giver: Detetive Keith (Celadon)
- Objetivo: Infiltrar Rocket Hideout em Celadon, derrotar Giovanni
- Reward: Silph Scope, ROCKET-01 desbloqueado

**MAIN-11 — "A Batalha de Saffron"**
- Giver: Funcionário da Silph Co. (fora do prédio tomado)
- Objetivo: Libertar Silph Co. dos Rockets (11 andares), derrotar Giovanni final
- Reward: Master Ball ×1, Marsh Badge, acesso Elite Four desbloqueado futuro

**MAIN-12 — "Campeão de Kanto"**
- Giver: Auto-trigger ao chegar no Indigo Plateau
- Objetivo: Derrotar os 4 membros da Elite Four + Campeão Blue
- Reward: Título "Campeão de Kanto", créditos, portal para Johto ativado, P1 Prestige disponível

---

### GYM (Desafios de Ginásio)

**GYM-01 a GYM-08** — correspondem a cada um dos 8 ginásios acima
- Cada gym quest tem: objetivo de derrotar o líder + sub-objetivo de completar o puzzle interno
- Rewards: Badge, TM exclusiva, HM correspondente, título de ginásio

---

### ROCKET (Arco Team Rocket)

**ROCKET-01 — "Dentro da Besta"**
- Após MAIN-10: investigar operações secundárias do Rocket
- Objetivo: Capturar Grunt com produtos ilegais em Route 12
- Reward: TM rara, informação sobre Silph Co.

**ROCKET-02 — "Laboratório Proibido"**
- Objetivo: Investigar laboratório secreto em Cinnabar Island
- Revela: experimentos com DNA de Mew → origem de Mewtwo
- Reward: Fossil item, lore journal

**ROCKET-03 — "Infiltrado"**
- Objetivo: Disfarçar-se de Grunt (uniforme obtido) e entrar em reunião secreta
- Missão stealth: não pode entrar em combate
- Reward: Localização do cofre de Giovanni

**ROCKET-04 — "O Cofre de Giovanni"**
- Objetivo: Roubar dados do cofre na Rocket Hideout
- Reward: Chave para sala secreta de Mewtwo

**ROCKET-05 — "Mewtwo Acorrentado"**
- Objetivo: Acessar câmara de Mewtwo em Cerulean Cave
- Boss: Mewtwo versão controlada pelo Rocket (não capturável aqui)
- Reward: MewTwo weakened → capturável na Cerulean Cave livremente depois

**ROCKET-06 — "Fim da Gangue"**
- Objetivo: Transmitir evidências para Rádio Lavender, expor o Rocket
- Reward: Título "Detetive Pokémon", skin exclusiva de uniforme anti-Rocket

---

### UTIL (Utilitárias / Side Quests)

**UTIL-01 — "Ajuda ao Vizinho"** — Pallet Town, entregar encomenda a Viridian
**UTIL-02 — "A Pokédex Incompleta"** — Oak, capturar 10 espécies diferentes
**UTIL-03 — "Bugsy's Request"** — Viridian Forest, capturar Caterpie raro
**UTIL-04 — "Pedras da Montanha"** — Mt. Moon, encontrar Moon Stone para pesquisador
**UTIL-05 — "Fossile Recovery"** — Mt. Moon, escolher Dome ou Helix Fossil
**UTIL-06 — "Garota Perdida"** — Cerulean, resgatar Pokémon da garota na Cave
**UTIL-07 — "Pescador Solitário"** — Vermilion, conseguir Old Rod
**UTIL-08 — "Snorlax Dorme"** — Route 12, usar Poké Flute, reward: Good Rod
**UTIL-09 — "O Safari Urgente"** — Fuchsia, completar Safari Zone em tempo
**UTIL-10 — "Pokémon Órfão"** — Lavender Town, adotar Cubone da torre
**UTIL-11 — "Rádio Pirata"** — Celadon, destruir transmissor Rocket
**UTIL-12 — "Contrabando"** — Route 13, interceptar carregamento Rocket
**UTIL-13 — "Clefairy da Sorte"** — Mt. Moon, capturar Clefairy Alpha
**UTIL-14 — "Voltorb Minefield"** — Power Plant, desativar Voltorbs-bomba
**UTIL-15 — "Super Rod Request"** — Fuchsia, Super Rod ao completar Pokédex aquática
**UTIL-16 — "Ladrão de Pokémons"** — Celadon Dept Store, prender ladrão
**UTIL-17 — "Treino de Elite"** — Victory Road, completar desafio de trainers especiais
**UTIL-18 — "Berço dos Lendários"** — Coletar 3 amuletos para acessar sala de Articuno/Zapdos/Moltres antecipado

---

### COLETOR (Coleção e Achievements)

**COLETOR-01 — "Pokédex Inicial"** — Capturar 25 espécies
**COLETOR-02 — "Colecionador"** — Capturar 50 espécies
**COLETOR-03 — "Quase Lá"** — Capturar 100 espécies
**COLETOR-04 — "Kanto Completo"** — Capturar todas as 151 espécies
**COLETOR-05 — "Shiny Hunter"** — Capturar primeiro Pokémon shiny (1/4096 base)
**COLETOR-06 — "Alpha Slayer"** — Derrotar 10 Alpha Pokémons diferentes
**COLETOR-07 — "TM Collector"** — Obter 30 TMs diferentes
**COLETOR-08 — "Rich Trainer"** — Acumular 99.999 coins
**COLETOR-09 — "Speedrunner"** — Completar MAIN-12 em menos de 10 horas de jogo
**COLETOR-10 — "Prestígio Supremo"** — Atingir Prestige 3 com qualquer Pokémon

---

## BANCO DE DADOS JSON — SCHEMAS

### species.json
```json
{
  "species": [
    {
      "id": 1,
      "name": "Bulbasaur",
      "name_pt": "Bulbasauro",
      "types": ["grass", "poison"],
      "base_stats": {
        "hp": 45, "atk": 49, "def": 45,
        "spatk": 65, "spdef": 65, "spd": 45
      },
      "catch_rate": 45,
      "base_exp": 64,
      "growth_rate": "medium_slow",
      "abilities": ["overgrow"],
      "hidden_ability": "chlorophyll",
      "height_m": 0.7,
      "weight_kg": 6.9,
      "category": "Seed",
      "flavor_text": "Carrega uma semente nas costas desde o nascimento."
    }
  ]
}
```

### moves.json
```json
{
  "moves": [
    {
      "id": 1,
      "name": "Pound",
      "name_pt": "Soco",
      "type": "normal",
      "category": "physical",
      "power": 40,
      "accuracy": 100,
      "pp": 35,
      "priority": 0,
      "effect": null,
      "effect_chance": 0,
      "cooldown_s": 1.5,
      "range_tiles": 1.0,
      "aoe": false,
      "description": "Ataque físico básico."
    }
  ]
}
```

### learnsets.json
```json
{
  "learnsets": {
    "1": {
      "by_level": [
        {"level": 1, "move_id": 33},
        {"level": 1, "move_id": 45},
        {"level": 3, "move_id": 73},
        {"level": 7, "move_id": 22}
      ],
      "by_tm": [9, 17, 19, 22, 87, 132, 148, 156, 164, 166, 169]
    }
  }
}
```

### evolutions.json
```json
{
  "evolutions": [
    {
      "from_id": 1,
      "to_id": 2,
      "method": "level",
      "condition": {"level": 16},
      "item_id": null,
      "can_cancel": true
    },
    {
      "from_id": 133,
      "to_id": 134,
      "method": "item",
      "condition": null,
      "item_id": "water_stone",
      "can_cancel": false
    },
    {
      "from_id": 67,
      "to_id": 68,
      "method": "trade",
      "condition": null,
      "item_id": null,
      "can_cancel": false
    }
  ]
}
```

### quests.json
```json
{
  "quests": [
    {
      "id": "MAIN-01",
      "category": "MAIN",
      "title": "Primeiro Passo",
      "description": "Escolha seu Pokémon inicial com o Prof. Oak e comece sua jornada.",
      "giver_npc": "prof_oak",
      "giver_location": "pallet_town_lab",
      "status": "AVAILABLE",
      "prerequisites": [],
      "objectives": [
        {"id": "obj1", "type": "talk", "target": "prof_oak", "count": 1},
        {"id": "obj2", "type": "choose_starter", "target": null, "count": 1},
        {"id": "obj3", "type": "reach_zone", "target": "route_1", "count": 1}
      ],
      "rewards": {
        "exp": 100,
        "money": 0,
        "items": [
          {"item_id": "poke_ball", "count": 5},
          {"item_id": "pokedex", "count": 1}
        ],
        "unlock_quests": ["MAIN-02", "UTIL-01", "UTIL-02"]
      }
    }
  ]
}
```

---

## FÓRMULAS E CONSTANTES

### stat_atual (Pokémon)
```
# Para HP:
hp_max = floor(((2 × base_hp + iv_hp + floor(ev_hp/4)) × level) / 100) + level + 10

# Para outros stats:
stat = floor((floor(((2 × base + iv + floor(ev/4)) × level) / 100) + 5) × nature_modifier)
```

Onde:
- `base`: stat base da espécie
- `iv`: 0–31 (Individual Value, gerado ao spawnar)
- `ev`: 0–255 (Effort Value, ganho ao derrotar)
- `level`: nível atual
- `nature_modifier`: 0.9, 1.0 ou 1.1 (dependendo da nature)

### Dano (combat)
```
damage = floor(
  (((2 × level / 5 + 2) × power × (atk / def)) / 50 + 2)
  × stab × type_effectiveness × crit × random
)
```

Onde:
- `stab`: 1.5 se o tipo da move == tipo do atacante, senão 1.0
- `type_effectiveness`: 0, 0.25, 0.5, 1.0, 2.0 ou 4.0
- `crit`: 1.5 se crítico (chance base 6.25%), senão 1.0
- `random`: float entre 0.85 e 1.0

### Drop (loot)
```
roll = random(0.0, 1.0) + luck_bonus
if roll > 0.997: tier = "legendary"
elif roll > 0.970: tier = "epic"
elif roll > 0.850: tier = "rare"
elif roll > 0.600: tier = "uncommon"
else: tier = "common"
```

### Captura
```
catch_value = ((3×HPmax − 2×HPcur) × catch_rate × ball_mod) / (3×HPmax)
catch_prob = clamp(catch_value / 255.0, 0.0, 1.0)
success = random() < catch_prob
shake_count = floor(catch_prob × 3)  # 0, 1, 2, ou 3 abanadas
```

### EXP ao vencer
```
exp_gained = floor((base_exp × level_enemy × 1.5) / 7)
# × 1.5 se capturado ao invés de derrotado
# × 1.2 se Wild (não-treinador)
# distribuído igualmente entre treinador e follower
```

### Velocidade de movimento
```
# Tiles por segundo
walk_speed = 4.0
run_speed = 4.0 × 1.6 = 6.4
bike_speed = 4.0 × 2.4 = 9.6
surf_speed = 4.0 × 1.2 = 4.8

# Agilidade do treinador adiciona:
spd_bonus = agility_points × 0.1  # tiles/s adicionais
```

### Amizade (evolução por friendship)
```
# Amizade aumenta por:
friendship += 1  # ao subir de nível
friendship += 2  # ao usar berry específica
friendship += 5  # ao ganhar ginásio com o Pokémon ativo
friendship -= 1  # ao desmaiar

# Threshold para evolução: 220
```

---

## ESTADOS DO JOGO — FSM GLOBAL

```
BOOT
  └─► MAIN_MENU
        ├─► NEW_GAME ─► CHARACTER_SELECT ─► CUTSCENE_INTRO ─► OVERWORLD
        └─► LOAD_GAME ─► OVERWORLD

OVERWORLD
  ├─► DIALOG      (NPC talk, retorna a OVERWORLD)
  ├─► SHOP        (retorna a OVERWORLD)
  ├─► COMBAT      (wild ou trainer)
  │     ├─► COMBAT_WIN  ─► LOOT_SCREEN ─► OVERWORLD
  │     └─► COMBAT_LOSE ─► RESPAWN ─► OVERWORLD
  ├─► CAPTURE     (overlaid sobre OVERWORLD)
  ├─► DUNGEON     (sub-estado de OVERWORLD, mesma FSM)
  ├─► EVOLUTION   (modal, retorna a OVERWORLD)
  ├─► MENU_PAUSE
  │     ├─► INVENTORY
  │     ├─► POKEMON_BOX
  │     ├─► QUEST_LOG
  │     ├─► SKILL_TREE
  │     └─► MAP
  └─► REGION_PORTAL ─► LOADING ─► OVERWORLD (nova região)
```

---

## SPRINTS DE DESENVOLVIMENTO

### Sprint 0 — Fundação (DONE)
- [x] Estrutura de pastas criada
- [x] project.godot configurado
- [x] DataLoader.gd carregando JSONs
- [x] species.json com 151 espécies (base)
- [x] moves.json com 165 moves (base)

### Sprint 1 — Mundo Base (DONE parcial)
- [x] KantoWorld.tscn com TileMapLayers
- [x] Treinador.gd com movimento WASD
- [x] Câmera follow
- [x] Colisão básica com tileset
- [ ] ChunkLoader.gd funcional
- [ ] ZoneManager.gd com spawn tables

### Sprint 2 — Combate Core
- [ ] CombatManager.gd
- [ ] DamageCalculator.gd com fórmulas corretas
- [ ] WildPokemon.gd com IA básica
- [ ] PokemonFollower.gd com estados IDLE/COMBAT/GUARD
- [ ] HUD com barras HP e cooldowns
- [ ] StatusEffects.gd

### Sprint 3 — Sistemas Principais
- [ ] CaptureSystem.gd + animação arco
- [ ] LootSystem.gd com tiers
- [ ] QuestSystem.gd
- [ ] EXPSystem.gd + level up
- [ ] EvolutionSystem.gd
- [ ] SaveSystem.gd

### Sprint 4 — Conteúdo Kanto
- [ ] 8 Ginásios implementados
- [ ] 54 quests no quests.json
- [ ] Todos os NPCs com diálogos
- [ ] Alpha Pokémons spawning
- [ ] Lendários com respawn timer

### Sprint 4B — Polimento e Dungeons
- [ ] Dungeons completas (Mt. Moon, Cerulean Cave, etc.)
- [ ] Sistema de HMs funcional no overworld
- [ ] Música e SFX integrados
- [ ] Tutorial interativo
- [ ] Balanceamento de EXP e economia

### Sprint 5 — Multiplayer (futuro)
- [ ] Servidor dedicado (Nakama ou custom)
- [ ] Sync de posição de jogadores
- [ ] Trading system
- [ ] Guilds básico

### Sprint 5B — Mundo Completo e Regiões
Ver POKEMOBILE_WORLD.md para detalhes completos do Sprint 5B.
