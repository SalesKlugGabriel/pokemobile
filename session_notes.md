# Session Notes — PokéMobile

## Sessão 2026-04-18

### O que foi feito (Sprint 8B — parcial)

- **8B.4 DONE** — dialogs.json já continha oak_intro, pallet_resident_1/2, route_1_trainer_1, viridian_guard — marcado como concluído.
- **8B.5 DONE** — DungeonPortal + KantoDungeons wired:
  - `DungeonPortal.gd` corrigido: quando `target_dungeon_id` vazio → chama `exit_dungeon()` em vez de `push_warning`.
  - `PortalManager.gd` refatorado: usa `WorldManager.warp_to()` (elimina `SaveManager.set_pending_spawn_pos` que não existia). Referência `KantoWorld.tscn` → `WorldMap.tscn`.
  - `DungeonMap.gd` criado: script de KantoDungeons que registra player e aplica `apply_pending_spawn()`.
  - `KantoDungeons.tscn` populado: script=DungeonMap, PortalManager filho, nó Exits com MtMoon_Exit e PokemonTower_Exit (return_tile placeholder tile(50,5) — atualizar quando WorldMap expandir para Route3/Lavender).

- **8B.3 BLOQUEADO** — criação de .ogg placeholder requer ffmpeg (indisponível). AudioManager usa `push_warning` para áudio ausente — não causa crash.
- **8B.1, 8B.2** — dependem do Godot Editor rodando localmente.

### Pendências restantes (8B)
- 8B.1: pintar WorldMap.tscn no Godot Editor
- 8B.2: teste ao vivo no Godot
- 8B.3: gerar .ogg com ffmpeg localmente (`ffmpeg -f lavfi -i "sine=frequency=440:duration=10" -c:a libvorbis bgm/pallet_town.ogg`)

## Sessão 2026-04-08

### O que foi feito (Sprint 0 — COMPLETO)
- **0.1** Estrutura de pastas completa criada (`assets/`, `data/`, `scenes/`, `scripts/`)
- **0.2** `project.godot` criado: 1280×720, pixel snap (filter=0), input map completo (WASD, skills 1-4/Q/E/R/F, space, enter/Z, tab, B, M, esc/P, F11)
- **0.3** `GameData.gd` — carrega todos os JSONs de `/data/` no `_ready()`, expõe funções de consulta tipadas
- **0.4** `SaveManager.gd` — esqueleto completo com estrutura de save_data, helpers de acesso rápido, load/save/delete
- **0.5** `EventBus.gd` — todos os sinais globais definidos (trainer, follower, wild, capture, combat, items, progression, quests, world, UI)
- **0.6** `RNGManager.gd` — RNG centralizado com seed configurável, helpers: randf, randf_range, randi_range, chance, pick, pick_unique, shuffle

### Decisões arquiteturais
- GameData usa `str(species_id)` como chave (JSON não suporta chaves int)
- SaveManager esqueleto — implementação completa no Sprint 5
- Input Map hardcoded no project.godot (mais fácil de editar no Godot Editor)

---

## Sessão 2026-04-09

### O que foi feito (Sprint 1 — COMPLETO)
- **1.1–1.6** JSONs de dados: species.json (151), moves.json, learnsets.json, evolutions.json, items.json (47), spawns.json, quests.json

### O que foi feito (Sprint 2 — COMPLETO)
- **2.1** `BaseEntity.gd` — CharacterBody2D tile-a-tile (TILE_SIZE=16, tween), FSM hooks, interação via physics query, animação direcional
- **2.2** `PokemonEntity.gd` — FSM: IDLE→WANDER→FLEE→CHASE→BATTLE. Detecção Manhattan, wander por raio de spawn, flee em passos, chase até adjacente → `wild_encounter_started`
- **2.3** `TrainerEntity.gd` — Input WASD+Shift(run)+Z/Enter(interact), trail de tiles para follower, lock de input via EventBus (dialog/battle)
- **2.4** `NpcEntity.gd` — patrol por waypoints com wait, `start_dialog()` emite `dialog_started` + `npc_dialog_requested`
- Cenas `.tscn`: `TrainerEntity.tscn`, `PokemonEntity.tscn`, `NpcEntity.tscn` em `scenes/entities/`
- EventBus: adicionados `wild_encounter_started`, `battle_started`, `battle_ended`, `player_tile_entered`, `dialog_started`, `dialog_ended`, `npc_dialog_requested`
- Input Map: adicionado `run` (Shift)

### Decisões arquiteturais (Sprint 2)
- Collision layers: 2=player, 4=pokemon/npc, 5=world+player (mask para entidades)
- `dialogue_*` (com linhas já carregadas) vs `dialog_*` (gatilho de início sem conteúdo) — coexistem no EventBus
- Follower trail: TRAIL_LENGTH=4 tiles de delay, posição calculada sobre o array de tiles percorridos
- NPC não responde a `_on_interact_with` (base) — aguarda `start_dialog()` chamado pelo WorldManager após detectar `interaction_triggered`

