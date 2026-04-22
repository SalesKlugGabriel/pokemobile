# PokéMobile — World Design Document
## Arquitetura do Mundo Seamless | Kanto + Regiões Futuras

---

## ARQUITETURA TÉCNICA DO MUNDO SEAMLESS

### Cena principal: KantoWorld.tscn

```
KantoWorld (Node2D)
├── WorldEnvironment
├── Camera2D (com dead zone 96×72)
├── TileMapLayer_Ground        # layer 0 — terreno base (grama, água, areia, neve)
├── TileMapLayer_Details       # layer 1 — detalhes do terreno (flores, pedras pequenas)
├── TileMapLayer_Objects       # layer 2 — objetos mid (arbustos, troncos, cercas)
├── TileMapLayer_Buildings     # layer 3 — construções (casas, ginásios, pokemon centers)
├── TileMapLayer_Roof          # layer 4 — telhados (renderizados acima do jogador)
├── TileMapLayer_Collision     # layer 5 — colisão + triggers invisíveis (zona de spawn, portais)
├── Entities (Node2D)
│   ├── Trainer (CharacterBody2D)
│   ├── PokemonFollower (CharacterBody2D)
│   ├── WildPokemons (Node2D)  # instâncias dinâmicas
│   └── NPCs (Node2D)          # instâncias dinâmicas
├── ChunkLoader
├── ZoneManager
├── HUD (CanvasLayer)
└── AudioManager (local)
```

### 6 Camadas TileMapLayer
| Layer | Nome | Z-index | Descrição |
|-------|------|---------|-----------|
| 0 | Ground | -10 | Terreno base: grama, água, areia, lava, neve |
| 1 | Details | -9 | Flores, sombras, variações de textura |
| 2 | Objects | -5 | Árvores, arbustos, pedras, fences |
| 3 | Buildings | 0 | Casas, ginásios, caves — frente |
| 4 | Roof | 10 | Telhados (y-sort ou layer fixa acima do player) |
| 5 | Collision | 999 | Invisível: CollisionPolygon2D + Area2D triggers |

### Tilemap de Kanto
- **Tamanho total**: 500 × 380 tiles
- **tile_size**: 32 × 32 pixels
- **Tamanho em pixels**: 16.000 × 12.160 px
- **Tileset**: `kanto_overworld.png` + `kanto_interior.png`
- **Coordenada de origem**: (0, 0) = canto superior esquerdo do tilemap

---

## LAYOUT POSICIONAL DO MAPA — KANTO

### Cidades principais (tile coords do centro)

| Cidade | tile_x | tile_y | Notas |
|--------|--------|--------|-------|
| pallet_town | 50 | 162 | Spawn inicial do jogador |
| viridian_city | 50 | 112 | 1ª cidade, PokéMart completo |
| pewter_city | 50 | 60 | Ginásio 1 (Rock) |
| cerulean_city | 140 | 50 | Ginásio 2 (Water) |
| vermilion_city | 175 | 195 | Ginásio 3 (Electric), porto SS Anne |
| lavender_town | 250 | 90 | Pokémon Tower |
| celadon_city | 200 | 95 | Ginásio 4 (Grass), Dept Store |
| fuchsia_city | 175 | 250 | Ginásio 5 (Poison), Safari Zone |
| saffron_city | 210 | 145 | Ginásio 6 (Psychic), Silph Co. |
| cinnabar_island | 50 | 295 | Ginásio 7 (Fire), laboratório |
| indigo_plateau | 10 | 45 | Elite Four + Campeão |
| bills_house | 180 | 35 | Casa do Bill (pré-cerulean) |

### Posição de saída para Johto
- **Route 26/27/28**: borda direita do tilemap (tile_x ≈ 498, tile_y 5–25)
- Portal para Johto: tile (498, 10), (498, 22), (498, 5)

---

## ROTAS DE KANTO — COORDENADAS E SPECS

