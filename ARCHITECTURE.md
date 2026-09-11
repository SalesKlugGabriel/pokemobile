# Arquitetura — mapa do código atual

Referência inspecionada: commit `ed8ddeb`, 11/09/2026. Ver handoff para diferenças
em andamento. Godot instalado: 4.2.2; entrada `scenes/ui/TitleScreen.tscn`.
O jogo é um RPG de ação em tempo real, single-player, com export web/mobile.

| Camada | Implementação existente |
|---|---|
| Dados | `data/pokemon/species.json`, `data/moves/moves.json`, `data/world/zones.json`, carregados por `GameData` |
| Persistência | `scripts/autoloads/SaveManager.gd`; apresentação não inventa estado salvo |
| Eventos | `scripts/autoloads/EventBus.gd`; conferir assinaturas antes de conectar |
| Combate | `scripts/combat/`, `FollowerPokemon.gd`, `WildPokemon.gd`; ver docs/combat.md |
| Mundo | `scripts/world/MapLayouts.gd`, `BaseMap.gd`, `WorldManager.gd`, `scenes/world/maps/` |
| UI | `scripts/ui/`, `scenes/ui/`, autoload `GlobalUI`, componentes associados aos mapas |
| Arte | `assets/tilesets/overworld.png` + `.tres`, `assets/sprites/`, geradores em `tools/` |
| Editor externo | `/root/pokemobile-editor`; mapas/sprites/feedback, dados em `/root/pokemobile-editor-data` |

`project.godot` declara os autoloads reais. `BattleResolver` e `CaptureSystem` são
autoloads do combate atual; não recriar o antigo motor de turnos.
MapLayouts pinta o terreno; BaseMap aplica overrides, monta telhados e conecta os
sistemas. Alteração visual deve preservar atlas/colisão, sem refazer a geografia.

## Validação

Rodar na worktree correta; uma importação nova pode precisar de segunda passagem
para atualizar o cache de `class_name` antes de interpretar os testes.

```bash
godot4 --headless --editor --import --quit
godot4 --headless --script res://scripts/tests/teste_tudo_compila.gd
godot4 --headless --script res://scripts/tests/teste_fase2_combate.gd
```

Para suíte completa, `tools/rodar_testes.sh` verifica código de saída e marcador
de resultado. Seu log é `/tmp/saida_teste.txt`: não executar duas instâncias em
paralelo no mesmo servidor. Preferir logs exclusivos por worktree ao orquestrar.
Erro de script/compilação reprova, mesmo que o Godot termine com código zero.

Visual exige navegador real além de headless: desktop, mobile, resize, clique/toque,
comparação antes/depois. Não confundir screenshots de galeria com gameplay real.
`tools/exportar_web.sh` faz o export com carimbo e ponte de toque obrigatória.
Não chamar um export cru de build final jogável para celular.

## Publicação e sincronização

O serviço observado foi `pokemobile_pokemobile_app`, imagem `pokemobile:latest`;
`/root/pokemobile.yaml` ainda menciona `pokemobile-app:latest`. Consultar definição
efetiva antes de publicar. Nenhum deploy é necessário para validar docs.
Integrar commits revisados, não copiar builds sobre a worktree ativa de outro agente.

Detalhes: [combate](docs/combat.md), [UI](docs/frontend-ui.md),
[arte](docs/art-direction.md), [mundo](docs/world-design.md),
[passagem de trabalho](docs/agent-handoff.md).