---

## Sessão 2026-04-09 (continuação)

### O que foi feito (Sprint 3 — COMPLETO)
- **3.1** `WorldManager.gd` (autoload) — registra TileMap+Player, `is_tile_walkable()` (custom_data "blocked" > physics polygon > tile vazio), warp entre mapas, roteia `interaction_triggered` → `NpcEntity.start_dialog()`
- **3.2** `BaseMap.gd` — script base para cenas de mapa: registra no WorldManager em `_ready()`, desregistra em `_exit_tree()`
- **3.3** `PokemonSpawner.gd` — spawn por peso (campo `weight` do spawns.json), max_spawns, spawn_radius, respawn_interval, cleanup de pokémons em batalha
- **3.4** `PalletTown.tscn` — estrutura: TileMap + Entities/Player + Camera2D + Professor Oak (NPC) + PokemonSpawner
- **3.5** Camera2D filho do Player (zoom=2x), position_smoothing, limits placeholder
- `BaseEntity._is_tile_walkable` delegado ao WorldManager (sem fallback Engine.has_singleton — WorldManager sempre disponível como autoload)
- `GameData.get_biome_spawns()` adicionado como alias de `get_spawns()`
- WorldManager registrado como 5º autoload no project.godot

### Pendências (bloqueadas por assets)
- `PalletTown.tscn` referencia `res://assets/tilesets/overworld.tres` — precisa ser criado no Godot Editor
- Camera2D limits são placeholder (1280×720) — ajustar ao tamanho real do mapa pintado

### Próxima tarefa
**Sprint 4 — Sistema de Batalha:**
- 4.1 `BattleManager.gd` (autoload) — orquestra batalhas selvagens e de treinadores
- 4.2 `BattleState.gd` — dados do combate (HP, status, turno, fila de ações)
- 4.3 `BattleScene.tscn` — UI de batalha: HUD, animações, caixa de diálogo
- 4.4 Lógica de turno: seleção de ação, cálculo de dano, status, PP
- 4.5 Sistema de captura: catch rate, animação da Pokébola
### Problemas encontrados
- `run` estava faltando no input map do project.godot — adicionado (Shift)
- EventBus tinha `dialogue_started/ended` mas scripts novos usavam `dialog_started/ended` — ambos coexistem agora com semânticas distintas

---

## Sessão 2026-04-10 (Sprint 8 — Visual Polish)

### O que foi feito (Sprint 8 — COMPLETO)
- **8.1** `assets/generate_assets.py` — gerador Python (PIL): overworld.png (128×32 tileset 4+4 tiles), player.png (48×64 spritesheet 4dir×3frames), npc_default/npc_oak/npc_nurse.png, mon_001..151.png (32×16 2 frames), placeholder.png
- **8.2** `assets/tilesets/overworld.tres` — TileSet resource texto Godot 4: TileSetAtlasSource, 8 tiles walkable (row 0) + 8 tiles blocked (row 1 com custom_data_0="blocked"=true)
- **8.3** `scripts/world/MapLayouts.gd` — layouts procedurais em GDScript: PalletTown 50×40 tiles, Route1 20×60 tiles, PokéCenter 16×14 tiles. API: paint(tilemap, map_id), get_pixel_bounds(map_id)
- **8.4** `scripts/world/BaseMap.gd` — _paint_tiles() + _apply_camera_limits() em _ready() antes de register_map
- **8.5** `scripts/entities/SpriteBuilder.gd` — build_entity_frames(tex_path) retorna SpriteFrames com idle_down/up/left/right + walk_down/up/left/right. build_pokemon_frames(species_id) retorna SpriteFrames de Pokémon
- **8.6** TrainerEntity._load_sprites(), NpcEntity._load_sprites() (sprite por npc_name), PokemonEntity._load_sprites() — todos chamados em _on_ready()
- **8.7** Camera2D limits ajustados nas .tscn (Pallet 800×640, Route1 320×960, PokéCenter 256×224). Spawn tiles e posições de NPCs corrigidos para bater com layouts reais
- **8.8** WorldManager._shake_camera() + play_sfx("encounter") em wild encounters

### Tamanhos finais dos mapas
- PalletTown: 50×40 tiles = 800×640 px (player spawn: tile 11,22)
- Route1: 20×60 tiles = 320×960 px (player spawn: tile 9,55)
- PokéCenter: 16×14 tiles = 256×224 px (player spawn: tile 7,11)

### Pendências restantes (não bloqueantes)
- assets/audio/ vazio — AudioManager usa push_warning (não crash)
- overworld.tres precisa ser validado no Godot Editor (campo custom_data do TileSet)

### Próxima tarefa
**Sprint 9 — Loop de Jogo Completo:**
- 9.1 Auto-save em map_changed + battle_ended
- 9.2 PokéDex UI (lista seen/caught)
- 9.3 GameOver scene (time todo fainted)
- 9.4 BagScene polish (filtro por categoria)
- 9.5 Tela de créditos / win condition
- 9.6 QA pass — pending issues finais