| Rota | Nome | Início (tile) | Fim (tile) | Bioma | Level Min | Level Max | Largura | Comprimento |
|------|------|---------------|------------|-------|-----------|-----------|---------|-------------|
| Route 1 | Rota 1 | (45,120) | (55,162) | plains | 2 | 5 | 20 | 42 |
| Route 2 | Rota 2 | (45,65) | (55,112) | plains | 3 | 9 | 20 | 47 |
| Route 3 | Rota 3 | (55,58) | (110,60) | plains | 10 | 14 | 40 | 5 |
| Route 4 | Rota 4 | (110,55) | (140,58) | plains | 13 | 16 | 35 | 8 |
| Route 5 | Rota 5 | (200,100) | (210,140) | plains | 14 | 17 | 15 | 45 |
| Route 6 | Rota 6 | (200,145) | (210,195) | plains | 15 | 18 | 15 | 55 |
| Route 7 | Rota 7 | (160,95) | (200,100) | plains | 18 | 22 | 45 | 10 |
| Route 8 | Rota 8 | (210,95) | (250,100) | plains | 20 | 25 | 45 | 10 |
| Route 9 | Rota 9 | (140,55) | (220,60) | rocky | 22 | 26 | 85 | 8 |
| Route 10 | Rota 10 | (220,60) | (250,100) | rocky | 22 | 32 | 8 | 42 |
| Route 11 | Rota 11 | (210,145) | (250,150) | coastal | 17 | 20 | 45 | 8 |
| Route 12 | Rota 12 | (250,90) | (255,180) | coastal | 18 | 22 | 8 | 95 |
| Route 13 | Rota 13 | (200,245) | (255,250) | coastal | 20 | 24 | 58 | 8 |
| Route 14 | Rota 14 | (250,195) | (255,250) | coastal | 20 | 24 | 8 | 58 |
| Route 15 | Rota 15 | (175,245) | (200,250) | plains | 22 | 26 | 28 | 8 |
| Route 16 | Rota 16 | (145,95) | (180,100) | plains | 20 | 24 | 38 | 8 |
| Route 17 | Rota 17 | (145,100) | (175,195) | cycling_road | 22 | 28 | 35 | 100 |
| Route 18 | Rota 18 | (145,195) | (175,200) | plains | 22 | 26 | 33 | 8 |
| Route 19 | Rota 19 | (145,250) | (175,255) | water | 25 | 30 | 33 | 8 |
| Route 20 | Rota 20 | (50,255) | (145,260) | water | 28 | 35 | 98 | 8 |
| Route 21 | Rota 21 | (50,255) | (55,295) | water | 25 | 32 | 8 | 42 |
| Route 22 | Rota 22 | (10,110) | (45,115) | plains | 2 | 5 | 38 | 8 |
| Route 23 | Rota 23 | (10,45) | (15,110) | mountain | 42 | 50 | 8 | 68 |
| Route 24 | Rota 24 | (140,35) | (180,50) | plains | 13 | 17 | 43 | 18 |
| Route 25 | Rota 25 | (180,30) | (200,50) | coastal | 13 | 17 | 22 | 22 |

---

## ZONAS ESPECIAIS

| Zona | Tile Bounds | Descrição |
|------|-------------|-----------|
| viridian_forest | x:35-65, y:65-112 | Floresta dentro de Route 2, lv3-15 |
| nugget_bridge | x:140, y:40-55 | Ponte com 5 trainers + Rocket |
| cycling_road | x:145-175, y:100-195 | Route 17, velocidade forçada de bicicleta |
| safari_zone | x:150-175, y:255-295 | Área especial com timer e Safari Balls |
| seafoam_north | x:50-90, y:260-280 | Entrada norte das Seafoam Islands |
| cinnabar_lab | x:40-60, y:290-300 | Laboratório com fossils e diário de Mewtwo |
| silph_co_entrance | x:205-215, y:138-148 | Entrada do prédio de 11 andares |
| power_plant_entrance | x:240-255, y:82-95 | Usina com Pokémons elétricos |
| ss_anne_dock | x:165-185, y:193-200 | Porto de Vermilion |

---

## SISTEMA DE CHUNKS

### Configuração
```gdscript
const CHUNK_SIZE = 32      # tiles por chunk (1024×1024 px)
const LOAD_RADIUS = 5      # chunks ao redor do jogador carregados
const UNLOAD_RADIUS = 8    # chunks além desta distância descarregados
const SPAWN_TICK = 3.0     # segundos entre verificações de spawn
```

