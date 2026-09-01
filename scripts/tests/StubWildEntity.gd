## StubWildEntity.gd — dublê mínimo de WildPokemon pra testes headless de
## BattleManager: só o campo que BattleManager._on_wild_encounter_started()
## lê (zone_id), sem nenhum _ready()/dependência de autoload (WildPokemon.gd
## de verdade tem _ready() que referencia EventBus direto — instanciar via
## .new() num script --script bruto, fora da árvore de cena, esbarra numa
## resolução de identifier global que só funciona ao entrar na árvore de
## verdade; mesma limitação documentada em StubBattleScene/teste_fase2_safari).
extends Node

@export var zone_id    : String = ""
@export var species_id : int    = 1
@export var level      : int    = 5