### ChunkLoader.gd — Lógica
```gdscript
func _get_player_chunk() -> Vector2i:
    var tile_pos = world_to_tile(player.global_position)
    return Vector2i(tile_pos.x / CHUNK_SIZE, tile_pos.y / CHUNK_SIZE)

func _update_chunks():
    var center = _get_player_chunk()
    for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
        for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
            var chunk = center + Vector2i(dx, dy)
            if not loaded_chunks.has(chunk):
                _load_chunk(chunk)
    for chunk in loaded_chunks.keys():
        if center.distance_to(chunk) > UNLOAD_RADIUS:
            _unload_chunk(chunk)
```

### ZoneManager.gd — Spawn
```gdscript
func _spawn_pokemon_in_zone(zone: Dictionary):
    var active_spawns = get_spawn_count(zone.id)
    var max_spawns = zone.get("max_spawns", 8)
    if active_spawns >= max_spawns: return
    
    var entry = _weighted_random(zone.spawn_table)
    var pos = _random_walkable_pos(zone.bounds)
    _instantiate_wild_pokemon(entry.pokemon_id, zone.level_min, zone.level_max, pos, entry.behavior)
```

---

## DUNGEONS DE KANTO

### Dungeons no Overworld (seamless, sem transição de cena)

**viridian_forest**
- Parte do tilemap principal (x:35-65, y:65-112)
- Iluminação reduzida (shader de sombra de floresta)
- Saídas: norte (Pewter) e sul (Viridian City)
- Lv 3–15: Caterpie, Weedle, Pikachu (raro), Metapod, Kakuna

### Dungeons com cena separada (KantoDungeons.tscn)

**mt_moon**
- Andares: B1, B2, B3
- Entrada: Route 3 (tile ~110, 58)
- Saída: Route 4 (tile ~140, 56)
- B1 (lv8-14): Zubat, Geodude
- B2 (lv12-18): Zubat, Geodude, Clefairy (raro)
- B3 (lv15-20): Zubat, Geodude, Clefairy, Paras — Boss: Super Nerd com Kabuto/Omanyte Fossil
- Puzzle: escolha entre Dome Fossil (Kabuto) e Helix Fossil (Omanyte) na saída

**rock_tunnel**
- Andares: B1, B2
- Entrada: Route 10 norte
- Saída: Route 10 sul (Lavender lado)
- Escuro sem HM05 (Flash) — visão limitada a 3 tiles raio
- B1 (lv22-28): Zubat, Geodude, Onix, Machop
- B2 (lv25-32): Zubat, Graveler, Onix, Machop, Geodude

**pokemon_tower**
- Andares: 1F ao 7F (escada por escada)
- Localização: Lavender Town centro
- 1F–3F: Gastly, Haunter (lv22-28) — Pokémons fantasmas
- 4F–6F: Gastly, Haunter, Cubone (lv25-32) — Rockets bloqueando
- 7F: Boss Rocket + Sr. Fuji resgatado — requer Silph Scope para ver fantasmas
- Drop especial 7F: Poke Flute (quest MAIN-09)

**safari_zone**
- Área especial: mecânica própria (Safari Balls only, timer 30min real)
- Zonas internas (A, B, C, D) com pokémons raros
- Zona A (lv25-30): Nidoran♂, Nidoran♀, Paras, Doduo, Exeggcute
- Zona B (lv28-35): Rhyhorn, Kangaskhan (raro), Scyther/Pinsir (exclusivos)
- Zona C (lv30-38): Tauros, Chansey (raro), Dragonair (extremamente raro)
- Zona D (lv25-32): Slowpoke, Psyduck, Magikarp (pesca)
- Pesca com Super Rod: Dratini (lago central, lv15-20, raro)

**seafoam_islands**
- Andares: 1F, B1, B2, B3, B4
- Entrada: Route 20
- Saída: Route 19 (oeste) ou Route 21 (leste)
- Puzzle: empurrar pedras para desviar corrente d'água (HM04 Strength necessário)
- B1–B3 (lv28-40): Zubat, Golbat, Seel, Dewgong, Slowpoke, Psyduck
- B4 (lv35-45): Seel, Dewgong, Slowbro — Boss: Articuno (lv50, respawn 72h)

**power_plant**
- Andar único (planta elétrica)
- Entrada: Route 10 (requer Surf)
- Sem saída normal — teleporte de emergência se perder
- lv30-45: Voltorb, Electrode, Magnemite, Magneton, Electabuzz (raro)
- Boss final: Zapdos (lv50, respawn 72h)

**pokemon_mansion**
- Andares: 1F, 2F, 3F, B1
- Localização: Cinnabar Island
- Ruínas queimadas — ambiente dark
- lv30-42: Growlithe (Red/Blue) ou Vulpix (versão exclusiva), Koffing, Weezing, Grimer, Muk
- Chave para Cinnabar Gym está na B1
- Logs de pesquisa sobre Mewtwo (lore — colecionável)
- Boss: Blaine antes do Gym? (opcional — evento especial)

**victory_road**
- Andares: 1F, 2F, 3F
- Entrada: Route 23 (sul de Indigo Plateau)
- Requer todos os 8 Badges
- Puzzle: mover pedras com Strength por andares
- lv40-50: Zubat, Golbat, Onix, Graveler, Machoke, Rhyhorn, Venomoth
- Boss: treinadores especiais de alto nível em cada andar
- 3F topo: Moltres (lv50, respawn 72h)

**cerulean_cave**
- Andares: 1F, B1, B2
- Entrada: Route 4 lado de Cerulean (desbloqueada após ser Campeão)
- lv55-65: Chansey, Parasect, Ditto, Golbat, Graveler
- B2: Mewtwo (lv70, respawn semanal 168h)

**silph_co**
- Andares: 1F ao 11F + Telhado
- Localização: Saffron City centro
- Tomada pela Team Rocket (MAIN-11)
- Sistema de teleporters internos (puzzle de navegação)
- Cada andar: Rockets + Pokémons tipo Poison/Normal (lv30-45)
- 7F: Rival fight (segundo encontro avançado)
- 11F Boss: Giovanni final (antes do Viridian Gym)
- Telhado: NPC entrega Master Ball após libertar

**rocket_hideout**
- Andares: B1, B2, B3, B4 (sob Celadon Game Corner)
- Entrada: alavanca secreta no Game Corner
- B1–B3 (lv25-38): Rocket Grunts + Zubat, Koffing, Raticate
- B4: Giovanni first encounter (MAIN-10)
- Drop: Silph Scope (obrigatório para Pokemon Tower)

**ss_anne**
- Navio com múltiplos decks (1F, 2F, 3F + Deck superior)
- Em porto de Vermilion por tempo limitado (quest MAIN-07)
- Não é dungeon — é área de evento com trainers e itens
- Capitão no Camarote Superior: ensina HM01 (Cut)
- Rival fight: 2F

**digletts_cave**
- Andar único, túnel conectando Route 2 (sul) a Route 11 (leste de Pewter)
- tile bounds: x:60-175, y:112-150 (diagonal no tilemap)
- lv12-22: Diglett (90%), Dugtrio (10%)
- Muito estreito: sem pokémons voadores ou aquáticos

---

## REGIÕES FUTURAS

| # | Região | Geração | Status | Pokémons | Porta de Entrada |
|---|--------|---------|--------|----------|-----------------|
| 1 | Kanto | 1 | active | #1–151 | — (inicial) |
| 2 | Johto | 2 | coming_soon | #152–251 | Route 26/27/28 (borda leste Kanto) |
| 3 | Hoenn | 3 | coming_soon | #252–386 | Navio de Vermilion (sea route) |
| 4 | Sinnoh | 4 | coming_soon | #387–493 | Portal em Mt. Moon B3 (era glacial) |
| 5 | Unova | 5 | coming_soon | #494–649 | Avião de Cerulean Airport (futuro) |
| 6 | Kalos | 6 | coming_soon | #650–721 | Trem de Saffron Station (futuro) |
| 7 | Alola | 7 | coming_soon | #722–809 | Navio de Cinnabar |
| 8 | Galar | 8 | coming_soon | #810–898 | Portal energético pós-Elite Four |
| 9 | Paldea | 9 | coming_soon | #899–1010 | Portal ultra-wormhole em Cerulean Cave |

### UI de Mapa-Múndi
- Acessível via HM02 (Fly) ou menu de mapa
- Mostra mapa esquemático de todas as regiões
- Regiões coming_soon: silhueta cinza com "Em Breve"
- Regiões ativas: coloridas com zoom ao clicar
- Marcadores: cidades visitadas, dungeons descobertas, portais conhecidos
- Fast travel (Fly): somente para cidades com Pokémon Center visitadas

---

## SPRINT 5B — MUNDO COMPLETO E REGIÕES

### Objetivo do Sprint 5B
Completar o mapa de Kanto com todas as zonas funcionais, implementar sistema de regiões e preparar infraestrutura para Johto.

### Tarefas

**5B.1 — Tilemap Kanto completo**
- Pintar todos os tiles faltantes no KantoWorld.tscn
- Verificar colisões em todas as zonas
- Testar passabilidade de todas as rotas
- Entregável: screenshot do mapa completo sem gaps

**5B.2 — ZoneManager com todas as zonas**
- Implementar zones.json completo
- ZoneManager.gd lendo spawn_table de cada zona
- Testar spawn em 5 zonas diferentes
- Entregável: Pokémons corretos spawnando nas zonas corretas

**5B.3 — Sistema de Dungeons**
- DungeonManager.gd com transições de andar
- Implementar Mt. Moon (3 andares)
- Implementar Rock Tunnel (2 andares, escuridão)
- Implementar Pokémon Tower (7 andares)
- Entregável: traversal completo de cada dungeon

**5B.4 — Sistema de Portais de Região**
- RegionPortal.tscn + script
- Loading screen entre regiões
- regions.json lido pelo WorldManager
- Testar portal Kanto → Johto (cena stub de Johto)

**5B.5 — Dungeons avançadas**
- Cerulean Cave (2 andares + Mewtwo)
- Seafoam Islands (4 andares + Articuno)
- Victory Road (3 andares + Moltres)
- Power Plant (Zapdos)

**5B.6 — Safari Zone**
- Mecânica de Safari Ball only
- Timer de 30 minutos in-game
- Safari Ball em arco (igual capture normal)
- 4 zonas internas com spawn tables

**5B.7 — SS Anne e Silph Co.**
- SS Anne como evento temporário (desparecer após MAIN-07)
- Silph Co. 11 andares com teleporters
- Rocket Hideout 4 andares

**5B.8 — NPCs e Quests integradas ao mundo**
- Posicionar todos os 54 quest givers no tilemap
- Testar cadeia completa de quests MAIN-01 a MAIN-12
- Dialog boxes com portraits de NPC
- Quest log funcional

**5B.9 — Mapa-Múndi UI**
- Tela de mapa com regiões coming_soon
- Integração com HM02 Fly
- Marcadores de localização do jogador em tempo real
- Zoom e pan no mapa

---

## UI DO MAPA-MÚNDI

### Layout
```
┌─────────────────────────────────────────────────────────┐
│  MAPA-MÚNDI POKEMON                         [X] Fechar  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   [KANTO]  →  [JOHTO]  →  [HOENN]  →  [SINNOH]        │
│   (ativo)     (breve)     (breve)     (breve)           │
│                  ↓                                       │
│              [UNOVA]  [KALOS]  [ALOLA]  [GALAR] [PALDEA]│
│              (breve)  (breve)  (breve)  (breve) (breve) │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  Região Atual: KANTO           Zona: Route 1            │
│  Pokémons registrados: 45/151  Emblemas: 2/8            │
└─────────────────────────────────────────────────────────┘
```

### Zoom de região (Kanto)
```
┌─────────────────────────────────────────────────────────┐
│  KANTO ← Voltar                              [Fly] [X]  │
├─────────────────────────────────────────────────────────┤
│  [mapa esquemático com cidades e rotas marcadas]         │
│                                                          │
│  • Pallet Town ✓     • Vermilion City ✓                 │
│  • Viridian City ✓   • Lavender Town ✗                  │
│  • Pewter City ✓     • Celadon City ✗                   │
│  • Cerulean City ✓   • Fuchsia City ✗                   │
│                                                          │
│  [Você está aqui: Route 1 — ★]                          │
└─────────────────────────────────────────────────────────┘
```

### Componentes GDScript (Map.gd)
```gdscript
func _open_world_map():
    map_panel.visible = true
    _render_regions()
    _mark_player_position()

func _render_regions():
    for region in DataLoader.get_regions():
        var btn = _create_region_button(region)
        if region.status == "coming_soon":
            btn.disabled = true
            btn.modulate = Color(0.4, 0.4, 0.4)
        regions_container.add_child(btn)

func _on_fly_pressed():
    var visited = GameState.visited_cities
    _show_fly_destination_picker(visited)
    
func _teleport_to(city_id: String):
    var zone = DataLoader.get_zone(city_id)
    player.global_position = tile_to_world(zone.player_spawn)
    map_panel.visible = false
    AudioManager.play_bgm(zone.bgm)
```
